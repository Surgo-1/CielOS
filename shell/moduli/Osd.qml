// Quando cambia il volume: una pillola in basso al centro, per un secondo e mezzo. Nient'altro.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import qs.servizi

Scope {
    id: osd
    readonly property PwNode uscita: Pipewire.defaultAudioSink
    readonly property real livello: uscita?.audio?.volume ?? 0
    readonly property bool muto: uscita?.audio?.muted ?? false
    property bool visibile: false
    property bool pronto: false          // all'avvio i valori arrivano: non è un cambiamento tuo

    PwObjectTracker { objects: [osd.uscita] }
    Timer { running: true; interval: 2000; onTriggered: osd.pronto = true }
    Timer { id: nascondi; interval: 1500; onTriggered: osd.visibile = false }
    onLivelloChanged: mostra()
    onMutoChanged: mostra()
    function mostra() { if (pronto) { visibile = true; nascondi.restart(); } }

    PanelWindow {
        visible: osd.visibile
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        anchors.bottom: true
        margins.bottom: 80
        implicitWidth: 300
        implicitHeight: 52
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "cielos-osd"
        WlrLayershell.layer: WlrLayer.Overlay

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Tema.superficie
            border.color: Tema.bordo
            Row {
                anchors.centerIn: parent
                spacing: 14
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: osd.muto ? "volume_off" : "volume_up"
                    font.family: Tema.icone; font.pixelSize: 22; color: Tema.oroChiaro
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 190; height: 6; radius: 3
                    color: Qt.rgba(1, 1, 1, 0.12)
                    Rectangle {
                        width: parent.width * Math.min(1, osd.muto ? 0 : osd.livello)
                        height: parent.height; radius: 3
                        color: Tema.oro
                        Behavior on width { NumberAnimation { duration: 90 } }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 34
                    text: osd.muto ? "—" : Math.round(osd.livello * 100)
                    font.family: Tema.font; font.pixelSize: 14; color: Tema.testo
                }
            }
        }
    }
}
