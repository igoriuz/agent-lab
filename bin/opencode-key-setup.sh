#!/usr/bin/env bash
# Trägt den OpenCode-API-Schlüssel in .env ein und prüft ihn gegen den
# OpenCode-Go-Endpunkt.
#
#   ./bin/opencode-key-setup.sh
#
# Der Schlüssel wird interaktiv abgefragt (read -s) und dabei nicht angezeigt.
# Er landet weder in der Shell-History noch in einem Prozesslisting, und wird
# in jeder Ausgabe maskiert — auch in Fehlermeldungen der Gegenseite.

set -euo pipefail

cd "$(dirname "$0")/.."
ENV_FILE=".env"
API_BASE="https://opencode.ai/zen/go/v1"

[ -f "$ENV_FILE" ] || cp .env.example "$ENV_FILE"

read -rsp "OpenCode API-Schlüssel: " KEY
echo
KEY="${KEY// /}"; KEY="${KEY//$'\n'/}"; KEY="${KEY//$'\r'/}"
[ -n "$KEY" ] || { echo "Kein Schlüssel eingegeben, Abbruch." >&2; exit 1; }

redact() { sed "s#${KEY}#<KEY>#g"; }

echo "Prüfe Schlüssel gegen ${API_BASE} …"

# Modellliste abrufen — billigster Weg, den Schlüssel zu verifizieren,
# ohne Token zu verbrauchen.
RESP=$(curl -s --max-time 25 -H "Authorization: Bearer ${KEY}" "${API_BASE}/models" 2>&1 || true)

# Programm über -c, Daten über die Pipe.
#
# NICHT `python3 - <<'PY' <<<"$RESP"` — das sind zwei Umleitungen auf dieselbe
# Standardeingabe, die letzte gewinnt, und Python bekommt die Daten als
# Programm. Dieselbe Falle wie beim Übergeben des Tokens an ssh in
# bin/pve-telegram-notify.sh: stdin lässt sich nicht doppelt belegen.
MODELS=$(printf '%s' "$RESP" | python3 -c '
import json,sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
print("\n".join(m["id"] for m in d.get("data", []) if m.get("id")))
' 2>/dev/null || true)

if [ -z "$MODELS" ]; then
  echo "Konnte keine Modellliste abrufen. Antwort (Schlüssel maskiert):" >&2
  redact <<<"$RESP" | head -c 800 >&2
  echo >&2
  echo >&2
  echo "Wenn dort 401/403 steht, stimmt der Schlüssel nicht." >&2
  echo "Wenn 404: Endpunkt prüfen — ggf. hat sich der Pfad geändert." >&2
  exit 1
fi

echo "Schlüssel gültig. Verfügbare Modelle:"
echo "$MODELS" | sed 's/^/  /'
echo
echo "$MODELS" | grep -qi "deepseek.*flash" \
  && echo "DeepSeek Flash gefunden — passt zum Klassifizierer." \
  || echo "ACHTUNG: kein DeepSeek-Flash-Modell in der Liste. Modell-ID in config/models.yaml anpassen."

# Schreiben, ohne den Schlüssel je auf stdout zu bringen
grep -q '^OPENCODE_API_KEY=' "$ENV_FILE" || echo 'OPENCODE_API_KEY=' >> "$ENV_FILE"
tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
python3 - "$ENV_FILE" "$KEY" > "$tmp" <<'PY'
import sys
path, key = sys.argv[1], sys.argv[2]
out=[]
for line in open(path):
    if line.startswith("OPENCODE_API_KEY="): line = f"OPENCODE_API_KEY={key}\n"
    out.append(line)
sys.stdout.write("".join(out))
PY
mv "$tmp" "$ENV_FILE"
chmod 600 "$ENV_FILE"
echo
echo ".env geschrieben (Rechte 600)."
