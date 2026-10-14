#!/bin/bash
# Prova il guardiano vero nella VM (prove/vm.sh): copia guardiano e agente finto, prepara la VM, poi una serie di
# richieste con password giusta, sbagliata, annullata, vietate, e da una sessione remota (che polkit deve rifiutare).
set -uo pipefail
QUI=$(dirname "$(readlink -f "$0")")
D=~/cielos/vm
source <(sed 's/^/export /' "$D/credenziali.txt")
vm() { "$QUI/vm.sh" ssh "$@"; }
SCP=(scp -q -i "$D/chiave_vm" -P 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR)

if [ "${1:-}" != "--solo-prove" ]; then
    vm root "rm -rf /root/cielos && mkdir -p /root/cielos/prove"
    "${SCP[@]}" -r ~/cielos/guardiano root@127.0.0.1:/root/cielos/
    "${SCP[@]}" "$QUI/agente-prova.py" "$QUI/prepara-vm.sh" root@127.0.0.1:/root/cielos/prove/
    vm root "bash /root/cielos/prove/prepara-vm.sh '$utente' '$password'" | tail -3
    sleep 4
fi
vm root "faillock --user $utente --reset"

chiedi() {   # azione json risposta
    vm "$utente" "python3 -c '
import json, socket, sys
s = socket.socket(socket.AF_UNIX); s.connect(\"/tmp/prova-guardiano.sock\")
s.sendall((json.dumps({\"azione\": sys.argv[1], \"parametri\": json.loads(sys.argv[2]), \"risposta\": sys.argv[3]}) + \"\\n\").encode())
print(s.makefile().readline().strip())' '$1' '$2' '$3'"
}
caso() { echo; echo "── $1"; shift; chiedi "$@"; }

caso "elenco istantanee (sola lettura: niente password)" istantanee '{}' giusta
caso "installa htop, password SBAGLIATA" installa '{"pacchetti":["htop"]}' sbagliata
caso "installa htop, ANNULLA" installa '{"pacchetti":["htop"]}' annulla
echo "   htop installato? $(vm root 'pacman -Q htop 2>/dev/null || echo no')"
vm root "faillock --user $utente --reset"    # dopo 3 password sbagliate pam_faillock blocca l'account per 10 minuti
caso "installa htop, password giusta" installa '{"pacchetti":["htop"]}' giusta
echo "   htop installato? $(vm root 'pacman -Q htop 2>/dev/null || echo no')"
caso "togli pacman (vietato)" togli '{"pacchetti":["pacman"]}' giusta
caso "riavvia sshd" servizio '{"nome":"sshd","comando":"riavvia"}' giusta
caso "ferma polkit (vietato)" servizio '{"nome":"polkit","comando":"ferma"}' giusta
caso "apri la porta 8770 per la rete di casa" firewall '{"porta":8770,"comando":"apri"}' giusta
echo "   regole ufw: $(vm root 'ufw show added 2>/dev/null | tail -n +2 | tr "\n" " "')"
caso "togli htop" togli '{"pacchetti":["htop"]}' giusta
echo "   htop installato? $(vm root 'pacman -Q htop 2>/dev/null || echo no')"
caso "aggiorna il sistema" aggiorna '{}' giusta
caso "pulizia" pulisci '{}' giusta
caso "istantanea a mano" istantanea '{"descrizione":"prova"}' giusta
echo; echo "── da una sessione REMOTA (ssh), senza agente: polkit deve rifiutare senza chiedere"
vm "$utente" "gdbus call --system -d org.cielos.Guardiano -o /org/cielos/Guardiano -m org.cielos.Guardiano1.Esegui installa '{\"pacchetti\":[\"htop\"]}' -t 60"
echo; echo "── istantanee snapper"; vm root "snapper -c root list | tail -8"
echo; echo "── registro del guardiano"; vm root "cut -c1-170 /var/log/cielos/guardiano.log"
