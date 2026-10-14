// L'ora in colonna (ore sopra, minuti sotto; in fila se la barra è orizzontale), con i due punti d'oro. Mouse sopra: la data e il calendario del mese.
import QtQuick
import qs.servizi

Grid {
    id: o
    columns: Tema.orizzontale ? 3 : 1
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter
    property date ora: new Date()
    readonly property bool sopra: tocco.hovered
    spacing: Tema.orizzontale ? 4 : -2
    HoverHandler { id: tocco; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: scheda.alterna() }
    Timer {                              // allo scoccare del minuto, non ogni secondo
        running: true; repeat: true
        interval: 60000 - (Date.now() % 60000) + 50
        onTriggered: { o.ora = new Date(); interval = 60000 - (Date.now() % 60000) + 50; }
    }
    Text {
        text: Qt.formatTime(o.ora, "HH")
        font.family: Tema.font; font.pixelSize: 17; font.weight: Font.Medium; color: Tema.testo
    }
    Rectangle { width: Tema.orizzontale ? 2 : 10; height: Tema.orizzontale ? 10 : 2; radius: 1; color: Tema.oro }
    Text {
        text: Qt.formatTime(o.ora, "mm")
        font.family: Tema.font; font.pixelSize: 17; color: Tema.testo
    }

    Schedina {
        id: scheda
        icona: o
        larghezza: 270
        property int scarto: 0                   // mesi avanti o indietro rispetto a oggi
        onApertaChanged: if (aperta) { scarto = 0; o.ora = new Date(); }
        readonly property date mese: new Date(o.ora.getFullYear(), o.ora.getMonth() + scarto, 1)
        readonly property var nomiMesi: Lingua.inglese ? ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"] : ["gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno", "luglio",
                                         "agosto", "settembre", "ottobre", "novembre", "dicembre"]
        readonly property var nomiGiorni: Lingua.inglese ? ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"] : ["domenica", "lunedì", "martedì", "mercoledì", "giovedì", "venerdì", "sabato"]

        Text {
            text: Lingua.inglese ? scheda.nomiGiorni[o.ora.getDay()] + ", " + scheda.nomiMesi[o.ora.getMonth()] + " " + o.ora.getDate() : scheda.nomiGiorni[o.ora.getDay()] + " " + o.ora.getDate() + " " + scheda.nomiMesi[o.ora.getMonth()]
            color: Tema.testo; font.family: Tema.font; font.pixelSize: 17; font.weight: Font.Medium
            font.capitalization: Font.Capitalize
        }
        Item {
            width: parent.width; height: 24
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: scheda.nomiMesi[scheda.mese.getMonth()] + " " + scheda.mese.getFullYear()
                color: Tema.oro; font.family: Tema.font; font.pixelSize: 13; font.letterSpacing: 2
                font.capitalization: Font.AllUppercase
            }
            Row {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Repeater {
                    model: [["chevron_left", -1], ["chevron_right", 1]]
                    Text {
                        required property var modelData
                        text: modelData[0]; font.family: Tema.icone; font.pixelSize: 20; color: Tema.oroChiaro
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: scheda.scarto += parent.modelData[1] }
                    }
                }
            }
        }
        Grid {
            columns: 7
            columnSpacing: 0; rowSpacing: 2
            Repeater {
                model: Lingua.inglese ? ["M", "T", "W", "T", "F", "S", "S"] : ["L", "M", "M", "G", "V", "S", "D"]
                Text {
                    required property string modelData
                    width: 34; horizontalAlignment: Text.AlignHCenter
                    text: modelData; color: Tema.tenue; font.family: Tema.font; font.pixelSize: 11
                }
            }
            Repeater {
                model: 42
                Item {
                    required property int index
                    readonly property int primo: (scheda.mese.getDay() + 6) % 7      // lunedì = 0
                    readonly property date giorno: new Date(scheda.mese.getFullYear(), scheda.mese.getMonth(), index - primo + 1)
                    readonly property bool delMese: giorno.getMonth() === scheda.mese.getMonth()
                    readonly property bool oggi: giorno.toDateString() === o.ora.toDateString()
                    visible: index < 35 || (index - primo + 1) <= new Date(scheda.mese.getFullYear(), scheda.mese.getMonth() + 1, 0).getDate()
                    width: 34; height: 26
                    Rectangle {
                        anchors.centerIn: parent
                        width: 26; height: 26; radius: 13
                        color: parent.oggi ? Tema.oro : "transparent"
                    }
                    Text {
                        anchors.centerIn: parent
                        text: parent.giorno.getDate()
                        color: parent.oggi ? Tema.fondo : parent.delMese ? Tema.testo : Qt.rgba(1, 1, 1, 0.22)
                        font.family: Tema.font; font.pixelSize: 13; font.weight: parent.oggi ? Font.Bold : Font.Normal
                    }
                }
            }
        }
    }
}
