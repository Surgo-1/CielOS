// Un tasto grande della pagina iniziale del riquadro: icona, nome, una riga che dice a cosa serve.
import QtQuick
import qs.servizi

Rectangle {
    id: t
    property string icona
    property string nome
    property string spiega
    signal premuto()
    height: 104
    radius: Tema.raggio + 2
    color: tocco.containsMouse ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.14) : Qt.rgba(1, 1, 1, 0.035)
    border.color: tocco.containsMouse ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.6) : Tema.bordo
    Behavior on color { ColorAnimation { duration: Tema.durata } }
    Behavior on border.color { ColorAnimation { duration: Tema.durata } }
    scale: tocco.pressed ? 0.98 : 1
    Behavior on scale { NumberAnimation { duration: 90 } }

    Row {
        anchors { left: parent.left; leftMargin: 20; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
        spacing: 16
        Rectangle {
            width: 52; height: 52; radius: 26
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.12)
            Text { anchors.centerIn: parent; text: t.icona; font.family: Tema.icone; font.pixelSize: 28; color: Tema.oro }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 68
            spacing: 4
            Text { text: t.nome; color: Tema.testo; font.family: Tema.font; font.pixelSize: 17; font.weight: Font.Medium }
            Text { width: parent.width; text: t.spiega; color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13; wrapMode: Text.WordWrap }
        }
    }
    MouseArea { id: tocco; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: t.premuto() }
}
