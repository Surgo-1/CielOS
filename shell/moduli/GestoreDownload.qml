// Gestore download: interfaccia semplice per wget/paru integration
import QtQuick
import Quickshell

Item {
    id: gestore
    readonly property bool presente: download.in_corso
    
    property var download: ({
        "in_corso": false,
        "nome": "",
        "progresso": 0,
        "velocita": "0 B/s",
        "size": "0 B"
    })
    
    Timer {
        id: timerAggiorna
        interval: 1000
        repeat: true
        running: gestore.download.in_corso
        onTriggered: {
            // Aggiorna stato download (simulato - in produzione si leggerebbe da un processo)
            // Questo è un placeholder per l'integrazione reale
        }
    }
    
    function inizia(url) {
        // Avvia download con wget o aria2
        Quickshell.execDetached(["sh", "-c", "aria2c -x 8 -s 8 -j 1 '" + url + "'"])
        gestore.download.in_corso = true
        gestore.download.nome = url.split("/").pop()
    }
    
    function annulla() {
        // Annulla download
        Quickshell.execCmd("sh -c 'pkill aria2c'")
        gestore.download.in_corso = false
        gestore.download = {"in_corso": false, "nome": "", "progresso": 0, "velocita": "0 B/s", "size": "0 B"}
    }
}