#!/usr/bin/env bash
# OpenCode-Adapter — führt EINE Aufgabe aus.
#
# Vertrag: siehe adapters/README.md
#   Eingabe  über TASK_*-Umgebungsvariablen
#   Ausgabe  genau eine Zeile JSON auf stdout, Logs auf stderr
#
# Nicht ermittelbare Felder werden `null`, niemals geschätzt: Eine erfundene
# Zahl verfälscht den Harness-Vergleich still, eine fehlende nicht.

set -uo pipefail

LAB_ROOT="${LAB_ROOT:-/opt/agent-lab}"
HARNESS="opencode"

: "${TASK_ID:?fehlt}"
: "${TASK_PROMPT:?fehlt}"
: "${TASK_REPO:?fehlt}"
: "${TASK_BRANCH:?fehlt}"
: "${TASK_ROLE:=strong}"

log() { echo "[$HARNESS] $*" >&2; }

# Rolle → Modell aus der zentralen Konfiguration. Der Adapter kennt keine
# Modellnamen; er fragt die Config. So bleibt ein Modellwechsel eine Zeile
# in models.yaml.
# TASK_MODEL ueberschreibt — siehe adapters/README.md.
MODEL="${TASK_MODEL:-}"
[ -n "$MODEL" ] || MODEL=$(python3 - "$LAB_ROOT/config/models.yaml" "$TASK_ROLE" <<'PY'
import sys, yaml
cfg = yaml.safe_load(open(sys.argv[1]))
role = cfg["roles"].get(sys.argv[2]) or {}
prov, model = role.get("provider"), role.get("model")
print(f"{prov}/{model}" if prov and model else "")
PY
)

if [ -z "$MODEL" ]; then
  log "Rolle '$TASK_ROLE' hat kein Modell für diesen Harness"
  python3 -c "import json,sys;print(json.dumps({'task_id':sys.argv[1],'harness':sys.argv[2],'model':None,'exit_code':78,'error':'rolle_ohne_modell','duration_s':0,'turns':None,'tokens_in':None,'tokens_out':None,'cost_usd':None,'branch':None,'commits':0}))" "$TASK_ID" "$HARNESS"
  exit 0
fi

cd "$TASK_REPO" || { log "Arbeitsverzeichnis fehlt: $TASK_REPO"; exit 1; }

git rev-parse --git-dir >/dev/null 2>&1 || { log "kein git-Repo: $TASK_REPO"; exit 1; }
BEFORE=$(git rev-parse HEAD 2>/dev/null || echo "")
git checkout -q -B "$TASK_BRANCH" 2>/dev/null || log "Branch-Wechsel fehlgeschlagen, arbeite auf HEAD"

EVENTS=$(mktemp); trap 'rm -f "$EVENTS"' EXIT
START=$(date +%s)

log "Modell $MODEL, Branch $TASK_BRANCH"
timeout "${TASK_TIMEOUT:-3600}" opencode run \
  --model "$MODEL" --format json "$TASK_PROMPT" > "$EVENTS" 2>>/dev/stderr
EXIT=$?

END=$(date +%s)

AFTER=$(git rev-parse HEAD 2>/dev/null || echo "")
if [ -n "$BEFORE" ] && [ -n "$AFTER" ]; then
  COMMITS=$(git rev-list --count "${BEFORE}..${AFTER}" 2>/dev/null || echo 0)
else
  COMMITS=0
fi

# Ereignisstrom auswerten. Jede Zeile ist ein JSON-Objekt; `step_finish`
# trägt Token und Kosten, `step_start` zählt die Runden.
python3 - "$EVENTS" "$TASK_ID" "$HARNESS" "$MODEL" "$EXIT" "$((END-START))" "$TASK_BRANCH" "$COMMITS" <<'PY'
import json, sys

path, task_id, harness, model, exit_code, dur, branch, commits = sys.argv[1:9]

turns = 0
tin = tout = 0
cost = 0.0
saw_usage = False

for line in open(path, encoding="utf-8", errors="replace"):
    line = line.strip()
    if not line:
        continue
    try:
        ev = json.loads(line)
    except json.JSONDecodeError:
        continue
    t = ev.get("type")
    if t == "step_start":
        turns += 1
    elif t == "step_finish":
        part = ev.get("part") or {}
        tk = part.get("tokens") or {}
        if tk:
            saw_usage = True
            tin += tk.get("input") or 0
            tout += tk.get("output") or 0
        c = part.get("cost")
        if isinstance(c, (int, float)):
            cost += c

print(json.dumps({
    "task_id": task_id,
    "harness": harness,
    "model": model,
    "exit_code": int(exit_code),
    "duration_s": int(dur),
    "turns": turns or None,
    # Ohne Nutzungsdaten null statt 0 — "nicht gemessen" ist etwas anderes
    # als "nichts verbraucht", und nur der Unterschied macht den Vergleich
    # ehrlich.
    "tokens_in": tin if saw_usage else None,
    "tokens_out": tout if saw_usage else None,
    # Bei Abo-Abrechnung ist das kein Rechnungsbetrag, sondern der Massstab
    # fuer den Kontingentverbrauch. Genau die Zahl, die zaehlt, wenn Geld
    # nicht mehr die knappe Ressource ist.
    "cost_usd": round(cost, 6) if saw_usage else None,
    "branch": branch,
    "commits": int(commits),
}))
PY
