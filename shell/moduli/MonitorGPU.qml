// Monitor GPU avanzato: utilizzo, temperatura, VRAM in tempo reale
import QtQuick
import Quickshell
import qs.servizi

Item {
    id: monitor
    property int gpuUtilizzo: 0
    property int gpuMemoria: 0
    property int gpuMemoriaTotale: 4096
    property int gpuTemperatura: 40000
    property int gpuFrequenza: 0
    readonly property bool presente: gpuUtilizzo > 0 || gpuMemoria > 0
    
    Timer {
        id: timerGpu
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            // Utilizzo GPU
            Quickshell.execDetached("cat /sys/class/drm/card0/device/gpu_busy_percent 2>/dev/null || echo 0")
            
            // VRAM usata (NVIDIA)
            Quickshell.execDetached("nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null || echo 0")
            
            // VRAM totale (NVIDIA)
            Quickshell.execDetached("nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null || echo 4096")
            
            // Temperatura (milligradi)
            Quickshell.execDetached("cat /sys/class/drm/card0/device/hwmon/hwmon0/temp1_input 2>/dev/null | head -1 || echo 40000")
            
            // Frequenza
            Quickshell.execDetached("cat /sys/class/drm/card0/device/pp_od_clk_voltage 2>/dev/null | head -1 || echo 0")
        }
    }
    
    Column {
        anchors.fill: parent
        spacing: 4
        
        Text {
            text: "GPU"
            font.pixelSize: 11
            color: Tema.tenue
            opacity: 0.7
        }
        
        // Barra di utilizzo
        Rectangle {
            width: parent.width
            height: 4
            color: Tema.fondo
            radius: 2
            
            Rectangle {
                id: barraUtilizzo
                width: parent.width * (gpuUtilizzo / 100)
                height: parent.height
                radius: 2
                color: gpuUtilizzo > 80 ? Tema.allarme : (gpuUtilizzo > 60 ? Tema.oro : Tema.primario)
                
                NumberAnimation on width {
                    running: true
                    from: 0
                    to: parent.width * (gpuUtilizzo / 100)
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }
        }
        
        // Statistiche in una riga
        Row {
            spacing: 8
            
            Text {
                text: gpuUtilizzo + "%"
                font.pixelSize: 10
                color: gpuUtilizzo > 80 ? Tema.allarme : Tema.testo
            }
            
            Text {
                text: "🗂 " + gpuMemoria + "/" + gpuMemoriaTotale + " MB"
                font.pixelSize: 9
                color: gpuMemoria > gpuMemoriaTotale * 0.8 ? Tema.allarme : Tema.tenue
            }
            
            Text {
                text: "🌡 " + (gpuTemperatura / 1000).toFixed(1) + "°C"
                font.pixelSize: 9
                color: gpuTemperatura > 75000 ? Tema.allarme : (gpuTemperatura > 65000 ? Tema.oro : Tema.tenue)
            }
        }
    }
}