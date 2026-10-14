# La lingua di CielOS per gli script in bash: «. lingua.sh» e poi «t "testo in italiano" [valori…]» (vedi lingua.py).
# LINGUA_CODICE (it/en) si può cambiare dopo averlo caricato (l'installatore usa la lingua scelta).
LINGUA_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
LINGUA_CODICE=$(python3 "$LINGUA_DIR/lingua.py" --codice 2>/dev/null || echo it)
t() {
    if [ "$LINGUA_CODICE" = it ]; then
        local r=$1; shift; local i=1
        for v in "$@"; do r=${r//%$i/$v}; i=$((i + 1)); done
        printf '%s' "$r"
    else
        CIELOS_LINGUA=$LINGUA_CODICE python3 "$LINGUA_DIR/lingua.py" "$@"
    fi
}
