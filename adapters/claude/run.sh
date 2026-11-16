#!/usr/bin/env bash
# Claude-Code-Adapter — führt EINE Aufgabe aus.
#
# Vertrag: siehe adapters/README.md
#   Eingabe  über TASK_*-Umgebungsvariablen
#   Ausgabe  genau eine Zeile JSON auf stdout, Logs auf stderr

set -uo pipefail

export PATH="$HOME/.local/bin:$PATH"
LAB_ROOT="${LAB_ROOT:-/opt/agent-lab}"
HARNESS="claude"

: "${TASK_ID:?fehlt}"
: "${TASK_PROMPT:?fehlt}"
: "${TASK_REPO:?fehlt}"
: "${TASK_BRANCH:?fehlt}"
: "${TASK_ROLE:=strong}"

log() { echo "[$HARNESS] $*" >&2; }

# CLAUDE_CODE_OAUTH_TOKEN aus .env holen, falls nicht schon gesetzt.
#
# WARUM DAS HIER STEHT UND NICHT BEIM AUFRUFER:
# Ohne den Token antwortet Claude Code mit "Not logged in · Please run /login"
# — und zwar mit is_error im JSON, nicht mit einem Absturz. Der Lauf wird
# dadurch als FEHLGESCHLAGENE AUFGABE verbucht statt als fehlende
# Anmeldung. Ein Modell sieht dann schwach aus, obwohl nie eines gefragt
# wurde. Dieselbe Klasse von Messfehler wie die mitgezaehlten
# Build-Artefakte, nur schwerer zu bemerken, weil das Ergebnis plausibel
# aussieht.
#
# Deshalb laedt der Adapter die Zugangsdaten selbst und sagt LAUT, wenn sie
# fehlen, statt eine Messung zu erzeugen, die etwas anderes misst als
# behauptet.
if [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ] && [ -r "$LAB_ROOT/.env" ]; then
  # Nur diese eine Variable, nicht die ganze Datei: der Rest sind
  # Telegram- und Anbieterschluessel, die dieser Harness nicht braucht.
  CLAUDE_CODE_OAUTH_TOKEN=$(sed -n 's/^CLAUDE_CODE_OAUTH_TOKEN=//p' "$LAB_ROOT/.env" | head -1)
  export CLAUDE_CODE_OAUTH_TOKEN
fi
if [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
  log "WARNUNG: CLAUDE_CODE_OAUTH_TOKEN weder in der Umgebung noch in $LAB_ROOT/.env"
fi

fail_json() {
  python3 -c "
import json,sys
print(json.dumps({'task_id':sys.argv[1],'harness':sys.argv[2],'model':None,'exit_code':78,
'error':sys.argv[3],'duration_s':0,'turns':None,'tokens_in':None,'tokens_out':None,
'cost_usd':None,'branch':None,'commits':0}))" "$TASK_ID" "$HARNESS" "$1"
  exit 0
}

# Rolle → Modell aus der zentralen Konfiguration. Der Adapter kennt keine
# Modellnamen; er fragt die Config.
#
# TASK_MODEL ueberschreibt. Das braucht der Vergleich: Dasselbe Modell soll
# gegen einen anderen Harness antreten, unabhaengig davon, was die Rolle
# gerade vorsieht. Ohne diese Klammer laeuft der Adapter still mit seinem
# CLI-Standardmodell weiter — und man vergleicht Aepfel mit Birnen, ohne es
# zu merken.
MODEL="${TASK_MODEL:-}"
[ -n "$MODEL" ] || MODEL=$(python3 - "$LAB_ROOT/config/models.yaml" "$TASK_ROLE" <<'PY'
import sys, yaml
cfg = yaml.safe_load(open(sys.argv[1]))
role = cfg["roles"].get(sys.argv[2]) or {}
# Auch Fallbacks berücksichtigen: Wenn die Rolle primär woanders läuft,
# kann Claude trotzdem der hinterlegte Ausweichweg sein.
if role.get("harness") == "claude":
    print(role.get("model") or "")
elif (role.get("fallback") or {}).get("harness") == "claude":
    print((role["fallback"]).get("model") or "")
else:
    print("")
PY
)

[ -n "$MODEL" ] || log "kein explizites Modell für Rolle '$TASK_ROLE' — Claude-Standard"

# Effort gehört zur Rolle wie das Modell: Opus auf medium und Opus auf high
# sind zwei Rollen, nicht eine. TASK_EFFORT überschreibt, aus demselben Grund
# wie TASK_MODEL — die Ladder misst Paarungen, die keine Rolle vorsieht.
EFFORT="${TASK_EFFORT:-}"
[ -n "$EFFORT" ] || [ -n "${TASK_MODEL:-}" ] || EFFORT=$(python3 - "$LAB_ROOT/config/models.yaml" "$TASK_ROLE" <<'PY'
import sys, yaml
cfg = yaml.safe_load(open(sys.argv[1]))
role = cfg["roles"].get(sys.argv[2]) or {}
print(role.get("effort") or "" if role.get("harness") == "claude" else "")
PY
)

cd "$TASK_REPO" || fail_json "arbeitsverzeichnis_fehlt"
git rev-parse --git-dir >/dev/null 2>&1 || fail_json "kein_git_repo"

BEFORE=$(git rev-parse HEAD 2>/dev/null || echo "")
git checkout -q -B "$TASK_BRANCH" 2>/dev/null || log "Branch-Wechsel fehlgeschlagen, arbeite auf HEAD"

OUT=$(mktemp); trap 'rm -f "$OUT"' EXIT
START=$(date +%s)

# --permission-mode bypassPermissions ist hier notwendig und vertretbar:
# Ohne ihn wartet der Agent auf eine Freigabe, die niemand erteilt, und läuft
# in den Timeout. Vertretbar ist es, WEIL der Container unprivilegiert,
# vom Heimnetz trennbar und jederzeit neu aufsetzbar ist — nicht, weil das
# Risiko klein wäre. Auf einer Maschine mit Bestandsdaten wäre es falsch.
ARGS=(-p "$TASK_PROMPT" --output-format json --permission-mode bypassPermissions)
[ -n "$MODEL" ] && ARGS+=(--model "$MODEL")
[ -n "$EFFORT" ] && ARGS+=(--effort "$EFFORT")

log "Branch $TASK_BRANCH${MODEL:+, Modell $MODEL}${EFFORT:+, Effort $EFFORT}"
# stdin explizit schliessen. Ohne das wartet Claude Code 3 Sekunden auf
# Eingabe, die nie kommt, und schreibt eine Warnzeile VOR das JSON — was
# die Auswertung zerlegt und jeden Lauf unnoetig verlaengert.
timeout "${TASK_TIMEOUT:-3600}" claude "${ARGS[@]}" > "$OUT" 2>>/dev/stderr < /dev/null
EXIT=$?

END=$(date +%s)
AFTER=$(git rev-parse HEAD 2>/dev/null || echo "")
if [ -n "$BEFORE" ] && [ -n "$AFTER" ]; then
  COMMITS=$(git rev-list --count "${BEFORE}..${AFTER}" 2>/dev/null || echo 0)
else
  COMMITS=0
fi

python3 - "$OUT" "$TASK_ID" "$HARNESS" "$MODEL" "$EXIT" "$((END-START))" "$TASK_BRANCH" "$COMMITS" "$EFFORT" <<'PY'
import json, sys

path, task_id, harness, model, exit_code, dur, branch, commits, effort = sys.argv[1:10]

data = {}
try:
    raw = open(path, encoding="utf-8", errors="replace").read().strip()
    if raw:
        # --output-format json liefert ein einzelnes Objekt — aber es kann
        # Text davorstehen. Ab der ersten Klammer lesen, nicht ab Zeichen 0.
        start = raw.find("{")
        if start >= 0:
            data = json.loads(raw[start:])
except (json.JSONDecodeError, OSError):
    pass

usage = data.get("usage") or {}
have = bool(usage)

# Cache-Token zählen zur Eingabe: Sie sind verbrauchtes Kontingent, auch wenn
# sie billiger sind. Wer sie weglässt, unterschätzt den Verbrauch systematisch
# — und zwar genau bei den Harnesses, die gut cachen.
tin = None
if have:
    tin = (usage.get("input_tokens") or 0) \
        + (usage.get("cache_read_input_tokens") or 0) \
        + (usage.get("cache_creation_input_tokens") or 0)

cost = data.get("total_cost_usd")

# is_error ist aussagekräftiger als der Rückgabewert: Der Prozess endet auch
# bei einem API-Fehler mit 0.
if data.get("is_error") and int(exit_code) == 0:
    exit_code = 1

out = {
    "task_id": task_id,
    "harness": harness,
    "model": model or data.get("modelUsage") and next(iter(data["modelUsage"]), None) or None,
    "effort": effort or None,
    "exit_code": int(exit_code),
    "duration_s": int(dur),
    "turns": data.get("num_turns"),
    "tokens_in": tin,
    "tokens_out": usage.get("output_tokens") if have else None,
    "cost_usd": round(cost, 6) if isinstance(cost, (int, float)) else None,
    "branch": branch,
    "commits": int(commits),
}
if data.get("is_error"):
    out["error"] = (data.get("result") or "")[:200]

print(json.dumps(out))
PY
