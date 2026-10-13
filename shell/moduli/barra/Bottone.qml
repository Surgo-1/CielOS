// Un pulsante delle schedine: icona (facoltativa) e testo, si illumina sotto il mouse.
import QtQuick
import qs.servizi

Rectangle {
    id: b
    property string icona
    property string testo
    property bool acceso: false
    signal premuto()
    width: parent ? parent.width : 200
    height: 34; radius: 17
    color: tocco.containsMouse || acceso ? Qt.rgba(1, 0.75, 0.25, 0.22) : Qt.rgba(1, 0.75, 0.25, 0.08)
    border.color: Tema.bordo
    Behavior on color { ColorAnimation { duration: Tema.durata } }
    Row {
        anchors.centerIn: parent
        spacing: 8
        Text {
            visible: b.icona !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: b.icona; font.family: Tema.icone; font.pixelSize: 17; color: Tema.oroChiaro
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: b.testo; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13
        }
    }
    MouseArea { id: tocco; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.premuto() }
}
