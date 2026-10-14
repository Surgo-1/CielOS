#!/bin/sh
# Il login a tema Ciel (SDDM). Da lanciare a mano: sudo ~/cielos/sistema/sddm-ciel/installa.sh
#   (senza argomenti)  copia il tema in /usr/share/sddm/themes/ciel e lo attiva con /etc/sddm.conf.d/30-ciel.conf
#                      (rilanciarlo dopo aver cambiato i colori in Ciel li porta anche nel login)
#   togli              torna al tema di prima: toglie solo 30-ciel.conf
# Il tema di prima resta dov'è. Se il login non partisse: Ctrl+Alt+F2, entra, e «sudo rm /etc/sddm.conf.d/30-ciel.conf».
set -e
QUI=$(dirname "$(readlink -f "$0")")
TEMA=/usr/share/sddm/themes/ciel
CONF=/etc/sddm.conf.d/30-ciel.conf
[ "$(id -u)" = 0 ] || { echo "serve sudo: sudo $0 $*"; exit 1; }
if [ "$1" = togli ]; then
    rm -f "$CONF"
    echo "Tolto: al prossimo login torna il tema di prima."
    exit 0
fi
mkdir -p "$TEMA"
install -m 644 "$QUI/Main.qml" "$QUI/metadata.desktop" "$QUI/theme.conf" "$TEMA/"
install -m 644 "$QUI/CielAvatar.qml" "$TEMA/"
# i colori scelti in Ciel (cieltema): se ci sono, sopra a quelli di serie
UTENTE_HOME=$(getent passwd "${SUDO_USER:-$(logname 2>/dev/null)}" | cut -d: -f6)
if [ -n "$UTENTE_HOME" ] && [ -f "$UTENTE_HOME/.config/cielos/sddm.conf" ]; then
    install -m 644 "$UTENTE_HOME/.config/cielos/sddm.conf" "$TEMA/theme.conf.user"
else
    rm -f "$TEMA/theme.conf.user"
fi
mkdir -p /etc/sddm.conf.d
printf '[Theme]\nCurrent=ciel\n' > "$CONF"
echo "Installato: lo vedi al prossimo login. Per tornare indietro: sudo $0 togli"
