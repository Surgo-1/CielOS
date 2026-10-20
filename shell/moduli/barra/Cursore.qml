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
    spacing: 11
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 34; height: 34; radius: 17
        color: Tema.accentoSoft
        Text {
            anchors.centerIn: parent
            text: c.icona; font.family: Tema.icone; font.pixelSize: 20
            color: c.spento ? Tema.tenue : Tema.oroChiaro
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: c.iconaPremuta() }
    }
    Item {
        id: guida
        anchors.verticalCenter: parent.verticalCenter
        width: 150; height: 24
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: 7; radius: 3.5
            color: Tema.conAlfa(Tema.testo, 0.10)
            border.width: 1; border.color: Tema.bordoTenue
            Rectangle {
                width: parent.width * c.valore; height: parent.height; radius: 3.5
                color: c.spento ? Tema.tenue : Tema.oro
                Behavior on width { NumberAnimation { duration: 90 } }
            }
        }
        Rectangle {
            x: guida.width * c.valore - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 20; height: 20; radius: 10
            color: Tema.conAlfa(Tema.oro, 0.16)
            Behavior on x { NumberAnimation { duration: 90 } }
        }
        Rectangle {
            x: guida.width * c.valore - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 13; height: 13; radius: 6.5
            color: Tema.testo
            border.width: 2; border.color: Tema.oro
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
        width: 34
        text: Math.round(c.valore * 100) + "%"
        color: Tema.testo; font.family: Tema.font; font.pixelSize: 13; font.weight: Font.Medium
    }
}
