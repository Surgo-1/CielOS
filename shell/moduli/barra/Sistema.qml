// Come sta il PC: CPU, RAM, scheda video e temperature. Legge solo mentre la schedina è aperta (ogni 2 s):
// a schedina chiusa non costa niente.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.servizi

Icona {
    id: si
    nome: "monitor_heart"
    onPremuto: scheda.alterna()

    property var prima: null             // l'ultima lettura di /proc/stat, per la percentuale della CPU
    property real cpu: 0
    property real ram: 0; property real ramTot: 0
    property real gpu: 0; property real vram: 0; property real vramTot: 0
    property real tCpu: 0; property real tGpu: 0
    property bool conGpu: false

    Timer {
        running: scheda.aperta
        triggeredOnStart: true
        interval: 2000; repeat: true
        onTriggered: if (!leggi.running) leggi.running = true
    }
    Process {
        id: leggi
        command: ["sh", "-c",
            "head -1 /proc/stat; awk '/MemTotal|MemAvailable/{print $1, $2}' /proc/meminfo; " +
            "for h in /sys/class/hwmon/hwmon*; do [ \"$(cat $h/name)\" = coretemp ] && echo tcpu $(cat $h/temp1_input); done; " +
            "command -v nvidia-smi >/dev/null && echo gpu $(nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits | head -1 | tr -d ' ' | tr , ' ')"]
        stdout: StdioCollector {
            onStreamFinished: {
                let tot = 0, mem = 0;
                for (const r of text.split("\n")) {
                    const p = r.trim().split(/\s+/);
                    if (p[0] === "cpu") {
                        const n = p.slice(1).map(Number);
                        const ora = { tot: n.reduce((a, b) => a + b, 0), ozio: n[3] + n[4] };
                        if (si.prima) si.cpu = 1 - (ora.ozio - si.prima.ozio) / Math.max(1, ora.tot - si.prima.tot);
                        si.prima = ora;
                    } else if (p[0] === "MemTotal:") tot = Number(p[1]);
                    else if (p[0] === "MemAvailable:") mem = Number(p[1]);
                    else if (p[0] === "tcpu") si.tCpu = Number(p[1]) / 1000;
                    else if (p[0] === "gpu" && p.length >= 5) {
                        si.conGpu = true;
                        si.gpu = Number(p[1]) / 100; si.vram = Number(p[2]); si.vramTot = Number(p[3]); si.tGpu = Number(p[4]);
                    }
                }
                if (tot) { si.ramTot = tot / 1048576; si.ram = (tot - mem) / 1048576; }
            }
        }
    }

    component Misura: Column {
        property string etichetta
        property string dettaglio
        property real quota: 0
        width: parent ? parent.width : 260
        spacing: 5
        Item {
            width: parent.width; height: 16
            Text { text: parent.parent.etichetta; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
            Text {
                anchors.right: parent.right
                text: parent.parent.dettaglio; color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
            }
        }
        Rectangle {
            width: parent.width; height: 6; radius: 3
            color: Qt.rgba(1, 1, 1, 0.1)
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, parent.parent.quota)); height: parent.height; radius: 3
                color: parent.parent.quota > 0.9 ? Tema.allarme : Tema.oro
                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            }
        }
    }

    Schedina {
        id: scheda
        icona: si
        titolo: "Sistema"
        larghezza: 290
        spaziatura: 12
        Misura {
            etichetta: "Processore"
            dettaglio: Math.round(si.cpu * 100) + "%" + (si.tCpu ? " · " + Math.round(si.tCpu) + " °C" : "")
            quota: si.cpu
        }
        Misura {
            etichetta: "Memoria"
            dettaglio: si.ram.toFixed(1) + " / " + si.ramTot.toFixed(0) + " GB"
            quota: si.ramTot ? si.ram / si.ramTot : 0
        }
        Misura {
            visible: si.conGpu
            etichetta: "Scheda video"
            dettaglio: Math.round(si.gpu * 100) + "% · " + Math.round(si.tGpu) + " °C"
            quota: si.gpu
        }
        Misura {
            visible: si.conGpu
            etichetta: "Memoria video"
            dettaglio: (si.vram / 1024).toFixed(1) + " / " + (si.vramTot / 1024).toFixed(1) + " GB"
            quota: si.vramTot ? si.vram / si.vramTot : 0
        }
    }
}
