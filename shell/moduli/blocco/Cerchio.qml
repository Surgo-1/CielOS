// Il cerchio magico di Ciel (avatar/Avatar.qml di Ciel, collegato in ~/cielos/shell/ciel). Se Ciel non c'è,
// un nucleo dorato con i suoi anelli: il blocco funziona lo stesso, e mentre pensa o ascolta si accende piano.
import QtQuick

Item {
    id: c
    property color colore: "#ffbf3f"
    property string umore: "sereno"
    property string stato: "idle"
    readonly property bool attivo: stato !== "idle"

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

    Item {
        id: ripiego
        visible: av.status !== Loader.Ready
        anchors.fill: parent
        property real respiro: 0.55

        SequentialAnimation on respiro {
            running: c.attivo
            loops: Animation.Infinite
            NumberAnimation { to: 0.92; duration: 1100; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.45; duration: 1100; easing.type: Easing.InOutSine }
        }

        // l'alone: respira piano mentre Ciel pensa o ascolta
        Rectangle {
            id: alone
            anchors.centerIn: parent
            width: parent.width * 0.92; height: width; radius: width / 2
            color: Qt.rgba(c.colore.r, c.colore.g, c.colore.b, 0.09)
            opacity: c.attivo ? ripiego.respiro : 0.55
        }

        // due anelli: uno fermo, uno che gira appena quando c'è da pensare
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.68; height: width; radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(c.colore.r, c.colore.g, c.colore.b, 0.38)
        }
        Item {
            id: giro
            anchors.centerIn: parent
            width: parent.width * 0.78; height: width
            RotationAnimation on rotation {
                running: c.attivo
                from: 0; to: 360; duration: 7000; loops: Animation.Infinite
            }
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    readonly property real angolo: index * 2 * Math.PI / 3 - Math.PI / 2
                    x: giro.width / 2 + Math.cos(angolo) * giro.width / 2 - width / 2
                    y: giro.height / 2 + Math.sin(angolo) * giro.height / 2 - height / 2
                    width: 4; height: 4; radius: 2
                    color: c.colore
                    opacity: index === 0 ? 0.9 : 0.45
                }
            }
        }

        // il nucleo: una sfera di luce, non un disco piatto
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.38; height: width; radius: width / 2
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.28)
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.lighter(c.colore, 1.35) }
                GradientStop { position: 0.55; color: c.colore }
                GradientStop { position: 1; color: Qt.darker(c.colore, 1.5) }
            }
            scale: c.attivo ? 1.04 : 1
            Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

            Rectangle {                                   // il riflesso in alto
                x: parent.width * 0.24; y: parent.height * 0.16
                width: parent.width * 0.24; height: width; radius: width / 2
                color: Qt.rgba(1, 1, 1, 0.5)
            }
        }
    }
}
