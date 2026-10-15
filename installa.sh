#!/bin/bash
# L'installatore di CielOS: da un'Arch Linux minima (con un utente, sudo e la rete) a CielOS completo.
#
#   git clone … ~/cielos && ~/cielos/installa.sh          (da utente normale: sudo lo chiede lui quando serve)
#   ~/cielos/installa.sh --prova                           dice cosa farebbe, senza fare niente
#   ~/cielos/installa.sh --ciel | --senza-ciel             alla fine installa (o no) anche Ciel, senza chiederlo
#
# Cosa mette: Hyprland + la shell Ciel (barra, lanciatore, notifiche, blocco, impostazioni), il login a tema,
# il terminale (foot + fish + starship), CielFox (LibreWolf + Ciel), Ciel Codice, il riquadro dei modelli,
# il sistema nervoso (cield), il guardiano (azioni da amministratore con la password, aggiornamenti sicuri,
# ritorno indietro automatico), i driver giusti per la scheda video.
# Cosa NON mette: nessun modello di IA e nemmeno Ollama (li scegli tu dal riquadro, Super+A, se e quando vuoi);
# Ciel, l'assistente vocale, è un passo a parte: lo propone alla fine (installa-ciel.sh, si può fare anche dopo).
# Si può rilanciare: rifà solo quello che manca e non cancella niente (i file che sostituisce restano accanto,
# con «.prima-di-cielos»). Registro: ~/.local/state/cielos/installa.log
set -uo pipefail

QUI=$(dirname "$(readlink -f "$0")")
PROVA=0 CIEL=""
for a in "$@"; do
    case "$a" in --prova) PROVA=1 ;; --ciel) CIEL=si ;; --senza-ciel) CIEL=no ;; esac
done
REGISTRO=~/.local/state/cielos/installa.log
mkdir -p "$(dirname "$REGISTRO")"
exec > >(tee -a "$REGISTRO") 2>&1
echo; echo "════ CielOS, installazione del $(date '+%d/%m/%Y %H:%M') $([ $PROVA = 1 ] && echo '(PROVA: non faccio niente)')"

passo() { echo; echo "── $*"; }
fai() {         # esegue (o, in prova, dice) un comando; se fallisce si ferma tutto con il motivo
    if [ $PROVA = 1 ]; then echo "   [farei] $*"; return 0; fi
    "$@" || { echo "!! Non è andato: $*"; echo "   Il registro completo è in $REGISTRO. Puoi rilanciare l'installatore: riparte da qui."; exit 1; }
}
metti() {       # metti SORGENTE DESTINAZIONE: collegamento; se c'era un file diverso lo tiene da parte
    local s=$1 d=$2
    [ "$(readlink -f "$d" 2>/dev/null)" = "$(readlink -f "$s")" ] && return 0
    if [ $PROVA = 1 ]; then echo "   [farei] $d → $s"; return 0; fi
    mkdir -p "$(dirname "$d")"
    if [ -e "$d" ] || [ -L "$d" ]; then mv "$d" "$d.prima-di-cielos"; echo "   (il vecchio $d è in $d.prima-di-cielos)"; fi
    ln -s "$s" "$d"
}

# ── 0. controlli ─────────────────────────────────────────────────────────────────────────────────────────────
passo "Controlli"
[ -f /etc/arch-release ] || { echo "CielOS si installa su Arch Linux."; exit 1; }
[ "$(id -u)" != 0 ] || { echo "Lancialo da utente normale (non root): sudo lo chiedo io quando serve."; exit 1; }
command -v sudo >/dev/null || { echo "Serve sudo (pacman -S sudo, e il tuo utente nel gruppo wheel)."; exit 1; }
if [ "$QUI" != "$HOME/cielos" ]; then
    if [ -e "$HOME/cielos" ]; then echo "C'è già ~/cielos e non è questa cartella ($QUI): spostala o rinominala."; exit 1; fi
    fai ln -s "$QUI" "$HOME/cielos"                 # tutti i percorsi di CielOS partono da ~/cielos
fi
ping -c1 -W3 archlinux.org >/dev/null 2>&1 || { echo "Serve Internet (i pacchetti arrivano dai repository di Arch)."; exit 1; }
CACHYOS=0; grep -q '^\[cachyos' /etc/pacman.conf && CACHYOS=1
RADICE_BTRFS=0; [ "$(findmnt -no FSTYPE /)" = btrfs ] && RADICE_BTRFS=1
echo "   Arch ok · utente $USER · radice $(findmnt -no FSTYPE /)$([ $CACHYOS = 1 ] && echo ' · repository CachyOS')"
[ $RADICE_BTRFS = 1 ] || echo "   Attenzione: la radice non è btrfs: niente istantanee, quindi niente ritorno indietro dopo gli aggiornamenti."
[ $PROVA = 1 ] || sudo -n true 2>/dev/null || sudo -v || exit 1

# ── 1. la scheda video ───────────────────────────────────────────────────────────────────────────────────────
passo "Scheda video"
# il produttore (terzo campo di lspci -mm): «compatible» contiene «ati», quindi niente ricerche sulla riga intera
VIDEO=$(lspci -mm 2>/dev/null | awk -F'"' '$2 ~ /VGA|3D|Display/ {print $4}' || true)
DRIVER=(mesa)
if echo "$VIDEO" | grep -qi nvidia; then
    KERNEL=$(pacman -Qq | grep -xE 'linux(-lts|-zen|-hardened|-cachyos[a-z-]*)?' | grep -v -- '-headers$' || true)
    DRIVER+=(nvidia-open-dkms nvidia-utils dkms)
    for k in $KERNEL; do DRIVER+=("$k-headers"); done
    echo "   NVIDIA: driver aperto (serie GTX 16xx / RTX e successive; per le più vecchie serve un driver dall'AUR)"
elif echo "$VIDEO" | grep -qiE 'advanced micro devices|\bamd\b|\bati\b'; then
    DRIVER+=(vulkan-radeon libva-mesa-driver); echo "   AMD: mesa + vulkan-radeon"
elif echo "$VIDEO" | grep -qi intel; then
    DRIVER+=(vulkan-intel intel-media-driver); echo "   Intel: mesa + vulkan-intel"
else
    echo "   Nessuna scheda riconosciuta (macchina virtuale?): solo mesa"
fi

# ── 2. i pacchetti ───────────────────────────────────────────────────────────────────────────────────────────
passo "Pacchetti (dai repository ufficiali di Arch)"
PACCHETTI=(
    # desktop
    hyprland xdg-desktop-portal-hyprland xdg-desktop-portal-gtk quickshell qt6-wayland qt6-svg qt6-imageformats
    sddm polkit pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber networkmanager nm-connection-editor
    glib2 udisks2 gvfs xdg-utils usbutils adw-gtk-theme qt6-declarative
    power-profiles-daemon brightnessctl ddcutil playerctl libnotify grim slurp wl-clipboard xdg-user-dirs
    gpu-screen-recorder hyprpicker zbar qrencode cliphist hyprsunset
    # terminale
    foot fish starship fastfetch
    # caratteri (Rubik è dentro CielOS: grafica/font)
    ttf-material-symbols-variable noto-fonts noto-fonts-emoji ttf-jetbrains-mono-nerd
    # i programmi di CielOS
    python python-gobject python-pillow python-yaml pacman-contrib pciutils jq socat zip unzip ripgrep bubblewrap git
    # CielFox
    librewolf tor
    # guardiano e aggiornamenti sicuri
    snapper btrfs-progs ufw
    # l'avvio con il logo
    plymouth
    "${DRIVER[@]}"
)
MANCANO=()
for p in "${PACCHETTI[@]}"; do pacman -Qq "$p" >/dev/null 2>&1 || MANCANO+=("$p"); done
if [ ${#MANCANO[@]} -eq 0 ]; then
    echo "   Ci sono già tutti."
else
    echo "   Da installare (${#MANCANO[@]}): ${MANCANO[*]}"
    if [ $PROVA = 0 ]; then
        DIM=$(pacman -Sp --print-format '%s' "${MANCANO[@]}" 2>/dev/null | awk '{s+=$1} END {printf "%.0f", s/1e6}')
        echo "   Da scaricare: circa ${DIM:-?} MB (più le dipendenze)"
    fi
    fai sudo pacman -S --needed --noconfirm "${MANCANO[@]}"
fi

# ── 3. i file di CielOS per il tuo utente ────────────────────────────────────────────────────────────────────
passo "CielOS per $USER"
C="$HOME/cielos"
for b in "$C"/bin/*; do
    [ -f "$b" ] && [ -x "$b" ] && [ "$(basename "$b")" != ciel-shell ] && metti "$b" "$HOME/.local/bin/$(basename "$b")"
done
[ -L "$C/bin/ciel-shell" ] || [ -e "$C/bin/ciel-shell" ] || fai ln -s /usr/bin/qs "$C/bin/ciel-shell"
metti "$C/shell" "$HOME/.config/quickshell/ciel"
for u in ciel-shell cield; do metti "$C/sistema/$u.service" "$HOME/.config/systemd/user/$u.service"; done
# le voci del lanciatore, con i percorsi di questo utente
for d in "$C"/sistema/*.desktop; do
    dest="$HOME/.local/share/applications/$(basename "$d")"
    if [ $PROVA = 1 ]; then echo "   [farei] $dest"; continue; fi
    mkdir -p "$(dirname "$dest")"; [ -L "$dest" ] && rm -f "$dest"
    sed "s|/home/evixion|$HOME|g" "$d" > "$dest"
done
# il carattere della shell
if [ $PROVA = 0 ]; then
    mkdir -p ~/.local/share/fonts/cielos && cp -u "$C"/grafica/font/*.ttf "$C"/grafica/font/OFL.txt ~/.local/share/fonts/cielos/
    fc-cache -q ~/.local/share/fonts 2>/dev/null
else echo "   [farei] font Rubik in ~/.local/share/fonts/cielos"; fi
# Hyprland: la base di CielOS (con le stesse scorciatoie di caelestia)
metti "$C/hypr/hyprland.lua" "$HOME/.config/hypr/hyprland.lua"
# il terminale con la personalità di CielOS
metti "$C/terminale/ciel.fish" "$HOME/.config/fish/conf.d/ciel.fish"
# la shell Ciel è quella attiva; i colori e le scorciatoie di serie (cieltema li genera da cielos.json)
if [ $PROVA = 0 ]; then
    mkdir -p ~/.config/cielos && touch ~/.config/cielos/shell-attiva
    xdg-user-dirs-update 2>/dev/null
    "$C/bin/cieltema" genera >/dev/null 2>&1 || echo "   (cieltema non è riuscito: lo rifaccio dalle Impostazioni, Super+I)"
    systemctl --user daemon-reload
    systemctl --user enable cield.service >/dev/null 2>&1
else echo "   [farei] shell-attiva, cartelle utente, cieltema, servizi utente"; fi
# fish con la personalità di CielOS: solo se usi ancora bash (quella di serie di Arch); un'altra scelta tua resta
case "$(getent passwd "$USER" | cut -d: -f7)" in
    */bash) fai sudo chsh -s /usr/bin/fish "$USER" ;;
    */fish) ;;
    *) echo "   La tua shell resta $(getent passwd "$USER" | cut -d: -f7) (fish con CielOS: chsh -s /usr/bin/fish)" ;;
esac

# ── 4. il sistema (sudo) ─────────────────────────────────────────────────────────────────────────────────────
passo "Sistema"
fai sudo sh "$C/guardiano/sistema/installa.sh"
if [ $CACHYOS = 0 ]; then
    grep -q cielos-ondata /etc/pacman.conf || fai sudo sh "$C/guardiano/sistema/installa.sh" ondate
else
    echo "   Ondate: non con i repository di CachyOS (vedi guardiano/PROGETTO.md §7)"
fi
if [ $RADICE_BTRFS = 1 ] && [ ! -f /etc/snapper/configs/root ]; then
    fai sudo snapper -c root create-config /
fi
fai sudo sh "$C/sistema/sddm-ciel/installa.sh"
# nome e logo: os-release, menu di avvio, schermata d'avvio (sistema/identita)
fai sudo install -d /usr/share/cielos/identita /usr/lib/cielos /etc/pacman.d/hooks
fai sudo cp -rL "$C/sistema/identita/." /usr/share/cielos/identita/
fai sudo install -m755 "$C/sistema/identita/identita.sh" /usr/lib/cielos/identita.sh
fai sudo install -m644 "$C/sistema/identita/cielos-identita.hook" /etc/pacman.d/hooks/cielos-identita.hook
fai sudo /usr/lib/cielos/identita.sh nome
if [ -f /etc/mkinitcpio.conf.d/cielos-plymouth.conf ] && [ "$(plymouth-set-default-theme 2>/dev/null)" = cielos ]; then
    echo "   Avvio con il logo: c'è già"
else
    fai sudo /usr/lib/cielos/identita.sh avvio
fi
systemctl is-enabled -q power-profiles-daemon 2>/dev/null || fai sudo systemctl enable power-profiles-daemon
# la rete: NetworkManager (la barra lo usa), ma solo se non c'è già un altro gestore (due insieme litigano)
ALTRO=""
for s in systemd-networkd iwd dhcpcd connman; do systemctl is-enabled -q "$s" 2>/dev/null && ALTRO=$s; done
if [ -n "$ALTRO" ]; then
    echo "   La rete la gestisce già $ALTRO: lo lascio (la rete nella barra funziona con NetworkManager)."
else
    systemctl is-enabled -q NetworkManager 2>/dev/null || fai sudo systemctl enable NetworkManager
fi
# il login grafico: sddm, a meno che ce ne sia già un altro
DM=$(systemctl show -p Id --value display-manager.service 2>/dev/null)
if [ -z "$DM" ] || [ "$DM" = display-manager.service ]; then fai sudo systemctl enable sddm
elif [ "$DM" != sddm.service ]; then echo "   Il login è già $DM: lo lascio (il tema di CielOS è per sddm)."; fi
# il firewall: niente da fuori, tranne SSH se lo usi (se no chi entra da remoto resterebbe chiuso fuori: è successo
# nella prova in VM, 14/10)
if ! sudo ufw status 2>/dev/null | grep -q "Status: active"; then
    fai sudo ufw --force disable >/dev/null        # da spento le regole si aggiungono sempre (da «a metà» no)
    if systemctl is-enabled -q sshd 2>/dev/null || systemctl is-active -q sshd 2>/dev/null; then fai sudo ufw allow ssh; fi
    fai sudo ufw --force enable
    fai sudo systemctl enable ufw
fi

# ── 5. Ciel, l'assistente (facoltativo) ─────────────────────────────────────────────────────────────────────
passo "Ciel, l'assistente vocale"
if [ -z "$CIEL" ] && [ $PROVA = 0 ] && [ -r /dev/tty ]; then
    echo "   Ciel ti ascolta, ti risponde a voce e fa le cose sul PC. Le servono ~600-900 MB (librerie, voce, orecchie);"
    echo "   la mente (il modello) la scegli dopo, dal riquadro. Si può installare anche più avanti: ~/cielos/installa-ciel.sh"
    read -r -p "   La installo adesso? [s/N] " r </dev/tty || r=n
    case "${r,,}" in s|si|sì|y) CIEL=si ;; *) CIEL=no ;; esac
fi
if [ "$CIEL" = si ]; then
    "$C/installa-ciel.sh" $([ $PROVA = 1 ] && echo --prova) || echo "   Ciel non si è installata: riprova con ~/cielos/installa-ciel.sh"
else
    echo "   Non ora. Quando vuoi: ~/cielos/installa-ciel.sh"
fi

# ── fatto ────────────────────────────────────────────────────────────────────────────────────────────────────
passo "Fatto"
cat <<E
   CielOS è installato. Riavvia ed entra con Hyprland dal login.
   Super+Spazio lanciatore · Super+A riquadro (modelli, Codice, terminale) · Super+I impostazioni
   Super+T terminale · Super+W CielFox · Super+Q chiude una finestra · Super+L blocca
   Nessun modello di IA è installato: quando ne vuoi uno, Super+A → «Scarica modelli»
   (lì vedi anche se serve installare Ollama, e quale versione per la tua scheda video).
E
