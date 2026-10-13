#!/bin/bash
# La macchina virtuale di prova di CielOS (Arch in QEMU, senza finestra: ci si entra con ssh).
# I file grossi stanno in ~/cielos/vm (fuori da git): ISO, disco, chiave ssh, credenziali di prova.
#   vm.sh live      avvia la ISO (per installare)        vm.sh avvia    avvia il sistema installato
#   vm.sh ssh [utente] [comando…]                        vm.sh ferma    spegne la VM
#   vm.sh stato
set -euo pipefail
D=~/cielos/vm
ISO=$D/archlinux-2026.10.01-x86_64.iso
SSH=(ssh -i "$D/chiave_vm" -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR
     -o ConnectTimeout=5)
comune=(qemu-system-x86_64 -enable-kvm -cpu host -m 3072 -smp 2 -name cielos-vm
        -drive "file=$D/disco.raw,format=raw,if=virtio"
        -nic "user,model=virtio,hostfwd=tcp:127.0.0.1:2222-:22"
        -display none -serial "file:$D/seriale.log" -monitor "unix:$D/monitor.sock,server,nowait"
        -pidfile "$D/qemu.pid" -daemonize)
case "${1:-stato}" in
  live)
    [ -f "$D/disco.raw" ] || truncate -s 30G "$D/disco.raw"
    "${comune[@]}" -drive "file=$D/seed.img,format=raw,if=virtio" -cdrom "$ISO" -boot d ;;
  avvia) "${comune[@]}" -boot c ;;
  ssh)   shift; u=${1:-root}; shift || true; "${SSH[@]}" "$u@127.0.0.1" "$@" ;;
  ferma) echo system_powerdown | socat - "UNIX-CONNECT:$D/monitor.sock" >/dev/null 2>&1 \
           || kill "$(cat "$D/qemu.pid")" ;;
  stato) [ -f "$D/qemu.pid" ] && kill -0 "$(cat "$D/qemu.pid")" 2>/dev/null && echo accesa || echo spenta ;;
esac
