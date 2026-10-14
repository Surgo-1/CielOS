// Un riquadro del monitor: titolo, valore grande, una riga di dettaglio e (se c'è) il grafico.
import QtQuick
import qs.servizi

Rectangle {
    id: r
    property string titolo
    property string valore
    property string dettaglio
    property var storia: []
    property real massimo: 100
    property color colore: Tema.oro
    radius: Tema.raggio
    color: Qt.rgba(1, 1, 1, 0.04)
    border.color: Qt.rgba(1, 1, 1, 0.08)
    Column {
        x: 14; y: 12
        width: parent.width - 28
        spacing: 2
        Text { text: r.titolo; color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12; font.letterSpacing: 1
               font.capitalization: Font.AllUppercase }
        Text { text: r.valore; color: Tema.testo; font.family: Tema.font; font.pixelSize: 24; font.weight: Font.Medium }
        Text { width: parent.width; elide: Text.ElideRight; text: r.dettaglio; color: Tema.tenue
               font.family: Tema.font; font.pixelSize: 12 }
    }
    Grafico {
        visible: r.storia.length > 1
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 8 }
        height: parent.height * 0.42
        valori: r.storia; massimo: r.massimo; colore: r.colore
    }
}
