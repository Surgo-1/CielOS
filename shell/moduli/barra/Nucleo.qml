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
    readonly property var stati: ({ idle: Lingua.t("Aspetta che la chiami"), ascolto: Lingua.t("Ti ascolta"), pensa: Lingua.t("Ci sta pensando"),
                                     parla: Lingua.t("Sta parlando"), spenta: Lingua.t("È spenta"), domanda: Lingua.t("Aspetta una tua risposta") })
    readonly property color vivo: Ciel.stato === "spenta" ? Tema.tenue : Ciel.colore

    // l'alone: due cerchi larghissimi e trasparenti, la luce che esce dal nucleo
    Rectangle {
        anchors.centerIn: parent
        width: n.lato + 8; height: width; radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: Tema.conAlfa(n.vivo, Ciel.stato === "ascolto" ? 0.30 : 0.12)
        Behavior on border.color { ColorAnimation { duration: 300 } }
    }
    Rectangle {
        anchors.centerIn: parent
        width: n.lato * 0.84; height: width; radius: width / 2
        color: Tema.conAlfa(n.vivo, Ciel.stato === "spenta" ? 0.02 : 0.07)
        border.width: 1.5
        border.color: Tema.conAlfa(n.vivo, Ciel.stato === "ascolto" ? 0.85 : 0.38)
        Behavior on border.color { ColorAnimation { duration: 300 } }
    }
    // pensa: un satellite che gira sull'anello
    Item {
        anchors.fill: parent
        visible: Ciel.stato === "pensa"
        RotationAnimation on rotation { running: Ciel.stato === "pensa"; from: 0; to: 360; duration: 1100; loops: Animation.Infinite }
        Rectangle {
            width: n.lato * 0.17; height: width; radius: width / 2
            x: (n.lato - width) / 2; y: 0
            color: Ciel.colore
        }
    }
    // il nucleo: una sfera di luce, non un pallino piatto
    Rectangle {
        anchors.centerIn: parent
        width: n.lato * 0.46; height: width; radius: width / 2
        color: Tema.conAlfa(n.vivo, Ciel.stato === "spenta" ? 0.35 : 0.18)
        scale: tocco.containsMouse ? 1.15 : 1
        Behavior on scale { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
    }
    Rectangle {
        anchors.centerIn: parent
        width: n.lato * 0.30; height: width; radius: width / 2
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.lighter(n.vivo, Ciel.stato === "spenta" ? 1.0 : 1.45) }
            GradientStop { position: 1; color: n.vivo }
        }
        opacity: Ciel.stato === "spenta" ? 0.5 : 1
        Behavior on opacity { NumberAnimation { duration: 300 } }
        SequentialAnimation on scale {
            running: Ciel.stato === "ascolto"; loops: Animation.Infinite
            NumberAnimation { to: 1.12; duration: 900; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
        }
        SequentialAnimation on scale {
            running: Ciel.stato === "parla"; loops: Animation.Infinite
            NumberAnimation { to: 1.32; duration: 180 }
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
        larghezza: 300
        Row {
            spacing: 10
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 14; height: 14; radius: 7
                color: n.vivo
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Ciel.nome
                color: Tema.testo; font.family: Tema.font; font.pixelSize: 17; font.weight: Font.Medium
            }
            Item { width: 1; height: 1 }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: n.stati[Ciel.stato] ?? Ciel.stato
                color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
            }
        }
        Text {
            visible: Ciel.frase !== ""
            width: parent.width
            text: "«" + Ciel.frase + "»"
            wrapMode: Text.WordWrap; maximumLineCount: 4; elide: Text.ElideRight
            color: Tema.testo; font.family: Tema.font; font.pixelSize: 13; font.italic: true
            lineHeight: 1.15
        }
        Row {
            spacing: 8
            Bottone {
                icona: "edit"; testo: Lingua.t("Scrivi a Ciel"); width: (scheda.larghezza - 40) / 2
                onPremuto: { scheda.aperta = false; Pannelli.apri("lanciatore"); }
            }
            Bottone {
                icona: "settings"; testo: Lingua.t("Impostazioni"); width: (scheda.larghezza - 40) / 2
                onPremuto: { scheda.aperta = false; Pannelli.apri("impostazioni"); }
            }
        }
    }
}
