// Scarica modelli: cerchi (HuggingFace, libreria di Ollama, le fonti che hai permesso), scegli un risultato e vedi
// tutte le sue versioni, ognuna con la stima per questo PC: se gira, dove (scheda video / divisa / solo RAM), quanta
// memoria usa, quanto è veloce. La consigliata è già scelta; «Scarica» la passa a Ollama (bin/cielmodelli scarica,
// in uno scope suo: continua anche a riquadro chiuso). Il motore è ~/cielos/bin/cielmodelli.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.servizi

Item {
    id: sc
    property var scaricamenti: []                 // dal riquadro (lo controlla lui ogni secondo)
    signal aggiorna()                             // chiede al riquadro di rileggere gli scaricamenti subito

    readonly property string motore: Percorsi.bin("cielmodelli")
    property var risultati: []
    property var errori: []
    property bool cercando: false
    property string cercato: ""
    property var fonti: []
    property var info: null                       // i dettagli del modello scelto
    property bool calcolo: false
    property string versione: ""                  // nome_ollama della versione scelta
    readonly property var v: info ? (info.versioni.find(x => x.nome_ollama === versione) ?? null) : null
    readonly property var inCorso: v ? (scaricamenti.find(d => d.nome === v.nome_ollama) ?? null) : null

    function apri() { campo.forceActiveFocus(); if (!fonti.length) leggiFonti.running = true; }
    function indietro() { if (info || calcolo) { info = null; calcolo = false; return true; } return false; }

    function cercaTesto(t) { campo.text = t; apri(); cerca(); }
    function cerca() {
        const t = campo.text.trim();
        if (!t) return;
        info = null; cercando = true; cercato = t; risultati = []; errori = [];
        cercaP.command = [motore, "cerca", t, "--json"];
        cercaP.running = true;
    }
    function scegli(r) {
        info = null; calcolo = true; versione = "";
        dettP.command = [motore, "dettagli", r.fonte, r.id, "--json"];
        dettP.running = true;
    }
    function scarica() {
        if (!v) return;
        Avvia.comando("modello", [motore, "scarica", v.nome_ollama]);
        Qt.callLater(sc.aggiorna);
    }
    function numero(n) {
        if (n >= 1e6) return (n / 1e6).toFixed(1).replace(".", ",") + " mln";
        if (n >= 1e3) return Math.round(n / 1e3) + " mila";
        return String(n ?? 0);
    }
    function gb(x) { return (x ?? 0).toFixed(1).replace(".", ",") + " GB"; }

    Process {
        id: cercaP
        stdout: StdioCollector {
            onStreamFinished: {
                try { const r = JSON.parse(text); sc.risultati = r.risultati; sc.errori = r.errori; }
                catch (e) { sc.errori = ["la ricerca non è andata: " + text.slice(0, 120)]; }
                sc.cercando = false;
            }
        }
        onExited: code => { if (code !== 0) sc.cercando = false; }
    }
    Process {
        id: dettP
        stdout: StdioCollector {
            onStreamFinished: {
                try { sc.info = JSON.parse(text); sc.versione = sc.info.consigliata ?? (sc.info.versioni[0]?.nome_ollama ?? ""); }
                catch (e) { sc.errori = ["non riesco a leggere quel modello"]; sc.info = null; }
                sc.calcolo = false;
            }
        }
        onExited: code => { if (code !== 0) { sc.calcolo = false; sc.errori = ["non riesco a leggere quel modello"]; } }
    }
    Process {
        id: leggiFonti
        command: [sc.motore, "fonti", "--json"]
        stdout: StdioCollector { onStreamFinished: { try { sc.fonti = JSON.parse(text).fonti; } catch (e) {} } }
    }
    Process { id: cambiaFonte; onExited: leggiFonti.running = true }

    Column {
        anchors.fill: parent
        spacing: 12

        Row {                                          // la ricerca
            width: parent.width
            spacing: 10
            Rectangle {
                width: parent.width - cercaB.width - 10; height: 44; radius: Tema.raggio
                color: Qt.rgba(0.02, 0.03, 0.1, 0.9)
                border.color: campo.activeFocus ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.7) : Qt.rgba(1, 1, 1, 0.12)
                Text {
                    id: lente
                    anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    text: "search"; font.family: Tema.icone; font.pixelSize: 20; color: Tema.oro
                }
                TextInput {
                    id: campo
                    anchors { left: lente.right; leftMargin: 10; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    color: Tema.testo; font.family: Tema.font; font.pixelSize: 16; clip: true
                    selectionColor: Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.4)
                    onAccepted: sc.cerca()
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !campo.text
                        text: "Cerca un modello (es. qwen3, gemma, llama, mistral…)"
                        color: Tema.tenue; font: campo.font
                    }
                }
            }
            Pulsante { id: cercaB; anchors.verticalCenter: parent.verticalCenter; testo: "Cerca"; pieno: true; onPremuto: sc.cerca() }
        }

        Row {                                          // le fonti permesse (si accendono e spengono)
            spacing: 8
            visible: !sc.info && !sc.calcolo
            Text { anchors.verticalCenter: parent.verticalCenter; text: "Fonti:"; color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12 }
            Repeater {
                model: sc.fonti
                Rectangle {
                    required property var modelData
                    width: et.implicitWidth + 22; height: 26; radius: 13
                    color: modelData.attiva ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.22) : "transparent"
                    border.color: modelData.attiva ? Tema.oro : Tema.bordo
                    Text { id: et; anchors.centerIn: parent; text: parent.modelData.nome; color: parent.modelData.attiva ? Tema.testo : Tema.tenue; font.family: Tema.font; font.pixelSize: 12 }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { cambiaFonte.command = [sc.motore, "fonti", parent.modelData.id + "=" + (parent.modelData.attiva ? "no" : "si")]; cambiaFonte.running = true; }
                    }
                }
            }
        }

        Text {                                         // stato della ricerca / errori
            width: parent.width; wrapMode: Text.WordWrap
            visible: text !== ""
            text: sc.cercando ? "Cerco «" + sc.cercato + "»…"
                : sc.calcolo ? "Leggo le versioni e faccio i conti per il tuo PC…"
                : sc.errori.length ? sc.errori.join(" · ")
                : (!sc.info && sc.cercato && !sc.risultati.length) ? "Niente per «" + sc.cercato + "»." : ""
            color: sc.errori.length && !sc.cercando && !sc.calcolo ? Tema.allarme : Tema.tenue
            font.family: Tema.font; font.pixelSize: 13
        }

        ListView {                                     // i risultati
            id: lista
            visible: !sc.info && !sc.calcolo
            width: parent.width
            height: parent.height - y
            clip: true; spacing: 6
            model: sc.risultati
            boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle {
                required property var modelData
                width: lista.width; height: 58; radius: Tema.raggio
                color: tr.containsMouse ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.12) : Qt.rgba(1, 1, 1, 0.03)
                Behavior on color { ColorAnimation { duration: Tema.durata } }
                Column {
                    anchors { left: parent.left; leftMargin: 14; right: fonteR.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    spacing: 3
                    Text { width: parent.width; elide: Text.ElideMiddle; text: modelData.nome; color: Tema.testo; font.family: Tema.font; font.pixelSize: 15; font.weight: Font.Medium }
                    Text {
                        width: parent.width; elide: Text.ElideRight
                        text: [modelData.autore,
                               modelData.parametri_b ? (modelData.parametri_b + " mld di parametri" + (modelData.attivi_b ? " (" + modelData.attivi_b + " attivi)" : "")) : "",
                               modelData.scaricati ? sc.numero(modelData.scaricati) + " scaricamenti" : (modelData.scaricati_testo ?? ""),
                               modelData.descrizione ?? ""].filter(x => x).join(" · ")
                        color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
                    }
                }
                Text {
                    id: fonteR
                    anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    text: modelData.fonte === "huggingface" ? "HuggingFace" : "Ollama"
                    color: Tema.oroChiaro; font.family: Tema.font; font.pixelSize: 12
                }
                MouseArea { id: tr; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sc.scegli(parent.modelData) }
            }
        }

        Flickable {                                    // i dettagli di un modello
            id: dett
            visible: !!sc.info
            width: parent.width
            height: parent.height - y
            clip: true
            contentHeight: dc.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: dc
                width: dett.width
                spacing: 12

                Column {
                    width: parent.width; spacing: 4
                    Text { width: parent.width; elide: Text.ElideMiddle; text: sc.info?.id ?? ""; color: Tema.testo; font.family: Tema.font; font.pixelSize: 17; font.weight: Font.Medium }
                    Text {
                        width: parent.width; wrapMode: Text.WordWrap
                        text: [sc.info?.parametri_b ? sc.info.parametri_b + " mld di parametri" + (sc.info.attivi_b ? " (MoE, " + sc.info.attivi_b + " attivi)" : "") : "",
                               sc.info?.contesto ? "contesto " + Math.round(sc.info.contesto / 1024) + "k" : "",
                               sc.info?.vede_immagini ? "vede le immagini" : "",
                               sc.info?.licenza ? "licenza " + sc.info.licenza : ""].filter(x => x).join(" · ")
                        color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13
                    }
                    Text {
                        visible: !!sc.info?.accesso_limitato
                        text: "Ad accesso limitato: prima va accettata la licenza sulla sua pagina."
                        color: Tema.allarme; font.family: Tema.font; font.pixelSize: 13
                    }
                }

                Rectangle {                            // il riquadrino: la versione scelta, sul tuo PC
                    width: parent.width
                    height: rc.implicitHeight + 28
                    radius: Tema.raggio + 2
                    color: Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.07)
                    border.color: Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.4)
                    Column {
                        id: rc
                        x: 18; y: 14; width: parent.width - 36
                        spacing: 8
                        Row {
                            spacing: 10
                            Semaforo { anchors.verticalCenter: parent.verticalCenter; colore: sc.v?.stima.colore ?? "giallo"; width: 14; height: 14; radius: 7 }
                            Text { text: sc.v?.stima.giudizio ?? ""; color: Tema.testo; font.family: Tema.font; font.pixelSize: 18; font.weight: Font.Medium }
                            Text {
                                anchors.baseline: parent.children[1].baseline
                                visible: !!sc.v?.stima.parole_s
                                text: "~" + String(sc.v?.stima.parole_s ?? 0).replace(".", ",") + " parole al secondo"
                                color: Tema.oroChiaro; font.family: Tema.font; font.pixelSize: 14
                            }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: sc.v && sc.v.nome_ollama === sc.info?.consigliata
                                width: cons.implicitWidth + 16; height: 22; radius: 11
                                color: Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.25)
                                Text { id: cons; anchors.centerIn: parent; text: "consigliata per il tuo PC"; color: Tema.testo; font.family: Tema.font; font.pixelSize: 11 }
                            }
                        }
                        Text {
                            width: parent.width; wrapMode: Text.WordWrap
                            text: (sc.v?.quant ?? "") + " · " + (sc.v?.stima.dove_testo ?? "")
                            color: Tema.testo; font.family: Tema.font; font.pixelSize: 14
                        }
                        Text {
                            width: parent.width; wrapMode: Text.WordWrap
                            visible: !!sc.v?.stima.gira
                            text: "Usa ~" + sc.gb(sc.v?.stima.memoria_gb)
                                + (sc.v?.stima.vram_gb ? " (" + sc.gb(sc.v.stima.vram_gb) + " sulla scheda video" + (sc.v.stima.ram_gb ? ", " + sc.gb(sc.v.stima.ram_gb) + " in RAM" : "") + ")" : "")
                                + " · occupa " + sc.gb(sc.v?.dimensione_gb) + " sul disco · si carica in ~" + (sc.v?.stima.carica_s ?? 0) + " s"
                            color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13
                        }
                        Text {
                            visible: (sc.v?.bit ?? 5) < 3.5
                            text: "Compresso molto (" + (sc.v?.bit ?? 0) + " bit per peso): risponde peggio dell'originale."
                            color: "#f2c14e"; font.family: Tema.font; font.pixelSize: 12
                        }
                        Text {
                            visible: !!sc.v?.nota
                            text: sc.v?.nota ?? ""
                            color: Tema.allarme; font.family: Tema.font; font.pixelSize: 12
                        }
                        Text { text: sc.info?.hardware ?? ""; color: Tema.tenue; font.family: Tema.font; font.pixelSize: 11; opacity: 0.8 }

                        Item {                         // scarica / avanzamento
                            width: parent.width; height: 38
                            Pulsante {
                                visible: !sc.inCorso || sc.inCorso.stato !== "in corso"
                                anchors.verticalCenter: parent.verticalCenter
                                icona: sc.v?.installato ? "check" : "download"
                                testo: sc.v?.installato ? "Già installato" : (sc.inCorso?.stato === "fatto" ? "Scaricato" : "Scarica " + (sc.v?.quant ?? ""))
                                pieno: true
                                attivo: !!sc.v && !sc.v.installato && !sc.v.diviso && sc.inCorso?.stato !== "fatto"
                                onPremuto: sc.scarica()
                            }
                            Text {
                                visible: sc.inCorso?.stato === "errore" || sc.inCorso?.stato === "annullato"
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                width: parent.width * 0.55; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignRight
                                text: sc.inCorso?.messaggio ?? ""
                                color: Tema.allarme; font.family: Tema.font; font.pixelSize: 12
                            }
                            Avanzamento {
                                visible: sc.inCorso?.stato === "in corso"
                                anchors.fill: parent
                                d: sc.inCorso
                            }
                        }
                    }
                }

                Text { text: "Tutte le versioni"; color: Tema.oro; font.family: Tema.font; font.pixelSize: 12; font.letterSpacing: 2; font.capitalization: Font.AllUppercase }

                Repeater {
                    model: sc.info?.versioni ?? []
                    Rectangle {
                        required property var modelData
                        width: dc.width; height: 40; radius: Tema.raggio
                        color: modelData.nome_ollama === sc.versione ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.18)
                             : tv.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.025)
                        Behavior on color { ColorAnimation { duration: Tema.durata } }
                        Row {
                            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                            spacing: 12
                            Semaforo { anchors.verticalCenter: parent.verticalCenter; colore: modelData.stima.colore }
                            Text { width: 150; elide: Text.ElideRight; text: modelData.quant; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14 }
                            Text { width: 70; text: sc.gb(modelData.dimensione_gb); color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13 }
                            Text { width: 120; text: modelData.stima.giudizio; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
                            Text { width: 110; text: modelData.stima.parole_s ? "~" + String(modelData.stima.parole_s).replace(".", ",") + " parole/s" : ""; color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13 }
                        }
                        Text {
                            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                            text: modelData.installato ? "installato" : modelData.nome_ollama === sc.info?.consigliata ? "★ consigliata" : modelData.diviso ? "in pezzi" : ""
                            color: modelData.diviso && !modelData.installato ? Tema.tenue : Tema.oroChiaro; font.family: Tema.font; font.pixelSize: 12
                        }
                        MouseArea { id: tv; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sc.versione = parent.modelData.nome_ollama }
                    }
                }
                Item { width: 1; height: 6 }
            }
        }
    }
}
