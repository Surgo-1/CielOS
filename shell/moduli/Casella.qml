// La casella di Ciel: quando la voce è spenta (di serie su CielOS) Ciel risponde qui, in un riquadro che compare in
// basso nell'angolo opposto alla barra, e qui le si scrive (Invio manda). Mostra gli ultimi messaggi della
// conversazione (gli stessi della sua finestra e di «ciel …»), le sue domande di conferma (Sì / No) e cosa sta
// facendo. Compare da sola quando Ciel scrive qualcosa (anche di sua iniziativa) e sparisce dopo un po' se non la
// tocchi; resta aperta finché ci tieni sopra il mouse o stai scrivendo. Super+J (tasto_casella) la apre e la chiude.
// I messaggi arrivano da $XDG_RUNTIME_DIR/ciel-messaggi.json (scritto da Ciel solo quando cambia, seguito con
// inotify: a riposo nessun costo).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.servizi

Scope {
    id: c

    property bool aperta: false
    property var messaggi: []
    property int visto: -1               // l'ultimo messaggio di Ciel già mostrato (-1: non ancora letto il file)
    property string attesa: ""           // il messaggio mandato da qui di cui aspettiamo l'esito
    property string domandaCiel: ""      // una conferma di Ciel («La attivo?»)
    property string errore: ""
    property bool tastiera: false        // aperta con Super+J: prende subito la tastiera (fino a quando mandi)
    readonly property bool lavora: attesa !== "" || Ciel.stato === "pensa"

    function apri() { tastiera = true; aperta = true; Qt.callLater(() => campo.forceActiveFocus()); }
    function chiudi() { aperta = false; tastiera = false; campo.text = ""; }
    function manda() {
        const t = campo.text.trim();
        if (!t || attesa) return;
        campo.text = ""; errore = ""; tastiera = false;       // mandato: la tastiera torna alle finestre
        Ciel.chiama({ azione: "scrivi", testo: t, voce: false, conferme: true }, r => {
            if (!r.ok) { c.errore = r.messaggio || Lingua.t("Ciel non ha preso il messaggio."); return; }
            c.attesa = r.id ?? "";
        }, e => c.errore = e);
    }
    function conferma(si) {
        if (!domandaCiel || !attesa) return;
        Ciel.chiama({ azione: "conferma", id: attesa, si: si }, r => {});
        domandaCiel = "";
    }

    GlobalShortcut { appid: "ciel"; name: "casella"; description: "La casella di Ciel"; onPressed: c.aperta ? c.chiudi() : c.apri() }

    FileView {
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ciel-messaggi.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            let d = {};
            try { d = JSON.parse(text()); } catch (e) { return; }
            const lista = d.messaggi ?? [];
            const ultimo = lista.filter(m => m.chi === "ciel").slice(-1)[0];
            // al primo caricamento (shell appena partita) non riapre i messaggi vecchi
            if (c.visto >= 0 && ultimo && ultimo.id > c.visto && !Pannelli.lanciatore && !Pannelli.prova)
                c.aperta = true;
            if (ultimo) c.visto = Math.max(c.visto, ultimo.id); else if (c.visto < 0) c.visto = 0;
            c.messaggi = lista.slice(-12);
            scadenza.restart();
        }
    }

    // l'esito di quello che hai scritto qui: serve solo per le conferme (la risposta arriva con i messaggi)
    Timer {
        interval: 500; repeat: true; running: c.attesa !== ""
        onTriggered: Ciel.chiama({ azione: "risposta", id: c.attesa }, r => {
            if (r.stato === "domanda") c.domandaCiel = r.domanda ?? "";
            else if (r.stato === "fatto" || r.stato === "sconosciuta") { c.attesa = ""; c.domandaCiel = ""; }
        }, e => { c.attesa = ""; c.errore = e; })
    }

    // sparisce da sola: più tempo per i messaggi lunghi; mai mentre ci sei sopra, scrivi o aspetti
    Timer {
        id: scadenza
        interval: 9000 + 45 * ((c.messaggi.slice(-1)[0]?.testo ?? "").length)
        running: c.aperta && !sopra.hovered && campo.text === "" && !campo.activeFocus && !c.lavora && !c.domandaCiel
        onTriggered: c.chiudi()
    }

    PanelWindow {
        id: finestra
        visible: c.aperta || scheda.opacity > 0
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        anchors { bottom: true; right: Tema.lato !== "destra"; left: Tema.lato === "destra" }
        margins { bottom: Tema.margine; right: Tema.margine; left: Tema.margine }
        implicitWidth: 420
        implicitHeight: scheda.implicitHeight
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "ciel-casella"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: !c.aperta ? WlrKeyboardFocus.None
                                   : c.tastiera ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

        Rectangle {
            id: scheda
            width: parent.width
            implicitHeight: colonna.implicitHeight + 32
            radius: Tema.raggio + 6
            gradient: Gradient {
                GradientStop { position: 0; color: Tema.vetroAlto }
                GradientStop { position: 0.6; color: Tema.superficie }
                GradientStop { position: 1; color: Tema.vetroBasso }
            }
            border.width: 1
            border.color: Tema.alfa(Tema.oro, 0.38)
            opacity: c.aperta ? 1 : 0
            transform: Translate { y: c.aperta ? 0 : 12; Behavior on y { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } } }
            Behavior on opacity { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
            HoverHandler { id: sopra }
            Rectangle { x: 24; y: 0; width: 52; height: 2; radius: 1; color: Tema.oro }

            Column {
                id: colonna
                x: 16; y: 16
                width: parent.width - 32
                spacing: 10

                // la testata: chi è, cosa fa, chiudi
                Item {
                    width: parent.width; height: 24
                    Rectangle {
                        id: luce
                        anchors.verticalCenter: parent.verticalCenter
                        width: 10; height: 10; radius: 5
                        color: Ciel.viva ? Ciel.colore : Tema.tenue
                        SequentialAnimation on opacity {
                            running: c.lavora && Tema.animazioni; loops: Animation.Infinite
                            onStopped: luce.opacity = 1                 // finito: di nuovo accesa piena
                            NumberAnimation { from: 1; to: 0.3; duration: 500 }
                            NumberAnimation { from: 0.3; to: 1; duration: 500 }
                        }
                    }
                    Text {
                        anchors { left: luce.right; leftMargin: 8; verticalCenter: parent.verticalCenter }
                        text: Ciel.nome + "  " + (!Ciel.viva ? Lingua.t("· spenta") : c.lavora ? Lingua.t("· ci penso…") : "")
                        color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.Medium
                    }
                    Text {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        text: "close"; font.family: Tema.icone; font.pixelSize: 18
                        color: chiudiTocco.containsMouse ? Tema.oro : Tema.tenue
                        MouseArea { id: chiudiTocco; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor; onClicked: c.chiudi() }
                    }
                }

                // i messaggi: Ciel a sinistra, tu a destra
                Flickable {
                    id: scorri
                    width: parent.width
                    height: Math.min(contentHeight, 360)
                    contentHeight: elenco.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    onContentHeightChanged: contentY = Math.max(0, contentHeight - height)
                    Column {
                        id: elenco
                        width: scorri.width
                        spacing: 6
                        Text {
                            visible: c.messaggi.length === 0
                            width: parent.width
                            wrapMode: Text.Wrap
                            text: Lingua.t("Scrivimi qui quello che ti serve: rispondo in questa casella.")
                            color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13
                        }
                        Repeater {
                            model: c.messaggi
                            Item {
                                required property var modelData
                                readonly property bool mia: modelData.chi === "ciel"
                                width: elenco.width
                                height: nuvola.height
                                Rectangle {
                                    id: nuvola
                                    anchors.left: parent.mia ? parent.left : undefined
                                    anchors.right: parent.mia ? undefined : parent.right
                                    width: Math.min(parent.width * 0.86, testoM.implicitWidth + 24)
                                    height: testoM.implicitHeight + (chi.visible ? chi.height + 4 : 0) + 16
                                    radius: Tema.raggio - 2
                                    color: parent.mia ? Tema.accentoSoft : Tema.conAlfa(Tema.testo, 0.06)
                                    border.width: 1
                                    border.color: parent.mia ? Tema.alfa(Tema.oro, 0.24) : Tema.bordoTenue
                                    Text {
                                        id: chi
                                        visible: parent.parent.mia && parent.parent.modelData.mente && parent.parent.modelData.mente !== "veloce"
                                        x: 12; y: 6
                                        text: String(parent.parent.modelData.mente ?? "").replace(/^./, s => s.toUpperCase())
                                        color: Tema.oroChiaro; font.family: Tema.font; font.pixelSize: 11; font.weight: Font.Medium
                                    }
                                    Text {
                                        id: testoM
                                        x: 12; y: chi.visible ? chi.y + chi.height + 4 : 8
                                        width: Math.min(implicitWidth, elenco.width * 0.86 - 24)
                                        wrapMode: Text.Wrap
                                        textFormat: Text.PlainText
                                        text: parent.parent.modelData.testo
                                        color: Tema.testo; font.family: Tema.font; font.pixelSize: 13
                                        lineHeight: 1.15
                                    }
                                }
                            }
                        }
                    }
                }

                // una sua domanda di conferma
                Row {
                    visible: c.domandaCiel !== ""
                    spacing: 8
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: colonna.width - 150; wrapMode: Text.Wrap
                        text: c.domandaCiel; color: Tema.oroChiaro; font.family: Tema.font; font.pixelSize: 13
                    }
                    Rectangle {
                        width: 64; height: 30; radius: 15; color: Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.25)
                        Text { anchors.centerIn: parent; text: Lingua.t("Sì"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: c.conferma(true) }
                    }
                    Rectangle {
                        width: 64; height: 30; radius: 15; color: Qt.rgba(1, 1, 1, 0.08)
                        Text { anchors.centerIn: parent; text: Lingua.t("No"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: c.conferma(false) }
                    }
                }

                Text {
                    visible: c.errore !== ""
                    width: parent.width; wrapMode: Text.Wrap
                    text: c.errore; color: Tema.allarme; font.family: Tema.font; font.pixelSize: 12
                }

                // dove si scrive
                Rectangle {
                    width: parent.width; height: Math.max(44, campo.contentHeight + 22); radius: Tema.raggio
                    color: Tema.conAlfa(Tema.fondo, 0.55)
                    border.width: 1
                    border.color: campo.activeFocus ? Tema.alfa(Tema.oro, 0.7) : Tema.bordoTenue
                    Behavior on border.color { ColorAnimation { duration: Tema.durata } }
                    TextEdit {
                        id: campo
                        anchors { left: parent.left; leftMargin: 14; right: manda.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        wrapMode: TextEdit.Wrap
                        color: Tema.testo; font.family: Tema.font; font.pixelSize: 14
                        selectionColor: Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.4)
                        Keys.onPressed: e => {
                            if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && !(e.modifiers & Qt.ShiftModifier)) {
                                c.manda(); e.accepted = true;
                            } else if (e.key === Qt.Key_Escape) { c.chiudi(); e.accepted = true; }
                            else if (c.domandaCiel && campo.text === "" && (e.key === Qt.Key_S || e.key === Qt.Key_Y || e.key === Qt.Key_N)) {
                                c.conferma(e.key !== Qt.Key_N); e.accepted = true;
                            }
                        }
                        Text {
                            visible: campo.text === ""
                            text: c.domandaCiel ? Lingua.t("S = sì, N = no") : Lingua.t("Scrivi a Ciel…  (Maiusc+Invio: a capo)")
                            color: Tema.tenue; font: campo.font
                        }
                    }
                    Text {
                        id: manda
                        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        text: "send"; font.family: Tema.icone; font.pixelSize: 20
                        color: campo.text.trim() && !c.attesa ? Tema.oro : Tema.tenue
                        MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: c.manda() }
                    }
                }
            }
        }
    }
}
