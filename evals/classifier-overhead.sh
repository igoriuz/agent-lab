#!/usr/bin/env bash
# Misst den Kontext-Grundaufwand eines Klassifizierer-Aufrufs in drei Varianten.
#
# Hintergrund: Der Klassifizierer laeuft bei JEDER Aufgabe. Was er pro Aufruf
# an Kontingent frisst, entscheidet, wie lange das Abo traegt. Er braucht
# weder Werkzeuge noch LSP noch Dateizugriff — nur Zustand lesen und eine
# Entscheidung ausgeben.
#
#   ./classifier-overhead.sh      (im Container, als agent)

set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"
set -a; . /opt/agent-lab/.env; set +a

PROMPT='Projekt beispiel-app. Zustand: Paywall existiert, ungetestet. Aufgabe: Conversion verbessern. Antworte nur mit JSON: {"skill":..,"rolle":..,"begruendung":..}'
MODEL='deepseek-v4-flash'

sum_omp() {
  python3 -c '
import json, sys
tin = tout = 0
for line in sys.stdin:
    line = line.strip()
    if not line.startswith("{"):
        continue
    try:
        ev = json.loads(line)
    except json.JSONDecodeError:
        continue
    if ev.get("type") != "agent_end":
        continue
    for m in ev.get("messages", []):
        if m.get("role") != "assistant":
            continue
        u = m.get("usage") or {}
        tin += (u.get("input") or 0) + (u.get("cacheRead") or 0) + (u.get("cacheWrite") or 0)
        tout += u.get("output") or 0
print(f"  Token ein: {tin:>8,}   aus: {tout:>6,}")
'
}

echo "=== A) omp, voller Modus ==="
timeout 150 omp --print --mode json --no-session \
  --model "opencode-go/${MODEL}" "$PROMPT" </dev/null 2>/dev/null | sum_omp

echo "=== B) omp, ohne Werkzeuge und LSP ==="
timeout 150 omp --print --mode json --no-session --no-tools --no-lsp \
  --model "opencode-go/${MODEL}" "$PROMPT" </dev/null 2>/dev/null | sum_omp

echo "=== C) direkter API-Aufruf, ohne Harness ==="
python3 - "$PROMPT" "$MODEL" <<'PY'
import json, os, sys, urllib.request

prompt, model = sys.argv[1], sys.argv[2]
req = urllib.request.Request(
    "https://opencode.ai/zen/go/v1/chat/completions",
    data=json.dumps({"model": model, "messages": [{"role": "user", "content": prompt}]}).encode(),
    headers={"Authorization": "Bearer " + os.environ["OPENCODE_API_KEY"],
             "Content-Type": "application/json",
             # Ohne User-Agent antwortet der Endpunkt mit 403.
             "User-Agent": "agent-lab/1.0"},
)
with urllib.request.urlopen(req, timeout=90) as r:
    d = json.load(r)
u = d.get("usage") or {}
print(f"  Token ein: {u.get('prompt_tokens', 0):>8,}   aus: {u.get('completion_tokens', 0):>6,}")
PY
