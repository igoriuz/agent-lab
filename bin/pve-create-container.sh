#!/usr/bin/env bash
# Legt den agent-lab-Container auf einem Proxmox-Host an.
#
#   ./bin/pve-create-container.sh [pve-host]
#
# Idempotent: Ein bereits vorhandener Container wird nicht angefasst.
# Zum Neuaufbau vorher `pct destroy 102` auf dem Host.
#
# Danach: ./bin/provision.sh

set -euo pipefail
cd "$(dirname "$0")/.."

PVE_HOST="${1:-pve}"
VMID="${VMID:-102}"
HOSTNAME="agent-lab"
IP="${IP:-192.168.1.20}"
GATEWAY="${GATEWAY:-192.168.1.1}"
TEMPLATE="local:vztmpl/debian-13-standard_13.6-1_amd64.tar.zst"
PUBKEY="${PUBKEY:-$HOME/.ssh/pve_id.pub}"

# --- Warum diese Werte ------------------------------------------------------
#
# DISK  Feste Größe = harte Grenze. Ein Agent, der Amok läuft, füllt seine
#       eigenen 32 GB und bekommt ENOSPC. Host und andere Gäste merken nichts.
#       Der Thin-Pool ist überbuchbar, deshalb ist die Grenze pro Container
#       die eigentliche Schutzmaßnahme.
#
# CORES 4 von 6 — zwei bleiben für HA und AdGuard übrig, selbst wenn hier
#       ein Build alle Kerne auslastet.
#
# UNITS 50 statt Standard 100. Bei Konkurrenz bekommt dieser Container
#       WENIGER CPU als HA und AdGuard. Hausautomation ist latenzempfindlich,
#       ein Build darf warten.
DISK_GB="${DISK_GB:-32}"
MEM_MB="${MEM_MB:-8192}"
SWAP_MB="${SWAP_MB:-1024}"
CORES="${CORES:-4}"
CPUUNITS="${CPUUNITS:-50}"

[ -f "$PUBKEY" ] || { echo "SSH-Public-Key nicht gefunden: $PUBKEY" >&2; exit 1; }

echo "Ziel: ${PVE_HOST}, VMID ${VMID}, ${HOSTNAME} auf ${IP}"

if ssh "$PVE_HOST" "pct config ${VMID}" >/dev/null 2>&1; then
  echo "Container ${VMID} existiert bereits — nichts zu tun."
  ssh "$PVE_HOST" "pct config ${VMID} | grep -E 'hostname|rootfs|cores|memory|net0|onboot'"
  exit 0
fi

# Key über stdin, nicht als Argument.
scp -q "$PUBKEY" "${PVE_HOST}:/tmp/agent-lab.pub"

ssh "$PVE_HOST" bash -s <<REMOTE
set -euo pipefail

pct create ${VMID} ${TEMPLATE} \
  --hostname ${HOSTNAME} \
  --rootfs local-lvm:${DISK_GB} \
  --memory ${MEM_MB} \
  --swap ${SWAP_MB} \
  --cores ${CORES} \
  --cpuunits ${CPUUNITS} \
  --net0 name=eth0,bridge=vmbr0,ip=${IP}/24,gw=${GATEWAY} \
  --nameserver ${GATEWAY} \
  --onboot 1 \
  --unprivileged 1 \
  --features nesting=1 \
  --ssh-public-keys /tmp/agent-lab.pub \
  --description 'agent-lab - Orchestrator und Build-Umgebung. Repo: agent-lab'

rm -f /tmp/agent-lab.pub
pct start ${VMID}

# Warten, bis Netz steht
for i in \$(seq 1 30); do
  pct exec ${VMID} -- getent hosts deb.debian.org >/dev/null 2>&1 && break
  sleep 2
done

echo "--- Container läuft ---"
pct config ${VMID} | grep -E 'hostname|rootfs|cores|cpuunits|memory|net0|onboot|unprivileged'
REMOTE

echo
echo "Angelegt. Nächster Schritt: ./bin/provision.sh"
echo "Für 'ssh agent-lab' vom Mac in ~/.ssh/config eintragen:"
echo
echo "  Host agent-lab"
echo "      HostName ${IP}"
echo "      User root"
echo "      IdentityFile ${PUBKEY%.pub}"
echo "      IdentitiesOnly yes"
echo "      IdentityAgent none"
