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
    radius: Tema.raggio + 4
    gradient: Gradient {
        GradientStop { position: 0; color: Tema.vetroAlto }
        GradientStop { position: 1; color: Tema.vetroBasso }
    }
    border.width: 1
    border.color: Tema.bordoTenue

    Rectangle {                              // il filo del colore della misura
        x: 16; y: 0; width: 34; height: 2; radius: 1
        color: r.colore
    }
    Column {
        x: 16; y: 14
        width: parent.width - 32
        spacing: 3
        Text {
            text: r.titolo; color: Tema.tenue; font.family: Tema.font; font.pixelSize: 11
            font.letterSpacing: 1.3; font.capitalization: Font.AllUppercase; font.weight: Font.Medium
        }
        Text {
            text: r.valore; color: Tema.testo; font.family: Tema.font
            font.pixelSize: 27; font.weight: Font.Medium
        }
        Text {
            width: parent.width; elide: Text.ElideRight; text: r.dettaglio; color: Tema.tenue
            font.family: Tema.font; font.pixelSize: 12
        }
    }
    Grafico {
        visible: r.storia.length > 1
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 8 }
        height: parent.height * 0.42
        valori: r.storia; massimo: r.massimo; colore: r.colore
    }
}
