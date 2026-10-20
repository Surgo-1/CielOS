// Un titoletto dentro una pagina delle impostazioni, con una riga di spiegazione sotto (facoltativa).
import QtQuick
import qs.servizi

Column {
    id: t
    property string testo
    property string spiega
    width: parent ? parent.width : 400
    spacing: 5
    topPadding: 10
    Row {
        spacing: 8
        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 3; height: 13; radius: 1.5; color: Tema.oro }
        Text { anchors.verticalCenter: parent.verticalCenter; text: t.testo; color: Tema.oro; font.family: Tema.font
               font.pixelSize: 13; font.letterSpacing: 1.6; font.capitalization: Font.AllUppercase; font.weight: Font.Medium }
    }
    Text { visible: t.spiega !== ""; width: parent.width; wrapMode: Text.Wrap; text: t.spiega
           color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12; lineHeight: 1.1 }
}
