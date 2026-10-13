// Il cerchio magico di Ciel (avatar/Avatar.qml di Ciel, collegato in ~/cielos/shell/ciel). Se Ciel non c'è,
// un semplice nucleo dorato: il blocco funziona lo stesso.
import QtQuick

Item {
    id: c
    property color colore: "#ffbf3f"
    property string umore: "sereno"
    property string stato: "idle"

    Loader {
        id: av
        anchors.fill: parent
        source: Qt.resolvedUrl("../../ciel/Avatar.qml")
        onLoaded: {
            item.colore = Qt.binding(() => c.colore);
            item.umore = Qt.binding(() => c.umore);
            item.stato = Qt.binding(() => c.stato);
        }
    }
    Rectangle {
        visible: av.status !== Loader.Ready
        anchors.centerIn: parent
        width: parent.width * 0.3; height: width; radius: width / 2
        color: c.colore
    }
}
