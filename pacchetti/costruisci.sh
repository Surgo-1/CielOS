#!/bin/bash
# Costruisce i pacchetti di CielOS e il loro repository (pacchetti/repo: cielos.db + i .pkg.tar.zst).
#   pacchetti/costruisci.sh            cielos e ciel-assistente (da ~/assistente-vocale o da CIEL_SORGENTE)
# Serve solo makepkg (non compila niente: sono pacchetti «any»). Il repository si usa così, in pacman.conf:
#   [cielos]
#   SigLevel = Optional TrustAll
#   Server = file:///…/pacchetti/repo
set -euo pipefail
QUI=$(dirname "$(readlink -f "$0")")
REPO=$QUI/repo
mkdir -p "$REPO"
for p in cielos ciel-assistente; do
    ( cd "$QUI/$p" && PKGDEST="$REPO" BUILDDIR="${TMPDIR:-/tmp}/cielos-costruisci" makepkg -f -d --noconfirm >/dev/null ) \
        || { echo "!! $p non costruito"; exit 1; }
done
cd "$REPO"
ls -t cielos-r*.pkg.tar.zst | tail -n +2 | xargs -r rm -f          # tiene solo l'ultimo di ognuno
ls -t ciel-assistente-r*.pkg.tar.zst | tail -n +2 | xargs -r rm -f
repo-add -q -R cielos.db.tar.gz cielos-r*.pkg.tar.zst ciel-assistente-r*.pkg.tar.zst
ls -la "$REPO"
