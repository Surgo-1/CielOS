#!/bin/bash
# Costruisce i pacchetti di CielOS e il loro repository (pacchetti/repo: cielos.db + i .pkg.tar.zst).
#   pacchetti/costruisci.sh            cielos e ciel-assistente (da ~/assistente-vocale o da CIEL_SORGENTE)
# Serve solo makepkg (non compila niente: sono pacchetti «any»). Se c'è la chiave di CielOS (pacchetti/pubblica.sh
# chiave) firma i pacchetti e il database: i PC installati accettano solo pacchetti firmati da lei.
set -euo pipefail
QUI=$(dirname "$(readlink -f "$0")")
REPO=$QUI/repo
export GNUPGHOME=${CIELOS_FIRMA:-$HOME/.local/share/cielos/firma}
mkdir -p "$REPO"
for p in cielos ciel-assistente; do
    ( cd "$QUI/$p" && PKGDEST="$REPO" BUILDDIR="${TMPDIR:-/tmp}/cielos-costruisci" makepkg -f -d --noconfirm >/dev/null ) \
        || { echo "!! $p non costruito"; exit 1; }
done
cd "$REPO"
for n in cielos ciel-assistente; do                                 # tiene solo l'ultimo di ognuno
    ls -t "$n"-r*.pkg.tar.zst | tail -n +2 | while read -r f; do rm -f "$f" "$f.sig"; done
done
rm -f ./*.old
FIRMA=()
CHIAVE=$(gpg --batch --with-colons --list-secret-keys 2>/dev/null | awk -F: '/^fpr/{print $10; exit}')
if [ -n "$CHIAVE" ]; then
    for f in cielos-r*.pkg.tar.zst ciel-assistente-r*.pkg.tar.zst; do
        [ -f "$f.sig" ] || gpg --batch --yes -q --detach-sign --no-armor -u "$CHIAVE" "$f"
    done
    FIRMA=(--sign --key "$CHIAVE")
else
    echo "   (nessuna chiave di CielOS: pacchetti NON firmati, vanno bene solo per le prove)"
fi
rm -f cielos.db* cielos.files*
repo-add -q "${FIRMA[@]}" cielos.db.tar.gz cielos-r*.pkg.tar.zst ciel-assistente-r*.pkg.tar.zst
ls -la "$REPO"
