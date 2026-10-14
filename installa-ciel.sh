#!/bin/bash
# Ciel, l'assistente vocale, su CielOS: il passo in più dell'installatore (installa.sh lo propone alla fine, e si
# può lanciare anche dopo, quando vuoi).
#
#   ~/cielos/installa-ciel.sh                 chiede voce e orecchie, dice quanto scarica, poi installa
#   ~/cielos/installa-ciel.sh --voce paola|sara --orecchie base|small --si     senza domande
#   ~/cielos/installa-ciel.sh --prova         dice cosa farebbe
#
# Mette: il codice di Ciel (~/assistente-vocale), le sue librerie in un ambiente Python a parte (uv, Python 3.11),
# Ollama (il motore delle menti, con la libreria giusta per la scheda video), la voce e le orecchie scelte, i servizi.
# NON mette nessuna mente: Ciel parte lo stesso (comandi, timer, volume, app…) e ti spiega come sceglierne una
# dal riquadro dei modelli (Super+A → «Usa per Ciel»), quando vuoi e adatta al tuo PC.
# Registro: ~/.local/state/cielos/installa-ciel.log
set -uo pipefail

C="$HOME/cielos"
A="$HOME/assistente-vocale"
VENV="$HOME/.local/share/cielos/ciel-venv"
PROVA=0 SI=0 VOCE="" ORECCHIE=""
while [ $# -gt 0 ]; do
    case "$1" in
        --prova) PROVA=1 ;;
        --si) SI=1 ;;
        --voce) VOCE=${2:-}; shift ;;
        --orecchie) ORECCHIE=${2:-}; shift ;;
        -h|--help) sed -n '2,14p' "$0" | sed 's/^# \?//'; exit 0 ;;
        *) echo "Non conosco «$1» (--help per l'aiuto)"; exit 1 ;;
    esac
    shift
done
REGISTRO=~/.local/state/cielos/installa-ciel.log
mkdir -p "$(dirname "$REGISTRO")"
exec > >(tee -a "$REGISTRO") 2>&1
echo; echo "════ Ciel, installazione del $(date '+%d/%m/%Y %H:%M') $([ $PROVA = 1 ] && echo '(PROVA: non faccio niente)')"

passo() { echo; echo "── $*"; }
fai() {
    if [ $PROVA = 1 ]; then echo "   [farei] $*"; return 0; fi
    "$@" || { echo "!! Non è andato: $*"; echo "   Il registro è in $REGISTRO. Puoi rilanciarlo: rifà solo quello che manca."; exit 1; }
}
metti() {       # collegamento; se c'era un file diverso lo tiene da parte
    local s=$1 d=$2
    [ "$(readlink -f "$d" 2>/dev/null)" = "$(readlink -f "$s")" ] && return 0
    if [ $PROVA = 1 ]; then echo "   [farei] $d → $s"; return 0; fi
    mkdir -p "$(dirname "$d")"
    if [ -e "$d" ] || [ -L "$d" ]; then mv "$d" "$d.prima-di-cielos"; fi
    ln -s "$s" "$d"
}
scegli() {      # scegli DOMANDA PREDEFINITA "1:valore:descrizione" … → stampa il valore
    local domanda=$1 pred=$2; shift 2
    echo "   $domanda" >&2
    local i=1 v
    for o in "$@"; do echo "     $i) ${o#*:}" >&2; i=$((i + 1)); done
    read -r -p "   Scelta [$pred]: " v </dev/tty || v=""
    v=${v:-$pred}
    [[ $v =~ ^[0-9]+$ ]] && [ "$v" -ge 1 ] && [ "$v" -le $# ] || v=$pred
    o=${!v}; echo "${o%%:*}"
}

# ── 0. controlli ─────────────────────────────────────────────────────────────────────────────────────────────
passo "Controlli"
[ "$(id -u)" != 0 ] || { echo "Lancialo da utente normale (sudo lo chiedo io)."; exit 1; }
[ -d "$C" ] || { echo "Prima CielOS: ~/cielos/installa.sh"; exit 1; }
if [ ! -f "$A/assistente.py" ]; then
    if [ -n "${CIEL_REPO:-}" ]; then
        fai git clone "$CIEL_REPO" "$A"
    else
        echo "Manca il codice di Ciel in $A."
        echo "Mettilo lì (git clone <indirizzo> ~/assistente-vocale), oppure: CIEL_REPO=<indirizzo> $0"
        exit 1
    fi
fi
NUOVO=1; [ -f "$HOME/.config/cielos/ciel-installata" ] && NUOVO=0
echo "   codice: $A $([ $NUOVO = 0 ] && echo '(già installata: aggiorno solo quello che manca)')"

# ── 1. le scelte ─────────────────────────────────────────────────────────────────────────────────────────────
passo "Voce e orecchie"
INTERATTIVO=0; [ $SI = 0 ] && [ $PROVA = 0 ] && [ -r /dev/tty ] && INTERATTIVO=1
if [ -z "$VOCE" ]; then
    if [ $INTERATTIVO = 1 ]; then
        VOCE=$(scegli "Con che voce parla Ciel?" 1 \
            "paola:Paola (Piper): leggerissima, risponde subito · 63 MB" \
            "sara:Sara (Kokoro): più naturale, un attimo più lenta a cominciare · 354 MB")
    else VOCE=paola; fi
fi
if [ -z "$ORECCHIE" ]; then
    if [ $INTERATTIVO = 1 ]; then
        ORECCHIE=$(scegli "Con cosa ti ascolta (riconoscimento della voce, sul processore)?" 1 \
            "base:Whisper base: veloce anche su PC modesti · 145 MB" \
            "small:Whisper small: sbaglia meno parole, chiede un processore più svelto · 485 MB")
    else ORECCHIE=base; fi
fi
case "$VOCE" in paola) MOTORE_VOCE=piper ;; sara) MOTORE_VOCE=kokoro ;; *) echo "Voce: paola o sara"; exit 1 ;; esac
case "$ORECCHIE" in tiny|base|small) ;; *) echo "Orecchie: base o small"; exit 1 ;; esac
echo "   voce: $VOCE · orecchie: Whisper $ORECCHIE · parola di risveglio: «Hey Jarvis» (poi la cambi in «Ciel»)"

# ── 2. i pacchetti ───────────────────────────────────────────────────────────────────────────────────────────
passo "Pacchetti"
# Ollama con la libreria per la scheda video (la decide cielmodelli: è lo stesso consiglio del riquadro)
MOTORE=$("$C/bin/cielmodelli" motore --json 2>/dev/null | python3 -c 'import json,sys; print(" ".join(json.load(sys.stdin)["pacchetti"]))' 2>/dev/null)
[ -n "$MOTORE" ] || MOTORE=ollama
PACCHETTI=(uv portaudio tesseract tesseract-data-ita tesseract-data-eng $MOTORE)
MANCANO=()
for p in "${PACCHETTI[@]}"; do pacman -Qq "$p" >/dev/null 2>&1 || MANCANO+=("$p"); done
MB_PAC=0
if [ ${#MANCANO[@]} -gt 0 ]; then
    MB_PAC=$(pacman -Sp --print-format '%s' "${MANCANO[@]}" 2>/dev/null | awk '{s+=$1} END {printf "%.0f", s/1e6}')
    echo "   Da installare: ${MANCANO[*]} (~${MB_PAC:-?} MB, più le dipendenze)"
else echo "   Ci sono già tutti."; fi

# quanto si scarica in tutto (le librerie Python: ~300 MB la prima volta; i modelli secondo le scelte)
MB_PY=0; [ -x "$VENV/bin/python" ] || MB_PY=330
MB_MOD=$(( $([ "$VOCE" = sara ] && echo 354 || echo 63) + $(case $ORECCHIE in tiny) echo 75 ;; base) echo 145 ;; small) echo 485 ;; esac) + 10 ))
[ $NUOVO = 0 ] && MB_MOD=0
TOTALE=$(( ${MB_PAC:-0} + MB_PY + MB_MOD ))
echo "   Da scaricare in tutto: circa $TOTALE MB (pacchetti ${MB_PAC:-0}, librerie $MB_PY, voce/orecchie ≤$MB_MOD)"
if [ $INTERATTIVO = 1 ]; then
    read -r -p "   Procedo? [S/n] " ok </dev/tty || ok=n
    case "${ok,,}" in ""|s|si|sì|y) ;; *) echo "   Va bene, niente. Puoi rilanciarlo quando vuoi."; exit 0 ;; esac
fi
[ ${#MANCANO[@]} -gt 0 ] && fai sudo pacman -S --needed --noconfirm "${MANCANO[@]}"
if systemctl list-unit-files ollama.service >/dev/null 2>&1 && ! systemctl is-enabled -q ollama 2>/dev/null; then
    fai sudo systemctl enable --now ollama
fi

# ── 3. le librerie di Ciel ───────────────────────────────────────────────────────────────────────────────────
passo "Librerie di Ciel (Python 3.11 a parte, il sistema resta com'è)"
if [ ! -x "$VENV/bin/python" ]; then
    fai uv venv -q --python 3.11 "$VENV"
fi
fai uv pip install -q --python "$VENV/bin/python" -r "$A/requirements.txt"
if [ -L "$A/.venv" ] || [ ! -e "$A/.venv" ]; then
    [ "$(readlink -f "$A/.venv" 2>/dev/null)" = "$(readlink -f "$VENV")" ] || { [ $PROVA = 1 ] || { rm -f "$A/.venv"; ln -s "$VENV" "$A/.venv"; }; }
else
    echo "   $A/.venv c'è già (una cartella vera): la lascio e uso quella"
fi

# ── 4. la configurazione per questo PC e i modelli di voce e orecchie ────────────────────────────────────────
passo "Configurazione"
if [ $NUOVO = 1 ]; then
    fai "$A/.venv/bin/python" "$A/configura.py" nuovo-pc --voce $MOTORE_VOCE --orecchie "$ORECCHIE" --parola hey_jarvis
else
    echo "   config.yaml resta com'è (Ciel era già installata)"
fi
passo "Voce, orecchie, parola di risveglio"
fai "$A/.venv/bin/python" "$A/setup_modelli.py"

# ── 5. i servizi e il resto ──────────────────────────────────────────────────────────────────────────────────
passo "Servizi"
for u in assistente ciel-aec ciel-gui; do metti "$A/sistema/$u.service" "$HOME/.config/systemd/user/$u.service"; done
metti "$A/sistema/ciel" "$HOME/.local/bin/ciel"
# il microfono senza eco (ciel_mic): ~/.asoundrc lo include
if ! grep -qs "asoundrc-ciel" ~/.asoundrc; then
    [ $PROVA = 1 ] && echo "   [farei] ~/.asoundrc include asoundrc-ciel" || echo "<$A/sistema/asoundrc-ciel>" >> ~/.asoundrc
fi
for d in ciel.desktop ciel-chiudi.desktop ciel-code.desktop; do
    [ -f "$A/sistema/$d" ] || continue
    [ $PROVA = 1 ] && { echo "   [farei] ~/.local/share/applications/$d"; continue; }
    mkdir -p ~/.local/share/applications && sed "s|/home/evixion|$HOME|g" "$A/sistema/$d" > ~/.local/share/applications/$d
done
if [ $PROVA = 0 ]; then
    systemctl --user daemon-reload
    systemctl --user enable -q assistente.service ciel-aec.service
    systemctl --user restart ciel-aec.service assistente.service
    mkdir -p ~/.config/cielos && touch ~/.config/cielos/ciel-installata
fi

passo "Fatto"
cat <<E
   Ciel è accesa (parte da sola a ogni accesso). Chiamala con «Hey Jarvis», o scrivile: Super+Spazio,
   oppure dal terminale: ciel "che ore sono?".
   Non ha ancora una mente: senza, fa i comandi (volume, app, finestre, timer, ora) e ti spiega il resto.
   Per dargliene una: Super+A → cerca e scarica un modello adatto al tuo PC → «Usa per Ciel».
   Registro di Ciel: journalctl --user -u assistente -f
E
