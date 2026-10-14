// Le notifiche: il server (riceve quelle di tutte le app), i fumetti in alto a destra sullo schermo che stai usando,
// il «non disturbare» e le ultime 50 in memoria (per il centro notifiche e per Ciel).
// Stessi comandi IPC di caelestia (notifs enableDnd / disableDnd / clear): Ciel e le automazioni di cield non
// cambiano. In prova (CIELOS_PROVA=1) il server non parte (c'è già quello dell'altra shell).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import qs.servizi

Scope {
    id: radice

    property bool nonDisturbare: false
    property var fumetti: []             // le notifiche visibili adesso (al massimo 4)
    property var storia: []              // le ultime 50
    property bool centro: false          // il centro notifiche (Super+N) è aperto

    function aggiungi(n) {
        storia = [n, ...storia].slice(0, 50);
        if (!nonDisturbare) {
            fumetti = [n, ...fumetti].slice(0, 4);
            if (Tema.suonoNotifiche && n.urgency !== NotificationUrgency.Low)
                Quickshell.execDetached(["pw-play", "/usr/share/sounds/freedesktop/stereo/message-new-instant.oga"]);
        }
    }
    function togliFumetto(n) { fumetti = fumetti.filter(x => x !== n); }

    Loader {
        active: !Pannelli.prova
        sourceComponent: NotificationServer {
            keepOnReload: false
            actionsSupported: true
            imageSupported: true
            bodyMarkupSupported: true
            bodyHyperlinksSupported: true
            persistenceSupported: true
            onNotification: n => { n.tracked = true; radice.aggiungi(n); }
        }
    }

    IpcHandler {
        target: "notifs"
        function enableDnd(): void { radice.nonDisturbare = true; radice.fumetti = []; }
        function disableDnd(): void { radice.nonDisturbare = false; }
        function isDndEnabled(): bool { return radice.nonDisturbare; }
        function prova(): void {          // un fumetto finto, per vedere com'è
            radice.fumetti = [{ appName: "Discord", summary: "Marco", body: "Stasera ci sei per la partita?",
                                appIcon: "discord", actions: [{ identifier: "r", text: "Rispondi", invoke: () => {} }] },
                              ...radice.fumetti];
        }
        function centro(): void { radice.centro = !radice.centro; }
        function clear(): void {
            for (const n of radice.storia) n.dismiss?.();
            radice.storia = []; radice.fumetti = [];
        }
    }

    GlobalShortcut { appid: "ciel"; name: "notifiche"; description: "Centro notifiche"; onPressed: radice.centro = !radice.centro }

    // il centro notifiche: a destra sullo schermo che usi, le ultime 50; clic su una la apre, × la toglie
    PanelWindow {
        visible: radice.centro || pannello.x < pannello.width
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        anchors { top: true; right: true; bottom: true }
        implicitWidth: 400
        color: "transparent"
        exclusionMode: ExclusionMode.Normal     // zona 0: non si prende spazio, ma rispetta la barra
        WlrLayershell.namespace: "ciel-centro"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: radice.centro ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        Rectangle {
            id: pannello
            width: parent.width - Tema.margine
            height: parent.height - 2 * Tema.margine
            y: Tema.margine
            x: radice.centro ? 0 : width + Tema.margine
            Behavior on x { NumberAnimation { duration: Tema.durata * 1.4; easing.type: Easing.OutCubic } }
            radius: Tema.raggio
            color: Tema.superficie
            border.color: Tema.bordo
            focus: radice.centro
            Keys.onEscapePressed: radice.centro = false

            Item {
                id: testa
                x: 16; y: 14
                width: parent.width - 32; height: 34
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Notifiche"
                    color: Tema.oro; font.family: Tema.font; font.pixelSize: 13; font.letterSpacing: 2
                    font.capitalization: Font.AllUppercase; font.weight: Font.Medium
                }
                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 6
                    Repeater {
                        model: [[radice.nonDisturbare ? "notifications_off" : "notifications", "nd"], ["delete_sweep", "via"], ["close", "chiudi"]]
                        Rectangle {
                            required property var modelData
                            width: 32; height: 32; radius: 16
                            color: t.containsMouse || (modelData[1] === "nd" && radice.nonDisturbare) ? Qt.rgba(1, 0.75, 0.25, 0.2) : "transparent"
                            Text { anchors.centerIn: parent; text: parent.modelData[0]; font.family: Tema.icone; font.pixelSize: 19; color: Tema.oroChiaro }
                            MouseArea {
                                id: t
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const c = parent.modelData[1];
                                    if (c === "nd") { radice.nonDisturbare = !radice.nonDisturbare; if (radice.nonDisturbare) radice.fumetti = []; }
                                    else if (c === "via") { for (const n of radice.storia) n.dismiss?.(); radice.storia = []; }
                                    else radice.centro = false;
                                }
                            }
                        }
                    }
                }
            }
            Text {
                visible: radice.storia.length === 0
                anchors.centerIn: parent
                text: radice.nonDisturbare ? "Non disturbare acceso.\nNessuna notifica." : "Nessuna notifica."
                horizontalAlignment: Text.AlignHCenter
                color: Tema.tenue; font.family: Tema.font; font.pixelSize: 14
            }
            ListView {
                anchors { top: testa.bottom; topMargin: 10; left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12 }
                clip: true
                spacing: 8
                model: radice.storia
                delegate: Fumetto {
                    required property var modelData
                    notifica: modelData
                    width: ListView.view.width
                    fisso: true
                    onChiuso: { modelData.dismiss?.(); radice.storia = radice.storia.filter(x => x !== modelData); }
                }
            }
        }
    }

    PanelWindow {
        visible: radice.fumetti.length > 0 && !radice.centro
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        anchors { top: true; right: true }
        margins { top: Tema.margine; right: Tema.margine }
        implicitWidth: 380
        implicitHeight: colonna.implicitHeight
        color: "transparent"
        exclusionMode: ExclusionMode.Normal     // zona 0: non si prende spazio, ma rispetta la barra
        WlrLayershell.namespace: "ciel-notifiche"
        WlrLayershell.layer: WlrLayer.Overlay

        Column {
            id: colonna
            width: parent.width
            spacing: 8
            Repeater {
                model: radice.fumetti
                Fumetto {
                    required property var modelData
                    notifica: modelData
                    width: colonna.width
                    onChiuso: radice.togliFumetto(modelData)
                }
            }
        }
    }

    component Fumetto: Rectangle {
        id: f
        property var notifica
        property bool fisso: false       // nel centro: non sparisce da sola
        signal chiuso
        // entra scivolando da destra; esce dissolvendosi verso destra, poi sparisce dall'elenco
        property bool uscendo: false
        function via() { if (uscendo) return; uscendo = true; uscita.start(); }
        Timer { id: uscita; interval: Tema.durata; onTriggered: f.chiuso() }
        property real scarto: 24
        transform: Translate { x: f.scarto }
        Behavior on scarto { NumberAnimation { duration: Tema.durata * 1.3; easing.type: Easing.OutCubic } }
        implicitHeight: interno.implicitHeight + 24
        radius: Tema.raggio
        color: Tema.superficie
        border.color: tocco.containsMouse ? Qt.rgba(1, 0.75, 0.25, 0.6) : Tema.bordo
        border.width: 1
        opacity: 0
        Component.onCompleted: { opacity = 1; scarto = 0; }
        onUscendoChanged: if (uscendo) { opacity = 0; scarto = 24; }
        Text {                           // × per toglierla dal centro
            visible: f.fisso
            anchors { top: parent.top; right: parent.right; margins: 8 }
            z: 2
            text: "close"; font.family: Tema.icone; font.pixelSize: 16; color: Tema.tenue
            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: f.via() }
        }
        Behavior on opacity { NumberAnimation { duration: Tema.durata } }

        Timer {                          // sparisce da solo (non mentre ci passi sopra il mouse)
            running: !tocco.containsMouse && !f.fisso
            interval: (f.notifica?.expireTimeout ?? 0) > 0 ? f.notifica.expireTimeout : 6000
            onTriggered: f.via()
        }
        MouseArea {
            id: tocco
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.LeftButton) {
                    const a = (f.notifica?.actions ?? []).find(x => x.identifier === "default");
                    if (a) a.invoke();
                }
                f.via();
            }
        }

        Row {
            id: interno
            x: 12; y: 12
            width: parent.width - 24
            spacing: 12
            IconImage {
                width: 36; height: 36
                visible: source != ""
                source: f.notifica?.image || (f.notifica?.appIcon ? Quickshell.iconPath(f.notifica.appIcon, true) : "")
                asynchronous: true
            }
            Column {
                width: parent.width - 48
                spacing: 3
                Text {
                    width: parent.width
                    text: f.notifica?.appName ?? ""
                    color: Tema.tenue; font.family: Tema.font; font.pixelSize: 11; font.letterSpacing: 1
                    font.capitalization: Font.AllUppercase; elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: f.notifica?.summary ?? ""
                    color: Tema.oroChiaro; font.family: Tema.font; font.pixelSize: 15; font.weight: Font.Medium
                    wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    visible: text !== ""
                    text: f.notifica?.body ?? ""
                    textFormat: Text.StyledText
                    color: Tema.testo; font.family: Tema.font; font.pixelSize: 13
                    wrapMode: Text.WordWrap; maximumLineCount: 4; elide: Text.ElideRight
                }
                Row {                    // i pulsanti della notifica (Rispondi, Apri…)
                    spacing: 6
                    topPadding: 4
                    Repeater {
                        model: (f.notifica?.actions ?? []).filter(a => a.identifier !== "default")
                        Rectangle {
                            required property var modelData
                            height: 26; width: etichetta.implicitWidth + 20; radius: 13
                            color: Qt.rgba(1, 0.75, 0.25, 0.12)
                            border.color: Tema.bordo
                            Text {
                                id: etichetta
                                anchors.centerIn: parent
                                text: parent.modelData.text
                                color: Tema.testo; font.family: Tema.font; font.pixelSize: 12
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { parent.modelData.invoke(); f.via(); }
                            }
                        }
                    }
                }
            }
        }
    }
}
