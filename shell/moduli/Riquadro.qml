// Il riquadro (Super+A, tasto_riquadro): al centro dello schermo che stai usando, come il lanciatore. Pagina iniziale
// con sei tasti: Install (i programmi, come Shelly), Strumenti (come il menu di Omarchy), Scarica modelli, Codice,
// Terminale, I miei modelli. Esc torna indietro (o chiude), un clic fuori chiude. Da terminale:
// qs -c ciel ipc call riquadro alterna | apri | chiudi | aperto | pagina install|strumenti|guida|scarica|codice|modelli
// | guida PAGINA (es. 12-errori)
// | strumento appunti|emoji|scorciatoie|wifi|velocita
// (Codice non è più l'app Ciel Codice: è la pagina degli agenti che si scaricano e si aprono da lì — FreeBuff,
//  OpenCode, Aider, Crush — con il motore in bin/cielagenti. L'app Ciel Codice resta nel lanciatore.)
// Le pagine sono in moduli/riquadro/; il motore dei modelli è bin/cielmodelli.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.servizi
import "riquadro"

Scope {
    id: q

    property string pagina: ""                    // "" (i tasti) | "install" | "scarica" | "modelli"
    property var scaricamenti: []
    readonly property var titoli: ({ "": ["Ciel", "dashboard"], scarica: ["Scarica modelli", "download"],
                                     modelli: ["I miei modelli", "deployed_code"], install: ["Install", "apps"],
                                     codice: ["Codice", "code"],
                                     strumenti: ["Strumenti", "construction"], guida: ["Guida", "menu_book"] })

    function apri(p) { pagina = p ?? ""; Pannelli.apri("riquadro"); }
    function leggiScaricamentiOra() { if (!leggiScaricamenti.running) leggiScaricamenti.running = true }
    property int attesaScaricamenti: 0        // colpi da 1 s dopo un comando: lo scaricamento scrive il suo file appena parte
    function svegliaScaricamenti() { attesaScaricamenti = 20; leggiScaricamentiOra() }
    function chiudi() { Pannelli.chiudi(); }
    function alterna() { Pannelli.riquadro ? chiudi() : apri(""); }
    function vai(p) {
        pagina = p;
        if (p === "scarica") Qt.callLater(scarica.apri);
        if (p === "install") Qt.callLater(install.apri);
        if (p === "codice") Qt.callLater(codice.apri);
        if (p === "strumenti") Qt.callLater(() => strumenti.apri(""));
        if (p === "guida") Qt.callLater(() => guida.apri(""));
    }
    function strumento(v) { pagina = "strumenti"; Pannelli.apri("riquadro"); Qt.callLater(() => strumenti.apri(v)); }
    function indietro() {
        if (pagina === "scarica" && scarica.indietro()) return;
        if (pagina === "install" && install.indietro()) return;
        if (pagina === "strumenti" && strumenti.indietro()) return;
        if (pagina === "guida" && guida.indietro()) return;
        if (pagina) pagina = ""; else chiudi();
    }
    function terminale() {
        Avvia.comando("terminale", [Tema.terminale || "foot"]);
        chiudi();
    }

    GlobalShortcut { appid: "ciel"; name: "riquadro"; description: "Il riquadro di Ciel"; onPressed: q.alterna() }
    Connections { target: Pannelli; function onStrumento(v) { q.strumento(v); } }
    GlobalShortcut { appid: "ciel"; name: "appunti"; description: "La cronologia degli appunti"; onPressed: q.strumento("appunti") }
    GlobalShortcut { appid: "ciel"; name: "emoji"; description: "Le emoji"; onPressed: q.strumento("emoji") }
    GlobalShortcut { appid: "ciel"; name: "scorciatoie"; description: "L'elenco delle scorciatoie"; onPressed: q.strumento("scorciatoie") }
    IpcHandler {
        target: "riquadro"
        function apri(): void { q.apri(""); }
        function chiudi(): void { q.chiudi(); }
        function alterna(): void { q.alterna(); }
        function aperto(): bool { return Pannelli.riquadro; }
        function pagina(nome: string): void {
            q.apri(nome);
            if (nome === "scarica") Qt.callLater(scarica.apri);
            if (nome === "install") Qt.callLater(install.riapri);       // anche dopo un'installazione: rilegge
            if (nome === "codice") Qt.callLater(codice.apri);
            if (nome === "strumenti") Qt.callLater(() => strumenti.apri(""));
        }
        function cerca(testo: string): void { q.apri("scarica"); scarica.cercaTesto(testo); }
        function programmi(testo: string): void { q.apri("install"); install.scheda = "cerca"; install.cerca(testo); }
        function rimuovi(testo: string): void { q.apri("install"); install.scheda = "rimuovi"; install.elenca(testo); }
        function strumento(vista: string): void { q.strumento(vista); }
        function guida(nome: string): void { q.pagina = "guida"; Pannelli.apri("riquadro"); Qt.callLater(() => guida.apri(nome)); }     // appunti | emoji | scorciatoie | wifi | velocita
        function modello(fonte: string, id: string): void { q.apri("scarica"); scarica.scegli({ fonte: fonte, id: id }); }
    }

    // gli scaricamenti: un file per scaricamento, riletti ogni secondo solo mentre ce n'è uno in corso (e una volta
    // quando apri la pagina): a pagina aperta ma ferma non gira nessun processo
    Process {
        id: leggiScaricamenti
        command: [Percorsi.bin("cielmodelli"), "scaricamenti", "--json"]
        stdout: StdioCollector { onStreamFinished: { try { q.scaricamenti = JSON.parse(text).scaricamenti; } catch (e) {} } }
    }
    readonly property bool paginaModelli: Pannelli.riquadro && (pagina === "scarica" || pagina === "modelli")
    onPaginaChanged: if (paginaModelli) Qt.callLater(q.leggiScaricamentiOra)
    Connections {
        target: Pannelli
        function onRiquadroChanged() { if (q.paginaModelli) Qt.callLater(q.leggiScaricamentiOra) }
    }
    Timer {
        interval: 1000; repeat: true
        running: paginaModelli && (q.attesaScaricamenti > 0 || q.scaricamenti.some(d => d.stato === "in corso"))
        onTriggered: { if (q.attesaScaricamenti > 0) q.attesaScaricamenti--; q.leggiScaricamentiOra(); }
    }

    PanelWindow {
        id: finestra
        visible: Pannelli.riquadro || scheda.opacity > 0     // resta il tempo di svanire
        screen: Quickshell.screens.find(s => s.name === Pannelli.schermo) ?? Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "ciel-riquadro"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: Pannelli.riquadro && !Pannelli.prova ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        onVisibleChanged: if (visible) scheda.forceActiveFocus()

        Rectangle {                      // velo: un clic fuori chiude
            anchors.fill: parent
            color: Qt.rgba(0.02, 0.03, 0.09, 0.35)
            opacity: Pannelli.riquadro ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
            MouseArea { anchors.fill: parent; enabled: Pannelli.riquadro; onClicked: q.chiudi() }
        }

        // l'ombra sotto la carta
        Rectangle {
            width: scheda.width + 26; height: scheda.height
            anchors.horizontalCenter: parent.horizontalCenter
            y: scheda.y + 12
            radius: scheda.radius + 13
            color: Tema.ombra
            opacity: scheda.opacity * 0.6
        }

        Rectangle {
            id: scheda
            width: Math.min(q.pagina ? 900 : 760, parent.width - 80)
            height: q.pagina ? Math.min(660, parent.height * 0.74) : intestazione.height + casa.implicitHeight + 78
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * (q.pagina ? 0.12 : 0.18) + (Pannelli.riquadro ? 0 : -10)
            opacity: Pannelli.riquadro ? 1 : 0
            scale: Pannelli.riquadro ? 1 : 0.975
            Behavior on y { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
            radius: Tema.raggio + 8
            gradient: Gradient {
                GradientStop { position: 0; color: Tema.vetroAlto }
                GradientStop { position: 0.5; color: Tema.superficieNetta }
                GradientStop { position: 1; color: Tema.vetroBasso }
            }
            border.width: 1
            border.color: Tema.alfa(Tema.oro, 0.40)
            clip: true
            focus: true
            Keys.onEscapePressed: q.indietro()
            MouseArea { anchors.fill: parent }          // i clic dentro non chiudono

            Rectangle {                                  // filo d'accento in cima
                x: 26; y: 0; width: 64; height: 2; radius: 1
                color: Tema.oro
            }

            Row {                                       // in cima: indietro, icona, titolo
                id: intestazione
                x: 22; y: 16
                width: parent.width - 44
                height: 46
                spacing: 12
                Rectangle {
                    visible: q.pagina !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    width: 34; height: 34; radius: 17
                    color: ind.containsMouse ? Tema.accentoMedio : Tema.biancoTenue
                    border.width: 1; border.color: ind.containsMouse ? Tema.bordoForte : Tema.bordoTenue
                    Text { anchors.centerIn: parent; text: "arrow_back"; font.family: Tema.icone; font.pixelSize: 19; color: Tema.oro }
                    MouseArea { id: ind; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: q.indietro() }
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44; height: 44; radius: Tema.raggio + 2
                    color: Tema.accentoSoft
                    border.width: 1; border.color: Tema.alfa(Tema.oro, 0.24)
                    Text {
                        anchors.centerIn: parent
                        // q.pagina può essere una pagina che non conosciamo (IPC, o una versione più nuova della shell):
                        // in quel caso si resta sul titolo della casa, invece di un errore QML (TypeError su undefined)
                        text: (q.titoli[q.pagina] ?? q.titoli[""])[1]; font.family: Tema.icone; font.pixelSize: 23; color: Tema.oro
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0
                    Text {
                        text: "CielOS"
                        color: Tema.oro; font.family: Tema.font; font.pixelSize: 10; font.letterSpacing: 2.2
                        font.capitalization: Font.AllUppercase; font.weight: Font.Medium
                    }
                    Text {
                        text: Lingua.t((q.titoli[q.pagina] ?? q.titoli[""])[0])
                        color: Tema.testo; font.family: Tema.font; font.pixelSize: 20; font.weight: Font.Medium
                    }
                }
                Item { width: Math.max(0, parent.width - 400); height: 1 }
                Text {                                   // la via d'uscita, sempre a portata
                    anchors.verticalCenter: parent.verticalCenter
                    text: q.pagina === "" ? Lingua.t("Esc per chiudere") : Lingua.t("Esc per tornare")
                    color: Tema.tenue; font.family: Tema.font; font.pixelSize: 11
                }
            }

            Item {                                      // le pagine
                id: corpo
                x: 22; y: intestazione.y + intestazione.height + 16
                width: parent.width - 44
                height: parent.height - y - 20

                Column {                                // la pagina iniziale: Install, poi i quattro tasti
                    id: casa
                    visible: q.pagina === ""
                    width: parent.width
                    spacing: 12
                    Row {
                        spacing: 12
                        Tasto { width: (casa.width - 24) / 3; icona: "apps"; nome: "Install"; spiega: Lingua.t("Programmi da Arch, AUR e Flathub"); onPremuto: q.vai("install") }
                        Tasto { width: (casa.width - 24) / 3; icona: "construction"; nome: Lingua.t("Strumenti"); spiega: Lingua.t("Registra, QR, appunti, emoji"); onPremuto: q.vai("strumenti") }
                        Tasto { width: (casa.width - 24) / 3; icona: "menu_book"; nome: Lingua.t("Guida"); spiega: Lingua.t("La wiki di CielOS"); onPremuto: q.vai("guida") }
                    }
                    Grid {
                        width: parent.width
                        columns: 2; columnSpacing: 12; rowSpacing: 12
                        Tasto { width: (casa.width - 12) / 2; icona: "download"; nome: Lingua.t("Scarica modelli"); spiega: Lingua.t("Cerca su HuggingFace e Ollama, e vedi se gira sul tuo PC"); onPremuto: q.vai("scarica") }
                        Tasto { width: (casa.width - 12) / 2; icona: "code"; nome: Lingua.t("Codice"); spiega: Lingua.t("FreeBuff, OpenCode, Aider e Crush: scarica e apri"); onPremuto: q.vai("codice") }
                        Tasto { width: (casa.width - 12) / 2; icona: "terminal"; nome: Lingua.t("Terminale"); spiega: Lingua.t("Apre %1", Tema.terminale || "foot"); onPremuto: q.terminale() }
                        Tasto { width: (casa.width - 12) / 2; icona: "deployed_code"; nome: Lingua.t("I miei modelli"); spiega: Lingua.t("Accendi, spegni, libera la memoria, elimina"); onPremuto: q.vai("modelli") }
                    }
                    Row {                                // in fondo: le scorciatoie della casa
                        width: parent.width
                        spacing: 14
                        Repeater {
                            model: [["Super + A", Lingua.t("questo riquadro")], ["Super + Space", Lingua.t("Ciel e le app")], ["Esc", Lingua.t("indietro")]]
                            Row {
                                required property var modelData
                                spacing: 6
                                Rectangle {
                                    height: 20; width: k.implicitWidth + 12; radius: 5
                                    color: Tema.biancoTenue; border.width: 1; border.color: Tema.bordoTenue
                                    Text { id: k; anchors.centerIn: parent; text: parent.parent.modelData[0]
                                           color: Tema.testo; font.family: Tema.font; font.pixelSize: 11; font.weight: Font.Medium }
                                }
                                Text { anchors.verticalCenter: parent.verticalCenter; text: parent.modelData[1]
                                       color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12 }
                            }
                        }
                    }
                }
                Scarica { id: scarica; anchors.fill: parent; visible: q.pagina === "scarica"; scaricamenti: q.scaricamenti
                          onAggiorna: q.svegliaScaricamenti() }
                Install { id: install; anchors.fill: parent; visible: q.pagina === "install" }
                Codice { id: codice; anchors.fill: parent; visible: q.pagina === "codice" }
                Strumenti { id: strumenti; anchors.fill: parent; visible: q.pagina === "strumenti" }
                Guida { id: guida; anchors.fill: parent; visible: q.pagina === "guida" }
                Modelli { anchors.fill: parent; visible: q.pagina === "modelli"; attiva: Pannelli.riquadro && visible; scaricamenti: q.scaricamenti }
            }
        }
    }
}
