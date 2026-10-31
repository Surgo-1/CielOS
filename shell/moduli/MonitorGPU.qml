// Monitor GPU avanzato: utilizzo, temperatura, VRAM in tempo reale
import QtQuick
import Quickshell
import Quickshell.Wayland

Item {
    id: monitor
    readonly property bool presente: GPU.perso || GPU.utilizzo > 0
    
    // Dati GPU dal sistema (via cield o comandi diretti)
    PropertyVariant {
        id: GPU
        target: Quickshell.bind({
            "utilizzo": Quickshell.execQuery("bash", "-c", "cat /sys/class/drm/card0/device/gpu_busy_percent 2>/dev/null || echo 0"),
            "memoria": Quickshell.execQuery("bash", "-c", "nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null || echo 0"),
            "memoriaTotale": Quickshell.execQuery("bash", "-c", "nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null || echo 4096"),
            "temperatura": Quickshell.execQuery("bash", "-c", "cat /sys/class/drm/card0/device/hwmon/hwmon0/temp1_input 2>/dev/null | head -1 || echo 40000"),
            "frequenza": Quickshell.execQuery("bash", "-c", "cat /sys/class/drm/card0/device/pp_od_clk_voltage 2>/dev/null | head -1 || echo 0"),
        })
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
                width: parent.width * (parseInt(GPU.utilizzo) / 100)
                height: parent.height
                radius: 2
                color: GPU.utilizzo > 80 ? Tema.allarme : (GPU.utilizzo > 60 ? Tema.oro : Tema.primario)
                
                NumberAnimation on width {
                    running: true
                    from: 0
                    to: parent.width * (parseInt(GPU.utilizzo) / 100)
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }
        }
        
        // Statistiche in una riga
        Row {
            spacing: 8
            
            Text {
                text: parseInt(GPU.utilizzo) + "%"
                font.pixelSize: 10
                color: GPU.utilizzo > 80 ? Tema.allarme : Tema.testo
            }
            
            Text {
                text: "🗂 " + parseInt(GPU.memoria) + "/" + parseInt(GPU.memoriaTotale) + " MB"
                font.pixelSize: 9
                color: GPU.memoria > parseInt(GPU.memoriaTotale) * 0.8 ? Tema.allarme : Tema.tenue
            }
            
            Text {
                text: "🌡 " + parseInt(GPU.temperatura) / 1000 + "°C"
                font.pixelSize: 9
                color: parseInt(GPU.temperatura) > 75000 ? Tema.allarme : (parseInt(GPU.temperatura) > 65000 ? Tema.oro : Tema.tenue)
            }
        }
    }
}