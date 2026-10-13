#!/bin/bash
# Dopo l'installazione, DENTRO la VM come root: istantanee snapper, accesso automatico dell'utente di prova su tty1
# con l'agente polkit finto (agente-prova.py), e il guardiano installato con il suo installa.sh.
# I file arrivano in /root/cielos (copiati da prova-guardiano-vm.sh). Uso: prepara-vm.sh UTENTE PASSWORD
set -euo pipefail
UTENTE=$1; PASSWORD=$2
snapper -c root list >/dev/null 2>&1 || snapper -c root create-config /
install -d /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \\\\u' --noclear --autologin $UTENTE %I \$TERM
EOF
install -m 755 -o "$UTENTE" /root/cielos/prove/agente-prova.py /home/$UTENTE/agente-prova.py
printf '%s\n' "$PASSWORD" > /home/$UTENTE/.password-prova
chown "$UTENTE:$UTENTE" /home/$UTENTE/.password-prova; chmod 600 /home/$UTENTE/.password-prova
cat > /home/$UTENTE/.bash_profile <<'EOF'
[ "$(tty)" = /dev/tty1 ] && exec python3 ~/agente-prova.py > ~/agente.log 2>&1
EOF
chown "$UTENTE:$UTENTE" /home/$UTENTE/.bash_profile
sh /root/cielos/guardiano/sistema/installa.sh
systemctl daemon-reload
systemctl restart getty@tty1
echo "PREPARATA"
