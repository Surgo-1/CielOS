// Il riquadro: una finestra al centro dello schermo che stai usando, come il lanciatore (Super+Spazio), che si apre
// con Super+A (tasto_riquadro, si cambia in Impostazioni → Scorciatoie). Per ora è vuota: è il posto pronto per
// quello che ci metteremo. Esc o un clic fuori chiude; anche da terminale: qs -c ciel ipc call riquadro alterna
// Per riempirla: il contenuto va in «corpo» (sotto il titolo); titolo e icona in cima.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.servizi

Scope {
    id: q

    property string titolo: "Riquadro"
    property string icona: "dashboard"

    function apri() { Pannelli.apri("riquadro"); }
    function chiudi() { Pannelli.chiudi(); }
    function alterna() { Pannelli.riquadro ? chiudi() : apri(); }

    GlobalShortcut { appid: "ciel"; name: "riquadro"; description: "Il riquadro di Ciel"; onPressed: q.alterna() }
    IpcHandler {
        target: "riquadro"
        function apri(): void { q.apri(); }
        function chiudi(): void { q.chiudi(); }
        function alterna(): void { q.alterna(); }
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
            width: Math.min(720, parent.width - 80)
            height: Math.max(220, colonna.implicitHeight + 36)
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.2 + (Pannelli.riquadro ? 0 : -10)
            opacity: Pannelli.riquadro ? 1 : 0
            scale: Pannelli.riquadro ? 1 : 0.98
            Behavior on y { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
            radius: Tema.raggio + 4
            color: Tema.superficie
            border.color: Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.45)
            focus: true
            Keys.onEscapePressed: q.chiudi()
            MouseArea { anchors.fill: parent }          // i clic dentro non chiudono

            Column {
                id: colonna
                x: 22; y: 18
                width: parent.width - 44
                spacing: 14

                Row {
                    spacing: 10
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: q.icona; font.family: Tema.icone; font.pixelSize: 22; color: Tema.oro
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: q.titolo
                        color: Tema.oro; font.family: Tema.font; font.pixelSize: 13; font.letterSpacing: 2
                        font.capitalization: Font.AllUppercase; font.weight: Font.Medium
                    }
                }

                Item {                           // il corpo: per ora un segnaposto
                    id: corpo
                    width: parent.width
                    height: 140
                    Text {
                        anchors.centerIn: parent
                        text: "Qui arriverà qualcosa di nuovo."
                        color: Tema.tenue; font.family: Tema.font; font.pixelSize: 15
                    }
                }
            }
        }
    }
}
