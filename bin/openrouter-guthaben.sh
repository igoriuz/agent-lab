#!/usr/bin/env bash
# Prueft das OpenRouter-Guthaben, BEVOR eine Ladder startet.
#
#   ./bin/openrouter-guthaben.sh [mindestbetrag]
#
# WARUM: Am 2026-09-13 liefen acht GLM-Flash-Laeufe gegen HTTP 402 und landeten
# als "0 Token, kein Erfolg" in den Rohdaten. Das sah aus wie eine Aussage ueber
# das Modell, war aber eine ueber das Konto. Der Waechter ist Vorbedingung, nicht
# Bremse: Er misst nicht das Modell, er verhindert nur eine Messung, die nichts
# misst.
#
# Der Schluessel bleibt in CT 103. Er wird hier nicht ausgegeben und nicht
# kopiert — die Abfrage laeuft drueben, zurueck kommt nur eine Zahl.
set -uo pipefail

MINDEST="${1:-0.50}"
# Gleicher Standard wie der Adapter: die LAN-Adresse, nicht der Tailnet-Name.
# Sie funktioniert auch, wenn nach einem Restore /dev/net/tun fehlt.
HERMES_SSH="${HERMES_SSH:-hermes@192.168.1.21}"

ANTWORT=$(ssh -o BatchMode=yes -o ConnectTimeout=10 "$HERMES_SSH" '
KEY=$(python3 -c "
import json
d = json.load(open(\"/home/hermes/.hermes/auth.json\"))
def suche(o):
    if isinstance(o, dict):
        for v in o.values():
            if isinstance(v, str) and v.startswith(\"sk-or-\"):
                print(v); return True
            if suche(v): return True
    elif isinstance(o, list):
        for v in o:
            if suche(v): return True
    return False
suche(d)" 2>/dev/null)
[ -n "$KEY" ] || { echo "KEIN_KEY"; exit 0; }
# Zwei Abfragen, weil sie zwei verschiedene Dinge sagen: /credits gilt fuers
# ganze KONTO, /key nur fuer diesen Schluessel. Am 2026-09-19 hat ein fremder
# Verbraucher am Konto 2,70 $ verbrannt, waehrend die Ladder 0,13 $ brauchte —
# wer nur /credits liest, haelt das fuer die eigenen Kosten.
REST=$(curl -s -m 15 https://openrouter.ai/api/v1/credits -H "Authorization: Bearer $KEY" |
  python3 -c "
import json, sys
d = json.load(sys.stdin)[\"data\"]
print(round(d[\"total_credits\"] - d[\"total_usage\"], 4))" 2>/dev/null)
KEYTAG=$(curl -s -m 15 https://openrouter.ai/api/v1/key -H "Authorization: Bearer $KEY" |
  python3 -c "
import json, sys
d = json.load(sys.stdin)[\"data\"]
print(round(d.get(\"usage_daily\") or 0, 4))" 2>/dev/null)
[ -n "$REST" ] && echo "$REST ${KEYTAG:-?}" || echo "ABFRAGE_FEHLER"
') || { echo "[guthaben] SSH nach $HERMES_SSH fehlgeschlagen" >&2; exit 2; }

REST="${ANTWORT%% *}"
KEY_HEUTE="${ANTWORT##* }"

case "$REST" in
  KEIN_KEY)        echo "[guthaben] kein OpenRouter-Schluessel in $HERMES_SSH gefunden" >&2; exit 2 ;;
  ABFRAGE_FEHLER)  echo "[guthaben] OpenRouter antwortet nicht wie erwartet" >&2; exit 2 ;;
esac

if ! awk -v r="$REST" -v m="$MINDEST" 'BEGIN{exit !(r+0 >= m+0)}'; then
  echo "[guthaben] Konto $REST \$ uebrig, mindestens $MINDEST \$ verlangt — Ladder nicht gestartet" >&2
  exit 1
fi

echo "[guthaben] Konto $REST \$ uebrig (Mindestbetrag $MINDEST \$), dieser Key heute $KEY_HEUTE \$" >&2
echo "$REST"
