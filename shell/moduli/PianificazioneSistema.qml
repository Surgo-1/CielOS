// Pianificazione sistema: spegni/riavvia a orario
import QtQuick
import Quickshell

Item {
    id: pianificazione
    readonly property bool presente: timerAttivo
    
    property bool timerAttivo: false
    property string azione: ""  // "riavvio", "spegni", "sospendi"
    property string ora: ""
    property int minuti: 0
    
    function pianifica(azione, ore, minuti) {
        timerAttivo = true
        this.azione = azione
        this.minuti = minuti
        
        let comando = ""
        switch(azione) {
            case "riavvio":
                comando = "systemctl reboot"
                break
            case "spegni":
                comando = "systemctl poweroff"
                break
            case "sospendi":
                comando = "systemctl suspend"
                break
        }
        
        // Usa at per pianificare
        let orario = (ores * 60 + minuti).toString() + " minute"
        Quickshell.execCmd("echo '" + comando + "' | at now + " + orario + " 2>/dev/null")
        
        return true
    }
    
    function annulla() {
        Quickshell.execCmd("atq | awk '{print $1}' | xargs -r atrm 2>/dev/null")
        timerAttivo = false
        azione = ""
        minuti = 0
        return true
    }
}