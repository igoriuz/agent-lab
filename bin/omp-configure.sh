#!/usr/bin/env bash
# Erzeugt die oh-my-pi-Anbieterkonfiguration im Container aus .env.
#
#   ./bin/omp-configure.sh [host]
#
# WARUM ERZEUGT UND NICHT VON HAND GEPFLEGT:
# oh-my-pi loest in models.yml KEINE Umgebungsvariablen auf — der Schluessel
# muss woertlich dort stehen. Damit .env die einzige Quelle fuer Geheimnisse
# bleibt, wird die Datei hier generiert und liegt als erzeugtes Artefakt im
# Container (Rechte 600, Verzeichnis 700), nicht im Repo.

set -euo pipefail
cd "$(dirname "$0")/.."
HOST="${1:-agent-lab}"

[ -f .env ] || { echo ".env fehlt." >&2; exit 1; }
set -a; . ./.env; set +a
: "${OPENCODE_API_KEY:?fehlt in .env}"

# OpenRouter ist OPTIONAL. Er ist der metrierte Topf und damit die einzige
# Stelle, an der ein Modell aus dem Go-Katalog auch ARBEITEN darf, ohne das
# Klassifizierer-Kontingent anzufassen (Leitsatz 2). Fehlt der Schluessel,
# wird der Provider weggelassen statt einen leeren einzutragen — ein Provider
# mit leerem Key sieht in der Konfiguration vorhanden aus und scheitert erst
# beim Aufruf.
OPENROUTER_BLOCK=""
FUNKTIONSTESTS=("opencode-go/deepseek-v4-flash")
if [ -n "${OPENROUTER_API_KEY:-}" ]; then
  OPENROUTER_BLOCK="  openrouter:
    baseUrl: https://openrouter.ai/api/v1
    api: openai-completions
    apiKey: ${OPENROUTER_API_KEY}"
  FUNKTIONSTESTS+=("openrouter/deepseek/deepseek-v4-flash-0731")
else
  echo "Hinweis: OPENROUTER_API_KEY leer — Provider openrouter wird ausgelassen." >&2
fi

echo "Schreibe ~/.omp/agent/models.yml auf ${HOST} …"

# STDIN IST HIER SCHON BELEGT — deshalb wird der Schluessel LOKAL eingesetzt.
#
# Nicht `printf ... | ssh 'bash -s' <<REMOTE` und drueben `read KEY`: Das
# Heredoc IST die Standardeingabe, `read` bekommt die erste Skriptzeile und
# die Pipe verpufft. Dieselbe Falle wie in bin/pve-telegram-notify.sh und
# bin/opencode-key-setup.sh. Stdin laesst sich nicht doppelt belegen.
#
# Der Schluessel steht damit kurz im Heredoc-Text, der ueber die
# SSH-Verbindung geht — nicht in einer Kommandozeile, also in keinem
# Prozesslisting auf beiden Seiten.
ssh "$HOST" 'bash -s' <<REMOTE
set -e
install -d -o agent -g agent -m 700 /home/agent/.omp/agent
cat > /home/agent/.omp/agent/models.yml <<'YML'
# ERZEUGT von bin/omp-configure.sh — nicht von Hand aendern.
# Quelle der Wahrheit ist .env; hier steht der Schluessel woertlich, weil
# oh-my-pi in dieser Datei keine Umgebungsvariablen aufloest.
providers:
  opencode-go:
    baseUrl: https://opencode.ai/zen/go/v1
    api: openai-completions
    apiKey: ${OPENCODE_API_KEY}
${OPENROUTER_BLOCK}
YML
chown agent:agent /home/agent/.omp/agent/models.yml
chmod 600 /home/agent/.omp/agent/models.yml
echo "models.yml geschrieben"
REMOTE

echo "Prüfe Modellerkennung …"
ssh "$HOST" 'su - agent -s /bin/bash -c "export PATH=\$HOME/.local/bin:\$PATH; omp models opencode-go --json 2>/dev/null | head -c 200"' \
  | python3 -c '
import json, sys
raw = sys.stdin.read()
print("Antwort erhalten." if raw.strip() else "Keine Antwort.")
'

# Ein Funktionstest PRO PROVIDER. Modellerkennung allein sagt nur, dass der
# Katalog abrufbar ist — nicht, dass ein Aufruf durchgeht.
for MODELL in "${FUNKTIONSTESTS[@]}"; do
echo "Funktionstest ${MODELL} …"
ssh "$HOST" "su - agent -s /bin/bash -c \"export PATH=\\\$HOME/.local/bin:\\\$PATH; cd /tmp && timeout 90 omp --print --mode json --no-session --model ${MODELL} 'antworte nur mit: ok' < /dev/null 2>&1\"" \
  | python3 -c '
import json, sys
err = None
ok = False
for line in sys.stdin:
    line = line.strip()
    if not line.startswith("{"):
        continue
    try:
        ev = json.loads(line)
    except json.JSONDecodeError:
        continue
    msg = ev.get("message") or {}
    if msg.get("errorMessage"):
        err = msg["errorMessage"]
    for part in (msg.get("content") or []):
        if part.get("type") == "text" and part.get("text"):
            ok = True
print("FEHLER: " + err.replace(chr(10), " ")[:120] if err else ("OK — Antwort erhalten." if ok else "UNKLAR: keine Textantwort."))
'
done
