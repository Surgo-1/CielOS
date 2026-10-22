// Impostazioni → Energia e ora: il profilo di energia (risparmio, bilanciato, prestazioni), la batteria, il fuso
// orario e l'ora presa da Internet. Cambiare l'ora del sistema chiede la password (come sempre).
import QtQuick
import Quickshell
import Quickshell.Io
import qs.servizi

Column {
    id: p
    width: parent ? parent.width : 500
    spacing: 12
    readonly property var e: Impostati.stato?.energia ?? ({ profili: [], batterie: [] })
    readonly property var o: Impostati.stato?.ora ?? ({})
    property var fusi: []
    Process {
        running: true
        command: ["timedatectl", "list-timezones"]
        stdout: StdioCollector { onStreamFinished: p.fusi = text.trim().split("\n").map(z => ({ testo: z.replace(/_/g, " "), valore: z })) }
    }
    readonly property var nomi: ({ "power-saver": Lingua.t("risparmio"), "balanced": Lingua.t("bilanciato"), "performance": Lingua.t("prestazioni") })

    Titoletto { testo: Lingua.t("Energia"); spiega: Lingua.t("«Risparmio» abbassa i consumi (e il rumore); «Prestazioni» spinge il processore al massimo, utile nei giochi.") }
    Row {
        spacing: 6
        Repeater {
            model: p.e.profili
            Chip { required property string modelData; testo: p.nomi[modelData] ?? modelData; acceso: p.e.profilo === modelData
                   onPremuto: Impostati.fai(["energia", modelData]) }
        }
    }
    Repeater {
        model: p.e.batterie
        Text { required property var modelData
               text: Lingua.t("Batteria %1: %2% (%3)", modelData.nome, modelData.carica, { Charging: Lingua.t("in carica"), Discharging: Lingua.t("si scarica"), Full: Lingua.t("carica"), "Not charging": Lingua.t("ferma") }[modelData.stato] ?? modelData.stato)
               color: Tema.testo; font.family: Tema.font; font.pixelSize: 14 }
    }
    Text {
        visible: p.e.batterie.length > 0
        width: parent.width
        wrapMode: Text.WordWrap
        text: Lingua.t("A batteria CielOS passa da solo al profilo «risparmio»; ricollegando l'alimentatore rimette quello di prima, senza sovrascrivere una scelta fatta da te.")
        color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
    }

    Titoletto { testo: Lingua.t("Data e ora") }
    Tendina {
        width: parent.width
        testo: Lingua.t("Fuso orario")
        voci: p.fusi
        valore: p.o.fuso ?? ""
        onScelto: v => Impostati.fai(["ora", "fuso", v])
    }
    Interruttore {
        width: parent.width
        testo: Lingua.t("Ora presa da Internet")
        spiega: p.o.sincronizzata ? Lingua.t("Sincronizzata.") : Lingua.t("Non ancora sincronizzata.")
        acceso: p.o.ntp ?? false
        onCambiato: v => Impostati.fai(["ora", "ntp", v ? "1" : "0"])
    }
}
