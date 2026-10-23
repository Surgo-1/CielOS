// La barra della Nightly: una capsula di vetro che galleggia in cima allo schermo. A sinistra il segno di Ciel e i
// workspace, al centro l'ora (mono, grande), a destra volume, rete, batteria: un clic apre il centro di controllo.
// Niente animazioni continue e nessun processo che gira a vuoto: l'ora si aggiorna ogni 15 s, la rete ogni 20 s.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import qs.servizi
import "../componenti"

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: finestra
        required property ShellScreen modelData
        readonly property var spazi: Hyprland.workspaces.values
            .filter(w => w.id > 0 && w.monitor?.name === modelData.name)
            .sort((a, b) => a.id - b.id)
        readonly property int attivo: Hyprland.focusedWorkspace?.id ?? 0
        readonly property PwNode uscita: Pipewire.defaultAudioSink
        readonly property var pile: UPower.devices.values.filter(d => d.isLaptopBattery && d.isPresent !== false)
        readonly property int perc: pile.length > 0
            ? Math.round(pile.reduce((s, d) => s + d.percentage, 0) / pile.length) : -1
        property string rete: ""

        screen: modelData
        anchors { top: Tema.lato !== "basso"; bottom: Tema.lato === "basso"; left: true; right: true }
        implicitHeight: Tema.barra + Tema.margine * 2
        color: "transparent"
        exclusionMode: Pannelli.prova ? ExclusionMode.Ignore : ExclusionMode.Normal
        exclusiveZone: Tema.barra + Tema.margine
        WlrLayershell.namespace: "nightly-barra"

        PwObjectTracker { objects: [finestra.uscita] }

        // la rete: un solo `nmcli monitor` che dorme finché NetworkManager non dice che è cambiato qualcosa (niente
        // un processo ogni venti secondi), e una lettura quando cambia
        Process {
            id: leggiRete
            command: ["sh", "-c", "nmcli -t -f TYPE,STATE device status 2>/dev/null | awk -F: '$2==\"connected\"{print $1; exit}'"]
            stdout: StdioCollector { onStreamFinished: finestra.rete = text.trim() }
        }
        Process {
            running: true
            command: ["setpriv", "--pdeathsig", "TERM", "nmcli", "monitor"]   // muore con la shell
            stdout: SplitParser { onRead: _ => { if (!leggiRete.running) leggiRete.running = true; } }
        }
        Component.onCompleted: leggiRete.running = true

        Hud {
            id: capsula
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Tema.margine
            anchors.rightMargin: Tema.margine
            height: Tema.barra
            angoli: false
            radius: height / 2

            // ── sinistra: il segno di Ciel e i workspace ──
            Row {
                id: sinistra
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                spacing: 16

                Row {
                    spacing: 8
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                        width: 7; height: 7; radius: 3.5
                        anchors.verticalCenter: parent.verticalCenter
                        color: Tema.oro
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "CIEL"
                        color: Tema.oro
                        font.family: Tema.font
                        font.pixelSize: 12
                        font.letterSpacing: 3.4
                        font.weight: Font.Medium
                    }
                }

                Row {
                    spacing: 7
                    anchors.verticalCenter: parent.verticalCenter
                    Repeater {
                        model: finestra.spazi
                        Rectangle {
                            required property var modelData
                            readonly property bool qui: modelData.id === finestra.attivo
                            width: qui ? 18 : 7
                            height: 7
                            radius: 3.5
                            anchors.verticalCenter: parent.verticalCenter
                            color: qui ? Tema.ciano : Tema.alfa(Tema.ciano, 0.28)
                            border.width: qui ? 0 : 1
                            border.color: Tema.alfa(Tema.ciano, 0.45)
                            Behavior on width { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Hyprland.dispatch("workspace " + modelData.id)
                            }
                        }
                    }
                }
            }

            // ── centro: l'ora, e la data sotto ──
            Column {
                anchors.centerIn: parent
                spacing: -2
                Text {
                    id: ora
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(new Date(), "HH:mm")
                    color: Tema.testo
                    font.family: Tema.mono
                    font.pixelSize: 17
                    font.weight: Font.Medium
                    font.letterSpacing: 1.2
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(new Date(), "ddd d MMM").toUpperCase()
                    color: Tema.tenue
                    font.family: Tema.font
                    font.pixelSize: 9
                    font.letterSpacing: 2.2
                }
            }
            Timer {
                interval: 15000; running: true; repeat: true
                onTriggered: { ora.text = Qt.formatDateTime(new Date(), "HH:mm") }
            }

            // ── destra: volume, rete, batteria ──
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Icona {
                    nome: (!finestra.uscita || finestra.uscita.audio?.muted || finestra.uscita.audio?.volume === 0)
                          ? "volume_off" : finestra.uscita.audio.volume < 0.4 ? "volume_down" : "volume_up"
                    colore: Tema.tenue
                    onPremuto: Pannelli.mostra("centro")
                    onRotella: r => {
                        if (finestra.uscita?.audio)
                            finestra.uscita.audio.volume = Math.max(0, Math.min(1,
                                finestra.uscita.audio.volume + (r.angleDelta.y > 0 ? 0.05 : -0.05)));
                    }
                }
                Icona {
                    nome: finestra.rete === "wifi" ? "wifi" : finestra.rete === "ethernet" ? "lan" : "wifi_off"
                    colore: finestra.rete ? Tema.tenue : Tema.allarme
                    onPremuto: Pannelli.mostra("centro")
                }
                Icona {
                    visible: finestra.perc >= 0
                    nome: finestra.perc < 15 ? "battery_alert" : finestra.perc < 60 ? "battery_5_bar" : "battery_full"
                    colore: finestra.perc < 15 ? Tema.allarme : Tema.tenue
                    onPremuto: Pannelli.mostra("centro")
                }
                Icona {
                    nome: "tune"
                    colore: Tema.tenue
                    onPremuto: Pannelli.mostra("centro")
                }
            }
        }
    }
}
