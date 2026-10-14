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
    readonly property var nomi: ({ "power-saver": "risparmio", "balanced": "bilanciato", "performance": "prestazioni" })

    Titoletto { testo: "Energia"; spiega: "«Risparmio» abbassa i consumi (e il rumore); «Prestazioni» spinge il processore al massimo, utile nei giochi." }
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
               text: "Batteria " + modelData.nome + ": " + modelData.carica + "% (" + ({ Charging: "in carica", Discharging: "si scarica", Full: "carica", "Not charging": "ferma" }[modelData.stato] ?? modelData.stato) + ")"
               color: Tema.testo; font.family: Tema.font; font.pixelSize: 14 }
    }

    Titoletto { testo: "Data e ora" }
    Tendina {
        width: parent.width
        testo: "Fuso orario"
        voci: p.fusi
        valore: p.o.fuso ?? ""
        onScelto: v => Impostati.fai(["ora", "fuso", v])
    }
    Interruttore {
        width: parent.width
        testo: "Ora presa da Internet"
        spiega: p.o.sincronizzata ? "Sincronizzata." : "Non ancora sincronizzata."
        acceso: p.o.ntp ?? false
        onCambiato: v => Impostati.fai(["ora", "ntp", v ? "1" : "0"])
    }
}
