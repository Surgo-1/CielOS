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
    height: 36
    radius: Tema.raggioPiccolo + 4
    color: tocco.containsMouse || acceso ? Tema.accentoMedio : Tema.accentoSoft
    border.width: 1
    border.color: tocco.containsMouse || acceso ? Tema.bordoForte : Tema.bordoTenue
    Behavior on color { ColorAnimation { duration: Tema.durata } }
    Behavior on border.color { ColorAnimation { duration: Tema.durata } }
    Row {
        anchors.centerIn: parent
        spacing: 9
        Text {
            visible: b.icona !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: b.icona; font.family: Tema.icone; font.pixelSize: 18; color: Tema.oroChiaro
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: b.testo; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14
            font.weight: Font.Medium
        }
    }
    MouseArea { id: tocco; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.premuto() }
}
