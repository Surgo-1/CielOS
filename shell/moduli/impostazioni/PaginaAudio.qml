// Impostazioni → Audio (PipeWire): da dove esce e da dove entra il suono, il volume di ogni dispositivo e di ogni
// programma che sta suonando. Clic su un dispositivo: diventa quello predefinito.
import QtQuick
import qs.servizi

Column {
    id: p
    width: parent ? parent.width : 500
    spacing: 10
    readonly property var a: Impostati.stato?.audio ?? ({ uscite: [], ingressi: [], app: [] })
    Timer { running: p.visible; interval: 4000; repeat: true; onTriggered: Impostati.aggiorna() }

    component Dispositivo: Rectangle {
        id: d
        property var dev
        property string tipo                 // uscita | ingresso
        width: p.width; height: 86; radius: Tema.raggio
        color: dev.predefinita ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.10) : Qt.rgba(1, 1, 1, 0.03)
        border.color: dev.predefinita ? Tema.oro : Tema.bordo
        Row {
            x: 14; y: 10; spacing: 10
            Text { text: d.tipo === "uscita" ? "speaker" : "mic"; font.family: Tema.icone; font.pixelSize: 20; color: Tema.oroChiaro }
            Text { width: p.width - 200; elide: Text.ElideRight; text: d.dev.descrizione; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14 }
        }
        Text { anchors { right: parent.right; rightMargin: 14; top: parent.top; topMargin: 12 }
               text: d.dev.predefinita ? Lingua.t("in uso") : Lingua.t("usa questo"); color: d.dev.predefinita ? Tema.oro : Tema.tenue; font.family: Tema.font; font.pixelSize: 12
               MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor
                           onClicked: Impostati.fai(["audio", d.tipo, d.dev.nome]) } }
        Text { x: 14; y: 50; text: d.dev.muto ? "volume_off" : "volume_up"; font.family: Tema.icone; font.pixelSize: 20
               color: d.dev.muto ? Tema.allarme : Tema.tenue
               MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                           onClicked: Impostati.fai(["audio", "muto", d.dev.nome, d.dev.muto ? "0" : "1"]) } }
        Cursore { x: 44; y: 32; width: parent.width - 60; testo: ""; min: 0; max: 150; passo: 1; unita: "%"
                  valore: d.dev.volume; onCambiato: v => Impostati.fai(["audio", "volume", d.dev.nome, String(Math.round(v))]) }
    }

    Titoletto { testo: Lingua.t("Uscita"); spiega: Lingua.t("Casse, cuffie, schermo (HDMI/DisplayPort).") }
    Repeater { model: p.a.uscite; Dispositivo { required property var modelData; dev: modelData; tipo: "uscita" } }
    Titoletto { testo: Lingua.t("Ingresso"); spiega: Lingua.t("Microfoni.") }
    Repeater { model: p.a.ingressi; Dispositivo { required property var modelData; dev: modelData; tipo: "ingresso" } }
    Text { visible: p.a.ingressi.length === 0; text: Lingua.t("Nessun microfono."); color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13 }
    Titoletto { testo: Lingua.t("Programmi"); spiega: Lingua.t("Il volume di ognuno, mentre suona.") }
    Text { visible: p.a.app.length === 0; text: Lingua.t("Nessun programma sta suonando."); color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13 }
    Repeater {
        model: p.a.app
        Cursore { required property var modelData; width: p.width; testo: modelData.nome; min: 0; max: 150; passo: 1; unita: "%"
                  valore: modelData.volume; onCambiato: v => Impostati.fai(["audio", "app", String(modelData.id), String(Math.round(v))]) }
    }
}
