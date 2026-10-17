# ScamBaiting: white-hat scammer time-wasting rig

One-command disposable honeypot VM: each session clones a golden Windows image, forces all
traffic through your VPN (fail-closed firewall), records a pcap, and destroys everything afterwards.

**Defensive only.** The guest cannot reach your host or LAN, cannot SSH/SMB/RDP/SMTP out, and cannot
scan. Never connect out to scammers' machines or use their credentials: that is unauthorized access
in most jurisdictions. Collect evidence, then report (FTC, IC3, abuse contacts).

## Quick start (Linux: Fedora/Nobara, Debian/Ubuntu, Arch)
    git clone https://github.com/codeAIoliNUX/ScamBaiting.git
    cd ScamBaiting && ./install.sh
    bait persona        # generate a fake persona
    # build the golden VM (below), then:
    bait setup && bait start

## Golden image (you must build your own: Windows can't be redistributed)
1. virt-manager: install Windows to /var/lib/libvirt/images/golden-win.qcow2 (SATA disk, e1000e NIC).
2. Local account only. No Microsoft login, no shared folders, no spice-guest-tools.
3. Serve `persona/seed.ps1` (python3 -m http.server) and run the line `bait persona` printed.
4. Install the remote-access tool scammers use (e.g. AnyDesk), shut down, run `bait setup`.

## Commands
`bait doctor | persona | setup | start | status | clean`

## Safety checklist
- Test the kill switch: disconnect the VPN mid-session; the VM must lose all connectivity.
- Treat session overlays and any dropped files as hostile (`KEEP_DISK=1` quarantines them).
- Use a throwaway VoIP number and a fake persona. Never real data.

## Roadmap
Evidence/report generator, Tauri one-click GUI, static site with safety and legal guide.
Not legal advice: know your local laws.
