// L'ora in colonna (ore sopra, minuti sotto), con i due punti d'oro. Sotto il mouse: la data.
import QtQuick
import qs.servizi

Column {
    id: o
    property date ora: new Date()
    spacing: -2
    Timer {                              // allo scoccare del minuto, non ogni secondo
        running: true; repeat: true
        interval: 60000 - (Date.now() % 60000) + 50
        onTriggered: { o.ora = new Date(); interval = 60000 - (Date.now() % 60000) + 50; }
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatTime(o.ora, "HH")
        font.family: Tema.font; font.pixelSize: 17; font.weight: Font.Medium; color: Tema.testo
    }
    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 10; height: 2; radius: 1; color: Tema.oro }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatTime(o.ora, "mm")
        font.family: Tema.font; font.pixelSize: 17; color: Tema.testo
    }
}
