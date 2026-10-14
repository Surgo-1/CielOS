#!/bin/bash
# Costruisce la ISO di CielOS (da root, su Arch, con archiso): sessione live con CielOS e l'installatore.
#   iso/costruisci.sh REPO [USCITA]           REPO = la cartella con cielos.db e i pacchetti (pacchetti/costruisci.sh)
#   CIELOS_ISO_CHIAVE=chiave.pub iso/costruisci.sh …   (solo per le prove: entra da SSH come root nella live)
# Parte dal profilo «releng» di Arch (quello della ISO ufficiale) e aggiunge: i pacchetti di iso/pacchetti.txt, il
# repository di CielOS (anche dentro la ISO, in /opt/cielos/repo: l'installatore lo usa), l'utente live «cielos»
# con l'accesso automatico alla sessione CielOS, NetworkManager al posto di systemd-networkd e iwd, il nome CielOS.
set -euo pipefail
QUI=$(dirname "$(readlink -f "$0")")
REPO=$(readlink -f "${1:?la cartella del repository di CielOS}")
USCITA=$(readlink -f "${2:-$PWD/iso-uscita}")
LAVORO=${CIELOS_ISO_LAVORO:-/var/tmp/cielos-iso}
[ "$(id -u)" = 0 ] || { echo "serve root"; exit 1; }
command -v mkarchiso >/dev/null || pacman -S --needed --noconfirm archiso
[ -f "$REPO/cielos.db" ] || { echo "in $REPO non c'è cielos.db"; exit 1; }

rm -rf "$LAVORO"; mkdir -p "$LAVORO" "$USCITA"
P=$LAVORO/profilo
cp -r /usr/share/archiso/configs/releng "$P"

# ── nome ───────────────────────────────────────────────────────────────────────────────────────────────────────
sed -i -e 's/^iso_name=.*/iso_name="cielos"/' -e 's/^iso_label=.*/iso_label="CIELOS_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"/' \
       -e 's/^iso_publisher=.*/iso_publisher="CielOS"/' -e 's/^iso_application=.*/iso_application="CielOS: live e installatore"/' \
       "$P/profiledef.sh"
# compressione zstd (non xz): la ISO si costruisce in pochi minuti e la live parte prima; poco più grande
sed -i "s/^airootfs_image_tool_options=.*/airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15' '-b' '1M')/" "$P/profiledef.sh"
grep -rl "Arch Linux" "$P/efiboot" "$P/syslinux" "$P/grub" 2>/dev/null | xargs -r sed -i 's/Arch Linux/CielOS/g'

# ── pacchetti e repository ─────────────────────────────────────────────────────────────────────────────────────
grep -v '^#' "$QUI/pacchetti.txt" | grep -v '^$' >> "$P/packages.x86_64"
sort -u -o "$P/packages.x86_64" "$P/packages.x86_64"
printf '\n[cielos]\nSigLevel = Optional TrustAll\nServer = file://%s\n' "$REPO" >> "$P/pacman.conf"
# multilib anche nella live (la scansione dell'hardware propone i pacchetti a 32 bit solo se c'è)
sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' "$P/pacman.conf"

# ── i file della live ─────────────────────────────────────────────────────────────────────────────────────────
A=$P/airootfs
cp -r "$QUI/aggiunte/." "$A/"
mkdir -p "$A/opt/cielos/repo" && cp -a "$REPO"/. "$A/opt/cielos/repo/"
# il repository di CielOS anche nel pacman.conf della live (per pacstrap dell'installatore)
mkdir -p "$A/etc"
cp "$P/pacman.conf" "$A/etc/pacman.conf"
sed -i "s|^Server = file://$REPO|Server = file:///opt/cielos/repo|" "$A/etc/pacman.conf"
# l'utente live: cielos, senza password, nel gruppo wheel (sudo senza password: sudoers.d/00-live)
for f in passwd shadow group gshadow; do [ -f "$A/etc/$f" ] || cp "/usr/share/archiso/configs/releng/airootfs/etc/$f" "$A/etc/$f" 2>/dev/null || touch "$A/etc/$f"; done
grep -q '^cielos:' "$A/etc/passwd" || echo 'cielos:x:1000:1000:CielOS (live):/home/cielos:/usr/bin/fish' >> "$A/etc/passwd"
grep -q '^cielos:' "$A/etc/shadow" || echo 'cielos::14871::::::' >> "$A/etc/shadow"
grep -q '^cielos:' "$A/etc/group" || echo 'cielos:x:1000:' >> "$A/etc/group"
grep -q '^wheel:' "$A/etc/group" && sed -i 's/^wheel:x:998:.*/&,cielos/; s/^wheel:x:998:,cielos/wheel:x:998:cielos/' "$A/etc/group" || echo 'wheel:x:998:cielos' >> "$A/etc/group"
grep -q '^cielos:' "$A/etc/gshadow" || echo 'cielos:!*::' >> "$A/etc/gshadow"
mkdir -p "$A/home/cielos"
# permessi (profiledef.sh)
sed -i '/^file_permissions=(/a\  ["/etc/sudoers.d/00-live"]="0:0:440"\n  ["/home/cielos"]="1000:1000:750"\n  ["/etc/gshadow"]="0:0:400"' "$P/profiledef.sh"

# ── servizi: login grafico e NetworkManager (via la rete di releng, che litiga con NetworkManager) ──────────────
W=$A/etc/systemd/system
rm -f "$W/multi-user.target.wants/systemd-networkd.service" "$W/multi-user.target.wants/iwd.service" \
      "$W/network-online.target.wants/systemd-networkd-wait-online.service" "$W/sockets.target.wants/systemd-networkd.socket" \
      "$W/systemd-networkd.service.d" 2>/dev/null || true
mkdir -p "$W/multi-user.target.wants"
ln -sf /usr/lib/systemd/system/NetworkManager.service "$W/multi-user.target.wants/NetworkManager.service"
ln -sf /usr/lib/systemd/system/sddm.service "$W/display-manager.service"
ln -sf /usr/lib/systemd/system/graphical.target "$W/default.target"
# cield per tutti (servizio dell'utente)
mkdir -p "$A/etc/systemd/user/graphical-session.target.wants"
ln -sf /usr/lib/systemd/user/cield.service "$A/etc/systemd/user/graphical-session.target.wants/cield.service"

# ── solo per le prove: entrare da SSH ──────────────────────────────────────────────────────────────────────────
if [ -n "${CIELOS_ISO_CHIAVE:-}" ]; then
    mkdir -p "$A/root/.ssh"; cp "$CIELOS_ISO_CHIAVE" "$A/root/.ssh/authorized_keys"
    sed -i '/^file_permissions=(/a\  ["/root/.ssh"]="0:0:700"\n  ["/root/.ssh/authorized_keys"]="0:0:600"' "$P/profiledef.sh"
    echo "   (ISO di PROVA: SSH come root con la chiave $CIELOS_ISO_CHIAVE)"
fi

mkarchiso -v -w "$LAVORO/lavoro" -o "$USCITA" "$P"
ls -la "$USCITA"
