#!/usr/bin/env bash
# Hermes-Adapter — führt EINE Aufgabe aus.
#
# Vertrag: siehe adapters/README.md
#   Eingabe  über TASK_*-Umgebungsvariablen
#   Ausgabe  genau eine Zeile JSON auf stdout, Logs auf stderr
#
# TOPOLOGIE, und warum sie so ist:
# Hermes läuft nicht hier, sondern in CT 103 (`hermes`). Dieser Adapter läuft
# im Worker CT 102, ruft Hermes per SSH auf, und Hermes führt seine
# Terminal- und Dateibefehle über sein SSH-Backend (TERMINAL_ENV=ssh) wieder
# HIER aus — im Arbeitsverzeichnis TASK_REPO. Eine Schleife 102 → 103 → 102.
# Die Keys für Modelle liegen damit nur in 103; der Agent kann seine eigene
# .env nicht lesen. Begründung in orchestrator/hermes.md.
#
# Das Arbeitsverzeichnis kommt über TERMINAL_CWD an (gemessen 2026-09-13:
# `--in DIR` wirkt nur lokal in 103 und erreicht das SSH-Backend nicht).

set -uo pipefail

LAB_ROOT="${LAB_ROOT:-/opt/agent-lab}"
HARNESS="hermes"
HERMES_SSH="${HERMES_SSH:-hermes@192.168.1.21}"

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

# Modell: TASK_MODEL überschreibt, sonst aus config/models.yaml nach Rolle.
# Schreibweise `provider/modell`, wobei das Modell selbst Schrägstriche haben
# darf (`openrouter/z-ai/glm-5.3-flash`). Getrennt wird am ERSTEN Schrägstrich.
SPEC="${TASK_MODEL:-}"
if [ -z "$SPEC" ]; then
  SPEC=$(python3 - "$LAB_ROOT/config/models.yaml" "$TASK_ROLE" <<'PY'
import sys, yaml
cfg = yaml.safe_load(open(sys.argv[1]))
role = cfg["roles"].get(sys.argv[2]) or {}
for cand in (role, role.get("fallback") or {}, *(role.get("candidates") or [])):
    if cand.get("harness") == "hermes" and cand.get("model"):
        print(f'{cand.get("provider","")}/{cand["model"]}'.lstrip("/")); break
else:
    print("")
PY
)
fi
PROVIDER=""; MODEL=""
if [ -n "$SPEC" ]; then
  case "$SPEC" in
    */*) PROVIDER="${SPEC%%/*}"; MODEL="${SPEC#*/}" ;;
    *)   MODEL="$SPEC" ;;
  esac
fi
[ -n "$MODEL" ] || log "kein explizites Modell für Rolle '$TASK_ROLE' — Hermes-Standard"

# Diese Werte landen in einer Kommandozeile auf der Gegenseite. Nur, was
# harmlos ist; alles andere ist ein Konfigurationsfehler, kein Freitext.
safe='^[A-Za-z0-9._:/-]*$'
for v in "$PROVIDER" "$MODEL" "$TASK_REPO" "$TASK_ID"; do
  [[ "$v" =~ $safe ]] || fail_json "unsichere_zeichen_in_parametern"
done

cd "$TASK_REPO" || fail_json "arbeitsverzeichnis_fehlt"
git rev-parse --git-dir >/dev/null 2>&1 || fail_json "kein_git_repo"

BEFORE=$(git rev-parse HEAD 2>/dev/null || echo "")
git checkout -q -B "$TASK_BRANCH" 2>/dev/null || log "Branch-Wechsel fehlgeschlagen, arbeite auf HEAD"

USAGE_REMOTE="/tmp/hermes-usage-${TASK_ID}.json"
OUT=$(mktemp); USAGE=$(mktemp); trap 'rm -f "$OUT" "$USAGE"' EXIT

# Werkzeugsätze: Standard sind Terminal und Datei. Ohne `memory` startet
# jeder Lauf ohne Vorgeschichte — sonst hätte der zweite Lauf einen Vorteil,
# den die anderen Harnesses nicht haben (oh-my-pi läuft aus demselben Grund
# mit --no-session). HERMES_TOOLSETS überschreibt, leer heißt Hermes-Standard.
TOOLSETS="${HERMES_TOOLSETS-terminal,file}"

ARGS="--usage-file $USAGE_REMOTE"
[ -n "$PROVIDER" ] && ARGS="$ARGS --provider $PROVIDER"
[ -n "$MODEL" ]    && ARGS="$ARGS -m $MODEL"
[ -n "$TOOLSETS" ] && ARGS="$ARGS -t $TOOLSETS"

log "Branch $TASK_BRANCH${SPEC:+, Modell $SPEC}, Hermes auf $HERMES_SSH, cwd $TASK_REPO"
START=$(date +%s)

# Der Prompt geht über stdin, nie über die Kommandozeile: Er ist Freitext.
# `bash -lc`, weil `hermes` nur im Login-PATH liegt. TERMINAL_CWD und der
# Prompt sind exportiert und damit in der inneren Shell sichtbar.
timeout "${TASK_TIMEOUT:-3600}" ssh -o BatchMode=yes -o ConnectTimeout=10 "$HERMES_SSH" \
  "export HERMES_TASK_PROMPT=\"\$(cat)\" TERMINAL_CWD='$TASK_REPO'; \
   bash -lc 'hermes -z \"\$HERMES_TASK_PROMPT\" $ARGS'" \
  <<<"$TASK_PROMPT" > "$OUT" 2>>/dev/stderr
EXIT=$?

END=$(date +%s)

# Nutzungsbericht abholen. Er wird laut Hermes auch bei Fehlschlag geschrieben.
ssh -o BatchMode=yes -o ConnectTimeout=10 "$HERMES_SSH" \
  "cat '$USAGE_REMOTE' 2>/dev/null; rm -f '$USAGE_REMOTE'" > "$USAGE" 2>/dev/null

AFTER=$(git rev-parse HEAD 2>/dev/null || echo "")
if [ -n "$BEFORE" ] && [ -n "$AFTER" ]; then
  COMMITS=$(git rev-list --count "${BEFORE}..${AFTER}" 2>/dev/null || echo 0)
else
  COMMITS=0
fi

python3 - "$USAGE" "$OUT" "$TASK_ID" "$HARNESS" "$SPEC" "$EXIT" "$((END-START))" "$TASK_BRANCH" "$COMMITS" <<'PY'
import json, sys

usage_path, out_path, task_id, harness, spec, exit_code, dur, branch, commits = sys.argv[1:10]
exit_code = int(exit_code)

# Schema des --usage-file (verifiziert 2026-09-13, Hermes v0.21.2):
#   estimated_cost_usd, cost_status ("unknown" bei OAuth-Abos), cost_source,
#   input_tokens, output_tokens, cache_read_tokens, cache_write_tokens,
#   reasoning_tokens, total_tokens, api_calls, model, provider, session_id,
#   completed, failed
u = {}
try:
    raw = open(usage_path, encoding="utf-8", errors="replace").read().strip()
    if raw:
        u = json.loads(raw)
except (json.JSONDecodeError, OSError):
    pass
have = bool(u)

# Cache-Token zählen zur Eingabe — verbrauchtes Kontingent, auch wenn billiger.
# Gleiche Regel wie im Claude-Adapter, sonst vergleicht man schief.
tin = None
if have:
    tin = (u.get("input_tokens") or 0) + (u.get("cache_read_tokens") or 0) \
        + (u.get("cache_write_tokens") or 0)

# Kosten nur, wenn Hermes sie kennt. Bei OAuth-Abos steht cost_status auf
# "unknown" und estimated_cost_usd auf 0.0 — das ist "nicht gemessen", nicht
# "kostenlos". Also null, nicht 0.
cost = None
if have and u.get("cost_status") not in (None, "unknown") and u.get("cost_source") != "none":
    c = u.get("estimated_cost_usd")
    if isinstance(c, (int, float)):
        cost = round(c, 6)

# `failed` im Bericht ist aussagekräftiger als der SSH-Rückgabewert.
if have and u.get("failed") and exit_code == 0:
    exit_code = 1
if have and u.get("completed") is False and exit_code == 0:
    exit_code = 1

# Null API-Aufrufe heißt: kein Modell wurde gefragt. Das ist ein Ausfall der
# Infrastruktur (Guthaben, Key, Netz), kein Messwert für das Modell. Also
# null statt 0 in den Token-Feldern, und ein Fehler, der das auch sagt.
# Gelernt 2026-09-13: acht GLM-Flash-Läufe mit 402 standen als "0 Token,
# erfolg: false" in der Tabelle und sahen aus wie ein gescheitertes Modell.
kein_aufruf = have and not u.get("api_calls")
if kein_aufruf:
    tin = None
    if exit_code == 0:
        exit_code = 1

model = None
if have and u.get("model"):
    model = f'{u.get("provider") or ""}/{u["model"]}'.lstrip("/")
elif spec:
    model = spec

out = {
    "task_id": task_id,
    "harness": harness,
    "model": model,
    "exit_code": exit_code,
    "duration_s": int(dur),
    # Hermes meldet API-Aufrufe, keine „Runden". Für einen Tool-Loop ist das
    # dasselbe: ein Aufruf pro Modellantwort. Im README vermerkt.
    "turns": u.get("api_calls") if have else None,
    "tokens_in": tin,
    "tokens_out": (u.get("output_tokens") if have and not kein_aufruf else None),
    "cost_usd": cost,
    "branch": branch,
    "commits": int(commits),
}
if have and u.get("reasoning_tokens") is not None:
    out["reasoning_tokens"] = u["reasoning_tokens"]
if have and u.get("session_id"):
    out["session_id"] = u["session_id"]
if not have:
    out["error"] = "kein_nutzungsbericht"
elif u.get("failed") or kein_aufruf:
    text = ""
    try:
        text = open(out_path, encoding="utf-8", errors="replace").read().strip()
    except OSError:
        pass
    out["error"] = text[:200] or ("kein_api_aufruf" if kein_aufruf else "hermes_failed")

print(json.dumps(out))
PY
