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
        { nome: "Aspetto", icona: "palette", chiavi: ["modo", "sfondo", "accento", "fondo", "testo", "allarme", "opacita_pannelli", "font",
                                                    "raggio", "margine", "barra_larghezza", "barra_lato", "animazioni"] },
        { nome: "Finestre", icona: "web_asset", chiavi: ["finestre_raggio", "finestre_bordo", "finestre_colore",
                                                       "spazio_dentro", "spazio_fuori"] },
        { nome: "Scorciatoie", icona: "keyboard", chiavi: ["tasto_lanciatore", "tasto_super", "tasto_blocco", "tasto_sessione",
                                                         "tasto_notifiche", "tasto_impostazioni", "tasto_terminale", "tasto_screenshot"] },
        { nome: "Sistema", icona: "tune", chiavi: ["terminale", "blocco_minuti", "suono_notifiche", "tema_app"] },
        { nome: "Automazioni", icona: "bolt", chiavi: [] }
    ]

    function valore(k) { return scelte[k] !== undefined ? scelte[k] : (schema[k]?.di_serie ?? null); }

    // i comandi a cieltema, uno alla volta
    property var coda: []
    function cieltema(args) { coda = [...coda, args]; avanti(); }
    function avanti() {
        if (comando.running || !coda.length) return;
        comando.command = [Quickshell.env("HOME") + "/cielos/bin/cieltema", ...coda[0], "--json"];
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
                } catch (e) { imp.messaggio = "cieltema non risponde"; imp.errore = true; }
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
        command: [Quickshell.env("HOME") + "/cielos/bin/cielctl", "regole", "--json"]
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
        cielctl.command = [Quickshell.env("HOME") + "/cielos/bin/cielctl", ...args];
        cielctl.running = true;
    }
    Process {                            // una nuova automazione: il modello si apre nell'editor di testo
        id: nuova
        command: [Quickshell.env("HOME") + "/cielos/bin/cielctl", "nuova", "Nuova automazione"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim();
                if (f) Quickshell.execDetached(["sh", "-c", 'kate "$1" 2>/dev/null || code "$1" 2>/dev/null || foot -e nano "$1"', "_", f]);
                imp.aggiornaRegole();
            }
        }
    }
    onSezioneChanged: if (sezione === 4) aggiornaRegole()

    GlobalShortcut { appid: "ciel"; name: "impostazioni"; description: "Impostazioni di Ciel"
        onPressed: Pannelli.impostazioni ? Pannelli.chiudi() : imp.apri() }
    IpcHandler {
        target: "impostazioni"
        function apri(): void { imp.apri(); }
        function chiudi(): void { Pannelli.chiudi(); }
        // una sezione per nome: aspetto, finestre, scorciatoie, sistema, automazioni
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
        onVisibleChanged: if (visible) { imp.messaggio = ""; imp.cattura = ""; tasti.forceActiveFocus(); if (imp.sezione === 4) imp.aggiornaRegole(); }

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

            // a sinistra: le sezioni
            Column {
                id: menu
                x: 14; y: 18
                width: 190
                spacing: 4
                Text {
                    leftPadding: 10; bottomPadding: 12
                    text: "Impostazioni"
                    color: Tema.oro; font.family: Tema.font; font.pixelSize: 15; font.letterSpacing: 2
                    font.capitalization: Font.AllUppercase; font.weight: Font.Medium
                }
                Repeater {
                    model: imp.sezioni
                    Rectangle {
                        required property var modelData
                        required property int index
                        width: menu.width; height: 38; radius: Tema.raggio / 1.5
                        color: imp.sezione === index ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.18)
                             : voce.containsMouse ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.08) : "transparent"
                        Behavior on color { ColorAnimation { duration: Tema.durata } }
                        Row {
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            spacing: 12
                            Text { text: modelData.icona; font.family: Tema.icone; font.pixelSize: 20; color: Tema.oroChiaro }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.nome; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14
                            }
                        }
                        MouseArea { id: voce; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { imp.sezione = index; imp.cattura = ""; } }
                    }
                }
            }
            Rectangle { x: menu.x + menu.width + 14; y: 18; width: 1; height: parent.height - 36; color: Tema.bordo }

            // a destra: i controlli
            Flickable {
                id: scorri
                x: menu.x + menu.width + 30
                y: 18
                width: parent.width - x - 18
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

                    Text {
                        text: imp.sezioni[imp.sezione].nome
                        color: Tema.testo; font.family: Tema.font; font.pixelSize: 22; font.weight: Font.Medium
                    }

                    // Aspetto: i temi pronti e i colori dallo sfondo
                    Flow {
                        visible: imp.sezione === 0
                        width: parent.width
                        spacing: 8
                        Repeater {
                            model: imp.temi
                            Chip { required property string modelData; testo: modelData; onPremuto: imp.cieltema(["tema", modelData]) }
                        }
                        Chip { testo: "Dallo sfondo"; icona: "wallpaper"; onPremuto: imp.cieltema(["sfondo"]) }
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
                        visible: imp.sezione === 2
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "Premi «Cambia» e poi la combinazione nuova. Esc annulla, Backspace la toglie."
                        color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
                    }

                    // Automazioni
                    Column {
                        visible: imp.sezione === 4
                        width: parent.width
                        spacing: 8
                        Text {
                            visible: imp.regole.length === 0
                            width: parent.width; wrapMode: Text.WordWrap
                            text: "Nessuna automazione. Creane una qui sotto (si apre nell'editor di testo), oppure chiedila a Ciel: «quando apro un gioco metti il non disturbare»."
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
                                    Text { text: modelData.nome; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.Medium }
                                    Text {
                                        width: parent.width; wrapMode: Text.WordWrap
                                        text: modelData.descrizione; color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
                                    }
                                    Row {
                                        spacing: 6
                                        Chip { testo: modelData.attiva ? "Metti in pausa" : "Riprendi"; icona: modelData.attiva ? "pause" : "play_arrow"
                                               onPremuto: imp.regola(modelData.attiva ? "pausa" : "riprendi", modelData.file) }
                                        Chip { testo: "Provala"; icona: "bolt"; onPremuto: imp.regola("esegui", modelData.file) }
                                        Chip { testo: "Modifica"; icona: "edit"
                                               onPremuto: Quickshell.execDetached(["sh", "-c", 'kate "$1" 2>/dev/null || code "$1" 2>/dev/null || foot -e nano "$1"', "_",
                                                   (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/cielos/automazioni/" + modelData.file]) }
                                        Chip { testo: "Togli"; icona: "delete"; onPremuto: imp.regola("togli", modelData.file) }
                                    }
                                }
                            }
                        }
                        Row {
                            spacing: 8
                            Chip { testo: "Nuova automazione"; icona: "add"; onPremuto: if (!nuova.running) nuova.running = true }
                            Chip { testo: "Aggiorna"; icona: "refresh"; onPremuto: imp.aggiornaRegole() }
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
                    Chip { testo: "Annulla"; icona: "undo"; onPremuto: imp.cieltema(["annulla"]) }
                    Chip {
                        property bool sicuro: false
                        testo: sicuro ? "Sicuro? Clicca ancora" : "Tutto di serie"; icona: "restart_alt"
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
