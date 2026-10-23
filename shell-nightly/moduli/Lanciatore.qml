// Il lanciatore della Nightly (Super+Spazio, o il segno di Ciel nella barra): scrivi e le app compaiono, frecce per
// scegliere, Invio per aprire, Esc per chiudere. Vetro al centro dello schermo e un filo di luce che segue la scelta.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.servizi
import "../componenti"

Scope {
    id: l
    property string testo: ""
    property int scelta: 0

    readonly property var app: DesktopEntries.applications.values.filter(a => !a.noDisplay)
    readonly property var trovate: {
        const q = testo.trim().toLowerCase();
        const punti = a => {
            const n = (a.name ?? "").toLowerCase();
            if (!q) return 1;
            if (n.startsWith(q)) return 100;
            if (n.split(/[\s\-_.]+/).some(p => p.startsWith(q))) return 80;
            if (n.includes(q)) return 50;
            if ((a.comment ?? "").toLowerCase().includes(q)) return 20;
            return 0;
        };
        return app.map(a => ({ a: a, p: punti(a) })).filter(x => x.p > 0)
                  .sort((x, y) => y.p - x.p || x.a.name.localeCompare(y.a.name))
                  .slice(0, 9).map(x => x.a);
    }

    function apriLanciatore() { testo = ""; scelta = 0; Pannelli.mostra("lanciatore"); }
    function esegui() {
        const a = trovate[Math.max(0, Math.min(scelta, trovate.length - 1))];
        Pannelli.chiudi();
        if (a) Avvia.app(a);
    }

    GlobalShortcut { appid: "ciel-nightly"; name: "lanciatore"; description: "Il lanciatore della Nightly"; onPressed: l.apriLanciatore() }
    IpcHandler {
        target: "nightly"
        function lanciatore(): void { l.apriLanciatore(); }
        function chiudi(): void { Pannelli.chiudi(); }
        function aperto(): string { return Pannelli.aperto; }
    }

    PanelWindow {
        id: finestra
        visible: Pannelli.aperto === "lanciatore"
        screen: Quickshell.screens.find(s => s.name === Pannelli.schermo) ?? Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "nightly-lanciatore"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: Pannelli.aperto === "lanciatore" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        onVisibleChanged: if (visible) Qt.callLater(() => campo.forceActiveFocus())

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.01, 0.02, 0.05, 0.42)
            MouseArea { anchors.fill: parent; onClicked: Pannelli.chiudi() }
        }

        Hud {
            id: carta
            width: Math.min(660, parent.width - 120)
            height: Math.min(460, parent.height * 0.62)
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.16

            MouseArea { anchors.fill: parent }

            Column {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12

                Row {
                    width: parent.width
                    spacing: 10
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "search"; color: Tema.ciano
                        font.family: Tema.icone; font.pixelSize: 20
                    }
                    TextInput {
                        id: campo
                        width: parent.width - 40
                        anchors.verticalCenter: parent.verticalCenter
                        color: Tema.testo
                        font.family: Tema.font
                        font.pixelSize: 20
                        selectionColor: Tema.alfa(Tema.ciano, 0.35)
                        selectedTextColor: Tema.testo
                        onTextChanged: l.scelta = 0
                        onAccepted: l.esegui()
                        Keys.onEscapePressed: Pannelli.chiudi()
                        Keys.onDownPressed: l.scelta = Math.min(l.scelta + 1, l.trovate.length - 1)
                        Keys.onUpPressed: l.scelta = Math.max(l.scelta - 1, 0)
                        Text {
                            visible: campo.text === ""
                            text: Lingua.t("Apri un programma, o scrivi per cercarlo")
                            color: Tema.tenue
                            font: campo.font
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Tema.alfa(Tema.ciano, 0.18) }

                ListView {
                    id: elenco
                    width: parent.width
                    height: parent.height - 82
                    clip: true
                    model: l.trovate
                    currentIndex: l.scelta
                    spacing: 2
                    delegate: Rectangle {
                        required property int index
                        required property var modelData
                        readonly property bool scelto: index === l.scelta
                        width: elenco.width; height: 42; radius: Tema.raggioPiccolo
                        color: scelto ? Tema.cianoFondo : "transparent"
                        border.width: scelto ? 1 : 0
                        border.color: Tema.alfa(Tema.ciano, 0.4)
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left; anchors.leftMargin: 10
                            spacing: 12
                            Image {
                                width: 20; height: 20
                                anchors.verticalCenter: parent.verticalCenter
                                sourceSize: Qt.size(40, 40)
                                source: Quickshell.iconPath(modelData.icon, true) || ""
                                visible: source != ""
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name
                                color: scelto ? Tema.testo : Tema.tenue
                                font.family: Tema.font; font.pixelSize: 14
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: l.scelta = index
                            onClicked: { l.scelta = index; l.esegui(); }
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: 16
                    Text { text: "↑↓ " + Lingua.t("scegli"); color: Tema.tenue; font.family: Tema.font; font.pixelSize: 10 }
                    Text { text: "Invio " + Lingua.t("apri"); color: Tema.tenue; font.family: Tema.font; font.pixelSize: 10 }
                    Text { text: "Esc " + Lingua.t("chiudi"); color: Tema.tenue; font.family: Tema.font; font.pixelSize: 10 }
                }
            }
        }
    }
}
