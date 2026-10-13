// Un pulsantino delle impostazioni: testo, icona facoltativa, acceso se è la scelta attuale.
import QtQuick
import qs.servizi

Rectangle {
    id: c
    property string testo
    property string icona
    property bool acceso: false
    signal premuto()
    width: riga.implicitWidth + 24
    height: 32; radius: 16
    color: acceso ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.3)
         : tocco.containsMouse ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.16) : Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.06)
    border.color: acceso ? Tema.oro : Tema.bordo
    Behavior on color { ColorAnimation { duration: Tema.durata } }
    Row {
        id: riga
        anchors.centerIn: parent
        spacing: 6
        Text {
            visible: c.icona !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: c.icona; font.family: Tema.icone; font.pixelSize: 16; color: Tema.oroChiaro
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: c.testo; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13
            font.capitalization: Font.Capitalize
        }
    }
    MouseArea { id: tocco; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: c.premuto() }
}
