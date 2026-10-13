// Ciel nella barra: il nucleo del colore della mente che sta parlando. Ferma quando aspetta, respira quando
// ascolta, gira quando pensa, pulsa quando parla, grigia se è spenta. Clic: il lanciatore (che è anche Ciel).
import QtQuick
import qs.servizi

Item {
    id: n
    readonly property int lato: Tema.barra - 16
    implicitWidth: lato
    implicitHeight: lato

    Rectangle {
        anchors.centerIn: parent
        width: n.lato; height: width; radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: Qt.rgba(Ciel.colore.r, Ciel.colore.g, Ciel.colore.b, Ciel.stato === "ascolto" ? 0.9 : 0.35)
        Behavior on border.color { ColorAnimation { duration: 300 } }
    }
    Item {
        anchors.fill: parent
        visible: Ciel.stato === "pensa"
        RotationAnimation on rotation { running: Ciel.stato === "pensa"; from: 0; to: 360; duration: 1100; loops: Animation.Infinite }
        Rectangle { width: n.lato * 0.2; height: width; radius: width / 2; x: (n.lato - width) / 2; color: Ciel.colore }
    }
    Rectangle {
        anchors.centerIn: parent
        width: n.lato * 0.46; height: width; radius: width / 2
        color: Ciel.colore
        opacity: Ciel.stato === "spenta" ? 0.5 : 1
        Behavior on color { ColorAnimation { duration: 400 } }
        SequentialAnimation on scale {
            running: Ciel.stato === "ascolto"; loops: Animation.Infinite
            NumberAnimation { to: 1.1; duration: 900; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
        }
        SequentialAnimation on scale {
            running: Ciel.stato === "parla"; loops: Animation.Infinite
            NumberAnimation { to: 1.3; duration: 180 }
            NumberAnimation { to: 1.0; duration: 220 }
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Pannelli.lanciatore ? Pannelli.chiudi() : Pannelli.apri("lanciatore")
    }
}
