// Le impostazioni di Ciel, a mano: tutto quello che si può dire a voce si può cambiare anche qui.
// I controlli nascono dallo schema di cieltema (~/cielos/bin/cieltema schema): una chiave nuova lì compare da sola.
// Ogni modifica passa da cieltema (che controlla il valore, salva com'era prima e rigenera i file); il pannello
// segue ~/.config/cielos/cielos.json, quindi vede subito anche quello che cambi a voce o dal terminale.
// Si apre con Super+I, dalla schedina di Ciel nella barra, o «Impostazioni di Ciel» nel lanciatore.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.servizi
import "impostazioni"
import "impostazioni/scorciatoia.js" as Scorciatoia

Scope {
    id: imp

    property var schema: ({})            // chiave → {tipo, di_serie, limiti, cosa}
    property var temi: []
    property var scelte: ({})            // le chiavi che hai cambiato (cielos.json)
    property string messaggio: ""
    property bool errore: false
    property int sezione: 0
    property string cattura: ""          // la scorciatoia che si sta registrando (tasto_…)
    property var regole: []              // le automazioni (da cield)

    readonly property var sezioni: [
        { nome: "Aspetto", icona: "palette", chiavi: ["preset", "modo", "grafica", "sfondo", "accento", "fondo", "testo", "allarme", "opacita_pannelli", "font",
                                                    "raggio", "margine", "barra_larghezza", "barra_lato", "animazioni"] },
        { nome: "Finestre", icona: "web_asset", chiavi: ["finestre_raggio", "finestre_bordo", "finestre_colore",
                                                       "spazio_dentro", "spazio_fuori"] },
        { nome: "Schermi", icona: "monitor", chiavi: [], pagina: "PaginaSchermi" },
        { nome: "Tastiera e mouse", icona: "mouse", chiavi: [], pagina: "PaginaInput" },
        { nome: "Audio", icona: "volume_up", chiavi: [], pagina: "PaginaAudio" },
        { nome: "Energia e ora", icona: "bolt", chiavi: [], pagina: "PaginaEnergia" },
        { nome: "Scorciatoie", icona: "keyboard", chiavi: ["tasto_lanciatore", "tasto_super", "tasto_blocco", "tasto_sessione",
                                                         "tasto_notifiche", "tasto_impostazioni", "tasto_riquadro", "tasto_casella", "tasto_terminale", "tasto_screenshot"] },
        { nome: "Ciel", icona: "auto_awesome", chiavi: [], pagina: "PaginaCiel" },
        { nome: "Automazioni", icona: "auto_mode", chiavi: [] },
        { nome: "Medico", icona: "stethoscope", chiavi: [], pagina: "PaginaMedico" },
        { nome: "Hardware", icona: "memory", chiavi: [], pagina: "PaginaHardware" },
        { nome: "Sistema", icona: "tune", chiavi: ["terminale", "blocco_minuti", "suono_notifiche", "avatar", "tema_app"] },
        { nome: "Avanzate", icona: "code", chiavi: [], pagina: "PaginaAvanzate" }
    ]
    readonly property string nomeSezione: sezioni[sezione].nome

    function valore(k) { return scelte[k] !== undefined ? scelte[k] : (schema[k]?.di_serie ?? null); }

    // i comandi a cieltema, uno alla volta
    property var coda: []
    function cieltema(args) { coda = [...coda, args]; avanti(); }
    function avanti() {
        if (comando.running || !coda.length) return;
        comando.command = [Percorsi.bin("cieltema"), ...coda[0], "--json"];
        coda = coda.slice(1);
        comando.running = true;
    }
    function imposta(k, v) { cieltema(["imposta", `${k}=${v}`]); }
    function togli(k) { cieltema(["togli", k]); }

    function apri() { Pannelli.apri("impostazioni"); }

    Process {
        id: comando
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    if (r.chiavi) { imp.schema = r.chiavi; imp.temi = r.temi ?? []; }
                    else { imp.messaggio = r.messaggio ?? ""; imp.errore = !r.ok; }
                } catch (e) { imp.messaggio = Lingua.t("cieltema non risponde"); imp.errore = true; }
            }
        }
        onExited: imp.avanti()
    }
    Component.onCompleted: cieltema(["schema"])

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/cielos/cielos.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { imp.scelte = JSON.parse(text()) || {}; } catch (e) {} }
        onLoadFailed: imp.scelte = ({})
    }

    // le automazioni: chieste a cield quando apri la loro sezione, e dopo ogni cambio
    Process {
        id: leggiRegole
        command: [Percorsi.bin("cielctl"), "regole", "--json"]
        stdout: StdioCollector {
            onStreamFinished: { try { imp.regole = JSON.parse(text).regole ?? []; } catch (e) { imp.regole = []; } }
        }
    }
    function aggiornaRegole() { if (!leggiRegole.running) leggiRegole.running = true; }
    Process {
        id: cielctl
        onExited: imp.aggiornaRegole()
    }
    function regola(...args) {
        cielctl.command = [Percorsi.bin("cielctl"), ...args];
        cielctl.running = true;
    }
    Process {                            // una nuova automazione: il modello si apre nell'editor di testo
        id: nuova
        command: [Percorsi.bin("cielctl"), "nuova", Lingua.t("Nuova automazione")]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim();
                if (f) Avvia.comando("editor", ["sh", "-c", 'kate "$1" 2>/dev/null || code "$1" 2>/dev/null || foot -e nano "$1"', "_", f]);
                imp.aggiornaRegole();
            }
        }
    }
    onSezioneChanged: if (nomeSezione === "Automazioni") aggiornaRegole()

    GlobalShortcut { appid: "ciel"; name: "impostazioni"; description: "Impostazioni di Ciel"
        onPressed: Pannelli.impostazioni ? Pannelli.chiudi() : imp.apri() }
    IpcHandler {
        target: "impostazioni"
        function apri(): void { imp.apri(); }
        function chiudi(): void { Pannelli.chiudi(); }
        function aperta(): bool { return Pannelli.impostazioni; }
        // una sezione per nome: aspetto, finestre, scorciatoie, ciel, sistema, automazioni
        function sezione(nome: string): void {
            const i = imp.sezioni.findIndex(x => x.nome.toLowerCase() === nome.toLowerCase());
            if (i >= 0) imp.sezione = i;
            imp.apri();
        }
    }

    PanelWindow {
        id: finestra
        visible: Pannelli.impostazioni || pannello.opacity > 0
        screen: Quickshell.screens.find(x => x.name === Pannelli.schermo) ?? Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "ciel-impostazioni"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: Pannelli.impostazioni && !Pannelli.prova ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        onVisibleChanged: if (visible) { imp.messaggio = ""; imp.cattura = ""; tasti.forceActiveFocus(); if (imp.nomeSezione === "Automazioni") imp.aggiornaRegole(); }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.02, 0.03, 0.09, 0.55)
            opacity: Pannelli.impostazioni ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
        }
        MouseArea { anchors.fill: parent; enabled: Pannelli.impostazioni; onClicked: Pannelli.chiudi() }

        Item {                           // la tastiera: Esc chiude, o registra una scorciatoia
            id: tasti
            anchors.fill: parent
            focus: true
            Keys.onPressed: e => {
                if (imp.cattura) {
                    e.accepted = true;
                    if (e.key === Qt.Key_Escape) { imp.cattura = ""; return; }
                    if (e.key === Qt.Key_Backspace && !e.modifiers) { imp.imposta(imp.cattura, "nessuno"); imp.cattura = ""; return; }
                    const n = Scorciatoia.nome(e);
                    if (!n) return;                          // solo modificatori, per ora
                    imp.imposta(imp.cattura, n);
                    imp.cattura = "";
                } else if (e.key === Qt.Key_Escape) {
                    Pannelli.chiudi();
                }
            }
        }

        Rectangle {
            id: pannello
            anchors.centerIn: parent
            width: Math.min(parent.width - 80, 860)
            height: Math.min(parent.height - 80, 720)
            radius: Tema.raggio + 4
            color: Tema.superficie
            border.color: Tema.bordo
            scale: Pannelli.impostazioni ? 1 : 0.97
            opacity: Pannelli.impostazioni ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
            MouseArea { anchors.fill: parent }      // i clic dentro non chiudono

            // in cima: le sezioni come i tasti del riquadro (Super+A), non un elenco a menu
            Column {
                id: testata
                x: 18; y: 14
                width: parent.width - 36
                spacing: 12

                Row {                            // icona e nome della sezione aperta, come l'intestazione del riquadro
                    spacing: 12
                    Rectangle {
                        width: 42; height: 42; radius: Tema.raggio + 2
                        color: Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.12)
                        border.color: Tema.bordo
                        Text { anchors.centerIn: parent; text: imp.sezioni[imp.sezione].icona
                               font.family: Tema.icone; font.pixelSize: 24; color: Tema.oro }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            text: Lingua.t("Impostazioni")
                            color: Tema.oro; font.family: Tema.font; font.pixelSize: 11; font.letterSpacing: 2
                            font.capitalization: Font.AllUppercase; font.weight: Font.Medium
                        }
                        Text {
                            text: Lingua.t(imp.sezioni[imp.sezione].nome)
                            color: Tema.testo; font.family: Tema.font; font.pixelSize: 19; font.weight: Font.Medium
                        }
                    }
                }

                Flow {                           // i tasti: uno per sezione, icona sopra e nome sotto (due righe bastano)
                    width: parent.width
                    spacing: 8
                    Repeater {
                        model: imp.sezioni
                        Rectangle {
                            required property var modelData
                            required property int index
                            // sette tasti per riga, arrotondando per difetto: se no la virgola mobile ne fa stare sei
                            readonly property real passo: Math.floor((testata.width - 8 * 6) / 7)
                            width: passo; height: 62; radius: Tema.raggio
                            color: imp.sezione === index ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.18)
                                 : voce.containsMouse ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.08) : Qt.rgba(1, 1, 1, 0.035)
                            border.color: imp.sezione === index ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.6) : Tema.bordo
                            Behavior on color { ColorAnimation { duration: Tema.durata } }
                            scale: voce.pressed ? 0.97 : 1
                            Behavior on scale { NumberAnimation { duration: 90 } }
                            Column {
                                anchors.centerIn: parent
                                width: parent.width - 10
                                spacing: 2
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.icona; font.family: Tema.icone; font.pixelSize: 20
                                    color: imp.sezione === index ? Tema.oro : Tema.oroChiaro
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: parent.width; horizontalAlignment: Text.AlignHCenter
                                    text: Lingua.t(modelData.nome); wrapMode: Text.WordWrap
                                    color: Tema.testo; font.family: Tema.font; font.pixelSize: 11
                                    lineHeight: 0.95
                                }
                            }
                            MouseArea { id: voce; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: { imp.sezione = index; imp.cattura = ""; } }
                        }
                    }
                }
            }

            // sotto: i controlli della sezione
            Flickable {
                id: scorri
                x: 18
                y: testata.y + testata.height + 14
                width: parent.width - 36
                height: parent.height - y - piede.height - 24
                contentHeight: contenuto.implicitHeight + 10
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: contenuto
                    width: scorri.width - 8
                    // cambiando sezione il contenuto nuovo entra piano (dissolvenza e pochi pixel di corsa)
                    Connections { target: imp; function onSezioneChanged() { entra.restart(); } }
                    ParallelAnimation {
                        id: entra
                        NumberAnimation { target: contenuto; property: "opacity"; from: 0; to: 1; duration: Tema.durata; easing.type: Easing.OutCubic }
                        NumberAnimation { target: contenuto; property: "y"; from: 8; to: 0; duration: Tema.durata; easing.type: Easing.OutCubic }
                    }
                    spacing: 14

                    // le pagine di sistema (schermi, input, audio, energia, hardware, avanzate): impostazioni/Pagina*.qml
                    Loader {
                        width: parent.width
                        visible: active                  // tolta la pagina, il Loader tiene la sua altezza: nascosto non occupa posto
                        active: Pannelli.impostazioni && !!imp.sezioni[imp.sezione].pagina
                        source: active ? "impostazioni/" + imp.sezioni[imp.sezione].pagina + ".qml" : ""
                        onLoaded: Impostati.aggiorna()
                    }

                    // Aspetto: i temi pronti e i colori dallo sfondo
                    Flow {
                        visible: imp.sezione === 0
                        width: parent.width
                        spacing: 8
                        Repeater {
                            model: imp.temi
                            Chip { required property string modelData; testo: Lingua.t(modelData); onPremuto: imp.cieltema(["tema", modelData]) }
                        }
                        Chip { testo: Lingua.t("Dallo sfondo"); icona: "wallpaper"; onPremuto: imp.cieltema(["sfondo"]) }
                    }
                    // Aspetto: gli sfondi di CielOS (disegnati, in grafica/sfondi) o nessuno
                    Flow {
                        visible: imp.sezione === 0
                        width: parent.width
                        spacing: 8
                        Repeater {
                            model: [[Lingua.t("Notte"), "notte"], [Lingua.t("Alba"), "alba"], [Lingua.t("Aurora"), "aurora"]]
                            Chip {
                                required property var modelData
                                testo: modelData[0]; icona: "landscape"
                                onPremuto: imp.imposta("sfondo", Percorsi.radice + "/grafica/sfondi/" + modelData[1] + ".jpg")
                            }
                        }
                        Chip { testo: Lingua.t("Nessuno sfondo"); icona: "format_color_fill"; onPremuto: imp.imposta("sfondo", "nessuno") }
                    }

                    // Sistema: la lingua di CielOS (la shell cambia subito; le altre app dal prossimo accesso)
                    Column {
                        visible: imp.nomeSezione === "Sistema"
                        width: parent.width
                        spacing: 8
                        Text { text: Lingua.t("Lingua"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 14 }
                        Row {
                            spacing: 8
                            Repeater {
                                model: [["it", "Italiano"], ["en", "English"]]
                                Chip {
                                    required property var modelData
                                    testo: modelData[1]; icona: "translate"; acceso: Lingua.codice === modelData[0]
                                    onPremuto: { Lingua.scelta = modelData[0]; Impostati.fai(["lingua", modelData[0]], r => { imp.messaggio = r.messaggio ?? ""; imp.errore = false; }); }
                                }
                            }
                        }
                    }

                    Repeater {
                        model: imp.sezioni[imp.sezione].chiavi.filter(k => imp.schema[k])
                        Riga {
                            required property string modelData
                            width: contenuto.width
                            chiave: modelData
                            info: imp.schema[modelData]
                            valore: imp.valore(modelData)
                            cambiata: imp.scelte[modelData] !== undefined
                            inCattura: imp.cattura === modelData
                            onImposta: v => { imp.cattura = ""; imp.imposta(modelData, v); }
                            onTogli: imp.togli(modelData)
                            onCattura: { imp.cattura = modelData; tasti.forceActiveFocus(); }
                        }
                    }

                    Text {
                        visible: imp.nomeSezione === "Scorciatoie"
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: Lingua.t("Premi «Cambia» e poi la combinazione nuova. Esc annulla, Backspace la toglie.")
                        color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
                    }

                    // Automazioni
                    Column {
                        visible: imp.nomeSezione === "Automazioni"
                        width: parent.width
                        spacing: 8
                        Text {
                            visible: imp.regole.length === 0
                            width: parent.width; wrapMode: Text.WordWrap
                            text: Lingua.t("Nessuna automazione. Creane una qui sotto (si apre nell'editor di testo), oppure chiedila a Ciel: «quando apro un gioco metti il non disturbare».")
                            color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13
                        }
                        Repeater {
                            model: imp.regole
                            Rectangle {
                                required property var modelData
                                width: parent.width
                                height: righe.implicitHeight + 20
                                radius: Tema.raggio
                                color: Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.05)
                                border.color: Tema.bordo
                                opacity: modelData.attiva ? 1 : 0.6
                                Column {
                                    id: righe
                                    x: 14; y: 10
                                    width: parent.width - 28
                                    spacing: 6
                                    Text { text: Lingua.t(modelData.nome); color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.Medium }
                                    Text {
                                        width: parent.width; wrapMode: Text.WordWrap
                                        text: modelData.descrizione; color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
                                    }
                                    Row {
                                        spacing: 6
                                        Chip { testo: modelData.attiva ? Lingua.t("Metti in pausa") : Lingua.t("Riprendi"); icona: modelData.attiva ? "pause" : "play_arrow"
                                               onPremuto: imp.regola(modelData.attiva ? "pausa" : "riprendi", modelData.file) }
                                        Chip { testo: Lingua.t("Provala"); icona: "bolt"; onPremuto: imp.regola("esegui", modelData.file) }
                                        Chip { testo: Lingua.t("Modifica"); icona: "edit"
                                               onPremuto: Avvia.comando("editor", ["sh", "-c", 'kate "$1" 2>/dev/null || code "$1" 2>/dev/null || foot -e nano "$1"', "_",
                                                   (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/cielos/automazioni/" + modelData.file]) }
                                        Chip { testo: Lingua.t("Togli"); icona: "delete"; onPremuto: imp.regola("togli", modelData.file) }
                                    }
                                }
                            }
                        }
                        Row {
                            spacing: 8
                            Chip { testo: Lingua.t("Nuova automazione"); icona: "add"; onPremuto: if (!nuova.running) nuova.running = true }
                            Chip { testo: Lingua.t("Aggiorna"); icona: "refresh"; onPremuto: imp.aggiornaRegole() }
                        }
                    }
                }
            }

            // in fondo: annulla, tutto di serie, e com'è andata l'ultima modifica
            Item {
                id: piede
                x: scorri.x; width: scorri.width
                height: 40
                anchors { bottom: parent.bottom; bottomMargin: 14 }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Chip { testo: Lingua.inglese ? "Undo" : "Annulla"; icona: "undo"; onPremuto: imp.cieltema(["annulla"]) }
                    Chip {
                        property bool sicuro: false
                        testo: sicuro ? Lingua.t("Sicuro? Clicca ancora") : Lingua.t("Tutto di serie"); icona: "restart_alt"
                        onPremuto: { if (sicuro) { imp.cieltema(["ripristina"]); sicuro = false; } else sicuro = true; }
                        Timer { running: parent.sicuro; interval: 3000; onTriggered: parent.sicuro = false }
                    }
                }
                Text {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: parent.width - 330
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    text: imp.messaggio
                    color: imp.errore ? Tema.allarme : Tema.tenue; font.family: Tema.font; font.pixelSize: 12
                }
            }
        }
    }
}
