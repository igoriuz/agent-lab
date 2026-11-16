#!/usr/bin/env bash
# Repo in den Container spiegeln.
#
#   ./bin/sync.sh [host]
#
# .env ist ausgenommen: Sie wird von den Setup-Skripten verwaltet und traegt
# im Container andere Rechte (Gruppe `agent`, 640). Ein Abgleich vom Mac
# ueberschreibt Eigentuemer und Rechte und sperrt den Agenten aus — genau das
# ist am 2026-08-16 passiert.
set -euo pipefail
cd "$(dirname "$0")/.."
HOST="${1:-agent-lab}"
rsync -a --delete --exclude='.git' --exclude='.env' ./ "${HOST}:/opt/agent-lab/"
ssh "$HOST" 'chgrp -f agent /opt/agent-lab/.env 2>/dev/null; chmod -f 640 /opt/agent-lab/.env 2>/dev/null; true'
echo "synchronisiert nach ${HOST}:/opt/agent-lab"
