#!/bin/sh
# Il guardiano di CielOS. Da lanciare a mano: sudo ~/cielos/guardiano/sistema/installa.sh
#   (senza argomenti)  copia il guardiano in /usr/lib/cielos/guardiano (di root: Ciel non può modificarlo) e
#                      registra servizio, D-Bus e azioni polkit (password ogni volta)
#   togli              toglie tutto (il registro in /var/log/cielos resta)
set -e
QUI=$(dirname "$(readlink -f "$0")")
[ "$(id -u)" = 0 ] || { echo "serve sudo: sudo $0 $*"; exit 1; }
DEST=/usr/lib/cielos/guardiano
if [ "$1" = togli ]; then
    systemctl stop cielos-guardiano.service 2>/dev/null || true
    rm -f /etc/systemd/system/cielos-guardiano.service /usr/share/dbus-1/system.d/org.cielos.Guardiano.conf \
          /usr/share/dbus-1/system-services/org.cielos.Guardiano.service \
          /usr/share/polkit-1/actions/org.cielos.guardiano.policy
    rm -rf "$DEST"
    systemctl daemon-reload
    echo "Guardiano tolto."
    exit 0
fi
install -d -m 755 "$DEST"
install -m 644 "$QUI/../guardiano.py" "$QUI/../azioni.py" "$QUI/../PROGETTO.md" "$DEST/"
install -m 644 "$QUI/cielos-guardiano.service" /etc/systemd/system/
install -m 644 "$QUI/org.cielos.Guardiano.conf" /usr/share/dbus-1/system.d/
install -m 644 "$QUI/org.cielos.Guardiano.service" /usr/share/dbus-1/system-services/
install -m 644 "$QUI/org.cielos.guardiano.policy" /usr/share/polkit-1/actions/
install -d -m 750 /var/log/cielos
systemctl daemon-reload
systemctl reload dbus 2>/dev/null || systemctl reload dbus-broker 2>/dev/null || true
echo "Guardiano installato. Si accende da solo quando Ciel chiede qualcosa. Per toglierlo: sudo $0 togli"
