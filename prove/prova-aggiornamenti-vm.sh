#!/bin/bash
# Prova degli aggiornamenti sicuri (fase 5) nella VM (prove/vm.sh), SENZA Internet: un repository locale con un
# «desktop» finto (cielos-prova-desktop: v1 parte, v2 no; i pacchetti li costruisce questo script con makepkg).
#   1. prepara   guardiano nuovo installato, core/extra spenti (niente download), v1 installata e accesa,
#                /etc/cielos/avvio.conf: «segnale=servizio:cielos-prova-desktop.service»
#   2. rotto     arriva la v2 → aggiorna dal guardiano (password giusta, agente finto) → in prova → riavvio →
#                il servizio fallisce → il sistema torna indietro da solo e riavvia → di nuovo v1, ritorno registrato
#   3. buono     arriva una v3 che funziona → aggiorna → riavvio → confermato, niente ritorno
#   4. ripristina  pacman.conf com'era, pacchetto finto tolto
# Uso: prova-aggiornamenti-vm.sh [prepara|rotto|buono|ripristina|tutto]
set -uo pipefail
QUI=$(dirname "$(readlink -f "$0")")
D=~/cielos/vm
source <(sed 's/^/export /' "$D/credenziali.txt")
vm() { "$QUI/vm.sh" ssh "$@"; }
SCP=(scp -q -i "$D/chiave_vm" -P 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR)
PK=$(mktemp -d)
trap 'rm -rf "$PK"' EXIT

pacchetto() {   # versione funziona(1|0)
    mkdir -p "$PK/v$1"
    cat > "$PK/v$1/PKGBUILD" <<E
pkgname=cielos-prova-desktop
pkgver=$1
pkgrel=1
pkgdesc="SOLO PER LA VM DI PROVA: fa le veci del desktop"
arch=(any)
license=(MIT)
options=(!strip !debug)
package() {
  install -d "\$pkgdir/usr/bin" "\$pkgdir/usr/lib/systemd/system"
  if [ $2 = 1 ]; then printf '#!/bin/sh\nexec sleep infinity\n' > "\$pkgdir/usr/bin/cielos-prova-desktop"
  else printf '#!/bin/sh\necho "desktop rotto (prova)" >&2\nexit 1\n' > "\$pkgdir/usr/bin/cielos-prova-desktop"; fi
  chmod 755 "\$pkgdir/usr/bin/cielos-prova-desktop"
  printf '[Unit]\nDescription=Desktop finto della VM di prova\n[Service]\nExecStart=/usr/bin/cielos-prova-desktop\n[Install]\nWantedBy=multi-user.target\n' > "\$pkgdir/usr/lib/systemd/system/cielos-prova-desktop.service"
}
E
    (cd "$PK/v$1" && PKGDEST="$PK" makepkg -f >/dev/null 2>&1) || { echo "makepkg non riuscito"; exit 1; }
    "${SCP[@]}" "$PK"/cielos-prova-desktop-$1-1-any.pkg.tar.zst root@127.0.0.1:/srv/prova/v/
    vm root "repo-add -q /srv/prova/v/cielos-prova.db.tar.gz /srv/prova/v/cielos-prova-desktop-$1-1-any.pkg.tar.zst"
}

chiedi() {   # azione json risposta (dall'agente finto nella sessione locale della VM)
    vm "$utente" "python3 -c '
import json, socket, sys
s = socket.socket(socket.AF_UNIX); s.connect(\"/tmp/prova-guardiano.sock\")
s.sendall((json.dumps({\"azione\": sys.argv[1], \"parametri\": json.loads(sys.argv[2]), \"risposta\": sys.argv[3]}) + \"\\n\").encode())
print(s.makefile().readline().strip()[:600])' '$1' '$2' '$3'"
}

aspetta_riavvio() {   # aspetta che la VM si spenga e torni raggiungibile
    local t0=$SECONDS
    while vm root true 2>/dev/null; do sleep 3; [ $((SECONDS - t0)) -gt 400 ] && { echo "   (non si è riavviata)"; return 1; }; done
    echo "   …riavvio ($((SECONDS - t0)) s)"
    while ! vm root true 2>/dev/null; do sleep 3; [ $((SECONDS - t0)) -gt 600 ] && { echo "   (non torna)"; return 1; }; done
    echo "   …di nuovo su ($((SECONDS - t0)) s)"
    sleep 5
}

stato() {
    vm root 'echo "   pacchetto: $(pacman -Q cielos-prova-desktop)  desktop: $(systemctl is-active cielos-prova-desktop)"
             echo "   in prova: $(cat /var/lib/cielos/aggiornamenti/in-prova.json 2>/dev/null | tr -d "\n " | cut -c1-160 || echo no)"
             echo "   ritorni: $(python3 -c "import json;r=json.load(open(\"/var/lib/cielos/aggiornamenti/ritorni.json\"));print(len(r), r[-1][\"motivo\"], r[-1][\"pacchetti\"])" 2>/dev/null || echo 0)"
             echo "   sottovolumi: $(btrfs subvolume list / | grep -v snapshots | awk "{print \$NF}" | tr "\n" " ")"'
}

prepara() {
    echo "── prepara"
    vm root "rm -rf /root/cielos && mkdir -p /root/cielos /srv/prova/v"
    "${SCP[@]}" -r ~/cielos/guardiano root@127.0.0.1:/root/cielos/
    vm root 'set -e
        sh /root/cielos/guardiano/sistema/installa.sh >/dev/null
        [ -f /etc/pacman.conf.prova-offline ] || cp /etc/pacman.conf /etc/pacman.conf.prova-offline
        awk "/^\[/{s=\$0} (s==\"[core]\"||s==\"[extra]\") {print \"#\" \$0; next} {print}" /etc/pacman.conf.prova-offline > /etc/pacman.conf
        printf "\n[cielos-prova]\nSigLevel = Optional TrustAll\nServer = file:///srv/prova/v\n" >> /etc/pacman.conf
        rm -f /srv/prova/v/*
        mkdir -p /etc/cielos && echo "segnale=servizio:cielos-prova-desktop.service" > /etc/cielos/avvio.conf
        rm -f /var/lib/cielos/aggiornamenti/in-prova.json'
    pacchetto 1 1
    vm root 'pacman -Sy --noconfirm cielos-prova-desktop >/dev/null && systemctl enable --now cielos-prova-desktop 2>/dev/null; faillock --user '"$utente"' --reset'
    stato
}

rotto() {
    echo "── arriva la v2, che rompe il «desktop»"
    pacchetto 2 0
    chiedi aggiorna '{}' giusta
    stato
    echo "   riavvio (come faresti tu)"; vm root "systemctl reboot" 2>/dev/null
    aspetta_riavvio || return
    echo "   (al primo avvio il servizio d'avvio vede il desktop fallire, torna indietro e riavvia: può essere già successo)"
    local t0=$SECONDS
    until vm root "[ ! -f /var/lib/cielos/aggiornamenti/in-prova.json ] && pacman -Q cielos-prova-desktop | grep -q ' 1-1'" 2>/dev/null; do
        sleep 4; [ $((SECONDS - t0)) -gt 300 ] && { echo "   (non è tornata indietro)"; break; }
    done
    stato
    echo "   (il registro dell'avvio fallito resta nel sottovolume «rotto», con il sistema di quel momento)"
}

buono() {
    echo "── arriva la v3, che funziona"
    pacchetto 3 1
    vm root "faillock --user $utente --reset"
    chiedi aggiorna '{}' giusta
    echo "   riavvio"; vm root "systemctl reboot" 2>/dev/null
    aspetta_riavvio || return
    echo "   aspetto la conferma (il desktop deve restare su 90 s)…"; sleep 110
    stato
    vm root "journalctl -b -u cielos-avvio --no-pager -o cat | tail -3"
}

ripristina() {
    echo "── ripristina"
    vm root '[ -f /etc/pacman.conf.prova-offline ] && mv /etc/pacman.conf.prova-offline /etc/pacman.conf
             systemctl disable --now cielos-prova-desktop 2>/dev/null; pacman -Rns --noconfirm cielos-prova-desktop >/dev/null
             rm -rf /srv/prova /etc/cielos/avvio.conf; echo fatto'
}

case "${1:-tutto}" in
    prepara) prepara ;; rotto) rotto ;; buono) buono ;; ripristina) ripristina ;;
    tutto) prepara; rotto; buono ;;
esac
