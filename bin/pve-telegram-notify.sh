#!/usr/bin/env bash
# Richtet auf dem Proxmox-Host ein Telegram-Ziel für Benachrichtigungen ein.
#
# Warum: Backup-Fehler, SMART-Warnungen und Thin-Pool-Füllstand kommen damit
# sofort aufs Handy statt in ein Postfach, in das niemand schaut.
#
#   ./bin/pve-telegram-notify.sh [pve-host]
#
# Der Bot-Token wird aus .env gelesen und im Skripttext über die
# SSH-Standardeingabe übertragen — nicht als Kommandozeilenargument. Er ist
# damit in keinem Prozesslisting sichtbar, weder hier noch auf dem Host.
# Dort landet er in /etc/pve/priv/, nicht in der Klartext-Config.
#
# Das bestehende Mail-Ziel bleibt erhalten: Telegram für sofort, Mail als
# Beleg und Rückfallebene.

set -euo pipefail

cd "$(dirname "$0")/.."
PVE_HOST="${1:-pve}"

[ -f .env ] || { echo ".env fehlt — erst ./bin/telegram-setup.sh laufen lassen." >&2; exit 1; }
set -a; . ./.env; set +a

: "${TELEGRAM_BOT_TOKEN:?fehlt in .env}"
: "${TELEGRAM_CHAT_ID:?fehlt in .env}"

b64() { printf '%s' "$1" | base64 | tr -d '\n'; }

# Body-Vorlage für PVE. {{ escape … }} maskiert für die Einbettung in JSON —
# ohne das zerlegt das erste Anführungszeichen im Text die Struktur.
BODY_B64=$(b64 "{\"chat_id\":\"${TELEGRAM_CHAT_ID}\",\"text\":\"[{{ severity }}] {{ escape title }}\n\n{{ escape message }}\"}")
CTYPE_B64=$(b64 'application/json')
TOKEN_B64=$(b64 "$TELEGRAM_BOT_TOKEN")

echo "Lege Webhook-Ziel auf ${PVE_HOST} an…"

# Alles lokal einsetzen und das fertige Skript über stdin schicken.
#
# Zwei Fallen, die hier Zeit gekostet haben:
#
# 1. stdin nicht doppelt belegen. `bash -s` liest das Skript von stdin; ein
#    zusätzliches `read` für den Token bekommt dann nichts, und der Token kam
#    leer an. Erkennbar war das an PVEs eigener Maskierung: In der
#    Fehlermeldung stand `<masked>` zwischen JEDEM Zeichen — das passiert,
#    wenn ein Leerstring maskiert wird.
#
# 2. Der Parameter heißt `--secret`, der Template-Namensraum aber `secrets`
#    im Plural: `{{ secrets.token }}`. Mit `{{ secret.token }}` bleibt der
#    Platzhalter unersetzt stehen, und Telegram antwortet mit 404, weil der
#    Bot-Pfad dann nicht existiert.
ssh "$PVE_HOST" bash -s <<REMOTE
set -euo pipefail

pvesh delete /cluster/notifications/endpoints/webhook/telegram 2>/dev/null || true

pvesh create /cluster/notifications/endpoints/webhook \
  --name telegram \
  --method post \
  --url 'https://api.telegram.org/bot{{ secrets.token }}/sendMessage' \
  --header 'name=Content-Type,value=${CTYPE_B64}' \
  --body '${BODY_B64}' \
  --secret 'name=token,value=${TOKEN_B64}' \
  --comment 'Telegram - sofortige Meldungen aufs Handy'

echo "Endpunkt angelegt, teste…"
pvesh create /cluster/notifications/targets/telegram/test

# Beide Ziele: Telegram für sofort, Mail als Beleg.
pvesh set /cluster/notifications/matchers/default-matcher \
  --target telegram --target mail \
  --comment 'Alle Meldungen an Telegram und Mail'

echo "--- Ziele ---"
pvesh get /cluster/notifications/targets --output-format json
echo "--- Matcher ---"
pvesh get /cluster/notifications/matchers --output-format json
REMOTE

echo
echo "Fertig. Auf dem Handy müsste eine Testmeldung liegen."
