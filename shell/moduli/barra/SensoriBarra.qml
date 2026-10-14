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
    Timer {
        running: sb.scelti.length > 0
        interval: 3000; repeat: true
        onTriggered: if (sb.conNvidia && !nvidia.running) nvidia.running = true
    }

    Repeater {
        model: sb.scelti
        Item {
            id: voce
            required property var modelData
            readonly property string file: sb.percorsi[modelData.id] ?? ""
            property real valore: sb.valori[modelData.id] ?? NaN
            width: testo.implicitWidth + 4; height: testo.implicitHeight
            FileView {
                id: f
                path: voce.file
                printErrors: false
                onLoaded: { const n = parseFloat(text()); if (!isNaN(n)) voce.valore = n / (voce.modelData.divisore || 1); }
            }
            Timer { running: voce.file !== ""; interval: 3000; repeat: true; onTriggered: f.reload() }
            Text {
                id: testo
                anchors.centerIn: parent
                text: isNaN(voce.valore) ? "–" : voce.modelData.tipo === "temp" ? Math.round(voce.valore) + "°"
                      : voce.modelData.tipo === "power" ? Math.round(voce.valore) + "W" : Math.round(voce.valore)
                color: voce.modelData.tipo === "temp" && voce.valore >= 85 ? Tema.allarme
                     : voce.modelData.tipo === "temp" && voce.valore >= 70 ? "#ffb347" : Tema.tenue
                font.family: Tema.font; font.pixelSize: 11; font.weight: Font.Medium
            }
        }
    }
}
