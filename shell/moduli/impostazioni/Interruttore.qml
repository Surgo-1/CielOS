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
    height: Math.max(34, col.implicitHeight)
    opacity: attivo ? 1 : 0.5
    Column {
        id: col
        anchors { left: parent.left; right: tasto.left; rightMargin: 14; verticalCenter: parent.verticalCenter }
        spacing: 2
        Text { width: parent.width; wrapMode: Text.Wrap; text: i.testo; color: Tema.testo; font.family: Tema.font
               font.pixelSize: 14; font.weight: Font.Medium }
        Text { visible: i.spiega !== ""; width: parent.width; wrapMode: Text.Wrap; text: i.spiega
               color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12 }
    }
    Rectangle {
        id: tasto
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: 48; height: 26; radius: 13
        color: i.acceso ? Tema.oro : Tema.conAlfa(Tema.testo, 0.11)
        border.width: 1
        border.color: i.acceso ? Tema.oroChiaro : Tema.bordoTenue
        Behavior on color { ColorAnimation { duration: Tema.durata } }
        Behavior on border.color { ColorAnimation { duration: Tema.durata } }
        Rectangle {
            width: 20; height: 20; radius: 10; y: 3
            x: i.acceso ? parent.width - width - 3 : 3
            color: i.acceso ? Tema.fondo : Tema.testo
            Behavior on x { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
        }
        MouseArea { anchors.fill: parent; enabled: i.attivo; cursorShape: Qt.PointingHandCursor; onClicked: i.cambiato(!i.acceso) }
    }
}
