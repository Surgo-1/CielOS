#!/bin/bash
# /usr/lib/cielos/cielos-repo: i repository di CielOS su questo PC. Mette la chiave di CielOS nel portachiavi di
# pacman, la sezione [cielos] di pacman.conf (firma obbligatoria, server dalla lista del pacchetto:
# /etc/pacman.d/cielos-mirrorlist, GitHub) e accende [multilib] (i pacchetti a 32 bit: Steam e i giochi), fermo
# all'ondata se le ondate sono attive. Lo chiamano l'installatore e il pacchetto cielos a ogni aggiornamento; non fa
# niente nella live (lì il repository è quello della ISO).
C=${1:-/etc/pacman.conf}
[ -e /etc/cielos-live ] && exit 0
pacman-key --populate cielos >/dev/null 2>&1 || echo "   (la chiave di CielOS non è nel portachiavi: sudo pacman-key --populate cielos)"
[ -f "$C" ] || exit 0

# multilib, se è ancora quello commentato di Arch
if grep -q '^#\[multilib\]' "$C" && ! grep -q '^\[multilib\]' "$C"; then
    INC=/etc/pacman.d/mirrorlist
    grep -q '^Include *= */etc/pacman.d/cielos-ondata' "$C" && INC=/etc/pacman.d/cielos-ondata
    awk -v inc="$INC" '/^#\[multilib\]$/ { print "[multilib]"; if ((getline r) > 0 && r !~ /^#?Include/) print r; print "Include = " inc; next } { print }' \
        "$C" > "$C.cielos" && mv "$C.cielos" "$C"
fi

grep -q 'cielos-mirrorlist' "$C" && exit 0
if grep -q '^\[cielos\]' "$C"; then
    awk '/^\[/{s=$0} s=="[cielos]" && /^[[:space:]]*(SigLevel|Server|Include)[[:space:]]*=/{next} {print}
         $0=="[cielos]"{print "SigLevel = Required DatabaseRequired"; print "Include = /etc/pacman.d/cielos-mirrorlist"}' \
        "$C" > "$C.cielos" && mv "$C.cielos" "$C"
else
    printf '\n[cielos]\nSigLevel = Required DatabaseRequired\nInclude = /etc/pacman.d/cielos-mirrorlist\n' >> "$C"
fi
