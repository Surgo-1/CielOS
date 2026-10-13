// La schedina accanto a un'icona della barra: si apre da sola quando il mouse ci si ferma sopra (un attimo,
// così passarci sopra di corsa non apre niente), scivola fuori dalla barra e si chiude poco dopo che il mouse
// è andato via, sia dall'icona sia dalla schedina. Il clic sull'icona la apre o la chiude subito.
// Uso: Schedina { icona: r; titolo: "Rete"; …contenuto… }
import QtQuick
import Quickshell
import qs.servizi

PopupWindow {
    id: s
    required property Item icona
    property string titolo
    property int larghezza: 300
    property bool aperta: false
    default property alias contenuto: colonna.data
    readonly property bool sopra: icona.sopra || dentro.hovered

    function alterna() { aperta = !aperta; }

    anchor.item: icona
    anchor.rect.x: icona.width + 6
    anchor.rect.y: icona.height - implicitHeight
    implicitWidth: larghezza + 8
    implicitHeight: colonna.implicitHeight + 28
    color: "transparent"
    visible: aperta || fondo.opacity > 0

    Timer {                              // ci si ferma sopra: si apre
        running: s.icona.sopra && !s.aperta
        interval: 220
        onTriggered: s.aperta = true
    }
    Timer {                              // il mouse è andato via: si chiude
        running: s.aperta && !s.sopra
        interval: 450
        onTriggered: s.aperta = false
    }

    Rectangle {
        id: fondo
        width: s.larghezza
        height: parent.height
        x: s.aperta ? 8 : -6
        opacity: s.aperta ? 1 : 0
        scale: s.aperta ? 1 : 0.96
        transformOrigin: Item.BottomLeft
        radius: Tema.raggio
        color: Tema.superficie
        border.color: Tema.bordo
        Behavior on x { NumberAnimation { duration: Tema.durata * 1.3; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Tema.durata * 1.3; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
        HoverHandler { id: dentro }

        Column {
            id: colonna
            x: 14; y: 14
            width: parent.width - 28
            spacing: 10
            Text {
                visible: s.titolo !== ""
                text: s.titolo
                color: Tema.oro; font.family: Tema.font; font.pixelSize: 13; font.letterSpacing: 2
                font.capitalization: Font.AllUppercase; font.weight: Font.Medium
            }
        }
    }
}
