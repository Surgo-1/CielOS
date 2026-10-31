// Statistiche Rete in tempo reale: download/upload speed, IP, ping
import QtQuick
import Quickshell

Item {
    id: rete
    readonly property bool presente: speedDownload > 0 || speedUpload > 0
    
    property real speedDownload: 0  // KB/s
    property real speedUpload: 0    // KB/s
    property string ipLocale: ""
    property string pingMs: "0"
    
    Timer {
        id: timerRete
        interval: 1000  // Aggiorna ogni secondo
        repeat: true
        running: true
        property real rxPrev: 0
        property real txPrev: 0
        
        onTriggered: {
            // Legge i dati di rete da /proc/net/dev
            let output = Quickshell.execCmd("cat /proc/net/dev | grep -v 'lo:' | grep ':' | head -1 | awk '{print $2, $10}'")
            if (output) {
                let parts = output.trim().split(/\s+/)
                if (parts.length >= 2) {
                    let rxCurr = parseFloat(parts[0]) / 1024
                    let txCurr = parseFloat(parts[1]) / 1024
                    
                    if (rxPrev > 0) {
                        speedDownload = Math.max(0, rxCurr - rxPrev)
                        speedUpload = Math.max(0, txCurr - txPrev)
                    }
                    rxPrev = rxCurr
                    txPrev = txCurr
                }
            }
        }
    }
    
    Timer {
        id: timerInfoRete
        interval: 30000  // IP e Ping ogni 30s
        repeat: true
        running: true
        onTriggered: {
            ipLocale = Quickshell.execCmd("ip route get 1.1.1.1 2>/dev/null | awk '{print $7}'").trim()
            let pingOut = Quickshell.execCmd("ping -c 1 -W 1 1.1.1.1 2>/dev/null | grep 'time=' | awk -F'time=' '{print $2}' | cut -d' ' -f1")
            pingMs = pingOut ? pingOut.trim() : "N/A"
        }
    }
    
    Component.onCompleted: {
        ipLocale = Quickshell.execCmd("ip route get 1.1.1.1 2>/dev/null | awk '{print $7}'").trim()
    }
    
    Row {
        anchors.centerIn: parent
        spacing: 8
        
        // Icona di rete con stato
        Text {
            text: speedDownload > 1000 ? "⚡" : (speedDownload > 100 ? "🌐" : "📶")
            font.pixelSize: 12
        }
        
        // Speed Download
        Row {
            spacing: 2
            Text {
                text: "⬇"
                font.pixelSize: 9
                color: Tema.primario
            }
            Text {
                text: formatSpeed(speedDownload)
                font.pixelSize: 10
                color: Tema.testo
            }
        }
        
        // Speed Upload
        Row {
            spacing: 2
            Text {
                text: "⬆"
                font.pixelSize: 9
                color: Tema.oro
            }
            Text {
                text: formatSpeed(speedUpload)
                font.pixelSize: 10
                color: Tema.testo
            }
        }
        
        // Ping
        Text {
            text: pingMs !== "N/A" ? pingMs + "ms" : ""
            font.pixelSize: 9
            color: parseFloat(pingMs) < 50 ? Tema.primario : (parseFloat(pingMs) < 100 ? Tema.oro : Tema.allarme)
        }
    }
    
    function formatSpeed(speedKb) {
        if (speedKb > 1024) {
            return (speedKb / 1024).toFixed(1) + " MB/s"
        }
        return Math.round(speedKb) + " KB/s"
    }
}