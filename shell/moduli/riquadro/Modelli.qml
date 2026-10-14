// I miei modelli: quelli scaricati (in Ollama), con gli scaricamenti in corso in cima. Per ognuno: quanto occupa,
// se è in memoria adesso (e quanta scheda video usa), la stima per questo PC, chi lo usa. Si può spegnere (nessuno lo
// usa e lascia la memoria), riaccendere, togliere dalla memoria, eliminare (due clic). Quelli che usa Ciel hanno il
// lucchetto: per spegnerli o eliminarli prima si cambia il modello nelle impostazioni di Ciel.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.servizi

Item {
    id: mo
    property var scaricamenti: []
    property bool attiva: false                   // la pagina è aperta: si rilegge ogni 5 s
    readonly property string motore: Quickshell.env("HOME") + "/cielos/bin/cielmodelli"
    property var modelli: []
    property string hw: ""
    property real libero: 0
    property bool ollama: true
    property string motoreMsg: ""                  // Ollama manca, è spento o senza la libreria della scheda video
    property bool letto: false
    property string avviso: ""
    property string daEliminare: ""               // primo clic su «Elimina»: chiede conferma per 4 s

    function leggi() { if (!leggiP.running) leggiP.running = true; }
    function fai(...args) {
        azione.command = [motore, ...args, "--json"];
        azione.running = true;
    }
    function breve(n) { return n.replace(/^hf\.co\//, ""); }
    function gb(x) { return (x ?? 0).toFixed(1).replace(".", ",") + " GB"; }
    onAttivaChanged: if (attiva) leggi()

    Process {
        id: leggiP
        command: [mo.motore, "installati", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    mo.modelli = r.modelli; mo.hw = r.hardware; mo.libero = r.libero_gb; mo.ollama = r.ollama;
                    mo.motoreMsg = r.motore?.messaggio ?? "";
                } catch (e) {}
                mo.letto = true;
            }
        }
    }
    Process {
        id: azione
        stdout: StdioCollector {
            onStreamFinished: { try { const r = JSON.parse(text); mo.avviso = r.ok === false ? (r.messaggio ?? "") : ""; } catch (e) {} }
        }
        onExited: mo.leggi()
    }
    Timer { interval: 5000; repeat: true; running: mo.attiva; onTriggered: mo.leggi() }
    Timer { id: scadenza; interval: 4000; onTriggered: mo.daEliminare = "" }
    // quando uno scaricamento finisce, l'elenco si aggiorna
    property int finiti: scaricamenti.filter(d => d.stato === "fatto").length
    onFinitiChanged: leggi()

    Column {
        anchors.fill: parent
        spacing: 10

        Column {                                       // scaricamenti in corso
            width: parent.width
            spacing: 8
            visible: mo.scaricamenti.some(d => d.stato === "in corso")
            Text { text: "In arrivo"; color: Tema.oro; font.family: Tema.font; font.pixelSize: 12; font.letterSpacing: 2; font.capitalization: Font.AllUppercase }
            Repeater {
                model: mo.scaricamenti.filter(d => d.stato === "in corso")
                Avanzamento { required property var modelData; width: parent.width; d: modelData; conNome: true }
            }
        }

        Text {
            width: parent.width; wrapMode: Text.WordWrap
            visible: text !== ""
            text: mo.avviso !== "" ? mo.avviso : mo.motoreMsg !== "" ? mo.motoreMsg
                  : !mo.ollama && mo.letto ? "Ollama è spento: i modelli ci sono, ma non posso dire quali sono in memoria." : ""
            color: Tema.allarme; font.family: Tema.font; font.pixelSize: 13
        }

        ListView {
            id: lista
            width: parent.width
            height: parent.height - y - piede.height - 10
            clip: true; spacing: 6
            boundsBehavior: Flickable.StopAtBounds
            model: mo.modelli
            delegate: Rectangle {
                id: riga
                required property var modelData
                width: lista.width; height: 66; radius: Tema.raggio
                color: Qt.rgba(1, 1, 1, modelData.acceso ? 0.035 : 0.015)
                opacity: modelData.acceso ? 1 : 0.6
                Behavior on opacity { NumberAnimation { duration: Tema.durata } }

                Column {
                    anchors { left: parent.left; leftMargin: 14; right: azioni.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    spacing: 4
                    Row {
                        width: parent.width; spacing: 8
                        Rectangle {                    // in memoria adesso
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8; height: 8; radius: 4
                            color: riga.modelData.in_memoria ? Tema.oro : "transparent"
                            border.color: riga.modelData.in_memoria ? Tema.oro : Tema.tenue
                        }
                        Text {
                            width: Math.min(implicitWidth, parent.width - 120); elide: Text.ElideMiddle
                            text: mo.breve(riga.modelData.nome); color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.Medium
                        }
                        Text {
                            visible: riga.modelData.di_ciel
                            anchors.verticalCenter: parent.verticalCenter
                            text: "lock"; font.family: Tema.icone; font.pixelSize: 14; color: Tema.oroChiaro
                        }
                        Text {
                            visible: riga.modelData.di_ciel
                            anchors.verticalCenter: parent.verticalCenter
                            text: "lo usa Ciel"; color: Tema.oroChiaro; font.family: Tema.font; font.pixelSize: 12
                        }
                    }
                    Row {
                        spacing: 8
                        Semaforo { anchors.verticalCenter: parent.verticalCenter; colore: riga.modelData.stima.colore }
                        Text {
                            text: [mo.gb(riga.modelData.dimensione_gb),
                                   [riga.modelData.parametri, riga.modelData.quant].filter(x => x).join(" "),
                                   riga.modelData.stima.giudizio + (riga.modelData.stima.parole_s ? " (~" + String(riga.modelData.stima.parole_s).replace(".", ",") + " parole/s)" : ""),
                                   riga.modelData.in_memoria ? "in memoria" + (riga.modelData.vram_gb ? ", " + mo.gb(riga.modelData.vram_gb) + " sulla scheda video" : "") : "",
                                   riga.modelData.acceso ? "" : "spento"].filter(x => x).join(" · ")
                            color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
                        }
                    }
                }

                Row {
                    id: azioni
                    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    spacing: 6
                    Pulsante {
                        visible: riga.modelData.in_memoria
                        testo: "Libera"; icona: "memory"
                        onPremuto: mo.fai("libera", riga.modelData.nome)
                    }
                    Pulsante {
                        testo: riga.modelData.acceso ? "Spegni" : "Accendi"
                        icona: riga.modelData.acceso ? "toggle_on" : "toggle_off"
                        attivo: !riga.modelData.di_ciel
                        onPremuto: mo.fai(riga.modelData.acceso ? "spegni" : "accendi", riga.modelData.nome)
                    }
                    Pulsante {
                        readonly property bool conferma: mo.daEliminare === riga.modelData.nome
                        testo: conferma ? "Sicuro?" : "Elimina"
                        icona: "delete"
                        pericolo: true; pieno: conferma
                        attivo: !riga.modelData.di_ciel
                        onPremuto: {
                            if (conferma) { mo.daEliminare = ""; mo.fai("elimina", riga.modelData.nome); }
                            else { mo.daEliminare = riga.modelData.nome; scadenza.restart(); }
                        }
                    }
                }
            }
        }

        Text {
            id: piede
            width: parent.width; elide: Text.ElideRight
            text: mo.letto ? mo.modelli.length + " modelli · " + mo.gb(mo.modelli.reduce((s, m) => s + m.dimensione_gb, 0)) + " in tutto · "
                             + mo.hw : "Leggo i modelli…"
            color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
        }
    }
}
