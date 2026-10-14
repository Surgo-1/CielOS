# Il terminale di CielOS: prompt, saluto e «?» per chiedere a Ciel. Solo con la shell Ciel attiva (con caelestia
# resta tutto com'era). Collegato in ~/.config/fish/conf.d/ciel.fish. Niente di pesante: il saluto legge un file e
# lancia un fastfetch ridotto; il prompt è starship con i colori della tavolozza del terminale (cioè del tema di Ciel:
# giallo = l'accento, giallo chiaro = l'accento chiaro, rosso = allarme), così segue da solo quello che scegli.
test -e ~/.config/cielos/shell-attiva; or return
status is-interactive; or return

set -q CIELOS_DIR; or set -gx CIELOS_DIR ~/cielos
set -gx STARSHIP_CONFIG $CIELOS_DIR/terminale/starship.toml

function fish_greeting
    # la lingua di CielOS: la scelta nelle Impostazioni, se no quella del sistema (italiano se LANG comincia con «it»)
    set -l en 0
    set -l scelta (cat (set -q XDG_CONFIG_HOME; and echo $XDG_CONFIG_HOME; or echo ~/.config)/cielos/lingua 2>/dev/null)
    if test "$scelta" = en
        set en 1
    else if test "$scelta" != it; and test -n "$LANG"; and not string match -qr '^(it|C$|C\.|POSIX)' -- $LANG
        set en 1
    end
    set -l ora (date +%H)
    set -l saluto Buonanotte
    if test $ora -ge 5 -a $ora -lt 13; set saluto Buongiorno
    else if test $ora -ge 13 -a $ora -lt 18; set saluto "Buon pomeriggio"
    else if test $ora -ge 18; set saluto Buonasera
    end
    if test $en = 1
        set saluto "Good night"
        if test $ora -ge 5 -a $ora -lt 13; set saluto "Good morning"
        else if test $ora -ge 13 -a $ora -lt 18; set saluto "Good afternoon"
        else if test $ora -ge 18; set saluto "Good evening"
        end
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
    set -l g (set_color yellow)
    set -l n (set_color normal)
    set -l riga
    switch $stato
        case spenta
            if command -q ciel
                set riga "Ciel dorme. La svegli con "$g"ciel accendi"$n"."
                test $en = 1; and set riga "Ciel is asleep. Wake her up with "$g"ciel accendi"$n"."
            else                     # CielOS senza l'assistente: i tasti per cominciare
                set riga $g"Super+Spazio"$n" cerca e apre, "$g"Super+A"$n" i modelli e Codice, "$g"cielos"$n" per aggiornare e il resto."
                test $en = 1; and set riga $g"Super+Space"$n" finds and opens, "$g"Super+A"$n" models and Code, "$g"cielos"$n" to update and more."
            end
        case pensa
            set riga "Ciel sta pensando a qualcosa."
            test $en = 1; and set riga "Ciel is thinking about something."
        case parla
            set riga "Ciel sta parlando."
            test $en = 1; and set riga "Ciel is talking."
        case '*'
            set riga "Ciel è qui. Chiedile qualcosa con "$g"? la tua domanda"$n"."
            test $en = 1; and set riga "Ciel is here. Ask her something with "$g"? your question"$n"."
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
