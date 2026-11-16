#!/usr/bin/env bash
# Bringt skills/ dorthin, wo Hermes sie sucht — als Einweg-Projektion.
#
#   adapters/hermes/install.sh [ssh-ziel]      Standard: hermes
#
# Hermes liest Skills als Verzeichnisse mit SKILL.md und YAML-Frontmatter,
# also unverändert das Format aus skills/. Sie landen unter
# ~/.hermes/skills/agent-lab/, getrennt von den mitgelieferten Skills, damit
# --delete nur unsere eigenen räumt.
#
# memory/ wird NICHT übertragen. Hermes hat ein eigenes Gedächtnis pro
# Profil, das der Bot selbst schreibt; memory/ in Git ist Faden und
# Versucht-Liste und wird nur vom Orchestrator geschrieben. Zwei Dinge,
# bewusst getrennt — siehe orchestrator/hermes.md.
set -euo pipefail
cd "$(dirname "$0")/../.."
ZIEL="${1:-hermes}"
ssh "$ZIEL" 'mkdir -p ~/.hermes/skills/agent-lab'
rsync -a --delete --exclude='.DS_Store' skills/ "${ZIEL}:~/.hermes/skills/agent-lab/"
echo "skills/ → ${ZIEL}:~/.hermes/skills/agent-lab/ ($(find skills -name SKILL.md | wc -l | tr -d ' ') Skills)"
