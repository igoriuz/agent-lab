#!/usr/bin/env bash
# oh-my-pi-Adapter — führt EINE Aufgabe aus.
#
# Vertrag: siehe adapters/README.md
#   Eingabe  über TASK_*-Umgebungsvariablen
#   Ausgabe  genau eine Zeile JSON auf stdout, Logs auf stderr
#
# Besonderheit gegenüber den anderen Adaptern: oh-my-pi kann sich per OAuth
# an Abo-Plänen anmelden (Anthropic Claude Pro/Max, xAI SuperGrok, Codex …).
# Damit lässt sich DASSELBE Modell einmal hier und einmal im Hersteller-
# Harness messen — der einzige Weg, Modell- von Harness-Wirkung zu trennen.

set -uo pipefail

export PATH="$HOME/.local/bin:$PATH"
LAB_ROOT="${LAB_ROOT:-/opt/agent-lab}"
HARNESS="oh-my-pi"

: "${TASK_ID:?fehlt}"
: "${TASK_PROMPT:?fehlt}"
: "${TASK_REPO:?fehlt}"
: "${TASK_BRANCH:?fehlt}"
: "${TASK_ROLE:=strong}"

log() { echo "[$HARNESS] $*" >&2; }

fail_json() {
  python3 -c "
import json,sys
print(json.dumps({'task_id':sys.argv[1],'harness':sys.argv[2],'model':None,'exit_code':78,
'error':sys.argv[3],'duration_s':0,'turns':None,'tokens_in':None,'tokens_out':None,
'cost_usd':None,'branch':None,'commits':0}))" "$TASK_ID" "$HARNESS" "$1"
  exit 0
}

# Modell aus der zentralen Konfiguration. `OMP_MODEL` überschreibt — genau
# das braucht der Vergleich, wenn dasselbe Modell gegen einen anderen Harness
# antreten soll.
MODEL="${TASK_MODEL:-${OMP_MODEL:-}}"
if [ -z "$MODEL" ]; then
  MODEL=$(python3 - "$LAB_ROOT/config/models.yaml" "$TASK_ROLE" <<'PY'
import sys, yaml
cfg = yaml.safe_load(open(sys.argv[1]))
role = cfg["roles"].get(sys.argv[2]) or {}
for cand in (role, role.get("fallback") or {}, *(role.get("candidates") or [])):
    if cand.get("harness") == "oh-my-pi":
        print(cand.get("model") or ""); break
else:
    print("")
PY
)
fi

cd "$TASK_REPO" || fail_json "arbeitsverzeichnis_fehlt"
git rev-parse --git-dir >/dev/null 2>&1 || fail_json "kein_git_repo"

BEFORE=$(git rev-parse HEAD 2>/dev/null || echo "")
git checkout -q -B "$TASK_BRANCH" 2>/dev/null || log "Branch-Wechsel fehlgeschlagen, arbeite auf HEAD"

OUT=$(mktemp); trap 'rm -f "$OUT"' EXIT
START=$(date +%s)

# --print nicht-interaktiv, --mode json maschinenlesbar.
# --no-session: Jeder Lauf startet ohne Vorgeschichte. Sonst würde oh-my-pi
# sein Sitzungsgedächtnis mitschleppen, und der Vergleich mäße nicht mehr
# dieselbe Ausgangslage — der zweite Lauf hätte einen Vorteil, den die
# anderen Harnesses nicht haben.
ARGS=(--print --mode json --no-session)
[ -n "$MODEL" ] && ARGS+=(--model "$MODEL")

log "Branch $TASK_BRANCH${MODEL:+, Modell $MODEL}"
timeout "${TASK_TIMEOUT:-3600}" omp "${ARGS[@]}" "$TASK_PROMPT" > "$OUT" 2>>/dev/stderr < /dev/null
EXIT=$?

END=$(date +%s)
AFTER=$(git rev-parse HEAD 2>/dev/null || echo "")
if [ -n "$BEFORE" ] && [ -n "$AFTER" ]; then
  COMMITS=$(git rev-list --count "${BEFORE}..${AFTER}" 2>/dev/null || echo 0)
else
  COMMITS=0
fi

python3 - "$OUT" "$TASK_ID" "$HARNESS" "$MODEL" "$EXIT" "$((END-START))" "$TASK_BRANCH" "$COMMITS" <<'PY'
import json, sys

path, task_id, harness, model, exit_code, dur, branch, commits = sys.argv[1:9]

raw = ""
try:
    raw = open(path, encoding="utf-8", errors="replace").read()
except OSError:
    pass

# Schema (verifiziert 2026-08-16): zeilenweise JSON-Objekte.
#   turn_start                        -> eine Runde
#   agent_end.messages[]              -> alle Nachrichten mit usage
#   usage: {input, output, cacheRead, cacheWrite, totalTokens,
#           cost: {input, output, cacheRead, cacheWrite, total}}
events = []
for line in raw.splitlines():
    line = line.strip()
    if line.startswith("{"):
        try:
            events.append(json.loads(line))
        except json.JSONDecodeError:
            pass

turns = sum(1 for e in events if e.get("type") == "turn_start") or None

# Nachrichten bevorzugt aus agent_end — dort liegt der vollstaendige Verlauf.
# Sonst die einzelnen turn_end-Nachrichten, sonst nichts.
messages = []
for e in events:
    if e.get("type") == "agent_end" and isinstance(e.get("messages"), list):
        messages = e["messages"]
        break
else:
    messages = [e["message"] for e in events
                if e.get("type") == "turn_end" and isinstance(e.get("message"), dict)]

tin = tout = 0
cost = 0.0
saw = False
err = None
model_seen = None

for m in messages:
    if not isinstance(m, dict) or m.get("role") != "assistant":
        continue
    model_seen = model_seen or (
        f"{m.get('provider')}/{m.get('model')}" if m.get("provider") and m.get("model") else None
    )
    if m.get("errorMessage"):
        err = m["errorMessage"]
    u = m.get("usage") or {}
    if u:
        saw = True
        # Cache zaehlt zur Eingabe: verbrauchtes Kontingent, auch wenn
        # billiger. Weglassen unterschaetzt gut cachende Harnesses.
        tin += (u.get("input") or 0) + (u.get("cacheRead") or 0) + (u.get("cacheWrite") or 0)
        tout += u.get("output") or 0
        c = u.get("cost") or {}
        if isinstance(c.get("total"), (int, float)):
            cost += c["total"]

out = {
    "task_id": task_id,
    "harness": harness,
    "model": model or model_seen,
    "exit_code": int(exit_code),
    "duration_s": int(dur),
    "turns": turns,
    "tokens_in": tin if saw else None,
    "tokens_out": tout if saw else None,
    "cost_usd": round(cost, 6) if saw else None,
    "branch": branch,
    "commits": int(commits),
}
if err:
    out["error"] = err.replace("\n", " ")[:200]
    if out["exit_code"] == 0:
        # Der Prozess endet auch bei einem API-Fehler mit 0.
        out["exit_code"] = 1
elif not events and raw.strip():
    out["error"] = "ausgabe_nicht_json:" + raw.strip()[:120]

print(json.dumps(out))
PY
