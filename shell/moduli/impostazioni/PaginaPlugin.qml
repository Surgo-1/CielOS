// Impostazioni → Plugin: il catalogo di cielplugin (giochi, sviluppo, web app, programmi da terminale, servizi,
// comunicazione, grafica, ufficio, sistema). «Installa» e «Togli» aprono un terminale: vedi cosa succede e la
// password la scrivi tu. In fondo: una web app tua (un sito in una finestra sola, nel menu delle app).
import QtQuick
import Quickshell
import Quickshell.Io
import qs.servizi

Column {
    id: p
    width: parent ? parent.width : 500
    spacing: 10
    property var dati: null
    property string categoria: ""
    property string filtro: ""
    Process {
        id: leggi
        running: true
        command: [Percorsi.bin("cielplugin"), "elenco", "--json"]
        stdout: StdioCollector { onStreamFinished: { try { p.dati = JSON.parse(text); } catch (e) {} } }
    }
    // dopo un'installazione (nel terminale) l'elenco si rilegge da solo
    Timer { running: p.visible; interval: 6000; repeat: true; onTriggered: if (!leggi.running) leggi.running = true }
    function fai(cmd, id) { Avvia.comando("cielplugin", [Percorsi.bin("cielplugin"), cmd, id]); }
    readonly property var visibili: (dati?.plugin ?? []).filter(x => (!categoria || x.categoria === categoria) &&
        (!filtro || (x.nome + " " + x.descrizione).toLowerCase().includes(filtro.toLowerCase())))

    Text {
        width: parent.width; wrapMode: Text.Wrap
        text: "Programmi e servizi pronti, dai repository ufficiali di Arch (solo quello che serve, controllato prima). L'installazione si apre in un terminale."
        color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
    }
    Rectangle {
        width: parent.width; height: 36; radius: 18; color: Qt.rgba(1, 1, 1, 0.05); border.color: cerca.activeFocus ? Tema.oro : Tema.bordo
        Text { id: lente; x: 12; anchors.verticalCenter: parent.verticalCenter; text: "search"; font.family: Tema.icone; font.pixelSize: 18; color: Tema.tenue }
        TextInput {
            id: cerca
            anchors { left: lente.right; leftMargin: 8; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            color: Tema.testo; font.family: Tema.font; font.pixelSize: 13; clip: true; selectByMouse: true
            onTextChanged: p.filtro = text
            Text { visible: !parent.text; text: "Cerca un plugin (steam, docker, whatsapp…)"; color: Tema.tenue; font: parent.font }
        }
    }
    Flow {
        width: parent.width; spacing: 6
        Chip { testo: "tutti"; acceso: p.categoria === ""; onPremuto: p.categoria = "" }
        Repeater {
            model: p.dati ? Object.keys(p.dati.categorie) : []
            Chip { required property string modelData; testo: p.dati.categorie[modelData][1]; icona: p.dati.categorie[modelData][0]
                   acceso: p.categoria === modelData; onPremuto: p.categoria = modelData }
        }
    }
    Text { visible: !p.dati; text: "Leggo il catalogo…"; color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13 }
    Repeater {
        model: p.visibili
        Rectangle {
            required property var modelData
            width: p.width; height: col.implicitHeight + 20; radius: Tema.raggio
            color: modelData.installato ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.07) : Qt.rgba(1, 1, 1, 0.03)
            border.color: modelData.installato ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.35) : Tema.bordo
            Column {
                id: col
                x: 14; y: 10; width: parent.width - 150; spacing: 3
                Row {
                    spacing: 8
                    Text { text: p.dati.categorie[modelData.categoria]?.[0] ?? "extension"; font.family: Tema.icone; font.pixelSize: 18; color: Tema.oroChiaro }
                    Text { text: modelData.nome; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.Medium }
                    Text { visible: modelData.installato; text: "installato"; color: "#7fe0a8"; font.family: Tema.font; font.pixelSize: 11
                           anchors.verticalCenter: parent.verticalCenter }
                    Text { visible: modelData.rischio === true; text: "fuori dai repository di Arch"; color: "#ffb347"; font.family: Tema.font; font.pixelSize: 11
                           anchors.verticalCenter: parent.verticalCenter }
                }
                Text { width: parent.width; wrapMode: Text.Wrap; text: modelData.descrizione; color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12 }
                Text { visible: (modelData.pacchetti ?? []).length > 0; width: parent.width; wrapMode: Text.Wrap
                       text: "Pacchetti: " + (modelData.pacchetti ?? []).join(", "); color: Qt.rgba(Tema.tenue.r, Tema.tenue.g, Tema.tenue.b, 0.7)
                       font.family: Tema.font; font.pixelSize: 11 }
            }
            Chip {
                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                testo: modelData.installato ? "Togli" : "Installa"
                icona: modelData.installato ? "delete" : "download"
                acceso: !modelData.installato
                onPremuto: p.fai(modelData.installato ? "togli" : "installa", modelData.id)
            }
        }
    }

    Titoletto { testo: "Una web app tua"; spiega: "Un sito in una finestra sola, con il suo nome e la sua icona nel menu delle app (es. Trello, Canva, il registro elettronico)." }
    Row {
        spacing: 8
        Rectangle {
            width: 180; height: 34; radius: 17; color: Qt.rgba(1, 1, 1, 0.05); border.color: nomeW.activeFocus ? Tema.oro : Tema.bordo
            TextInput { id: nomeW; anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        verticalAlignment: TextInput.AlignVCenter; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13; clip: true
                        KeyNavigation.tab: urlW
                        Text { visible: !parent.text; anchors.verticalCenter: parent.verticalCenter; text: "Nome"; color: Tema.tenue; font: parent.font } }
        }
        Rectangle {
            width: 280; height: 34; radius: 17; color: Qt.rgba(1, 1, 1, 0.05); border.color: urlW.activeFocus ? Tema.oro : Tema.bordo
            TextInput { id: urlW; anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        verticalAlignment: TextInput.AlignVCenter; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13; clip: true
                        Text { visible: !parent.text; anchors.verticalCenter: parent.verticalCenter; text: "https://…"; color: Tema.tenue; font: parent.font } }
        }
        Chip {
            testo: "Crea"; icona: "add"
            onPremuto: {
                let u = urlW.text.trim();
                if (!nomeW.text.trim() || !u) return;
                if (!/^https?:\/\//.test(u)) u = "https://" + u;
                Quickshell.execDetached([Percorsi.bin("cielplugin"), "webapp", nomeW.text.trim(), u]);
                nomeW.text = ""; urlW.text = "";
            }
        }
    }
    Repeater {
        model: p.dati ? Object.keys(p.dati.webapp ?? {}) : []
        Text { required property string modelData; text: "• " + p.dati.webapp[modelData].nome + " — " + p.dati.webapp[modelData].url
               color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12 }
    }
    Titoletto { testo: "Hook"; spiega: "Come in Omarchy: i tuoi script in ~/.config/cielos/hooks/tema, …/accesso, …/plugin partono da soli in quei momenti. Per tutto il resto (giochi, chiavette, rete, aggiornamenti) ci sono le Automazioni." }
}
