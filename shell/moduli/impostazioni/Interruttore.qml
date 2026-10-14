// Un interruttore acceso/spento con la sua etichetta (e una spiegazione, se c'è).
import QtQuick
import qs.servizi

Item {
    id: i
    property string testo
    property string spiega
    property bool acceso: false
    property bool attivo: true
    signal cambiato(bool v)
    width: parent ? parent.width : 400
    height: Math.max(32, col.implicitHeight)
    opacity: attivo ? 1 : 0.5
    Column {
        id: col
        anchors { left: parent.left; right: tasto.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
        spacing: 2
        Text { width: parent.width; wrapMode: Text.Wrap; text: i.testo; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14 }
        Text { visible: i.spiega !== ""; width: parent.width; wrapMode: Text.Wrap; text: i.spiega
               color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12 }
    }
    Rectangle {
        id: tasto
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: 44; height: 24; radius: 12
        color: i.acceso ? Tema.oro : Qt.rgba(1, 1, 1, 0.12)
        Behavior on color { ColorAnimation { duration: Tema.durata } }
        Rectangle {
            width: 18; height: 18; radius: 9; y: 3
            x: i.acceso ? parent.width - width - 3 : 3
            color: i.acceso ? Tema.fondo : Tema.testo
            Behavior on x { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
        }
        MouseArea { anchors.fill: parent; enabled: i.attivo; cursorShape: Qt.PointingHandCursor; onClicked: i.cambiato(!i.acceso) }
    }
}
