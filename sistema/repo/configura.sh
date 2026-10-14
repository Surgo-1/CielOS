#!/bin/bash
# /usr/lib/cielos/cielos-repo: il repository di CielOS su questo PC. Mette la chiave di CielOS nel portachiavi di
# pacman e la sezione [cielos] di pacman.conf: firma obbligatoria, server dalla lista del pacchetto
# (/etc/pacman.d/cielos-mirrorlist: GitHub). Lo chiamano l'installatore e
# il pacchetto cielos a ogni aggiornamento; non fa niente nella live (lì il repository è quello della ISO).
C=${1:-/etc/pacman.conf}
[ -e /etc/cielos-live ] && exit 0
pacman-key --populate cielos >/dev/null 2>&1 || echo "   (la chiave di CielOS non è nel portachiavi: sudo pacman-key --populate cielos)"
[ -f "$C" ] || exit 0
grep -q 'cielos-mirrorlist' "$C" && exit 0
if grep -q '^\[cielos\]' "$C"; then
    awk '/^\[/{s=$0} s=="[cielos]" && /^[[:space:]]*(SigLevel|Server|Include)[[:space:]]*=/{next} {print}
         $0=="[cielos]"{print "SigLevel = Required DatabaseRequired"; print "Include = /etc/pacman.d/cielos-mirrorlist"}' \
        "$C" > "$C.cielos" && mv "$C.cielos" "$C"
else
    printf '\n[cielos]\nSigLevel = Required DatabaseRequired\nInclude = /etc/pacman.d/cielos-mirrorlist\n' >> "$C"
fi
