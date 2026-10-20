// Il menu di spegnimento (pulsante in fondo alla barra, o Super+Esc): blocca, sospendi, esci, riavvia, spegni
// (e, con UEFI, riavvia nelle impostazioni del firmware).
// Frecce o mouse per scegliere, Invio per confermare, Esc o clic fuori per chiudere.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.servizi

Scope {
    id: s
    property int scelta: 0
    readonly property var voci: [
        ["lock", "Blocca", ["loginctl", "lock-session"]],
        ["bedtime", "Sospendi", ["systemctl", "suspend"]],
        ["logout", "Esci", ["sh", "-c", "loginctl terminate-session \"$XDG_SESSION_ID\""]],
        ["restart_alt", "Riavvia", ["systemctl", "reboot"]],
        ["power_settings_new", "Spegni", ["systemctl", "poweroff"]]
    ].concat(uefi ? [["memory", "BIOS/UEFI", ["systemctl", "reboot", "--firmware-setup"]]] : [])
    // (da Omarchy e Garuda) riavvia dritto nelle impostazioni del firmware: solo dove c'è UEFI
    property bool uefi: false
    FileView { path: "/sys/firmware/efi/fw_platform_size"; printErrors: false; onLoaded: s.uefi = true }
    function esegui(i) {
        Pannelli.chiudi();
        if (Pannelli.prova) { console.log("prova: avrei fatto", voci[i][1]); return; }
        Quickshell.execDetached(voci[i][2]);
    }

    PanelWindow {
        visible: Pannelli.sessione || riga.opacity > 0
        screen: Quickshell.screens.find(x => x.name === Pannelli.schermo) ?? Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "ciel-sessione"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: Pannelli.sessione && !Pannelli.prova ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        onVisibleChanged: if (visible) { s.scelta = 0; tasti.forceActiveFocus(); }

        Rectangle {                      // il velo scuro, che compare e svanisce
            anchors.fill: parent
            color: Qt.rgba(0.02, 0.03, 0.09, 0.6)
            opacity: Pannelli.sessione ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
        }
        MouseArea { anchors.fill: parent; enabled: Pannelli.sessione; onClicked: Pannelli.chiudi() }
        Item {
            id: tasti
            anchors.fill: parent
            focus: true
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Escape) Pannelli.chiudi();
                else if (e.key === Qt.Key_Left || e.key === Qt.Key_Up) s.scelta = (s.scelta + s.voci.length - 1) % s.voci.length;
                else if (e.key === Qt.Key_Right || e.key === Qt.Key_Down || e.key === Qt.Key_Tab) s.scelta = (s.scelta + 1) % s.voci.length;
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) s.esegui(s.scelta);
                e.accepted = true;
            }
        }
        Row {
            id: riga
            anchors.centerIn: parent
            spacing: 18
            opacity: Pannelli.sessione ? 1 : 0
            scale: Pannelli.sessione ? 1 : 0.96
            Behavior on opacity { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
            Repeater {
                model: s.voci
                Rectangle {
                    id: b
                    required property var modelData
                    required property int index
                    readonly property bool attiva: s.scelta === index
                    width: 126; height: 142; radius: Tema.raggio + 8
                    gradient: Gradient {
                        GradientStop { position: 0; color: attiva ? Tema.accentoMedio : Tema.vetroAlto }
                        GradientStop { position: 1; color: attiva ? Tema.superficie : Tema.vetroBasso }
                    }
                    border.color: attiva ? Tema.alfa(Tema.oro, 0.85) : Tema.bordoTenue
                    border.width: attiva ? 1.5 : 1
                    scale: attiva ? 1.03 : 1
                    Behavior on scale { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
                    Behavior on border.color { ColorAnimation { duration: Tema.durata } }
                    Rectangle {                      // l'alone della scelta
                        visible: b.attiva
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 14
                        width: 52; height: 52; radius: 26
                        color: Tema.accentoSoft
                    }
                    Column {
                        anchors.centerIn: parent
                        spacing: 11
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: b.modelData[0]; font.family: Tema.icone; font.pixelSize: 42
                            color: b.index === 4 && b.attiva ? Tema.allarme : Tema.oroChiaro
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Lingua.t(b.modelData[1]); font.family: Tema.font; font.pixelSize: 16
                            font.weight: b.attiva ? Font.Medium : Font.Normal
                            color: Tema.testo
                        }
                    }
                    Rectangle {                      // la barretta della scelta
                        visible: b.attiva
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 10
                        width: 20; height: 2; radius: 1
                        color: Tema.oro
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: s.scelta = b.index
                        onClicked: s.esegui(b.index)
                    }
                }
            }
        }
    }
}
