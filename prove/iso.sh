#!/bin/bash
# Prova della ISO di CielOS in QEMU, su un disco vuoto: la live, l'installatore grafico, poi il sistema installato.
#   prove/iso.sh live [bios]      avvia la ISO (UEFI con OVMF; «bios» per la prova senza UEFI) sul disco vuoto
#   prove/iso.sh disco [bios]     avvia il sistema installato (senza la ISO)
#   prove/iso.sh ssh [utente] [cmd]   nella live: root con la chiave di prova (porta 2223)
#   prove/iso.sh foto FILE        lo schermo in PNG
#   prove/iso.sh punta X Y        sposta il cursore (Hyprland della live)
#   prove/iso.sh clic             clic sinistro dov'è il cursore (dal monitor di QEMU, come un mouse vero)
#   prove/iso.sh scrivi TESTO     tasti veri (sendkey)   ·   prove/iso.sh tasto NOME (ret, tab, esc…)
#   prove/iso.sh ferma            spegne
set -euo pipefail
D=~/cielos/vm
ISO=${CIELOS_ISO:-$D/cielos.iso}
DISCO=$D/disco-iso.raw
MON=/tmp/claude-1000/iso-monitor.sock
SSH=(ssh -i "$D/chiave_vm" -p 2223 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5)
monitor() { echo "$*" | socat - "UNIX-CONNECT:$MON" >/dev/null; }
avvia() {   # $1 = live|disco, $2 = bios?
    [ -f "$DISCO" ] || truncate -s 25G "$DISCO"
    local fw=()
    if [ "${2:-}" != bios ]; then
        [ -f "$D/ovmf-vars.fd" ] || cp /usr/share/edk2/x64/OVMF_VARS.4m.fd "$D/ovmf-vars.fd"
        fw=(-drive "if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd" -drive "if=pflash,format=raw,file=$D/ovmf-vars.fd")
    fi
    local cd=()
    [ "$1" = live ] && cd=(-cdrom "$ISO" -boot d)
    mkdir -p "$(dirname "$MON")"
    qemu-system-x86_64 -enable-kvm -cpu host -m 6144 -smp 4 -name cielos-iso "${fw[@]}" \
        -drive "file=$DISCO,format=raw,if=virtio" "${cd[@]}" \
        -nic "user,model=virtio,hostfwd=tcp:127.0.0.1:2223-:22" -vga std -display none \
        -audiodev none,id=a -device intel-hda -device hda-duplex,audiodev=a \
        -monitor "unix:$MON,server,nowait" -pidfile "$D/iso-qemu.pid" -daemonize
}
case "${1:-}" in
    live)  avvia live "${2:-}" ;;
    disco) avvia disco "${2:-}" ;;
    ssh)   shift; u=${1:-root}; shift || true; "${SSH[@]}" "$u@127.0.0.1" "$@" ;;
    foto)  monitor "screendump /tmp/claude-1000/iso-foto.ppm"; sleep 0.5; magick /tmp/claude-1000/iso-foto.ppm "$2" ;;
    punta) "${SSH[@]}" root@127.0.0.1 "export XDG_RUNTIME_DIR=/run/user/1000; export HYPRLAND_INSTANCE_SIGNATURE=\$(ls /run/user/1000/hypr | head -1); hyprctl dispatch 'hl.dsp.cursor.move({ x = $2, y = $3 })' >/dev/null" ;;
    clic)  monitor "mouse_button 1"; sleep 0.1; monitor "mouse_button 0" ;;
    scrivi)
        t=$2
        for ((i = 0; i < ${#t}; i++)); do
            c=${t:i:1}
            case "$c" in
                " ") k=spc ;; ".") k=dot ;; "-") k=minus ;; "@") k=shift_r-2 ;;
                [A-Z]) k="shift-$(echo "$c" | tr 'A-Z' 'a-z')" ;;
                *) k=$c ;;
            esac
            monitor "sendkey $k"; sleep 0.05
        done ;;
    tasto) monitor "sendkey $2" ;;
    ferma) monitor "system_powerdown" || kill "$(cat "$D/iso-qemu.pid")" ;;
    *) sed -n '2,12p' "$0" | sed 's/^# \?//' ;;
esac
