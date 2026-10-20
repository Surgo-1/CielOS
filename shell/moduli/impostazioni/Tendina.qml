// Una scelta da un elenco lungo (es. le risoluzioni): mostra quella attuale; un clic apre l'elenco sotto.
// voci: [{testo, valore}]
import QtQuick
import qs.servizi

Column {
    id: t
    property string testo
    property var voci: []
    property var valore
    property bool aperta: false
    signal scelto(var v)
    width: parent ? parent.width : 400
    spacing: 7
    readonly property var attuale: voci.find(x => x.valore === valore)
    Text { visible: t.testo !== ""; text: t.testo; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.Medium }
    Rectangle {
        width: parent.width; height: 38; radius: Tema.raggioPiccolo + 8
        color: Tema.conAlfa(Tema.testo, 0.05)
        border.width: 1
        border.color: t.aperta ? Tema.alfa(Tema.oro, 0.7) : Tema.bordoTenue
        Behavior on border.color { ColorAnimation { duration: Tema.durata } }
        Text { anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
               text: t.attuale ? t.attuale.testo : (t.valore ?? "—"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
        Text { anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
               text: t.aperta ? "expand_less" : "expand_more"; font.family: Tema.icone; font.pixelSize: 20; color: Tema.oro }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: t.aperta = !t.aperta }
    }
    Rectangle {
        visible: t.aperta
        width: parent.width; height: Math.min(260, lista.contentHeight + 8); radius: Tema.raggio
        color: Tema.superficieNetta
        border.width: 1; border.color: Tema.alfa(Tema.oro, 0.28)
        clip: true
        ListView {
            id: lista
            anchors { fill: parent; margins: 4 }
            clip: true
            model: t.voci
            boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle {
                required property var modelData
                width: lista.width; height: 33; radius: Tema.raggioPiccolo + 2
                color: modelData.valore === t.valore ? Tema.accentoMedio
                     : v.containsMouse ? Tema.biancoTenue : "transparent"
                Text { anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                       text: modelData.testo; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
                Text { anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                       visible: modelData.valore === t.valore; text: "check"
                       font.family: Tema.icone; font.pixelSize: 16; color: Tema.oro }
                MouseArea { id: v; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { t.aperta = false; t.scelto(modelData.valore); } }
            }
        }
    }
}
