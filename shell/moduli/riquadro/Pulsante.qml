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
    width: riga.implicitWidth + 26
    height: 34; radius: 17
    opacity: attivo ? 1 : 0.4
    readonly property color base: pericolo ? Tema.allarme : Tema.oro
    color: pieno ? (tocco.containsMouse && attivo ? Qt.lighter(base, 1.12) : base)
         : tocco.containsMouse && attivo ? Qt.rgba(base.r, base.g, base.b, 0.2) : Qt.rgba(base.r, base.g, base.b, 0.07)
    border.color: pieno ? "transparent" : Qt.rgba(base.r, base.g, base.b, 0.45)
    Behavior on color { ColorAnimation { duration: Tema.durata } }
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
