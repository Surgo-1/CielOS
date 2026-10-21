// I miei modelli: quelli scaricati (in Ollama), con gli scaricamenti in corso in cima. Per ognuno: quanto occupa,
// se è in memoria adesso (e quanta scheda video usa), la stima per questo PC (token/s), chi lo usa. Si può spegnere
// (nessuno lo usa e lascia la memoria), riaccendere, togliere dalla memoria, eliminare (due clic; prima lo toglie
// dalla RAM, e se era la mente di Ciel, Ciel resta senza mente), farne la mente di Ciel («Usa per Ciel», due clic) e
// aprire le sue impostazioni (contesto, temperatura, memoria: quelle che Ciel e CielOS usano davvero).
import QtQuick
import Quickshell
import Quickshell.Io
import qs.servizi

Item {
    id: mo
    property var scaricamenti: []
    property bool attiva: false                   // la pagina è aperta: si rilegge ogni 5 s
    readonly property string motore: Percorsi.bin("cielmodelli")
    property var modelli: []
    property string hw: ""
    property real libero: 0
    property bool ollama: true
    property string motoreMsg: ""                  // Ollama manca, è spento o senza la libreria della scheda video
    property var menteCiel: null                   // il modello con cui pensa Ciel ("" nessuno, null Ciel non c'è)
    property bool letto: false
    property string avviso: ""
    property bool avvisoOk: false                 // l'avviso è una conferma (non un errore)
    property string daUsare: ""                   // primo clic su «Usa per Ciel»: chiede conferma per 4 s
    property string daEliminare: ""               // primo clic su «Elimina»: chiede conferma per 4 s
    property string caricando: ""                 // modello che stiamo caricando adesso (pulsante «Caricamento...»)
    property string impostazioniDi: ""            // il modello con la scheda delle impostazioni aperta

    function leggi() { if (!leggiP.running) leggiP.running = true; }
    function fai(...args) {
        azione.command = [motore, ...args, "--json"];
        azione.running = true;
    }
    function imposta(nome, chiave, valore) {
        azione.command = [motore, "imposta", nome, chiave + "=" + valore, "--json"];
        azione.running = true;
    }
    function breve(n) { return n.replace(/^hf\.co\//, ""); }
    function gb(x) { return (x ?? 0).toFixed(1).replace(".", Lingua.virgola) + " GB"; }
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
                    mo.menteCiel = r.mente_ciel ?? null;
                } catch (e) {                    // si vede (e finisce nelle segnalazioni) invece di una lista vuota
                    mo.motoreMsg = Lingua.t("Non riesco a leggere i modelli: ") + text.trim().split("\n").slice(-1)[0].slice(0, 200);
                    console.warn("cielmodelli installati: " + text.slice(-600));
                }
                mo.letto = true;
            }
        }
    }
    Process {
        id: azione
        stdout: StdioCollector {
            onStreamFinished: {
                try { const r = JSON.parse(text); mo.avviso = r.ok === false || r.messaggio ? (r.messaggio ?? "") : ""; mo.avvisoOk = r.ok !== false; } catch (e) {}
            }
        }
        onExited: { mo.caricando = ""; mo.leggi() }
    }
    Timer { interval: 5000; repeat: true; running: mo.attiva; onTriggered: mo.leggi() }
    Timer { id: scadenza; interval: 4000; onTriggered: { mo.daEliminare = ""; mo.daUsare = ""; } }
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
            Text { text: Lingua.t("In arrivo"); color: Tema.oro; font.family: Tema.font; font.pixelSize: 12; font.letterSpacing: 2; font.capitalization: Font.AllUppercase }
            Repeater {
                model: mo.scaricamenti.filter(d => d.stato === "in corso")
                Avanzamento { required property var modelData; width: parent.width; d: modelData; conNome: true }
            }
        }

        Text {
            width: parent.width; wrapMode: Text.WordWrap
            visible: text !== ""
            text: mo.avviso !== "" ? mo.avviso : mo.motoreMsg !== "" ? mo.motoreMsg
                  : !mo.ollama && mo.letto ? Lingua.t("Ollama è spento: i modelli ci sono, ma non posso dire quali sono in memoria.") : ""
            // l'avviso è un errore (rosso); Ollama che manca o è spento è solo un'informazione
            color: mo.avviso !== "" && !mo.avvisoOk ? Tema.allarme : mo.avviso !== "" ? Tema.oroChiaro : Tema.testo; font.family: Tema.font; font.pixelSize: 13
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
                width: lista.width; height: 66 + (pannello.visible ? pannello.height + 10 : 0); radius: Tema.raggio
                color: Qt.rgba(1, 1, 1, modelData.in_memoria ? 0.035 : 0.015)
                opacity: modelData.in_memoria ? 1 : 0.6
                Behavior on opacity { NumberAnimation { duration: Tema.durata } }
                Behavior on height { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }

                Column {
                    anchors { left: parent.left; leftMargin: 14; right: azioni.left; rightMargin: 12; top: parent.top; topMargin: 13 }
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
                            text: Lingua.t("lo usa Ciel"); color: Tema.oroChiaro; font.family: Tema.font; font.pixelSize: 12
                        }
                    }
                    Row {
                        spacing: 8
                        Semaforo { anchors.verticalCenter: parent.verticalCenter; colore: riga.modelData.stima.colore }
                        Text {
                            text: [mo.gb(riga.modelData.dimensione_gb),
                                   [riga.modelData.parametri, riga.modelData.quant].filter(x => x).join(" "),
                                   riga.modelData.stima.giudizio + (riga.modelData.stima.tok_s ? " (~" + String(riga.modelData.stima.tok_s).replace(".", Lingua.virgola) + Lingua.t(" tok/s)") : ""),
                                   riga.modelData.in_memoria ? Lingua.t("in memoria") + (riga.modelData.vram_gb ? Lingua.t(", %1 sulla scheda video", mo.gb(riga.modelData.vram_gb)) : "") : Lingua.t("spento")].filter(x => x).join(" · ")
                            color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
                        }
                    }
                }

                Row {
                    id: azioni
                    anchors { right: parent.right; rightMargin: 12; top: parent.top; topMargin: 16 }
                    spacing: 6
                    Pulsante {                     // le impostazioni di questo modello: contesto, temperatura, memoria
                        readonly property bool aperto: mo.impostazioniDi === riga.modelData.nome
                        icona: "tune"; testo: ""; pieno: aperto
                        onPremuto: mo.impostazioniDi = aperto ? "" : riga.modelData.nome
                    }
                    Pulsante {                     // la mente di Ciel (solo se l'assistente è installato)
                        visible: mo.menteCiel !== null && mo.menteCiel !== riga.modelData.nome
                        readonly property bool conferma: mo.daUsare === riga.modelData.nome
                        testo: conferma ? Lingua.t("Sicuro? Ciel si riavvia") : Lingua.t("Usa per Ciel"); icona: "neurology"
                        pieno: conferma
                        onPremuto: {
                            if (conferma) { mo.daUsare = ""; mo.fai("ciel", riga.modelData.nome); }
                            else { mo.daUsare = riga.modelData.nome; scadenza.restart(); }
                        }
                    }
                    Pulsante {
                        visible: riga.modelData.in_memoria
                        testo: Lingua.t("Libera"); icona: "memory"
                        onPremuto: mo.fai("libera", riga.modelData.nome)
                    }
                    Pulsante {
                        readonly property bool staCaricando: mo.caricando === riga.modelData.nome
                        testo: staCaricando ? Lingua.t("Caricamento...") : (riga.modelData.in_memoria ? Lingua.t("Spegni") : Lingua.t("Accendi"))
                        icona: staCaricando ? "sync" : (riga.modelData.in_memoria ? "toggle_on" : "toggle_off")
                        attivo: !riga.modelData.di_ciel && !staCaricando
                        onPremuto: {
                            if (riga.modelData.in_memoria) {
                                mo.fai("spegni", riga.modelData.nome)
                            } else {
                                mo.caricando = riga.modelData.nome
                                mo.fai("accendi", riga.modelData.nome)
                            }
                        }
                    }
                    Pulsante {
                        readonly property bool conferma: mo.daEliminare === riga.modelData.nome
                        testo: conferma ? Lingua.t("Sicuro?") : Lingua.t("Elimina")
                        icona: "delete"
                        pericolo: true; pieno: conferma
                        onPremuto: {
                            if (conferma) { mo.daEliminare = ""; mo.fai("elimina", riga.modelData.nome); }
                            else {
                                mo.daEliminare = riga.modelData.nome;
                                if (riga.modelData.di_ciel) {
                                    mo.avviso = Lingua.t("Ciel usa questo modello: eliminandolo resta senza mente (va bene, si sceglie dopo).");
                                    mo.avvisoOk = false;
                                }
                                scadenza.restart();
                            }
                        }
                    }
                }

                // le impostazioni del modello, aperte dal pulsante con le rotelle: contesto e temperatura valgono per
                // Ciel (se è la sua mente) e per come CielOS lo carica; la memoria si applica subito
                Column {
                    id: pannello
                    visible: mo.impostazioniDi === riga.modelData.nome
                    x: 14; y: 64; width: parent.width - 28; spacing: 6
                    readonly property var imp: riga.modelData.impostazioni ?? ({ contesto: 4096, temperatura: 0.3, memoria: "default" })

                    Row {
                        spacing: 6
                        Text { width: 108; anchors.verticalCenter: parent.verticalCenter; text: Lingua.t("Contesto (token)")
                               color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12 }
                        Repeater {
                            model: [2048, 4096, 8192, 16384, 32768]
                            Pulsante {
                                required property int modelData
                                testo: (modelData / 1024) + "k"
                                pieno: pannello.imp.contesto === modelData
                                onPremuto: mo.imposta(riga.modelData.nome, "contesto", modelData)
                            }
                        }
                    }
                    Row {
                        spacing: 6
                        Text { width: 108; anchors.verticalCenter: parent.verticalCenter; text: Lingua.t("Temperatura")
                               color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12 }
                        Repeater {
                            model: [0, 0.3, 0.7, 1]
                            Pulsante {
                                required property real modelData
                                testo: String(modelData).replace(".", Lingua.virgola)
                                pieno: Math.abs(pannello.imp.temperatura - modelData) < 0.001
                                onPremuto: mo.imposta(riga.modelData.nome, "temperatura", modelData)
                            }
                        }
                    }
                    Row {
                        spacing: 6
                        Text { width: 108; anchors.verticalCenter: parent.verticalCenter; text: Lingua.t("In memoria")
                               color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12 }
                        Repeater {
                            model: [["sempre", Lingua.t("Sempre")], ["default", Lingua.t("5 minuti")], ["no", Lingua.t("No")]]
                            Pulsante {
                                required property var modelData
                                testo: modelData[1]
                                pieno: pannello.imp.memoria === modelData[0]
                                onPremuto: mo.imposta(riga.modelData.nome, "memoria", modelData[0])
                            }
                        }
                    }
                    Text {
                        width: parent.width; wrapMode: Text.WordWrap
                        text: Lingua.t("Contesto e temperatura valgono per Ciel (quando è la sua mente) e per come CielOS lo carica; la memoria si applica subito. «No» lo toglie dalla RAM e non lo ricarica da solo.")
                        color: Tema.tenue; font.family: Tema.font; font.pixelSize: 11
                    }
                }
            }
        }

        Text {
            id: piede
            width: parent.width; elide: Text.ElideRight
            text: mo.letto ? Lingua.t("%1 modelli · %2 in tutto · ", mo.modelli.length, mo.gb(mo.modelli.reduce((s, m) => s + m.dimensione_gb, 0)))
                             + mo.hw : Lingua.t("Leggo i modelli…")
            color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
        }
    }
}
