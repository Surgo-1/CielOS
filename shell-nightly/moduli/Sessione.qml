// La sessione della Nightly: blocca, sospendi, esci, riavvia, spegni. Un elenco corto, tasti grandi, Esc per
// tornare indietro. Le azioni sono quelle di sistema (loginctl/systemctl/hyprctl): nessun comando nuovo.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.servizi
import "../componenti"

Scope {
    id: s
    function fai(cmd) { Pannelli.chiudi(); Quickshell.execDetached(cmd); }

    PanelWindow {
        id: finestra
        visible: Pannelli.aperto === "sessione"
        screen: Quickshell.screens.find(s => s.name === Pannelli.schermo) ?? Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "nightly-sessione"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: Pannelli.aperto === "sessione" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.01, 0.02, 0.05, 0.5)
            MouseArea { anchors.fill: parent; onClicked: Pannelli.chiudi() }
            focus: true
            Keys.onEscapePressed: Pannelli.chiudi()

            Hud {
                width: Math.min(380, parent.width - 120)
                height: content.height + 78
                anchors.centerIn: parent

                MouseArea { anchors.fill: parent }

                Column {
                    id: content
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 22
                    spacing: 6

                    Text {
                        text: Lingua.t("SESSIONE").toUpperCase()
                        color: Tema.ciano
                        font.family: Tema.font; font.pixelSize: 9; font.letterSpacing: 2.6
                        bottomPadding: 2
                    }
                    Repeater {
                        model: [
                            { icona: "lock", testo: Lingua.t("Blocca lo schermo"), cmd: ["loginctl", "lock-session"] },
                            { icona: "bedtime", testo: Lingua.t("Sospendi"), cmd: ["systemctl", "suspend"] },
                            { icona: "logout", testo: Lingua.t("Esci"), cmd: ["hyprctl", "dispatch", "exit"] },
                            { icona: "restart_alt", testo: Lingua.t("Riavvia"), cmd: ["systemctl", "reboot"] },
                            { icona: "power_settings_new", testo: Lingua.t("Spegni"), cmd: ["systemctl", "poweroff"] }
                        ]
                        Rectangle {
                            required property var modelData
                            width: parent.width
                            height: 44
                            radius: Tema.raggioPiccolo
                            color: tocco.containsMouse ? Tema.cianoFondo : "transparent"
                            border.width: 1
                            border.color: tocco.containsMouse ? Tema.alfa(Tema.ciano, 0.45) : "transparent"
                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 12
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.icona
                                    color: modelData.icona === "power_settings_new" ? Tema.allarme : Tema.ciano
                                    font.family: Tema.icone; font.pixelSize: 18
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.testo
                                    color: Tema.testo
                                    font.family: Tema.font; font.pixelSize: 14
                                }
                            }
                            MouseArea {
                                id: tocco
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: s.fai(modelData.cmd)
                            }
                        }
                    }
                }
            }
        }
    }
}
