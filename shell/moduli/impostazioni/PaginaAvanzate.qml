// Impostazioni → Avanzate: qualsiasi opzione di Hyprland, all'evenienza (es. decoration.rounding = 8,
// misc.vfr = true, cursor.no_hardware_cursors = true per qualche scheda video). Se Hyprland non la accetta,
// viene tolta e lo dice. E i file di configurazione, per chi vuole metterci le mani.
import QtQuick
import Quickshell
import qs.servizi

Column {
    id: p
    width: parent ? parent.width : 500
    spacing: 10
    readonly property var av: Impostati.stato?.scelte?.avanzate ?? ({})
    readonly property string conf: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/cielos/"
    function apri(f) {
        Avvia.comando("editor", ["sh", "-c", 'kate "$1" 2>/dev/null || code "$1" 2>/dev/null || ' + (Tema.terminale || "foot") + ' -e nano "$1"', "_", f]);
    }

    Titoletto { testo: "Opzioni di Hyprland"
                spiega: "Tutte quelle della documentazione di Hyprland (wiki.hyprland.org, Configuring → Variables): scrivi sezione.nome e il valore. Valgono subito." }
    Repeater {
        model: Object.keys(p.av)
        Rectangle {
            required property string modelData
            width: p.width; height: 38; radius: 10
            color: Qt.rgba(1, 1, 1, 0.04)
            Text { x: 14; anchors.verticalCenter: parent.verticalCenter; text: modelData + " = " + JSON.stringify(p.av[modelData])
                   color: Tema.testo; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
            Text { anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                   text: "close"; font.family: Tema.icone; font.pixelSize: 18; color: Tema.tenue
                   MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor
                               onClicked: Impostati.fai(["avanzata", modelData]) } }
        }
    }
    Row {
        spacing: 8
        Rectangle {
            width: 260; height: 34; radius: 17; color: Qt.rgba(1, 1, 1, 0.05); border.color: chiave.activeFocus ? Tema.oro : Tema.bordo
            TextInput { id: chiave; anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        verticalAlignment: TextInput.AlignVCenter
                        color: Tema.testo; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; clip: true; selectByMouse: true
                        KeyNavigation.tab: valore
                        Text { visible: !parent.text; anchors.verticalCenter: parent.verticalCenter; text: "decoration.rounding"; color: Tema.tenue; font: parent.font } }
        }
        Rectangle {
            width: 160; height: 34; radius: 17; color: Qt.rgba(1, 1, 1, 0.05); border.color: valore.activeFocus ? Tema.oro : Tema.bordo
            TextInput { id: valore; anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        verticalAlignment: TextInput.AlignVCenter
                        color: Tema.testo; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; clip: true; selectByMouse: true
                        onAccepted: aggiungi.premi()
                        Text { visible: !parent.text; anchors.verticalCenter: parent.verticalCenter; text: "8"; color: Tema.tenue; font: parent.font } }
        }
        Chip {
            id: aggiungi
            testo: "Applica"; icona: "check"
            function premi() { if (chiave.text.trim()) { Impostati.fai(["avanzata", chiave.text.trim(), valore.text.trim()]); chiave.text = ""; valore.text = ""; } }
            onPremuto: premi()
        }
    }

    Titoletto { testo: "File di configurazione"; spiega: "Le tue aggiunte a mano vanno in hypr-mio.lua: CielOS non lo tocca mai." }
    Flow {
        width: parent.width; spacing: 8
        Chip { testo: "hypr-mio.lua"; icona: "edit"; onPremuto: p.apri(p.conf + "hypr-mio.lua") }
        Chip { testo: "cielos.json (aspetto)"; icona: "edit"; onPremuto: p.apri(p.conf + "cielos.json") }
        Chip { testo: "sistema.json (schermi, input)"; icona: "edit"; onPremuto: p.apri(p.conf + "sistema.json") }
        Chip { testo: "Ricarica Hyprland"; icona: "refresh"; onPremuto: Avvia.comando("hyprctl", ["hyprctl", "reload"]) }
    }
}
