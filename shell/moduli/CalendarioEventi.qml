// Calendario Eventi: appuntamenti, promemoria, integrazione caldav/ical
import QtQuick
import Quickshell

Item {
    id: calendario
    readonly property bool presente: eventi.length > 0
    
    property var eventi: []
    property bool expanded: false
    
    Timer {
        id: timerAggiorna
        interval: 60000  // Aggiorna ogni minuto
        repeat: true
        running: true
        onTriggered: aggiornaEventi()
    }
    
    function aggiornaEventi() {
        // Legge da file ics locale o caldav
        let output = Quickshell.execCmd("calcurse -a -n 10 2>/dev/null || khal list now 7days 2>/dev/null || echo ''")
        if (output && output.trim()) {
            eventi = output.trim().split("\n").map(function(line) {
                let parts = line.split("::")
                return {
                    titolo: parts[0] || line,
                    ora: parts[1] || "",
                    data: parts[2] || ""
                }
            })
        } else {
            // Fallback: eventi demo o vuoto
            eventi = []
        }
    }
    
    Component.onCompleted: aggiornaEventi()
    
    Column {
        anchors.fill: parent
        spacing: 4
        
        Row {
            spacing: 8
            Text {
                text: "📅"
                font.pixelSize: 14
            }
            Text {
                text: Qt.formatDate(new Date(), "dddd dd MMMM")
                font.pixelSize: 11
                color: Tema.testo
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: expanded = !expanded
            }
        }
        
        Column {
            visible: expanded && eventi.length > 0
            spacing: 2
            
            Repeater {
                model: eventi
                delegate: Row {
                    spacing: 6
                    Text {
                        text: modelData.ora
                        font.pixelSize: 10
                        color: Tema.tenue
                    }
                    Text {
                        text: modelData.titolo
                        font.pixelSize: 10
                        color: Tema.testo
                        elide: Text.ElideRight
                        width: 200
                    }
                }
            }
        }
        
        // Evento imminente (sempre visibile se presente)
        Item {
            visible: !expanded && eventi.length > 0
            Row {
                spacing: 6
                Text {
                    text: eventi[0].ora
                    font.pixelSize: 10
                    color: Tema.primario
                }
                Text {
                    text: eventi[0].titolo
                    font.pixelSize: 10
                    color: Tema.testo
                    elide: Text.ElideRight
                    width: 180
                }
            }
        }
    }
}