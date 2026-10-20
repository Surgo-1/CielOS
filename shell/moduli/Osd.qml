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
        visible: osd.visibile || pillola.opacity > 0
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        anchors.bottom: true
        margins.bottom: 80
        implicitWidth: 320
        implicitHeight: 58
        color: "transparent"
        exclusionMode: ExclusionMode.Normal     // zona 0: non si prende spazio, ma rispetta la barra
        WlrLayershell.namespace: "ciel-osd"
        WlrLayershell.layer: WlrLayer.Overlay

        Rectangle {                              // l'ombra
            width: pillola.width + 18; height: pillola.height
            anchors.horizontalCenter: parent.horizontalCenter
            y: pillola.y + 6
            radius: height / 2
            color: Tema.ombra
            opacity: pillola.opacity * 0.65
        }
        Rectangle {
            id: pillola
            width: parent.width; height: parent.height
            y: osd.visibile ? 0 : 10
            opacity: osd.visibile ? 1 : 0
            Behavior on y { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
            radius: height / 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Tema.vetroAlto }
                GradientStop { position: 1; color: Tema.vetroBasso }
            }
            border.width: 1
            border.color: Tema.alfa(Tema.oro, 0.32)
            Row {
                anchors.centerIn: parent
                spacing: 13
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 38; height: 38; radius: 19
                    color: Tema.accentoSoft
                    Text {
                        anchors.centerIn: parent
                        text: osd.muto ? "volume_off" : osd.livello === 0 ? "volume_mute" : osd.livello < 0.4 ? "volume_down" : "volume_up"
                        font.family: Tema.icone; font.pixelSize: 21; color: osd.muto ? Tema.tenue : Tema.oro
                    }
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 196; height: 7; radius: 3.5
                    color: Tema.conAlfa(Tema.testo, 0.10)
                    border.width: 1; border.color: Tema.bordoTenue
                    Rectangle {
                        width: parent.width * Math.min(1, osd.muto ? 0 : osd.livello)
                        height: parent.height; radius: 3.5
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Tema.oro }
                            GradientStop { position: 1; color: Tema.oroChiaro }
                        }
                        Behavior on width { NumberAnimation { duration: 90 } }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    text: osd.muto ? "—" : Math.round(osd.livello * 100)
                    font.family: Tema.font; font.pixelSize: 14; font.weight: Font.Medium; color: Tema.testo
                }
            }
        }
    }
}
