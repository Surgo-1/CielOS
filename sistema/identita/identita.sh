#!/bin/bash
# L'identità di CielOS sul sistema (da root; l'installatore la copia in /usr/lib/cielos/identita.sh).
#   identita.sh nome     /etc/os-release e /etc/issue dicono CielOS; il logo tra le icone (LOGO=cielos)
#   identita.sh avvio    menu di avvio (Limine, GRUB o systemd-boot) col nome e lo sfondo di CielOS, e la schermata
#                        d'avvio (Plymouth, tema cielos): hook nell'initramfs, «quiet splash», initramfs rifatti
#   identita.sh tutto    le due cose insieme
#   identita.sh togli    rimette com'era (i file sostituiti restano accanto con .prima-di-cielos)
# I file da applicare stanno in /usr/share/cielos/identita (o accanto a questo script, per le prove).
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "identita.sh va eseguito da root"; exit 1; }
D=/usr/share/cielos/identita
[ -f "$D/os-release" ] || D=$(dirname "$(readlink -f "$0")")
SFONDO=cielos-avvio.png

prima() { [ -e "$1" ] && [ ! -e "$1.prima-di-cielos" ] && cp -a "$1" "$1.prima-di-cielos"; return 0; }
ripristina() { [ -e "$1.prima-di-cielos" ] || [ -L "$1.prima-di-cielos" ] && mv -f "$1.prima-di-cielos" "$1"; return 0; }

nome() {
    # /etc/os-release è un collegamento a /usr/lib/os-release (pacchetto filesystem): qui diventa un file nostro,
    # e l'hook di pacman lo rimette dopo ogni aggiornamento di filesystem
    [ -L /etc/os-release ] && [ ! -e /etc/os-release.prima-di-cielos ] && cp -P /etc/os-release /etc/os-release.prima-di-cielos
    rm -f /etc/os-release && install -m644 "$D/os-release" /etc/os-release
    prima /etc/issue; install -m644 "$D/issue" /etc/issue
    install -Dm644 "$D/logo.svg" /usr/share/icons/hicolor/scalable/apps/cielos.svg
    install -Dm644 "$D/logo.png" /usr/share/pixmaps/cielos.png
    command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -q /usr/share/icons/hicolor 2>/dev/null || true
}

# ── la riga di comando del kernel: «quiet splash» ─────────────────────────────────────────────────────────────
con_splash() {   # aggiunge quiet e splash a una riga di opzioni, se mancano
    local r=" $1 "
    [[ $r == *" quiet "* ]] || r="$r quiet "
    [[ $r == *" splash "* ]] || r="$r splash "
    echo "$r" | tr -s ' ' | sed 's/^ //; s/ $//'
}

esp() {   # dove sono montati i file di avvio (la prima che esiste)
    for m in /boot /efi /boot/efi; do mountpoint -q "$m" 2>/dev/null && echo "$m"; done
    echo /boot
}

limine_conf() {
    local m f
    for m in $(esp | awk '!v[$0]++'); do
        for f in EFI/limine/limine.conf EFI/BOOT/limine.conf boot/limine/limine.conf boot/limine.conf limine/limine.conf limine.conf; do
            [ -f "$m/$f" ] && { echo "$m/$f"; return; }
        done
    done
}

limine() {   # $1 = file di configurazione
    local conf=$1 radice rel tmp
    radice=$(findmnt -no TARGET -T "$conf")
    install -m644 "$D/avvio.png" "$radice/$SFONDO"
    rel=/$SFONDO
    prima "$conf"
    # le opzioni globali stanno prima della prima voce (riga che inizia con «/»): tolgo le nostre e le rimetto in cima
    tmp=$(mktemp)
    awk -v rel="$rel" '
        BEGIN { split("interface_branding interface_branding_colour interface_branding_color wallpaper wallpaper_style backdrop term_background term_foreground term_margin term_margin_gradient interface_help_colour interface_help_color", k, " "); for (i in k) togli[k[i]] = 1 }
        !fatto && /^[ \t]*\// {
            print "# ── CielOS (identita.sh) ──"
            print "interface_branding: CielOS"
            print "interface_branding_colour: 3FA9E8"
            print "wallpaper: boot():" rel
            print "wallpaper_style: stretched"
            print "backdrop: 0B1029"
            print "term_background: FF0B1029"
            print "term_foreground: DCE6F5"
            print "term_margin_gradient: 0"
            print "interface_help_colour: 3FA9E8"
            print ""
            fatto = 1
        }
        !fatto && (/^# ── CielOS/ || /^[ \t]*$/) { next }
        !fatto { split($0, p, ":"); c = p[1]; gsub(/[ \t]/, "", c); if (c in togli) next }
        { print }' "$conf" > "$tmp"
    cat "$tmp" > "$conf"; rm -f "$tmp"
    # la riga di comando: con limine-entry-tool (CachyOS e simili) sta in /etc/default/limine, sennò nelle voci
    if [ -f /etc/default/limine ] && grep -q '^KERNEL_CMDLINE' /etc/default/limine; then
        if ! grep -q '^KERNEL_CMDLINE.*splash' /etc/default/limine; then
            prima /etc/default/limine
            echo 'KERNEL_CMDLINE[default]+=" quiet splash"' >> /etc/default/limine
        fi
    else
        sed -i -E '/^[ \t]*(kernel_)?cmdline:/{/splash/!s/$/ quiet splash/}' "$conf"
    fi
    if grep -qs '^ENABLE_ENROLL_LIMINE_CONFIG=yes' /etc/default/limine /etc/limine-entry-tool.conf && command -v limine-enroll-config >/dev/null; then
        limine-enroll-config                       # la configurazione è firmata nel binario: va rifirmata
    fi
    echo "   Limine: $conf"
}

grub() {
    local g=/etc/default/grub
    install -Dm644 "$D/avvio.png" /boot/grub/$SFONDO
    prima $g
    imposta() {   # chiave valore
        if grep -qE "^#?$1=" $g; then sed -i -E "s|^#?$1=.*|$1=\"$2\"|" $g; else echo "$1=\"$2\"" >> $g; fi
    }
    imposta GRUB_DISTRIBUTOR CielOS
    imposta GRUB_BACKGROUND /boot/grub/$SFONDO
    imposta GRUB_COLOR_NORMAL "light-gray/black"
    imposta GRUB_COLOR_HIGHLIGHT "white/blue"
    local cmd
    cmd=$(sed -nE 's/^GRUB_CMDLINE_LINUX_DEFAULT="(.*)"/\1/p' $g | tail -1)
    imposta GRUB_CMDLINE_LINUX_DEFAULT "$(con_splash "$cmd")"
    grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1
    echo "   GRUB: /etc/default/grub"
}

systemd_boot() {   # $1 = cartella delle voci
    local f
    for f in "$1"/*.conf; do
        [ -f "$f" ] || continue
        prima "$f"
        sed -i -E 's/^title[ \t]+Arch Linux/title CielOS/; /^options/{/splash/!s/$/ quiet splash/}' "$f"
    done
    if [ -f /etc/kernel/cmdline ] && ! grep -q splash /etc/kernel/cmdline; then
        prima /etc/kernel/cmdline; sed -i 's/$/ quiet splash/' /etc/kernel/cmdline
    fi
    echo "   systemd-boot: $1"
}

avvio() {
    # la schermata d'avvio
    command -v plymouth-set-default-theme >/dev/null || { echo "manca plymouth (pacman -S plymouth)"; exit 1; }
    install -d /usr/share/plymouth/themes/cielos
    install -m644 "$D"/plymouth/* /usr/share/plymouth/themes/cielos/
    plymouth-set-default-theme cielos
    # l'hook plymouth nell'initramfs: un file a parte (mkinitcpio.conf resta com'era), subito dopo kms (o udev/systemd)
    install -d /etc/mkinitcpio.conf.d
    cat > /etc/mkinitcpio.conf.d/cielos-plymouth.conf <<'H'
# CielOS: la schermata d'avvio (Plymouth). Togliere questo file (e rifare l'initramfs) la spegne.
if [[ " ${HOOKS[*]} " != *" plymouth "* ]]; then
    _cielos=() _messo=0
    for _h in "${HOOKS[@]}"; do _cielos+=("$_h"); [[ $_h == kms ]] && { _cielos+=(plymouth); _messo=1; }; done
    if (( !_messo )); then
        _cielos=(); for _h in "${HOOKS[@]}"; do _cielos+=("$_h"); [[ $_h == udev || $_h == systemd ]] && _cielos+=(plymouth); done
    fi
    HOOKS=("${_cielos[@]}"); unset _cielos _messo _h
fi
H
    # il menu di avvio
    local conf; conf=$(limine_conf || true)
    if [ -n "$conf" ]; then limine "$conf"
    elif [ -f /etc/default/grub ] && [ -d /boot/grub ]; then grub
    else
        local e
        for e in $(esp | awk '!v[$0]++'); do [ -d "$e/loader/entries" ] && { systemd_boot "$e/loader/entries"; break; }; done
    fi
    mkinitcpio -P >/dev/null 2>&1 || { echo "mkinitcpio non riuscito: guardalo con «mkinitcpio -P»"; exit 1; }
    echo "   initramfs rifatti con la schermata d'avvio"
}

togli() {
    if [ -e /etc/os-release.prima-di-cielos ] || [ -L /etc/os-release.prima-di-cielos ]; then
        rm -f /etc/os-release; mv /etc/os-release.prima-di-cielos /etc/os-release
    fi
    ripristina /etc/issue
    rm -f /etc/mkinitcpio.conf.d/cielos-plymouth.conf
    local conf; conf=$(limine_conf || true)
    [ -n "$conf" ] && ripristina "$conf" && ripristina /etc/default/limine
    if [ -e /etc/default/grub.prima-di-cielos ]; then ripristina /etc/default/grub; grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1; fi
    local e f
    for e in $(esp | awk '!v[$0]++'); do for f in "$e"/loader/entries/*.conf; do ripristina "$f"; done; done
    ripristina /etc/kernel/cmdline
    command -v plymouth-set-default-theme >/dev/null && plymouth-set-default-theme -r >/dev/null 2>&1 || true
    mkinitcpio -P >/dev/null 2>&1 || true
    echo "identità di CielOS tolta"
}

case "${1:-}" in
    nome) nome ;;
    avvio) avvio ;;
    tutto) nome; avvio ;;
    togli) togli ;;
    *) sed -n '2,7p' "$0" | sed 's/^# \?//'; exit 1 ;;
esac
