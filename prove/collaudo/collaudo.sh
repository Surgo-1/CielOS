#!/bin/bash
# Il collaudo automatico di CielOS: una macchina virtuale con CielOS installato davvero, che ogni giro parte pulita,
# si aggiorna all'ultima versione pubblicata e viene messa sotto torchio (stress, un utente finto, comandi con input
# a caso, un esploratore AI con Ollama locale). Quello che si rompe diventa una issue «[collaudo]» su
# github.com/Surgo-1/CielOS (come le segnalazioni dei beta tester). Tutto sul PC: niente cloud, niente chiavi API.
#   collaudo.sh prepara          installa CielOS da zero nella VM con l'installatore vero (dalla ISO): una volta sola,
#                                o per ripartire da capo. Il disco di partenza: vm/collaudo-base.raw
#   collaudo.sh giro [MINUTI]    un giro completo (di serie 60 minuti): copia pulita, aggiorna, prove, rapporto
#   collaudo.sh giro --no-issue  lo stesso, ma il rapporto resta solo in vm/collaudo/ (niente issue)
#   collaudo.sh ssh [comando…]   entra nella VM del giro (utente collaudo)
#   collaudo.sh ferma | stato        ·   collaudo.sh accendi [base]   ·   collaudo.sh foto FILE.png   ·   collaudo.sh tasto NOME
# Variabili: COLLAUDO_RAM (MB, 6144), COLLAUDO_CPU (4), COLLAUDO_MODELLO (il modello di Ollama per l'esploratore).
# Prima di partire controlla che sul PC non si stia giocando (steam_app_*) e che ci sia RAM libera: se no rimanda.
set -euo pipefail
QUI=$(dirname "$(readlink -f "$0")")
D=~/cielos/vm
C=$D/collaudo
BASE=$D/collaudo-base.raw
DISCO=$C/disco-giro.raw
ISO=${CIELOS_ISO:-$D/cielos.iso}
PORTA=2224
MON=/tmp/claude-1000/collaudo-monitor.sock
mkdir -p "$C" "$(dirname "$MON")"
SSH_OPZ=(-i "$D/chiave_vm" -p $PORTA -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR
         -o ConnectTimeout=5 -o ServerAliveInterval=15)
ssh_vm() { local u=$1; shift; ssh "${SSH_OPZ[@]}" "$u@127.0.0.1" "$@"; }
scp_vm() { scp -i "$D/chiave_vm" -P $PORTA -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "$@"; }
dice() { echo "[$(date +%H:%M:%S)] $*"; }
monitor() { echo "$*" | socat - "UNIX-CONNECT:$MON" >/dev/null 2>&1; }
accesa() { [ -f "$C/qemu.pid" ] && kill -0 "$(cat "$C/qemu.pid")" 2>/dev/null; }

avvia() {   # $1 = disco, $2 = live (con la ISO) o niente
    local cd=()
    [ "${2:-}" = live ] && cd=(-cdrom "$ISO" -boot d)
    qemu-system-x86_64 -enable-kvm -cpu host -m "${COLLAUDO_RAM:-6144}" -smp "${COLLAUDO_CPU:-4}" -name cielos-collaudo \
        -drive "if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd" \
        -drive "if=pflash,format=raw,file=$C/ovmf-vars.fd" \
        -drive "file=$1,format=raw,if=virtio" "${cd[@]}" \
        -nic "user,model=virtio,hostfwd=tcp:127.0.0.1:$PORTA-:22" -vga std -display none \
        -audiodev none,id=a -device intel-hda -device hda-duplex,audiodev=a \
        -serial "file:$C/seriale.log" -monitor "unix:$MON,server,nowait" -pidfile "$C/qemu.pid" -daemonize
}
aspetta_ssh() {   # $1 = utente, $2 = secondi
    local fino=$((SECONDS + $2))
    until ssh_vm "$1" true 2>/dev/null; do
        [ $SECONDS -lt $fino ] || return 1
        accesa || return 1
        sleep 5
    done
}
ferma() {
    accesa || return 0
    monitor system_powerdown
    for _ in $(seq 60); do accesa || return 0; sleep 1; done
    kill "$(cat "$C/qemu.pid")" 2>/dev/null || true
}
libero() {   # il PC è libero? niente giochi, abbastanza RAM
    if command -v hyprctl >/dev/null && hyprctl -j clients 2>/dev/null | grep -q '"class": *"steam_app_'; then
        echo "si sta giocando"; return 1
    fi
    local mb; mb=$(awk '/MemAvailable/ {print int($2 / 1024)}' /proc/meminfo)
    if [ "$mb" -lt $(( ${COLLAUDO_RAM:-6144} + 3072 )) ]; then echo "poca RAM libera (${mb} MB)"; return 1; fi
}

prepara() {
    [ -f "$ISO" ] || { echo "manca la ISO: $ISO"; exit 1; }
    accesa && { echo "la VM del collaudo è già accesa"; exit 1; }
    dice "disco nuovo e firmware UEFI nuovo"
    rm -f "$BASE"; truncate -s 30G "$BASE"
    cp /usr/share/edk2/x64/OVMF_VARS.4m.fd "$C/ovmf-vars.fd"
    # la password dell'utente di prova: solo per questa VM (resta in vm/, fuori da git)
    [ -s "$C/password" ] || { head -c 12 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 14 > "$C/password"; chmod 600 "$C/password"; }
    avvia "$BASE" live
    dice "la live parte…"
    aspetta_ssh root 300 || { echo "la live non risponde (ssh)"; ferma; exit 1; }
    dice "installo CielOS con l'installatore vero"
    ssh_vm root "umask 077; cat > /tmp/pw" < "$C/password"
    ssh_vm root 'cat > /tmp/c.json' <<'J'
{"disco": "/dev/vda", "utente": "collaudo", "nome": "Collaudo", "password_file": "/tmp/pw", "host": "cielos-collaudo",
 "fuso": "Europe/Rome", "tastiera": "it", "lingua": "it_IT.UTF-8", "ciel": false, "cifra": false}
J
    ssh_vm root 'cielos-installa-sistema /tmp/c.json' > "$C/installazione.log" 2>&1 || true
    if ! grep -q '^FATTO' "$C/installazione.log"; then
        echo "installazione NON riuscita: $C/installazione.log"; tail -5 "$C/installazione.log"; ferma; exit 1
    fi
    dice "installato; preparo il collaudo (ssh, accesso automatico, sudo senza password: solo in questa VM)"
    scp_vm "$D/chiave_vm.pub" root@127.0.0.1:/tmp/chiave.pub
    ssh_vm root bash -s <<'S'
set -e
mount -o subvol=@ /dev/vda3 /mnt
mount /dev/vda2 /mnt/boot
mount -o subvol=@home /dev/vda3 /mnt/home                       # la home è un sottovolume suo
arch-chroot /mnt pacman -S --needed --noconfirm openssh python
arch-chroot /mnt systemctl enable sshd
install -d -m 700 -o 1000 -g 1000 /mnt/home/collaudo/.ssh
install -m 600 -o 1000 -g 1000 /tmp/chiave.pub /mnt/home/collaudo/.ssh/authorized_keys
install -d -m 700 /mnt/root/.ssh; install -m 600 /tmp/chiave.pub /mnt/root/.ssh/authorized_keys
echo 'collaudo ALL=(ALL) NOPASSWD: ALL' > /mnt/etc/sudoers.d/zz-collaudo; chmod 440 /mnt/etc/sudoers.d/zz-collaudo
install -d /mnt/etc/sddm.conf.d
printf '[Autologin]\nUser=collaudo\nSession=cielos\n' > /mnt/etc/sddm.conf.d/zz-collaudo.conf
# il firewall di CielOS chiude tutto quello che entra: ssh aperto (solo qui), al primo avvio dopo ufw
cat > /mnt/etc/systemd/system/collaudo-ssh.service <<'U'
[Unit]
Description=Collaudo: porta ssh aperta nel firewall
After=ufw.service
[Service]
Type=oneshot
ExecStart=/usr/bin/ufw allow 22/tcp
[Install]
WantedBy=multi-user.target
U
arch-chroot /mnt systemctl enable collaudo-ssh.service
# il primo accesso (cielos-utente) e la shell: come per chiunque
touch /mnt/var/lib/cielos-collaudo
umount -R /mnt
S
    ferma
    dice "prima accensione del sistema installato"
    avvia "$BASE"
    aspetta_ssh collaudo 300 || { echo "il sistema installato non risponde (ssh): $C/seriale.log"; ferma; exit 1; }
    ssh_vm collaudo 'cat /etc/os-release | head -2; pacman -Q cielos'
    ferma
    dice "pronto: $BASE"
}

giro() {
    local minuti=60 issue=1
    for a in "$@"; do case $a in --no-issue) issue=0 ;; [0-9]*) minuti=$a ;; esac; done
    [ -f "$BASE" ] || { echo "prima: collaudo.sh prepara"; exit 1; }
    accesa && { echo "un giro è già in corso"; exit 1; }
    local perche; if ! perche=$(libero); then dice "rimando il collaudo: $perche"; exit 0; fi
    local quando; quando=$(date +%Y%m%d-%H%M)
    local R=$C/giri/$quando; mkdir -p "$R"
    exec > >(tee -a "$R/giro.log") 2>&1
    dice "giro $quando ($minuti minuti)"
    rm -f "$DISCO"; cp --reflink=auto --sparse=always "$BASE" "$DISCO"       # la copia pulita (btrfs: istantanea)
    : > "$C/seriale.log"
    avvia "$DISCO"
    if ! aspetta_ssh collaudo 300; then
        dice "la VM non si accende"; cp "$C/seriale.log" "$R/"; ferma
        python3 "$QUI/rapporto.py" "$R" --non-parte $([ $issue = 0 ] && echo --no-issue); exit 1
    fi
    dice "aggiorno all'ultima CielOS pubblicata"
    ssh_vm collaudo 'sudo pacman -Syu --noconfirm' > "$R/aggiornamento.log" 2>&1 || dice "aggiornamento con errori"
    ssh_vm collaudo 'pacman -Q cielos ciel-assistente 2>/dev/null; uname -r' > "$R/versioni.txt" || true
    # se la base della VM è più vecchia del repository, quello che manca non è un guasto di CielOS:
    # il giro del 16/10 ha segnalato «comando mancante: cielos, cielmedico…» solo perché nella VM girava r50
    locale=$(git -C "$QUI/../.." rev-list --count HEAD 2>/dev/null || echo 0)
    vm=$(awk '/^cielos /{sub(/^r/, "", $2); sub(/\..*/, "", $2); print $2}' "$R/versioni.txt")
    if [ -n "$vm" ] && [ "$locale" -gt 0 ] && [ "$vm" -lt "$locale" ]; then
        dice "ATTENZIONE: nella VM gira cielos r$vm, il repository è a r$locale: la base è vecchia, rifai «collaudo.sh prepara» (i comandi nuovi risulterebbero mancanti)"
    fi
    dice "riavvio sul sistema aggiornato"
    ssh_vm collaudo 'sudo systemctl reboot' || true
    sleep 15
    aspetta_ssh collaudo 300 || { dice "dopo l'aggiornamento non riparte"; cp "$C/seriale.log" "$R/"; ferma
                                  python3 "$QUI/rapporto.py" "$R" --non-parte $([ $issue = 0 ] && echo --no-issue); exit 1; }
    sleep 30                                                              # la sessione grafica (accesso automatico)
    dice "le prove"
    scp_vm "$QUI/dentro.py" collaudo@127.0.0.1:/tmp/dentro.py
    local modello=${COLLAUDO_MODELLO:-$(python3 "$QUI/rapporto.py" --modello 2>/dev/null || true)}
    ssh_vm collaudo "python3 /tmp/dentro.py --minuti $minuti --uscita /tmp/collaudo ${modello:+--modello '$modello'}" \
        > "$R/prove.log" 2>&1 || dice "le prove sono finite male (vedi prove.log)"
    dice "raccolgo"
    ssh_vm collaudo 'cd /tmp && tar czf - collaudo' > "$R/dentro.tgz" 2>/dev/null && tar xzf "$R/dentro.tgz" -C "$R" && rm "$R/dentro.tgz" || true
    accesa || dice "la VM si è spenta da sola durante le prove"
    cp "$C/seriale.log" "$R/" 2>/dev/null || true
    ferma
    python3 "$QUI/rapporto.py" "$R" $([ $issue = 0 ] && echo --no-issue)
    # tiene gli ultimi 14 giri
    ls -1d "$C"/giri/*/ 2>/dev/null | head -n -14 | while read -r g; do rm -rf -- "$g"; done
}

case "${1:-}" in
    prepara) prepara ;;
    giro)    shift; giro "$@" ;;
    ssh)     shift; ssh_vm collaudo "$@" ;;
    accendi) [ "${2:-}" = base ] && avvia "$BASE" || avvia "$DISCO" ;;    # per guardarci dentro (ferma per spegnere)
    foto)    monitor "screendump /tmp/claude-1000/collaudo-foto.ppm"; sleep 0.5; magick /tmp/claude-1000/collaudo-foto.ppm "$2" ;;
    tasto)   monitor "sendkey $2" ;;
    scrivi)  t=$2                                                   # tasti veri, dal monitor di QEMU
             for ((i = 0; i < ${#t}; i++)); do
                 c=${t:i:1}
                 case "$c" in
                     " ") k=spc ;; ".") k=dot ;; "-") k=minus ;; "/") k=shift-7 ;; "_") k=shift-minus ;;
                     [A-Z]) k="shift-$(echo "$c" | tr 'A-Z' 'a-z')" ;; *) k=$c ;;
                 esac
                 monitor "sendkey $k"; sleep 0.05
             done ;;
    ferma)   ferma ;;
    stato)   accesa && echo "accesa" || echo "spenta"; ls -1t "$C/giri" 2>/dev/null | head -3 ;;
    *)       sed -n '2,14p' "$0" | sed 's/^# \?//' ;;
esac
