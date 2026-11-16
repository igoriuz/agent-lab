#!/usr/bin/env bash
# Führt EINE Aufgabe mit EINER Harness/Modell-Paarung aus und misst das
# Ergebnis an Tests statt an Meinungen.
#
#   eval-run.sh <aufgabe> <harness> <modell>
#   eval-run.sh S-wiederholgrenze oh-my-pi xai-oauth/grok-4.6
#
# Ablauf:
#   1. frische Kopie des Testprojekts, node_modules aus dem Cache verlinkt
#   2. git init + Ausgangscommit
#   3. Agent laeuft mit dem Aufgabentext
#   4. DANACH erst wird der verdeckte Pruefteil eingespielt
#   5. Typpruefung, bestehende Tests, Pruefteil
#
# Der Pruefteil kommt bewusst erst nach dem Lauf ins Projekt: Sonst koennte
# der Agent gegen die Pruefung hin optimieren statt die Aufgabe zu loesen —
# und das Ergebnis waere wertlos.

set -uo pipefail

LAB="${LAB_ROOT:-/opt/agent-lab}"
AUFGABE="${1:?Aufgabe fehlt}"
HARNESS="${2:?Harness fehlt}"
MODELL="${3:?Modell fehlt}"

AUFG_DIR="$LAB/evals/aufgaben/$AUFGABE"
[ -d "$AUFG_DIR" ] || { echo "Unbekannte Aufgabe: $AUFGABE" >&2; exit 1; }

CACHE="$HOME/.cache/agent-lab/node_modules"
LAUF_ID="${AUFGABE}-${HARNESS}-$(echo "$MODELL" | tr '/' '-')"
ARBEIT="/workspaces/eval-$LAUF_ID"

log() { echo "[eval] $*" >&2; }

# --- 1. Arbeitskopie ------------------------------------------------------
rm -rf "$ARBEIT"
cp -r "$LAB/evals/testprojekt" "$ARBEIT"
cd "$ARBEIT" || exit 1

if [ -d "$CACHE" ]; then
  ln -s "$CACHE" node_modules
else
  log "node_modules-Cache fehlt, installiere einmalig…"
  npm install --silent --no-audit --no-fund >/dev/null 2>&1
  mkdir -p "$(dirname "$CACHE")"
  cp -r node_modules "$CACHE"
fi

# --- 2. Ausgangszustand ---------------------------------------------------
git init -q
git config user.email agent@lab.local
git config user.name "agent-lab"
git add -A
git commit -q -m "Ausgangszustand"

# --- 3. Agent -------------------------------------------------------------
export TASK_ID="$LAUF_ID"
export TASK_REPO="$ARBEIT"
export TASK_BRANCH="eval/$LAUF_ID"
export TASK_ROLE=strong
export TASK_MODEL="$MODELL"
export TASK_PROMPT="$(cat "$AUFG_DIR/AUFGABE.md")"
export TASK_TIMEOUT="${TASK_TIMEOUT:-1800}"

METRIK=$("$LAB/adapters/$HARNESS/run.sh" 2>/dev/null)

# --- 4. Verdeckter Pruefteil ---------------------------------------------
if [ -f "$AUFG_DIR/pruefung.test.ts" ]; then
  cp "$AUFG_DIR/pruefung.test.ts" src/__tests__/zz-pruefung.test.ts
fi

# --- 5. Bewertung ---------------------------------------------------------
TYPEN=nein
npx tsc --noEmit >/dev/null 2>&1 && TYPEN=ja

JEST_OUT=$(npx jest --silent --json 2>/dev/null | tail -1)

python3 - "$METRIK" "$JEST_OUT" "$TYPEN" "$AUFGABE" <<'PY'
import json, sys

metrik_raw, jest_raw, typen, aufgabe = sys.argv[1:5]

try:
    metrik = json.loads(metrik_raw)
except Exception:
    metrik = {"error": "adapter_ohne_json"}

bestanden = fehlgeschlagen = None
pruefteil_ok = None
try:
    j = json.loads(jest_raw)
    bestanden = j.get("numPassedTests")
    fehlgeschlagen = j.get("numFailedTests")
    # Der verdeckte Pruefteil separat: Er allein beantwortet, ob die
    # Aufgabe geloest wurde. Die uebrigen Tests sagen nur, dass nichts
    # kaputtging.
    for suite in j.get("testResults", []):
        if "zz-pruefung" in suite.get("name", ""):
            pruefteil_ok = suite.get("status") == "passed"
except Exception:
    pass

# Erfolg heisst: Aufgabe geloest UND nichts kaputtgemacht UND Typen stimmen.
erfolg = bool(pruefteil_ok) and fehlgeschlagen == 0 and typen == "ja"

metrik.update({
    "aufgabe": aufgabe,
    "typen_ok": typen == "ja",
    "tests_bestanden": bestanden,
    "tests_fehlgeschlagen": fehlgeschlagen,
    "pruefteil_bestanden": pruefteil_ok,
    "erfolg": erfolg,
})
print(json.dumps(metrik))
PY
