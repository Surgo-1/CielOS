// I miei modelli: quelli scaricati (in Ollama), con gli scaricamenti in corso in cima. Per ognuno: quanto occupa,
// se è in memoria adesso (e quanta scheda video usa), la stima per questo PC (token/s), chi lo usa. Si può spegnere
// (nessuno lo usa e lascia la memoria), riaccendere, togliere dalla memoria, eliminare (due clic; prima lo toglie
// dalla RAM, e se era la mente di Ciel, Ciel resta senza mente), farne la mente di Ciel («Usa per Ciel», due clic) e
// aprire le sue impostazioni di esecuzione (le rotelle): contesto, campionamento, memoria, strati sulla scheda video,
// batch, mmap/mlock, ragionamento — quelle che Ollama sa davvero usare — con la memoria stimata e la ricarica.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.servizi
import "../impostazioni"

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
    property string impostazioniDi: ""            // il modello con la pagina delle impostazioni aperta
    property var scheda: null                     // cosa Ollama sa di quel modello (contesto massimo, strati, capacità)

    function leggi() { if (!leggiP.running) leggiP.running = true; }
    function fai(...args) {
        azione.command = [motore, ...args, "--json"];
        azione.running = true;
    }
    function imposta(nome, chiave, valore) {
        azione.command = [motore, "imposta", nome, chiave + "=" + valore, "--json"];
        azione.running = true;
    }
    function apriImpostazioni(nome) {
        if (mo.impostazioniDi === nome) { mo.impostazioniDi = ""; return; }
        mo.impostazioniDi = nome;
        mo.scheda = null;
        schedaP.command = [motore, "scheda", nome, "--json"];
        schedaP.running = true;
    }
    function ricarica(nome) {
        azione.command = [motore, "ricarica", nome, "--json"];
        azione.running = true;
    }
    function ripristina(nome) {
        // «auto» per tutto: i valori di serie, tranne la memoria (che è una scelta a parte)
        const chiavi = ["contesto", "temperatura", "top_p", "top_k", "min_p", "ripetizione", "presenza",
                        "max_token", "seed", "strati_gpu", "batch", "mmap", "mlock", "ragiona"];
        azione.command = [motore, "imposta", nome, ...chiavi.map(k => k + "=auto"), "--json"];
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
        id: schedaP
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    if (r.ok !== false) mo.scheda = r;
                } catch (e) { console.warn("cielmodelli scheda: " + text.slice(-400)); }
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
        onExited: {
            mo.caricando = ""; mo.leggi()
            if (mo.impostazioniDi !== "") {          // il contesto in memoria può essere cambiato: rileggi la scheda
                if (schedaP.running) schedaP.running = false
                schedaP.command = [mo.motore, "scheda", mo.impostazioniDi, "--json"]
                schedaP.running = true
            }
        }
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
                width: lista.width; height: 66; radius: Tema.raggio
                color: Qt.rgba(1, 1, 1, modelData.in_memoria ? 0.035 : 0.015)
                opacity: modelData.in_memoria ? 1 : 0.6
                Behavior on opacity { NumberAnimation { duration: Tema.durata } }

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
                        id: rigaInfo
                        width: parent.width
                        spacing: 8
                        Semaforo { anchors.verticalCenter: parent.verticalCenter; colore: riga.modelData.stima.colore }
                        Text {
                            // la riga si ferma prima dei pulsanti: una riga lunga va accorciata, non disegnata sotto
                            width: rigaInfo.width - 18; elide: Text.ElideRight
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
                    Pulsante {                     // le impostazioni di esecuzione di questo modello
                        readonly property bool aperto: mo.impostazioniDi === riga.modelData.nome
                        icona: "tune"; testo: ""; pieno: aperto
                        onPremuto: mo.apriImpostazioni(riga.modelData.nome)
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

    // ── le impostazioni di esecuzione: una pagina intera sopra l'elenco ───────────────────────────────────────
    // Contesto, campionamento, memoria, strati/batch/mmap/mlock/ragionamento: solo quello che Ollama sa usare davvero.
    Rectangle {
        id: foglio
        anchors.fill: parent
        visible: mo.impostazioniDi !== ""
        z: 20
        radius: Tema.raggio
        color: Tema.superficieNetta
        border.width: 1
        border.color: Tema.bordoForte

        readonly property var mod: mo.modelli.find(m => m.nome === mo.impostazioniDi) ?? null
        readonly property var imp: foglio.mod?.impostazioni ?? ({})
        readonly property var stima: foglio.mod?.stima ?? ({})
        readonly property int massimo: {
            const m = Number(mo.scheda?.contesto_max);
            return m && m > 2048 ? Math.min(m, 262144) : 32768;
        }
        readonly property int strati: Number(mo.scheda?.blocchi) > 0 ? Number(mo.scheda.blocchi) : 99
        readonly property var capacita: mo.scheda?.capacita ?? []
        property bool avanzate: false
        readonly property string nome: foglio.mod?.nome ?? mo.impostazioniDi

        function metti(chiave, valore) { mo.imposta(foglio.nome, chiave, valore); }

        Item {                                      // in cima: indietro, cosa stiamo guardando, ricarica
            id: testataF
            x: 18; y: 14; width: foglio.width - 36; height: 40
            Rectangle {
                width: 32; height: 32; radius: 16
                anchors.verticalCenter: parent.verticalCenter
                color: indF.containsMouse ? Tema.accentoMedio : Tema.biancoTenue
                border.width: 1; border.color: indF.containsMouse ? Tema.bordoForte : Tema.bordoTenue
                Text { anchors.centerIn: parent; text: "arrow_back"; font.family: Tema.icone; font.pixelSize: 18; color: Tema.oro }
                MouseArea { id: indF; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: mo.impostazioniDi = "" }
            }
            Column {
                x: 44; anchors.verticalCenter: parent.verticalCenter
                width: testataF.width - 44 - 300
                spacing: 0
                Text { text: Lingua.t("IMPOSTAZIONI DI ESECUZIONE"); color: Tema.oro; font.family: Tema.font
                       font.pixelSize: 10; font.letterSpacing: 2; font.capitalization: Font.AllUppercase; font.weight: Font.Medium }
                Text { width: parent.width; elide: Text.ElideMiddle
                       text: mo.breve(foglio.nome); color: Tema.testo; font.family: Tema.font
                       font.pixelSize: 17; font.weight: Font.Medium }
            }
            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 8
                Pulsante { testo: Lingua.t("Ricarica modello"); icona: "restart_alt"
                           attivo: foglio.mod?.in_memoria === true
                           onPremuto: mo.ricarica(foglio.nome) }
                Pulsante { testo: Lingua.t("Chiudi"); icona: "close"; onPremuto: mo.impostazioniDi = "" }
            }
        }

        Flickable {
            id: scorrimentoF
            x: 18; y: testataF.y + testataF.height + 6
            width: foglio.width - 36
            height: foglio.height - y - 58
            contentHeight: contenutoF.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: contenutoF
                width: scorrimentoF.width
                spacing: 12

                Titoletto {
                    testo: Lingua.t("Memoria stimata")
                    spiega: Lingua.t("Un conto, non una promessa: più contesto (e più strati sulla scheda video) vuol dire più memoria. Il resto lo tiene il desktop.")
                }
                Row {
                    spacing: 10
                    Rectangle {
                        width: (contenutoF.width - 10) / 2; height: 54; radius: Tema.raggioPiccolo + 6
                        color: Tema.conAlfa(Tema.testo, 0.035); border.width: 1; border.color: Tema.bordoTenue
                        Column {
                            anchors.centerIn: parent; spacing: 2
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "GPU"
                                   color: Tema.tenue; font.family: Tema.font; font.pixelSize: 11; font.letterSpacing: 1.2 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: mo.gb(foglio.stima.vram_gb ?? 0)
                                   color: Tema.oroChiaro; font.family: Tema.font; font.pixelSize: 15; font.weight: Font.Medium }
                        }
                    }
                    Rectangle {
                        width: (contenutoF.width - 10) / 2; height: 54; radius: Tema.raggioPiccolo + 6
                        color: Tema.conAlfa(Tema.testo, 0.035); border.width: 1; border.color: Tema.bordoTenue
                        Column {
                            anchors.centerIn: parent; spacing: 2
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: Lingua.t("Totale")
                                   color: Tema.tenue; font.family: Tema.font; font.pixelSize: 11; font.letterSpacing: 1.2 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: mo.gb(foglio.stima.memoria_gb ?? 0)
                                   color: Tema.testo; font.family: Tema.font; font.pixelSize: 15; font.weight: Font.Medium }
                        }
                    }
                }
                Text {
                    width: parent.width; wrapMode: Text.WordWrap
                    visible: !foglio.stima.gira
                    text: foglio.stima.dove_testo ?? ""
                    color: Tema.allarme; font.family: Tema.font; font.pixelSize: 12
                }

                Titoletto {
                    testo: Lingua.t("Contesto")
                    spiega: Lingua.t("Quanti token il modello può leggere e ricordare in una volta. Più è alto, più memoria serve; il massimo è quello che il modello dichiara. Il contesto entra nel modello: vale anche per le altre app che usano Ollama, dal prossimo caricamento.")
                }
                Cursore {
                    testo: Lingua.t("Contesto (token)")
                    min: 2048; max: foglio.massimo; passo: 1024
                    valore: foglio.imp.contesto ?? 4096
                    onCambiato: v => foglio.metti("contesto", v)
                }
                Flow {
                    width: parent.width; spacing: 6
                    Chip { testo: Lingua.t("di serie"); icona: "restart_alt"; acceso: foglio.imp.contesto === undefined
                           onPremuto: foglio.metti("contesto", "auto") }
                    Repeater {
                        model: [4096, 8192, 16384, 32768].filter(v => v <= foglio.massimo)
                        Chip {
                            required property int modelData
                            testo: (modelData / 1024) + "k"
                            acceso: Number(foglio.imp.contesto) === modelData
                            onPremuto: foglio.metti("contesto", modelData)
                        }
                    }
                }
                Text {
                    width: parent.width; wrapMode: Text.WordWrap
                    visible: mo.scheda !== null
                    text: Lingua.t("Massimo %1 token: è quello che dichiara il modello.", foglio.massimo)
                    color: Tema.tenue; font.family: Tema.font; font.pixelSize: 11
                }
                Text {
                    // il modello in memoria può essere a 4k anche se hai scelto 32k (l'ha caricato un'altra app)
                    width: parent.width; wrapMode: Text.WordWrap
                    visible: mo.scheda?.in_memoria === true && foglio.imp.contesto !== undefined
                             && Number(mo.scheda.contesto_attuale) !== Number(foglio.imp.contesto)
                    text: Lingua.t("In memoria adesso a %1 token, non a %2: «Ricarica modello» per applicarlo subito; le altre app lo prendono al prossimo caricamento.",
                                   mo.scheda?.contesto_attuale ?? "?", foglio.imp.contesto)
                    color: Tema.allarme; font.family: Tema.font; font.pixelSize: 11
                }

                Titoletto {
                    testo: Lingua.t("Campionamento")
                    spiega: Lingua.t("Come sceglie le parole: temperatura bassa = prevedibile, alta = varia. Top P e Top K limitano la scelta; Min P scarta le parole improbabili.")
                }
                Cursore {
                    testo: Lingua.t("Temperatura")
                    min: 0; max: 2; passo: 0.05; decimali: 2
                    valore: foglio.imp.temperatura ?? 0.3
                    onCambiato: v => foglio.metti("temperatura", v)
                }
                Cursore {
                    testo: "Top P"
                    min: 0; max: 1; passo: 0.01; decimali: 2
                    valore: foglio.imp.top_p ?? 0.9
                    onCambiato: v => foglio.metti("top_p", v)
                }
                Cursore {
                    testo: "Top K"
                    min: 0; max: 200; passo: 1
                    valore: foglio.imp.top_k ?? 40
                    onCambiato: v => foglio.metti("top_k", v)
                }
                Cursore {
                    testo: "Min P"
                    min: 0; max: 1; passo: 0.01; decimali: 2
                    valore: foglio.imp.min_p ?? 0
                    onCambiato: v => foglio.metti("min_p", v)
                }
                Cursore {
                    testo: Lingua.t("Ripetizione")
                    min: 0.5; max: 2; passo: 0.05; decimali: 2
                    valore: foglio.imp.ripetizione ?? 1.1
                    onCambiato: v => foglio.metti("ripetizione", v)
                }
                Cursore {
                    testo: Lingua.t("Presenza")
                    min: 0; max: 2; passo: 0.05; decimali: 2
                    valore: foglio.imp.presenza ?? 0
                    onCambiato: v => foglio.metti("presenza", v)
                }
                Cursore {
                    testo: Lingua.t("Max token (0 = senza limite)")
                    min: 0; max: 16384; passo: 256
                    valore: foglio.imp.max_token ?? 0
                    onCambiato: v => foglio.metti("max_token", v)
                }

                Item {                              // il seme: «casuale» o un numero, con Invio
                    width: parent.width; height: 34
                    Text { anchors.verticalCenter: parent.verticalCenter; text: Lingua.t("Seme")
                           color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.Medium }
                    Rectangle {
                        id: campoSeme
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        width: 150; height: 32; radius: Tema.raggioPiccolo + 6
                        color: Tema.conAlfa(Tema.testo, 0.05)
                        border.width: 1
                        border.color: seme.activeFocus ? Tema.alfa(Tema.oro, 0.7) : Tema.bordoTenue
                        Behavior on border.color { ColorAnimation { duration: Tema.durata } }
                        TextInput {
                            id: seme
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            verticalAlignment: TextInput.AlignVCenter
                            color: Tema.testo; font.family: Tema.font; font.pixelSize: 13
                            selectByMouse: true; clip: true
                            selectionColor: Tema.accentoForte
                            text: foglio.imp.seed === undefined ? "" : String(foglio.imp.seed)
                            onAccepted: { foglio.metti("seed", text.trim() === "" ? "auto" : text.trim()); focus = false; }
                            Text {
                                visible: !seme.text && !seme.activeFocus
                                anchors.verticalCenter: parent.verticalCenter
                                text: Lingua.t("casuale"); color: Tema.tenue; font: seme.font
                            }
                        }
                    }
                }

                Titoletto {
                    testo: Lingua.t("Memoria")
                    spiega: Lingua.t("«Sempre» lo tiene caricato anche quando nessuno lo usa; «5 minuti» è Ollama; «No» lo toglie subito e non si ricarica da solo.")
                }
                Flow {
                    width: parent.width; spacing: 6
                    Repeater {
                        // la mente di Ciel non si toglie dalla memoria: dovrebbe ricaricarla a ogni domanda
                        model: [["sempre", Lingua.t("sempre")], ["default", Lingua.t("5 minuti")], ["no", Lingua.t("no")]]
                               .filter(x => !(x[0] === "no" && foglio.nome === mo.menteCiel))
                        Chip {
                            required property var modelData
                            testo: modelData[1]
                            acceso: foglio.imp.memoria === modelData[0]
                            onPremuto: foglio.metti("memoria", modelData[0])
                        }
                    }
                }

                Interruttore {
                    testo: Lingua.t("Impostazioni avanzate")
                    spiega: Lingua.t("Strati sulla scheda video, batch, mmap/mlock, ragionamento: per chi sa cosa sta toccando.")
                    acceso: foglio.avanzate
                    onCambiato: v => foglio.avanzate = v
                }

                Column {
                    width: parent.width
                    spacing: 12
                    visible: foglio.avanzate

                    Cursore {
                        testo: Lingua.t("Strati sulla scheda video (0 = automatico)")
                        min: 0; max: foglio.strati; passo: 1
                        valore: foglio.imp.strati_gpu ?? 0
                        onCambiato: v => foglio.metti("strati_gpu", v)
                    }
                    Text {
                        width: parent.width; wrapMode: Text.WordWrap
                        visible: mo.scheda !== null
                        text: Lingua.t("Il modello ha %1 strati; quelli oltre la scheda video vanno in RAM.", foglio.strati)
                        color: Tema.tenue; font.family: Tema.font; font.pixelSize: 11
                    }
                    Cursore {
                        testo: Lingua.t("Batch (0 = automatico)")
                        min: 0; max: 2048; passo: 64
                        valore: foglio.imp.batch ?? 0
                        onCambiato: v => foglio.metti("batch", v)
                    }
                    Row {
                        spacing: 6
                        Text { width: 96; anchors.verticalCenter: parent.verticalCenter; text: "Mmap"
                               color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12 }
                        Repeater {
                            model: [["auto", Lingua.t("auto")], ["si", Lingua.t("sì")], ["no", Lingua.t("no")]]
                            Chip {
                                required property var modelData
                                testo: modelData[1]
                                acceso: (foglio.imp.mmap ?? "auto") === modelData[0]
                                onPremuto: foglio.metti("mmap", modelData[0])
                            }
                        }
                    }
                    Row {
                        spacing: 6
                        Text { width: 96; anchors.verticalCenter: parent.verticalCenter; text: "Mlock"
                               color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12 }
                        Repeater {
                            model: [["auto", Lingua.t("auto")], ["si", Lingua.t("sì")], ["no", Lingua.t("no")]]
                            Chip {
                                required property var modelData
                                testo: modelData[1]
                                acceso: (foglio.imp.mlock ?? "auto") === modelData[0]
                                onPremuto: foglio.metti("mlock", modelData[0])
                            }
                        }
                    }
                    Row {
                        spacing: 6
                        visible: foglio.capacita.includes("thinking")
                        Text { width: 96; anchors.verticalCenter: parent.verticalCenter; text: Lingua.t("Ragionamento")
                               color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12 }
                        Repeater {
                            model: [["auto", Lingua.t("auto")], ["si", Lingua.t("sì")], ["no", Lingua.t("no")]]
                            Chip {
                                required property var modelData
                                testo: modelData[1]
                                acceso: (foglio.imp.ragiona ?? "auto") === modelData[0]
                                onPremuto: foglio.metti("ragiona", modelData[0])
                            }
                        }
                    }
                    Text {
                        width: parent.width; wrapMode: Text.WordWrap
                        text: Lingua.t("Ollama non ha KV cache, speculative decoding, parallel slots, checkpoint o argomenti extra: quello che non esiste non lo mostro. «Auto» rimette il valore di serie.")
                        color: Tema.tenue; font.family: Tema.font; font.pixelSize: 11
                    }
                }
            }
        }

        Row {
            x: 18; anchors.bottom: parent.bottom; anchors.bottomMargin: 14
            spacing: 8
            Pulsante { testo: Lingua.t("Ripristina"); icona: "settings_backup_restore"
                       onPremuto: mo.ripristina(foglio.nome) }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: mo.avviso
                color: mo.avvisoOk ? Tema.oroChiaro : Tema.allarme
                font.family: Tema.font; font.pixelSize: 12
                width: Math.max(0, foglio.width - 36 - 280); elide: Text.ElideRight
            }
        }
    }
}
