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
    spacing: 6
    readonly property var attuale: voci.find(x => x.valore === valore)
    Text { visible: t.testo !== ""; text: t.testo; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14 }
    Rectangle {
        width: parent.width; height: 36; radius: 18
        color: Qt.rgba(1, 1, 1, 0.05); border.color: t.aperta ? Tema.oro : Tema.bordo
        Text { anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
               text: t.attuale ? t.attuale.testo : (t.valore ?? "—"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
        Text { anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
               text: t.aperta ? "expand_less" : "expand_more"; font.family: Tema.icone; font.pixelSize: 20; color: Tema.tenue }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: t.aperta = !t.aperta }
    }
    Rectangle {
        visible: t.aperta
        width: parent.width; height: Math.min(260, lista.contentHeight + 8); radius: 12
        color: Qt.rgba(0, 0, 0, 0.25); border.color: Tema.bordo
        ListView {
            id: lista
            anchors { fill: parent; margins: 4 }
            clip: true
            model: t.voci
            boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle {
                required property var modelData
                width: lista.width; height: 32; radius: 8
                color: modelData.valore === t.valore ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.22)
                     : v.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                Text { anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                       text: modelData.testo; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
                MouseArea { id: v; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { t.aperta = false; t.scelto(modelData.valore); } }
            }
        }
    }
}
