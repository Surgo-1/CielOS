// Impostazioni → Hardware: cosa c'è in questo PC e cosa gli serve (cielos-hardware: driver, firmware, microcodice,
// bluetooth, macchina virtuale…). Solo quello che serve davvero; «Installa» apre un terminale e chiede la password.
// Da qui anche il monitor di sistema e i sensori nella barra.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.servizi

Column {
    id: p
    width: parent ? parent.width : 500
    spacing: 10
    property var hw: null
    Process {
        id: leggi
        running: true
        command: [Percorsi.bin("cielos-hardware"), "--json"]
        stdout: StdioCollector { onStreamFinished: { try { p.hw = JSON.parse(text); } catch (e) {} } }
    }

    Row {
        spacing: 8
        Chip { testo: Lingua.t("Monitor di sistema"); icona: "monitoring"; onPremuto: Avvia.comando("ciel-monitor", [Percorsi.bin("ciel-monitor")]) }
        Chip { testo: Lingua.t("Sensori nella barra"); icona: "thermostat"; onPremuto: Avvia.comando("ciel-monitor", [Percorsi.bin("ciel-monitor"), "sensori"]) }
        Chip { testo: Lingua.t("Rileggi"); icona: "refresh"; onPremuto: if (!leggi.running) leggi.running = true }
    }

    Titoletto { testo: Lingua.t("Questo PC") }
    Text { visible: !p.hw; text: Lingua.t("Guardo l'hardware…"); color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13 }
    Repeater {
        model: p.hw ? p.hw.pezzi : []
        Row {
            required property var modelData
            spacing: 12
            Text { width: 150; text: modelData[0]; color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13 }
            Text { width: p.width - 162; wrapMode: Text.Wrap; text: modelData[1]; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
        }
    }

    Titoletto { testo: Lingua.t("Quello che gli serve"); spiega: Lingua.t("Driver, firmware e programmi scelti per questo hardware, e solo per questo.") }
    Repeater {
        model: p.hw ? Object.keys(p.hw.pacchetti) : []
        Row {
            required property string modelData
            readonly property bool manca: p.hw.mancano.includes(modelData)
            spacing: 10
            Text { text: parent.manca ? "add_circle" : "check_circle"; font.family: Tema.icone; font.pixelSize: 18
                   color: parent.manca ? Tema.oro : "#7fe0a8" }
            Text { width: 200; text: modelData; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
            Text { width: p.width - 250; wrapMode: Text.Wrap; text: p.hw.pacchetti[modelData]; color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12 }
        }
    }
    Repeater {
        model: p.hw ? p.hw.note : []
        Text { required property string modelData; width: p.width; wrapMode: Text.Wrap; text: "⚠ " + modelData
               color: "#ffb347"; font.family: Tema.font; font.pixelSize: 12 }
    }
    Row {
        spacing: 10
        Chip {
            visible: p.hw && p.hw.mancano.length > 0
            testo: Lingua.t("Installa quello che manca (%1)", p.hw?.mancano.length ?? 0); icona: "download"; acceso: true
            onPremuto: Avvia.comando("cielos-hardware", [Tema.terminale || "foot", "-e", "sh", "-c",
                                     "sudo cielos-hardware installa; echo; read -p '" + Lingua.t("Fatto. Invio per chiudere ") + "' x"])
        }
        Text {
            visible: p.hw && p.hw.mancano.length === 0
            text: Lingua.t("C'è tutto quello che serve a questo PC."); color: "#7fe0a8"; font.family: Tema.font; font.pixelSize: 13
        }
    }
}
