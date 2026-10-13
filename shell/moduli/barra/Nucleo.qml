// Ciel nella barra: il nucleo del colore della mente che sta parlando. Ferma quando aspetta, respira quando
// ascolta, gira quando pensa, pulsa quando parla, grigia se è spenta. Clic: il lanciatore (che è anche Ciel).
// Mouse sopra: una schedina con chi sta parlando, cosa sta facendo e l'ultima cosa che ha detto.
import QtQuick
import qs.servizi

Item {
    id: n
    readonly property int lato: Tema.barra - 16
    implicitWidth: lato
    implicitHeight: lato
    readonly property bool sopra: tocco.containsMouse
    readonly property var stati: ({ idle: "Aspetta che la chiami", ascolto: "Ti ascolta", pensa: "Ci sta pensando",
                                     parla: "Sta parlando", spenta: "È spenta", domanda: "Aspetta una tua risposta" })

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
        id: tocco
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: { scheda.aperta = false; Pannelli.lanciatore ? Pannelli.chiudi() : Pannelli.apri("lanciatore"); }
    }

    Schedina {
        id: scheda
        icona: n
        inAlto: true
        larghezza: 290
        Row {
            spacing: 10
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 12; height: 12; radius: 6; color: Ciel.colore }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Ciel.nome
                color: Tema.testo; font.family: Tema.font; font.pixelSize: 17; font.weight: Font.Medium
            }
        }
        Text {
            text: n.stati[Ciel.stato] ?? Ciel.stato
            color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13
        }
        Text {
            visible: Ciel.frase !== ""
            width: parent.width
            text: "«" + Ciel.frase + "»"
            wrapMode: Text.WordWrap; maximumLineCount: 4; elide: Text.ElideRight
            color: Tema.testo; font.family: Tema.font; font.pixelSize: 13; font.italic: true
        }
        Bottone {
            icona: "edit"; testo: "Scrivi a Ciel"
            onPremuto: { scheda.aperta = false; Pannelli.apri("lanciatore"); }
        }
    }
}
