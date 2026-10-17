#!/usr/bin/env bash
# One-command installer: ./install.sh   (never run as root; it uses sudo where needed)
set -euo pipefail
[[ $EUID -ne 0 ]] || { echo "Run as your normal user, not root."; exit 1; }
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

echo "[1/5] Installing dependencies"
if   command -v dnf     &>/dev/null; then sudo dnf install -y qemu-img qemu-kvm libvirt virt-install virt-viewer virt-manager nftables tcpdump curl
elif command -v apt-get &>/dev/null; then sudo apt-get update && sudo apt-get install -y qemu-utils qemu-system-x86 libvirt-daemon-system libvirt-clients virtinst virt-viewer virt-manager nftables tcpdump curl
elif command -v pacman  &>/dev/null; then sudo pacman -S --needed --noconfirm qemu-base libvirt virt-install virt-viewer virt-manager dnsmasq nftables tcpdump curl
else echo "Unsupported distro: install qemu, libvirt, virt-install, virt-viewer, nftables, tcpdump, curl manually."; fi

echo "[2/5] Enabling libvirt"
sudo systemctl enable --now libvirtd 2>/dev/null || sudo systemctl enable --now virtqemud.socket
sudo usermod -aG libvirt "$USER" || true

echo "[3/5] Linking command"
chmod +x "$HERE/bin/bait"; mkdir -p "$HOME/.local/bin" "$HERE/sessions"
ln -sf "$HERE/bin/bait" "$HOME/.local/bin/bait"
[[ -f "$HERE/config/bait.env" ]] || cp "$HERE/config/bait.env.example" "$HERE/config/bait.env"

echo "[4/5] Preparing overlay directory"
sudo mkdir -p /var/lib/libvirt/images/bait-sessions

echo "[5/5] Health check"
"$HERE/bin/bait" doctor || true
cat <<MSG

Next: build your own golden Windows VM (see README), then: bait setup && bait start
You may need to log out/in once for the libvirt group to apply.
MSG
