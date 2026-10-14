// Un titoletto dentro una pagina delle impostazioni, con una riga di spiegazione sotto (facoltativa).
import QtQuick
import qs.servizi

Column {
    property string testo
    property string spiega
    width: parent ? parent.width : 400
    spacing: 4
    topPadding: 8
    Text { text: parent.testo; color: Tema.oro; font.family: Tema.font; font.pixelSize: 13; font.letterSpacing: 1.5
           font.capitalization: Font.AllUppercase; font.weight: Font.Medium }
    Text { visible: parent.spiega !== ""; width: parent.width; wrapMode: Text.Wrap; text: parent.spiega
           color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12 }
}
