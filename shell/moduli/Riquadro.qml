// Il riquadro (Super+A, tasto_riquadro): al centro dello schermo che stai usando, come il lanciatore. Pagina iniziale
// con sei tasti: Install (i programmi, come Shelly), Strumenti (come il menu di Omarchy), Scarica modelli, Codice,
// Terminale, I miei modelli. Esc torna indietro (o chiude), un clic fuori chiude. Da terminale:
// qs -c ciel ipc call riquadro alterna | apri | chiudi | aperto | pagina install|strumenti|guida|scarica|modelli
// | guida PAGINA (es. 12-errori)
// | strumento appunti|emoji|scorciatoie|wifi|velocita
// (Codice apre l'app Ciel Codice, una finestra sua: ~/cielos/codice)
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
                                     strumenti: ["Strumenti", "construction"], guida: ["Guida", "menu_book"] })

    function apri(p) { pagina = p ?? ""; Pannelli.apri("riquadro"); }
    function chiudi() { Pannelli.chiudi(); }
    function alterna() { Pannelli.riquadro ? chiudi() : apri(""); }
    function vai(p) {
        pagina = p;
        if (p === "scarica") Qt.callLater(scarica.apri);
        if (p === "install") Qt.callLater(install.apri);
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
    function codice() {
        Avvia.comando("ciel-codice", [Percorsi.bin("ciel-codice"), "app"]);
        chiudi();
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
            if (nome === "strumenti") Qt.callLater(() => strumenti.apri(""));
        }
        function cerca(testo: string): void { q.apri("scarica"); scarica.cercaTesto(testo); }
        function programmi(testo: string): void { q.apri("install"); install.scheda = "cerca"; install.cerca(testo); }
        function rimuovi(testo: string): void { q.apri("install"); install.scheda = "rimuovi"; install.elenca(testo); }
        function strumento(vista: string): void { q.strumento(vista); }
        function guida(nome: string): void { q.pagina = "guida"; Pannelli.apri("riquadro"); Qt.callLater(() => guida.apri(nome)); }     // appunti | emoji | scorciatoie | wifi | velocita
        function modello(fonte: string, id: string): void { q.apri("scarica"); scarica.scegli({ fonte: fonte, id: id }); }
    }

    // gli scaricamenti: riletti ogni secondo mentre il riquadro è aperto (un file per scaricamento, niente di più)
    Process {
        id: leggiScaricamenti
        command: [Percorsi.bin("cielmodelli"), "scaricamenti", "--json"]
        stdout: StdioCollector { onStreamFinished: { try { q.scaricamenti = JSON.parse(text).scaricamenti; } catch (e) {} } }
    }
    Timer {
        interval: 1000; repeat: true; triggeredOnStart: true
        running: Pannelli.riquadro && (q.pagina === "scarica" || q.pagina === "modelli")
        onTriggered: if (!leggiScaricamenti.running) leggiScaricamenti.running = true
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

        Rectangle {
            id: scheda
            width: Math.min(q.pagina ? 880 : 720, parent.width - 80)
            height: q.pagina ? Math.min(640, parent.height * 0.72) : intestazione.height + casa.implicitHeight + 58
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * (q.pagina ? 0.14 : 0.2) + (Pannelli.riquadro ? 0 : -10)
            opacity: Pannelli.riquadro ? 1 : 0
            scale: Pannelli.riquadro ? 1 : 0.98
            Behavior on y { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
            radius: Tema.raggio + 4
            color: Qt.rgba(Tema.superficie.r, Tema.superficie.g, Tema.superficie.b, 0.99)   // opaco: qui si legge molto
            border.color: Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.45)
            clip: true
            focus: true
            Keys.onEscapePressed: q.indietro()
            MouseArea { anchors.fill: parent }          // i clic dentro non chiudono

            Row {                                       // in cima: indietro, icona, titolo
                id: intestazione
                x: 22; y: 18
                height: 30
                spacing: 10
                Rectangle {
                    visible: q.pagina !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30; height: 30; radius: 15
                    color: ind.containsMouse ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.18) : "transparent"
                    Text { anchors.centerIn: parent; text: "arrow_back"; font.family: Tema.icone; font.pixelSize: 20; color: Tema.oro }
                    MouseArea { id: ind; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: q.indietro() }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: q.titoli[q.pagina][1]; font.family: Tema.icone; font.pixelSize: 22; color: Tema.oro
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Lingua.t(q.titoli[q.pagina][0])
                    color: Tema.oro; font.family: Tema.font; font.pixelSize: 13; font.letterSpacing: 2
                    font.capitalization: Font.AllUppercase; font.weight: Font.Medium
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
                        Tasto { width: (casa.width - 24) / 3; icona: "apps"; nome: "Install"; spiega: Lingua.t("Programmi da Arch, AUR e Flathub: cerca, versioni, togli, aggiorna"); onPremuto: q.vai("install") }
                        Tasto { width: (casa.width - 24) / 3; icona: "construction"; nome: Lingua.t("Strumenti"); spiega: Lingua.t("Registra lo schermo, testo e QR, appunti, emoji, luce notturna…"); onPremuto: q.vai("strumenti") }
                        Tasto { width: (casa.width - 24) / 3; icona: "menu_book"; nome: Lingua.t("Guida"); spiega: Lingua.t("La wiki di CielOS e cosa vuol dire ogni errore"); onPremuto: q.vai("guida") }
                    }
                    Grid {
                        width: parent.width
                        columns: 2; columnSpacing: 12; rowSpacing: 12
                        Tasto { width: (casa.width - 12) / 2; icona: "download"; nome: Lingua.t("Scarica modelli"); spiega: Lingua.t("Cerca su HuggingFace e Ollama, e vedi se gira sul tuo PC"); onPremuto: q.vai("scarica") }
                        Tasto { width: (casa.width - 12) / 2; icona: "code"; nome: Lingua.t("Codice"); spiega: Lingua.t("Il Codex di CielOS: progetti, modelli locali o in cloud"); onPremuto: q.codice() }
                        Tasto { width: (casa.width - 12) / 2; icona: "terminal"; nome: Lingua.t("Terminale"); spiega: Lingua.t("Apre %1", Tema.terminale || "foot"); onPremuto: q.terminale() }
                        Tasto { width: (casa.width - 12) / 2; icona: "deployed_code"; nome: Lingua.t("I miei modelli"); spiega: Lingua.t("Accendi, spegni, libera la memoria, elimina"); onPremuto: q.vai("modelli") }
                    }
                }
                Scarica { id: scarica; anchors.fill: parent; visible: q.pagina === "scarica"; scaricamenti: q.scaricamenti
                          onAggiorna: if (!leggiScaricamenti.running) leggiScaricamenti.running = true }
                Install { id: install; anchors.fill: parent; visible: q.pagina === "install" }
                Strumenti { id: strumenti; anchors.fill: parent; visible: q.pagina === "strumenti" }
                Guida { id: guida; anchors.fill: parent; visible: q.pagina === "guida" }
                Modelli { anchors.fill: parent; visible: q.pagina === "modelli"; attiva: Pannelli.riquadro && visible; scaricamenti: q.scaricamenti }
            }
        }
    }
}
