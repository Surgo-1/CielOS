// Un pulsante piccolo del riquadro. «pieno»: quello principale (colore dell'accento); «pericolo»: rosso.
import QtQuick
import qs.servizi

Rectangle {
    id: b
    property string testo
    property string icona
    property bool pieno: false
    property bool pericolo: false
    property bool attivo: true
    signal premuto()
    width: riga.implicitWidth + 28
    height: 34; radius: 17
    opacity: attivo ? 1 : 0.4
    readonly property color base: pericolo ? Tema.allarme : Tema.oro
    color: pieno ? (tocco.containsMouse && attivo ? Qt.lighter(base, 1.10) : base)
         : tocco.containsMouse && attivo ? Tema.conAlfa(base, 0.20) : Tema.conAlfa(base, 0.07)
    border.width: 1
    border.color: pieno ? "transparent" : Tema.conAlfa(base, tocco.containsMouse ? 0.6 : 0.3)
    Behavior on color { ColorAnimation { duration: Tema.durata } }
    Behavior on border.color { ColorAnimation { duration: Tema.durata } }
    scale: tocco.pressed && attivo ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: 90 } }
    Row {
        id: riga
        anchors.centerIn: parent
        spacing: 6
        Text {
            visible: b.icona !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: b.icona; font.family: Tema.icone; font.pixelSize: 17
            color: b.pieno ? Tema.fondo : (b.pericolo ? Tema.allarme : Tema.oroChiaro)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: b.testo; font.family: Tema.font; font.pixelSize: 13; font.weight: Font.Medium
            color: b.pieno ? Tema.fondo : Tema.testo
        }
    }
    MouseArea {
        id: tocco; anchors.fill: parent; hoverEnabled: true
        cursorShape: b.attivo ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (b.attivo) b.premuto()
    }
}
