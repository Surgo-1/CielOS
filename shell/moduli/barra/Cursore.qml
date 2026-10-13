// Una barra da trascinare (volume, luminosità): icona, guida, percentuale. valore tra 0 e 1.
import QtQuick
import qs.servizi

Row {
    id: c
    property string icona
    property real valore: 0
    property bool spento: false
    signal cambiato(real x)
    signal iconaPremuta()
    spacing: 10
    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: c.icona; font.family: Tema.icone; font.pixelSize: 20
        color: c.spento ? Tema.tenue : Tema.oroChiaro
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: c.iconaPremuta() }
    }
    Item {
        id: guida
        anchors.verticalCenter: parent.verticalCenter
        width: 180; height: 22
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: 6; radius: 3
            color: Qt.rgba(1, 1, 1, 0.1)
            Rectangle {
                width: parent.width * c.valore; height: parent.height; radius: 3
                color: c.spento ? Tema.tenue : Tema.oro
                Behavior on width { NumberAnimation { duration: 90 } }
            }
        }
        Rectangle {
            x: guida.width * c.valore - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 14; height: 14; radius: 7
            color: Tema.oroChiaro
            Behavior on x { NumberAnimation { duration: 90 } }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onPressed: m => c.cambiato(Math.max(0, Math.min(1, m.x / guida.width)))
            onPositionChanged: m => { if (pressed) c.cambiato(Math.max(0, Math.min(1, m.x / guida.width))); }
            onWheel: r => c.cambiato(Math.max(0, Math.min(1, c.valore + (r.angleDelta.y > 0 ? 0.05 : -0.05))))
        }
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Math.round(c.valore * 100) + "%"
        color: Tema.testo; font.family: Tema.font; font.pixelSize: 13
    }
}
