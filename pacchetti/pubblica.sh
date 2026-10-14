#!/bin/bash
# Pubblica gli aggiornamenti di CielOS online: il repository dei pacchetti sta in una «release» di GitHub (gratis,
# niente server da tenere acceso) e i PC con CielOS lo leggono da lì (Server in /etc/pacman.d/cielos-mirrorlist).
#   pacchetti/pubblica.sh chiave              crea la chiave che firma i pacchetti (una volta sola; poi FANNE UNA COPIA)
#   pacchetti/pubblica.sh dove UTENTE/REPO    il repository GitHub dove pubblicare (es. evixion/cielos-pacchetti)
#   pacchetti/pubblica.sh                     costruisce, firma e pubblica (serve «gh auth login» fatto una volta)
#   pacchetti/pubblica.sh stato               cosa c'è online e cosa c'è qui
# PRIMA di dare la ISO a qualcuno, pubblica almeno una volta: se online non c'è niente, il suo «pacman -Syu» si ferma.
# I PC installati accettano solo pacchetti firmati con la chiave di CielOS: chi prende il repository GitHub non può
# mandare pacchetti falsi. La chiave segreta sta in ~/.local/share/cielos/firma: se la perdi, i PC già installati
# non accetteranno più aggiornamenti (serve una ISO nuova); se te la rubano, possono firmare al posto tuo.
set -euo pipefail
QUI=$(dirname "$(readlink -f "$0")")
RADICE=$(dirname "$QUI")
REPO=$QUI/repo
S=$RADICE/sistema/repo                  # quello che va nel pacchetto: la chiave pubblica e l'indirizzo
export GNUPGHOME=${CIELOS_FIRMA:-$HOME/.local/share/cielos/firma}
TAG=repo
chiave() { gpg --batch --with-colons --list-secret-keys 2>/dev/null | awk -F: '/^fpr/{print $10; exit}'; }
dove() { sed -n 's|^Server = https://github.com/\([^/]*/[^/]*\)/releases/.*|\1|p' "$S/cielos-mirrorlist" 2>/dev/null | head -1; }

case "${1:-}" in
chiave)
    if [ -n "$(chiave)" ]; then echo "La chiave c'è già: $(chiave)"; else
        mkdir -p "$GNUPGHOME"; chmod 700 "$GNUPGHOME"
        gpg --batch --passphrase '' --quick-gen-key "CielOS (pacchetti) <pacchetti@cielos.invalid>" ed25519 sign never
        echo "Chiave creata: $(chiave)"
    fi
    gpg --batch --armor --export "$(chiave)" > "$S/cielos.gpg"
    echo "$(chiave):4:" > "$S/cielos-trusted"
    echo "Chiave pubblica in sistema/repo/ (va nel pacchetto). Fai una copia di $GNUPGHOME in un posto sicuro."
    ;;
dove)
    [[ "${2:-}" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || { echo "uso: $0 dove UTENTE/REPOSITORY"; exit 1; }
    # solo GitHub: una copia locale come riserva non serve (se GitHub dice 404, pacman non la usa davvero)
    printf '# Da dove arrivano gli aggiornamenti di CielOS (pacchetti firmati)\nServer = https://github.com/%s/releases/download/%s\n' \
        "$2" "$TAG" > "$S/cielos-mirrorlist"
    echo "Gli aggiornamenti arriveranno da https://github.com/$2 (vale per i pacchetti e le ISO costruiti da adesso)."
    ;;
stato)
    echo "Qui:    $(cd "$REPO" 2>/dev/null && ls ./*.pkg.tar.zst 2>/dev/null | xargs -rn1 basename | tr '\n' ' ')"
    D=$(dove); [ -n "$D" ] || { echo "Online: nessun indirizzo (pubblica.sh dove UTENTE/REPO)"; exit 0; }
    echo "Online: https://github.com/$D/releases/tag/$TAG"
    T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
    if curl -fsSL "https://github.com/$D/releases/download/$TAG/cielos.db" -o "$T/db"; then
        tar -tzf "$T/db" | sed -n 's|/$||p' | sed 's/^/        /'
    else echo "        (ancora niente)"; fi
    ;;
"")
    command -v gh >/dev/null || { echo "Serve GitHub CLI: sudo pacman -S github-cli, poi gh auth login"; exit 1; }
    gh auth status >/dev/null 2>&1 || { echo "Prima entra su GitHub: gh auth login"; exit 1; }
    [ -n "$(chiave)" ] || { echo "Prima la chiave: $0 chiave"; exit 1; }
    D=$(dove); [ -n "$D" ] || { echo "Prima l'indirizzo: $0 dove UTENTE/REPO"; exit 1; }
    git -C "$RADICE" diff --quiet HEAD -- . ':!pacchetti/repo' || echo "!! Ci sono modifiche non salvate in CielOS: nel pacchetto va solo l'ultimo commit."
    git -C "$RADICE" diff --quiet HEAD -- sistema/repo || { echo "!! sistema/repo/ cambiato ma non salvato: fai il commit (va nel pacchetto)"; exit 1; }
    "$QUI/costruisci.sh" >/dev/null
    # la release (e il repository GitHub, la prima volta: pubblico, se no i PC non possono scaricare)
    gh repo view "$D" >/dev/null 2>&1 || gh repo create "$D" --public --add-readme \
        --description "Gli aggiornamenti di CielOS (pacchetti firmati per pacman)"
    gh release view "$TAG" -R "$D" >/dev/null 2>&1 || gh release create "$TAG" -R "$D" --title "Repository di CielOS" \
        --notes "Il repository pacman di CielOS. Non si scarica a mano: i PC con CielOS lo leggono da qui (pacman -Syu)."
    T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
    cd "$REPO"
    # prima i pacchetti, poi il database (così online non c'è mai un database che parla di pacchetti che mancano)
    gh release upload "$TAG" -R "$D" --clobber ./*.pkg.tar.zst ./*.pkg.tar.zst.sig
    for f in cielos.db cielos.files; do cp -L "$f" "$T/$f"; cp -L "$f.sig" "$T/$f.sig" 2>/dev/null || cp "$f.tar.gz.sig" "$T/$f.sig"; done
    gh release upload "$TAG" -R "$D" --clobber "$T"/*
    # via le versioni vecchie
    ORA=$(ls ./*.pkg.tar.zst ./*.pkg.tar.zst.sig | xargs -n1 basename; printf '%s\n' cielos.db cielos.db.sig cielos.files cielos.files.sig)
    gh release view "$TAG" -R "$D" --json assets -q '.assets[].name' | while read -r a; do
        grep -qxF "$a" <<< "$ORA" || gh release delete-asset "$TAG" "$a" -R "$D" -y >/dev/null
    done
    echo "Pubblicato su https://github.com/$D/releases/tag/$TAG :"
    ls ./*.pkg.tar.zst | xargs -n1 basename | sed 's/^/   /'
    echo "I PC con CielOS lo prendono al prossimo aggiornamento."
    ;;
*) sed -n '2,10p' "$0" | sed 's/^# \?//' ;;
esac
