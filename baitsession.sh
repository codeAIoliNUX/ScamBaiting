#!/usr/bin/env bash
# baitsession.sh - one-click disposable honeypot VM session (clone -> boot -> bind -> record -> teardown)
# Usage: sudo ./baitsession.sh start|setup|status
set -Eeuo pipefail

# ---------- config (override via env) ----------
GOLDEN="${GOLDEN:-/var/lib/libvirt/images/golden-win.qcow2}"   # read-only golden image, never booted directly
VPN_IF="${VPN_IF:-surfshark_wg}"            # check with: ip -br link  (wg/tun name of your tunnel)
NET="bait-net"; BR="virbr-bait"; SUBNET="192.168.77"
ROOT="${ROOT:-$HOME/scambait}"
SID="$(date +%Y%m%d-%H%M%S)-$(head -c3 /dev/urandom | xxd -p)"
DIR="$ROOT/sessions/$SID"
OVERLAY="$DIR/overlay.qcow2"
DOM="bait-$SID"
KEEP_DISK="${KEEP_DISK:-0}"                 # 1 = archive overlay to quarantine (treat as hostile!)
VCPUS=4; RAM_MB=6144
export LIBVIRT_DEFAULT_URI="qemu:///system"

log() { printf '[%s] %s\n' "$(date +%T)" "$*"; }
die() { log "ERROR: $*"; exit 1; }

# ---------- one-time setup: isolated libvirt net pinned to the VPN interface ----------
setup() {
  virsh net-info "$NET" &>/dev/null && { log "$NET already defined"; return; }
  cat > /tmp/$NET.xml <<EOF
<network>
  <name>$NET</name>
  <forward mode='nat' dev='$VPN_IF'/>
  <bridge name='$BR' stp='on' delay='0'/>
  <ip address='$SUBNET.1' netmask='255.255.255.0'>
    <dhcp><range start='$SUBNET.100' end='$SUBNET.150'/></dhcp>
  </ip>
</network>
EOF
  virsh net-define /tmp/$NET.xml
  virsh net-autostart "$NET"
  log "Defined $NET. Make golden image read-only: chmod a-w $GOLDEN"
}

# ---------- preflight ----------
preflight() {
  [[ $EUID -eq 0 ]] || die "run as root (nft/tcpdump/virsh)"
  [[ -f "$GOLDEN" ]] || die "golden image missing: $GOLDEN"
  ip link show "$VPN_IF" up &>/dev/null || die "VPN interface $VPN_IF is down"
  ip route get 1.1.1.1 | grep -q "dev $VPN_IF" || die "default route is NOT via $VPN_IF (leak risk)"
  virsh net-info "$NET" &>/dev/null || die "run '$0 setup' first"
  virsh net-start "$NET" 2>/dev/null || true
  EXIT_IP="$(curl -fsS --max-time 8 --interface "$VPN_IF" https://ifconfig.me || true)"
  [[ -n "$EXIT_IP" ]] || die "could not determine VPN exit IP"
  log "VPN exit IP: $EXIT_IP"
}

# ---------- fail-closed firewall: guest may ONLY leave via VPN; no host/LAN access ----------
guard_up() {
  nft add table inet baitguard
  nft add chain inet baitguard fwd '{ type filter hook forward priority -10; policy accept; }'
  nft add rule  inet baitguard fwd iifname "$BR" oifname != "$VPN_IF" drop
  nft add chain inet baitguard in '{ type filter hook input priority -10; policy accept; }'
  nft add rule  inet baitguard in iifname "$BR" udp dport '{53,67}' accept
  nft add rule  inet baitguard in iifname "$BR" tcp dport 53 accept
  nft add rule  inet baitguard in iifname "$BR" drop
  log "kill-switch rules active"
}
guard_down() { nft delete table inet baitguard 2>/dev/null || true; }

# ---------- optional OBS control (needs obs-cmd + obs-websocket enabled) ----------
obs() { command -v obs-cmd &>/dev/null && sudo -u "${SUDO_USER:-$USER}" obs-cmd "$@" || true; }

# ---------- teardown (always runs) ----------
teardown() {
  set +e
  log "tearing down $SID"
  obs recording stop
  [[ -n "${TCPDUMP_PID:-}" ]] && kill "$TCPDUMP_PID" 2>/dev/null
  virsh destroy "$DOM" &>/dev/null            # transient domain vanishes on destroy
  if [[ "$KEEP_DISK" == "1" ]]; then
    mkdir -p "$ROOT/quarantine" && mv "$OVERLAY" "$ROOT/quarantine/$SID.qcow2"
    chmod 000 "$ROOT/quarantine/$SID.qcow2"
    log "overlay quarantined (do NOT boot outside an isolated lab)"
  else
    shred -u "$OVERLAY" 2>/dev/null || rm -f "$OVERLAY"
  fi
  guard_down
  { echo "{\"session\":\"$SID\",\"vpn_exit_ip\":\"$EXIT_IP\",\"ended\":\"$(date -Is)\"}"; } > "$DIR/session.json"
  chown -R "${SUDO_USER:-root}": "$DIR" 2>/dev/null
  log "done. evidence in $DIR (pcap + notes)"
}

start() {
  preflight
  mkdir -p "$DIR"; chmod 700 "$DIR"
  trap teardown EXIT INT TERM

  qemu-img create -q -f qcow2 -F qcow2 -b "$GOLDEN" "$OVERLAY"   # copy-on-write clone, golden untouched
  guard_up

  tcpdump -i "$BR" -w "$DIR/capture.pcap" -U &>/dev/null & TCPDUMP_PID=$!

  virt-install --name "$DOM" --transient --import --noautoconsole \
    --vcpus "$VCPUS" --memory "$RAM_MB" --osinfo win10 \
    --disk "path=$OVERLAY,bus=sata" \
    --network "network=$NET,model=e1000e" \
    --graphics spice --video qxl \
    --channel unix,target.type=virtio,target.name=org.qemu.guest_agent.0
  log "VM $DOM booted"

  obs recording start
  command -v virt-viewer &>/dev/null && sudo -u "${SUDO_USER:-$USER}" virt-viewer "$DOM" &

  log "SESSION LIVE. Log numbers/IDs/URLs in $DIR/notes.md. Press Enter to end and destroy."
  touch "$DIR/notes.md"
  read -r
}

case "${1:-start}" in
  setup)  setup ;;
  start)  start ;;
  status) virsh list --all; nft list table inet baitguard 2>/dev/null || echo "guard not active" ;;
  *) die "usage: $0 setup|start|status" ;;
esac
