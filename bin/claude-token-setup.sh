#!/usr/bin/env bash
# Trägt den Claude-Code-Token in .env ein und prüft ihn im Container.
#
#   ./bin/claude-token-setup.sh [container-host]
#
# Den Token liefert `claude setup-token` — es GIBT IHN NUR AUS, gespeichert
# wird er nicht. Deshalb dieser Umweg über CLAUDE_CODE_OAUTH_TOKEN.
#
# Eingabe verdeckt (read -s): weder Shell-History noch Prozesslisting, und
# in jeder Ausgabe maskiert.

set -euo pipefail

cd "$(dirname "$0")/.."
HOST="${1:-agent-lab}"
ENV_FILE=".env"

[ -f "$ENV_FILE" ] || { echo ".env fehlt." >&2; exit 1; }

echo "Token holen mit:  ssh -t ${HOST} 'su - agent -c \"claude setup-token\"'"
echo
read -rsp "Claude-Token (sk-ant-oat…): " TOK
echo
TOK="${TOK// /}"; TOK="${TOK//$'\n'/}"; TOK="${TOK//$'\r'/}"
[ -n "$TOK" ] || { echo "Kein Token eingegeben, Abbruch." >&2; exit 1; }

redact() { sed "s#${TOK}#<TOKEN>#g"; }

# In .env schreiben, ohne den Token je auf stdout zu bringen.
grep -q '^CLAUDE_CODE_OAUTH_TOKEN=' "$ENV_FILE" || echo 'CLAUDE_CODE_OAUTH_TOKEN=' >> "$ENV_FILE"
tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
python3 - "$ENV_FILE" "$TOK" > "$tmp" <<'PY'
import sys
path, tok = sys.argv[1], sys.argv[2]
out = []
for line in open(path):
    if line.startswith("CLAUDE_CODE_OAUTH_TOKEN="):
        line = f"CLAUDE_CODE_OAUTH_TOKEN={tok}\n"
    out.append(line)
sys.stdout.write("".join(out))
PY
mv "$tmp" "$ENV_FILE"
chmod 600 "$ENV_FILE"

echo "Übertrage nach ${HOST} …"
scp -q "$ENV_FILE" "${HOST}:/opt/agent-lab/.env"
ssh "$HOST" 'chgrp agent /opt/agent-lab/.env && chmod 640 /opt/agent-lab/.env'

echo "Prüfe im Container …"
RESP=$(ssh "$HOST" 'su - agent -c "set -a; . /opt/agent-lab/.env; set +a; cd /tmp && timeout 60 claude -p \"antworte nur mit: ok\" --output-format json < /dev/null"' 2>&1 || true)

VERDICT=$(printf '%s' "$RESP" | python3 -c '
import json, sys
raw = sys.stdin.read().strip()
start = raw.find("{")
try:
    d = json.loads(raw[start:]) if start >= 0 else None
    if d is None: raise ValueError
except Exception:
    print("UNKLAR"); sys.exit()
print("FEHLER: " + str(d.get("result"))[:120] if d.get("is_error") else "OK: " + str(d.get("result"))[:60])
' 2>/dev/null || echo "UNKLAR")

case "$VERDICT" in
  OK:*)     echo "$VERDICT"; echo "Claude Code ist im Container angemeldet." ;;
  FEHLER:*) echo "$VERDICT" >&2; echo "Token wird abgelehnt." >&2; exit 1 ;;
  *)        echo "Antwort nicht auswertbar (Token maskiert):" >&2
            printf '%s' "$RESP" | redact | head -c 600 >&2; echo >&2; exit 1 ;;
esac
