#!/usr/bin/env bash
# Legt .env an und trägt Telegram-Token und Chat-ID ein.
#
# Der Token wird interaktiv abgefragt (read -s) und dabei nicht angezeigt.
# Er landet damit weder in der Shell-History noch in einem Prozesslisting.
# In jeder Ausgabe wird er maskiert — auch in Telegrams Fehlermeldungen,
# die ihn sonst zurückspiegeln.
#
#   ./bin/telegram-setup.sh
#
# Voraussetzung: Bot bei @BotFather angelegt (/newbot) UND dem Bot selbst
# eine Nachricht geschickt. Nicht dem BotFather — dem neuen Bot.

set -euo pipefail

cd "$(dirname "$0")/.."
ENV_FILE=".env"

[ -f "$ENV_FILE" ] || cp .env.example "$ENV_FILE"

read -rsp "Telegram Bot-Token: " TOKEN
echo
TOKEN="${TOKEN// /}"
TOKEN="${TOKEN//$'\n'/}"
TOKEN="${TOKEN//$'\r'/}"

if [ -z "$TOKEN" ]; then
  echo "Kein Token eingegeben, Abbruch." >&2
  exit 1
fi

api() { curl -s --max-time 20 "https://api.telegram.org/bot${TOKEN}/$1"; }
redact() { sed "s#${TOKEN}#<TOKEN>#g"; }

# --- Token prüfen ----------------------------------------------------------
ME=$(api getMe)
BOTNAME=$(python3 -c '
import json,sys
d=json.load(sys.stdin)
print(d["result"]["username"] if d.get("ok") else "")
' <<<"$ME" 2>/dev/null || true)

if [ -z "$BOTNAME" ]; then
  echo "Token wird von Telegram abgelehnt:" >&2
  redact <<<"$ME" >&2
  exit 1
fi
echo "Bot erkannt: @${BOTNAME}"

# --- Webhook? Der verschluckt getUpdates lautlos ---------------------------
WH=$(api getWebhookInfo)
WH_URL=$(python3 -c '
import json,sys
d=json.load(sys.stdin)
print(d.get("result",{}).get("url",""))
' <<<"$WH" 2>/dev/null || true)

if [ -n "$WH_URL" ]; then
  echo "Ein Webhook ist gesetzt ($WH_URL) — der zieht alle Updates ab," >&2
  echo "deshalb liefert getUpdates nichts. Entferne ihn mit:" >&2
  echo "  curl -s \"https://api.telegram.org/bot<TOKEN>/deleteWebhook\"" >&2
  exit 1
fi

# --- Chat-ID suchen --------------------------------------------------------
UPDATES=$(api getUpdates)
CHAT_ID=$(python3 -c '
import json,sys
d=json.load(sys.stdin)
for u in d.get("result", []):
    for key in ("message","edited_message","channel_post","my_chat_member"):
        m = u.get(key)
        if m and "chat" in m:
            print(m["chat"]["id"]); sys.exit(0)
' <<<"$UPDATES" 2>/dev/null || true)

if [ -z "$CHAT_ID" ]; then
  COUNT=$(python3 -c '
import json,sys
d=json.load(sys.stdin)
print(len(d.get("result", [])))
' <<<"$UPDATES" 2>/dev/null || echo "?")

  echo >&2
  echo "Keine Chat-ID gefunden. Telegram meldet ${COUNT} Update(s)." >&2
  echo >&2
  echo "Häufigste Ursachen:" >&2
  echo "  1. Die Nachricht ging an @BotFather statt an @${BOTNAME}." >&2
  echo "     Suche in Telegram gezielt nach @${BOTNAME} und schreib DORT." >&2
  echo "  2. Im Chat wurde nur /start angetippt, aber nicht abgeschickt." >&2
  echo "  3. Die Nachricht ist älter als 24 Stunden — Telegram verwirft sie." >&2
  echo >&2
  echo "Rohantwort (Token maskiert):" >&2
  redact <<<"$UPDATES" | head -c 1200 >&2
  echo >&2
  exit 1
fi

echo "Chat-ID: ${CHAT_ID}"

# --- Schreiben, ohne den Token je auf stdout zu bringen --------------------
tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
python3 - "$ENV_FILE" "$TOKEN" "$CHAT_ID" > "$tmp" <<'PY'
import sys
path, token, chat = sys.argv[1], sys.argv[2], sys.argv[3]
out=[]
for line in open(path):
    if line.startswith("TELEGRAM_BOT_TOKEN="): line = f"TELEGRAM_BOT_TOKEN={token}\n"
    elif line.startswith("TELEGRAM_CHAT_ID="): line = f"TELEGRAM_CHAT_ID={chat}\n"
    out.append(line)
sys.stdout.write("".join(out))
PY
mv "$tmp" "$ENV_FILE"
chmod 600 "$ENV_FILE"

# --- Testnachricht ---------------------------------------------------------
RESP=$(curl -s --max-time 20 -X POST \
  "https://api.telegram.org/bot${TOKEN}/sendMessage" \
  -d "chat_id=${CHAT_ID}" \
  --data-urlencode "text=agent-lab ist verbunden. Ab hier laufen Rückfragen, Freigaben und Bewertungen über diesen Kanal.")

if grep -q '"ok":true' <<<"$RESP"; then
  echo "Erledigt — schau auf dein Handy. .env geschrieben (Rechte 600)."
else
  echo "Senden fehlgeschlagen:" >&2
  redact <<<"$RESP" >&2
  exit 1
fi
