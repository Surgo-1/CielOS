#!/bin/bash
# Il kernel nel menu di avvio si chiama «CielOS-<versione di Linux>» (es. CielOS-7.2.9, e CielOS-7.2.9 (ripiego)).
# Lo rifà l'hook di pacman a ogni aggiornamento del kernel. Solo con il Limine messo dall'installatore di CielOS
# (/etc/cielos/avvio = limine-cielos): le altre configurazioni (CachyOS, limine-entry-tool…) non si toccano.
[ "$(cat /etc/cielos/avvio 2>/dev/null)" = limine-cielos ] || exit 0
conf=/boot/limine.conf
[ -w "$conf" ] || exit 0
v=$(pacman -Q linux 2>/dev/null | awk '{print $2}' | cut -d. -f1-3 | grep -oE '^[0-9]+(\.[0-9]+)*')
[ -n "$v" ] || exit 0
# solo le voci di CielOS (/CielOS, /CielOS-x.y.z, con o senza «(ripiego)»)
sed -i -E "s|^/CielOS(-[0-9.]+)?( \(ripiego\))?[[:space:]]*\$|/CielOS-$v\2|" "$conf"
echo "Menu di avvio: CielOS-$v"
