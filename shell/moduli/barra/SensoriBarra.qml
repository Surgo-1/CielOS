// I sensori che hai scelto (Monitor di sistema → Sensori → «nella barra»): il loro valore sotto l'icona del
// sistema, aggiornato ogni 3 s leggendo direttamente il file del sensore (nessun programma in più); la scheda video
// NVIDIA, che non ha un file, la chiede a nvidia-smi solo se l'hai scelta. Nessun sensore scelto: niente.
// Il percorso di ogni sensore si ricalcola all'avvio (i numeri hwmonN possono cambiare a ogni accensione).
import QtQuick
import Quickshell
import Quickshell.Io
import qs.servizi

Grid {
    id: sb
    columns: Tema.orizzontale ? Math.max(1, scelti.length) : 1
    spacing: 4
    horizontalItemAlignment: Grid.AlignHCenter
    property var scelti: []              // [{id, nome, chip, tipo, unita, divisore}] da sensori.json
    property var percorsi: ({})          // id → file del sensore adesso
    property var valori: ({})            // id → valore
    readonly property bool conNvidia: scelti.some(s => s.id.startsWith("nvidia"))
    // l'icona dice a colpo d'occhio che cosa è quel numero: temperatura, ventola, consumo, tensione o corrente
    function icona(tipo) {
        return ({ temp: "thermostat", fan: "air", power: "bolt", in: "electric_bolt", curr: "electrical_services" })[tipo]
               ?? "sensors";
    }
    function valoreTesto(s, v) {
        return isNaN(v) ? "–" : s.tipo === "temp" ? Math.round(v) + "°"
             : s.tipo === "power" ? Math.round(v) + "W" : Math.round(v);
    }

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/cielos/sensori.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try { sb.scelti = JSON.parse(text()).barra ?? []; } catch (e) { sb.scelti = []; }
            if (sb.scelti.length && !trova.running) trova.running = true;
        }
        onLoadFailed: sb.scelti = []
    }
    Process {
        id: trova
        command: [Percorsi.bin("cielimposta"), "sensori"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const m = {}, v = {};
                    for (const s of JSON.parse(text).sensori) { m[s.id] = s.percorso; v[s.id] = s.valore; }
                    sb.percorsi = m; sb.valori = v;
                } catch (e) {}
            }
        }
    }
    Process {
        id: nvidia
        command: ["nvidia-smi", "--query-gpu=temperature.gpu,power.draw", "--format=csv,noheader,nounits"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split("\n")[0]?.split(",").map(x => parseFloat(x));
                if (!p) return;
                const v = Object.assign({}, sb.valori);
                v["nvidia0/GPU"] = p[0]; v["nvidia0/consumo"] = p[1];
                sb.valori = v;
            }
        }
    }
    // la temperatura della scheda video: nvidia-smi sveglia il driver a ogni domanda, quindi si chiede ogni 15 s
    // (un numero nella barra non ha bisogno del secondo; i file dei sensori sotto restano ogni 3 s, sono gratis)
    Timer {
        running: sb.scelti.length > 0 && sb.conNvidia
        interval: 15000; repeat: true
        onTriggered: if (!nvidia.running) nvidia.running = true
    }

    Repeater {
        model: sb.scelti
        Item {
            id: voce
            required property var modelData
            readonly property string file: sb.percorsi[modelData.id] ?? ""
            property real valore: sb.valori[modelData.id] ?? NaN
            readonly property bool sopra: area.hovered
            readonly property color colore: modelData.tipo === "temp" && valore >= 85 ? Tema.allarme
                                         : modelData.tipo === "temp" && valore >= 70 ? "#ffb347" : Tema.tenue
            width: riga.implicitWidth + 4; height: riga.implicitHeight
            HoverHandler { id: area }
            FileView {
                id: f
                path: voce.file
                printErrors: false
                onLoaded: { const n = parseFloat(text()); if (!isNaN(n)) voce.valore = n / (voce.modelData.divisore || 1); }
            }
            Timer { running: voce.file !== ""; interval: 3000; repeat: true; onTriggered: f.reload() }
            Row {
                id: riga
                anchors.centerIn: parent
                spacing: 3
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: sb.icona(voce.modelData.tipo)
                    color: voce.colore; opacity: 0.8
                    font.family: Tema.icone; font.pixelSize: 13
                }
                Text {
                    id: testo
                    anchors.verticalCenter: parent.verticalCenter
                    text: sb.valoreTesto(voce.modelData, voce.valore)
                    color: voce.colore
                    font.family: Tema.font; font.pixelSize: 11; font.weight: Font.Medium
                }
            }
            // sopra il numero: il nome completo, così non serve indovinare a cosa si riferisce
            Schedina {
                icona: voce
                titolo: voce.modelData.chip
                larghezza: 250
                Text {
                    width: 220; wrapMode: Text.Wrap
                    text: voce.modelData.nome
                    color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.Medium
                }
                Text {
                    text: sb.valoreTesto(voce.modelData, voce.valore) +
                          (voce.modelData.unita && voce.modelData.tipo !== "temp" && voce.modelData.tipo !== "power"
                           ? " " + voce.modelData.unita : "")
                    color: Tema.oro; font.family: Tema.font; font.pixelSize: 20
                }
            }
        }
    }
}
