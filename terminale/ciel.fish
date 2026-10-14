# Il terminale di CielOS: prompt, saluto e «?» per chiedere a Ciel. Solo con la shell Ciel attiva (con caelestia
# resta tutto com'era). Collegato in ~/.config/fish/conf.d/ciel.fish. Niente di pesante: il saluto legge un file e
# lancia un fastfetch ridotto; il prompt è starship con i colori della tavolozza del terminale (cioè del tema di Ciel:
# giallo = l'accento, giallo chiaro = l'accento chiaro, rosso = allarme), così segue da solo quello che scegli.
test -e ~/.config/cielos/shell-attiva; or return
status is-interactive; or return

set -q CIELOS_DIR; or set -gx CIELOS_DIR ~/cielos
set -gx STARSHIP_CONFIG $CIELOS_DIR/terminale/starship.toml

function fish_greeting
    set -l ora (date +%H)
    set -l saluto Buonanotte
    if test $ora -ge 5 -a $ora -lt 13; set saluto Buongiorno
    else if test $ora -ge 13 -a $ora -lt 18; set saluto "Buon pomeriggio"
    else if test $ora -ge 18; set saluto Buonasera
    end
    # lo stato di Ciel: lo scrive lei ogni pochi secondi (più vecchio di 90 s vuol dire spenta)
    set -l stato spenta
    set -l f $XDG_RUNTIME_DIR/ciel-stato.json
    if test -r $f
        set -l dati (string collect < $f)
        set -l t (string match -r -g '"t": *([0-9]+)' -- $dati)
        if test -n "$t"; and test (math (date +%s) - $t) -lt 90
            set stato (string match -r -g '"stato": *"(\w+)"' -- $dati)
        end
    end
    set -l riga
    switch $stato
        case spenta
            if command -q ciel
                set riga "Ciel dorme. La svegli con "(set_color yellow)"ciel accendi"(set_color normal)"."
            else                     # CielOS senza l'assistente: i tasti per cominciare
                set riga (set_color yellow)"Super+Spazio"(set_color normal)" cerca e apre, "(set_color yellow)"Super+A"(set_color normal)" i modelli e Codice, "(set_color yellow)"cielos"(set_color normal)" per aggiornare e il resto."
            end
        case pensa;   set riga "Ciel sta pensando a qualcosa."
        case parla;   set riga "Ciel sta parlando."
        case '*';     set riga "Ciel è qui. Chiedile qualcosa con "(set_color yellow)"? la tua domanda"(set_color normal)"."
    end
    fastfetch -c $CIELOS_DIR/terminale/fastfetch.jsonc 2>/dev/null
    echo
    echo "  "(set_color --bold yellow)"$saluto."(set_color normal)" $riga"
    echo
end

# «? domanda»: la chiede a Ciel (stessa conversazione della sua finestra). «?» da solo: si chiacchiera.
function '?' --description 'Chiedi a Ciel'
    ciel $argv
end

# il titolo della finestra: «Ciel · cosa sta girando» (o la cartella)
function fish_title
    set -l cosa (status current-command)
    test "$cosa" = fish; and set cosa (prompt_pwd)
    echo "Ciel · $cosa"
end
