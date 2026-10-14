#!/bin/sh
# Il guardiano di CielOS. Da lanciare a mano: sudo ~/cielos/guardiano/sistema/installa.sh
#   (senza argomenti)  copia il guardiano in /usr/lib/cielos/guardiano (di root: Ciel non può modificarlo),
#                      registra servizio, D-Bus e azioni polkit (password ogni volta) e il controllo dell'avvio
#                      dopo gli aggiornamenti (cielos-avvio.service: senza aggiornamenti in prova non parte)
#   ondate             in più: i repository di Arch (core, extra, multilib) fermi a un giorno dell'Arch Linux
#                      Archive, che avanza solo quando lo approvi (pacman.conf salvato in pacman.conf.cielos-prima)
#   ondate togli       i repository tornano quelli di prima
#   togli              toglie tutto (il registro in /var/log/cielos e lo stato in /var/lib/cielos restano)
set -e
QUI=$(dirname "$(readlink -f "$0")")
[ "$(id -u)" = 0 ] || { echo "serve sudo: sudo $0 $*"; exit 1; }
DEST=/usr/lib/cielos/guardiano
CONF=/etc/pacman.conf

if [ "$1" = ondate ]; then
    if [ "$2" = togli ]; then
        [ -f $CONF.cielos-prima ] && mv $CONF.cielos-prima $CONF
        rm -f /etc/pacman.d/cielos-ondata
        echo "Ondate tolte: i repository sono di nuovo quelli di prima."
        exit 0
    fi
    if grep -q '^\[cachyos' $CONF; then
        echo "Qui ci sono i repository di CachyOS: le ondate fermerebbero solo i pacchetti di Arch, mentre quelli"
        echo "di CachyOS (che li sostituiscono quasi tutti) continuerebbero ad arrivare subito. Non le attivo."
        exit 1
    fi
    grep -q cielos-ondata $CONF && { echo "Le ondate sono già attive."; exit 0; }
    cp $CONF $CONF.cielos-prima
    # nelle sezioni core, extra e multilib il server diventa l'ondata (le -testing, se ci sono, restano come sono)
    awk '/^\[/{s=$0} (s=="[core]"||s=="[extra]"||s=="[multilib]") && /^Include *= *\/etc\/pacman.d\/mirrorlist/{print "Include = /etc/pacman.d/cielos-ondata"; next} {print}' \
        $CONF.cielos-prima > $CONF
    IERI=$(date -d yesterday +%Y/%m/%d)
    printf '# CielOS: i repository di Arch fermi a un giorno (lo cambia solo il guardiano)\nServer = https://archive.archlinux.org/repos/%s/$repo/os/$arch\n' \
        "$IERI" > /etc/pacman.d/cielos-ondata
    echo "Ondate attive: i pacchetti di Arch sono fermi a ieri ($IERI). Avanzano quando approvi un aggiornamento."
    exit 0
fi

if [ "$1" = togli ]; then
    systemctl stop cielos-guardiano.service 2>/dev/null || true
    systemctl disable cielos-avvio.service 2>/dev/null || true
    rm -f /etc/systemd/system/cielos-guardiano.service /etc/systemd/system/cielos-avvio.service \
          /usr/share/dbus-1/system.d/org.cielos.Guardiano.conf \
          /usr/share/dbus-1/system-services/org.cielos.Guardiano.service \
          /usr/share/polkit-1/actions/org.cielos.guardiano.policy
    rm -rf "$DEST"
    systemctl daemon-reload
    echo "Guardiano tolto."
    exit 0
fi
install -d -m 755 "$DEST"
install -m 644 "$QUI/../guardiano.py" "$QUI/../azioni.py" "$QUI/../aggiornamenti.py" "$QUI/../avvio.py" \
    "$QUI/../PROGETTO.md" "$DEST/"
install -m 644 "$QUI/cielos-guardiano.service" "$QUI/cielos-avvio.service" /etc/systemd/system/
install -m 644 "$QUI/org.cielos.Guardiano.conf" /usr/share/dbus-1/system.d/
install -m 644 "$QUI/org.cielos.Guardiano.service" /usr/share/dbus-1/system-services/
install -m 644 "$QUI/org.cielos.guardiano.policy" /usr/share/polkit-1/actions/
install -d -m 750 /var/log/cielos
install -d -m 755 /var/lib/cielos /var/lib/cielos/aggiornamenti
systemctl daemon-reload
systemctl enable cielos-avvio.service >/dev/null 2>&1
systemctl reload dbus 2>/dev/null || systemctl reload dbus-broker 2>/dev/null || true
echo "Guardiano installato. Si accende da solo quando Ciel chiede qualcosa. Per toglierlo: sudo $0 togli"
