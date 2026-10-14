#!/bin/bash
# Dopo un aggiornamento di Limine (hook di pacman): la copia sulla partizione di avvio si aggiorna anche lei.
# Solo sui sistemi installati dall'installatore di CielOS (/etc/cielos/avvio = limine-cielos): altrove
# (es. CachyOS con limine-entry-tool) ci pensano i loro strumenti.
[ "$(cat /etc/cielos/avvio 2>/dev/null)" = limine-cielos ] || exit 0
[ -f /boot/EFI/BOOT/BOOTX64.EFI ] && cp /usr/share/limine/BOOTX64.EFI /boot/EFI/BOOT/BOOTX64.EFI
if [ -f /boot/limine-bios.sys ]; then
    cp /usr/share/limine/limine-bios.sys /boot/limine-bios.sys
    part=$(findmnt -no SOURCE /boot)
    disco=/dev/$(lsblk -no PKNAME "$part" | head -1)
    # la partizione 1 è «BIOS boot» (l'ha creata l'installatore): lì va lo stadio 2
    if [ "$(lsblk -no PARTTYPE "${disco}1" "${disco}p1" 2>/dev/null | head -1)" = 21686148-6449-6e6f-744e-656564454649 ]; then
        limine bios-install "$disco" 1 >/dev/null
    fi
fi
echo "Limine aggiornato anche sulla partizione di avvio"
