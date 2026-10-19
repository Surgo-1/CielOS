// Install (Super+A → Install), come Shelly: un posto solo per i programmi.
//   Cerca      repository di Arch, AUR (anche le varianti -git e -bin) e Flathub insieme, raggruppati per programma;
//              apri un risultato e scegli la variante e la versione (per Arch anche le vecchie, dall'archivio)
//   Consigliati il catalogo scelto di CielOS (i plugin, dalla fonte più sicura)
//   Rimuovi    tutto quello che è installato e contiene le lettere che scrivi: scegli e togli (mai i pacchetti vitali)
//   Aggiorna tutto: sistema con le ondate (istantanea prima), AUR e Flatpak, in un terminale
// Installazioni e rimozioni girano in un terminale davanti a tutto (bin/cielplugin): vedi cosa fa, la password la
// scrivi tu; alla fine il riquadro si riapre qui e i risultati si rileggono.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.servizi

Item {
    id: ins
    readonly property string motore: Percorsi.bin("cielplugin")
    property string scheda: "cerca"               // cerca | consigliati | rimuovi
    property var gruppi: []
    property var errori: []
    property string cercato: ""
    property var scelto: null                     // il gruppo aperto (le sue varianti)
    property var versioni: ({})                   // "fonte:id" → [versioni]
    property string leggendo: ""                  // "fonte:id" delle versioni che si stanno leggendo
    property var installati: []
    property string filtro: ""
    property var esclusi: ({})                    // id → true: non spuntati in Rimuovi
    property bool sicuro: false
    property var agg: null                        // cosa aspetta un aggiornamento (cielplugin aggiornamenti)
    property bool aggLeggo: false
    property var dettagli: ({})                   // "fonte:id" → la scheda del programma
    property var dettAperti: ({})                 // "fonte:id" → true: la scheda è aperta
    property string dettLeggo: ""
    readonly property var daTogliere: installati.filter(v => !v.protetto && !esclusi[v.fonte + ":" + v.id])

    function apri() { campo.forceActiveFocus(); }
    // dopo un'installazione il riquadro si riapre qui: rilegge quello che c'era
    function riapri() {
        campo.forceActiveFocus();
        if (scheda === "cerca" && cercato) cerca(cercato);
        if (scheda === "rimuovi" && filtro) elenca(filtro);
    }
    function indietro() {
        if (scelto) { scelto = null; return true; }
        if (scheda !== "cerca") { scheda = "cerca"; return true; }
        return false;
    }
    function invio() {
        const t = campo.text.trim();
        if (!t) return;
        if (scheda === "rimuovi") elenca(t); else { scheda = "cerca"; cerca(t); }
    }
    function cerca(t) {
        scelto = null; cercato = t; errori = [];
        if (campo.text.trim() !== t) campo.text = t;
        cercaP.command = [motore, "cerca", t, "--json"];
        cercaP.running = true;
    }
    function elenca(t) {
        filtro = t; esclusi = ({}); sicuro = false;
        if (campo.text.trim() !== t) campo.text = t;
        elencaP.command = [motore, "installati", t, "--json"];
        elencaP.running = true;
    }
    function leggiVersioni(v) {
        const k = v.fonte + ":" + v.id;
        if (versioni[k] || versioniP.running) return;
        leggendo = k;
        versioniP.command = [motore, "versioni", v.fonte, v.id, "--json"];
        versioniP.running = true;
    }
    function installa(v, versione) {
        Avvia.comando("cielplugin", [motore, "pacchetto", v.fonte, v.id].concat(versione ? [versione] : []));
    }
    function togli() {
        if (!sicuro) { sicuro = true; return; }
        sicuro = false;
        Avvia.comando("cielplugin", [motore, "rimuovi"].concat(daTogliere.map(v => v.fonte + ":" + v.id)));
    }
    function aggiornaTutto() { Avvia.comando("cielplugin", [motore, "aggiorna-tutto"]); }
    function leggiAggiornamenti() {
        if (aggP.running) return;
        aggLeggo = true;
        aggP.command = [motore, "aggiornamenti", "--json"];
        aggP.running = true;
    }
    function apriScheda(nome) {
        scheda = nome; scelto = null; campo.forceActiveFocus();
        if (nome === "aggiornamenti") leggiAggiornamenti();
    }
    function apriDettagli(v) {
        const k = v.fonte + ":" + v.id;
        if (dettagli[k]) { const a = Object.assign({}, dettAperti); a[k] = !a[k]; dettAperti = a; return; }
        if (dettP.running) return;
        dettLeggo = k;
        dettP.command = [motore, "dettagli", v.fonte, v.id, "--json"];
        dettP.running = true;
    }
    function testoDettagli(d) {
        if (!d) return "";
        return [d.dimensione ? Lingua.t("scarichi %1", d.dimensione) : "",
                d.installata ? Lingua.t("occupa %1", d.installata) : "",
                d.licenza ? Lingua.t("licenza %1", d.licenza) : "",
                d.aggiornato ? Lingua.t("aggiornato il %1", d.aggiornato) : "",
                d.manutentore ? Lingua.t("manutentore: %1", d.manutentore) : "",
                d.voti !== undefined && d.voti !== null ? Lingua.t("%1 voti", d.voti) : "",
                d.popolarita !== undefined && d.popolarita !== null ? Lingua.t("popolarità %1", d.popolarita) : "",
                d.vecchio ? Lingua.t("segnato come non aggiornato") : "",
                d.dipende && d.dipende.length ? Lingua.t("dipende da: %1", d.dipende.slice(0, 8).join(", ") + (d.dipende.length > 8 ? "…" : "")) : ""
               ].filter(x => x).join(" · ");
    }
    function nomeFonte(v) {
        return v.fonte === "repo" ? "Arch · " + v.tipo : v.fonte === "flatpak" ? "Flathub"
             : v.tipo === "git" ? "AUR · git" : v.tipo === "bin" ? "AUR · bin" : "AUR";
    }
    function coloreFonte(f) { return f === "repo" ? "#7fe0a8" : f === "flatpak" ? "#7fb8ff" : "#ffb347"; }

    Process {
        id: cercaP
        stdout: StdioCollector {
            onStreamFinished: {
                try { const r = JSON.parse(text); ins.gruppi = r.gruppi; ins.errori = r.errori; }
                catch (e) { ins.gruppi = []; ins.errori = [Lingua.t("la ricerca non è andata: ") + text.slice(0, 120)]; }
                if (ins.scelto) ins.scelto = ins.gruppi.find(g => g.chiave === ins.scelto.chiave) ?? null;
            }
        }
    }
    Process {
        id: elencaP
        stdout: StdioCollector { onStreamFinished: { try { ins.installati = JSON.parse(text).voci; } catch (e) { ins.installati = []; } } }
    }
    Process {
        id: aggP
        stdout: StdioCollector {
            onStreamFinished: {
                try { ins.agg = JSON.parse(text); } catch (e) { ins.agg = { voci: [], conteggio: {}, errori: [Lingua.t("non riesco a leggere gli aggiornamenti")] }; }
                ins.aggLeggo = false;
            }
        }
        onExited: ins.aggLeggo = false
    }
    Process {
        id: dettP
        stdout: StdioCollector {
            onStreamFinished: {
                let d = null;
                try { const r = JSON.parse(text); if (r.ok) d = r; } catch (e) {}
                const m = Object.assign({}, ins.dettagli); if (d) m[ins.dettLeggo] = d; ins.dettagli = m;
                if (d) { const a = Object.assign({}, ins.dettAperti); a[ins.dettLeggo] = true; ins.dettAperti = a; }
                ins.dettLeggo = "";
            }
        }
        onExited: ins.dettLeggo = ""
    }
    Process {
        id: versioniP
        stdout: StdioCollector {
            onStreamFinished: {
                let l = [];
                try { l = JSON.parse(text).versioni; } catch (e) {}
                const v = Object.assign({}, ins.versioni); v[ins.leggendo] = l; ins.versioni = v; ins.leggendo = "";
            }
        }
    }
    Timer { id: scadenza; interval: 4000; running: ins.sicuro; onTriggered: ins.sicuro = false }

    Column {
        anchors.fill: parent
        spacing: 12

        Row {                                          // la ricerca (in Rimuovi: le lettere da cercare tra gli installati)
            width: parent.width
            spacing: 10
            Rectangle {
                width: parent.width - vaiB.width - 10; height: 44; radius: Tema.raggio
                color: Qt.rgba(0.02, 0.03, 0.1, 0.9)
                border.color: campo.activeFocus ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.7) : Qt.rgba(1, 1, 1, 0.12)
                Text {
                    id: lente
                    anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    text: ins.scheda === "rimuovi" ? "delete_sweep" : "search"; font.family: Tema.icone; font.pixelSize: 20; color: Tema.oro
                }
                TextInput {
                    id: campo
                    anchors { left: lente.right; leftMargin: 10; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    color: Tema.testo; font.family: Tema.font; font.pixelSize: 16; clip: true
                    selectionColor: Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.4)
                    onAccepted: ins.invio()
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !campo.text
                        text: ins.scheda === "rimuovi" ? Lingua.t("Lettere da cercare tra i programmi installati (es. steam, kde, python)")
                                                      : Lingua.t("Cerca un programma (Arch, AUR, Flathub)…")
                        color: Tema.tenue; font: campo.font
                    }
                }
            }
            Pulsante { id: vaiB; anchors.verticalCenter: parent.verticalCenter; pieno: true
                       testo: ins.scheda === "rimuovi" ? Lingua.t("Trova") : Lingua.t("Cerca"); onPremuto: ins.invio() }
        }

        Row {                                          // le schede, e aggiorna tutto
            spacing: 8
            Repeater {
                model: [["cerca", "search", Lingua.t("Cerca")],
                        ["aggiornamenti", "update", Lingua.t("Aggiornamenti") + (ins.agg && ins.agg.voci.length ? "  " + ins.agg.voci.length : "")],
                        ["consigliati", "star", Lingua.t("Consigliati")],
                        ["rimuovi", "delete", Lingua.t("Rimuovi")]]
                Pulsante {
                    required property var modelData
                    testo: modelData[2]; pieno: ins.scheda === modelData[0]
                    onPremuto: ins.apriScheda(modelData[0])
                }
            }
            Pulsante { testo: Lingua.t("Aggiorna tutto"); icona: "system_update_alt"; onPremuto: ins.aggiornaTutto() }
        }

        Text {                                         // lo stato
            width: parent.width; wrapMode: Text.WordWrap
            visible: text !== ""
            text: ins.scheda === "cerca" && !ins.scelto
                  ? (cercaP.running ? Lingua.t("Cerco «%1» nei repository di Arch, nell'AUR e su Flathub…", ins.cercato)
                     : ins.errori.length ? ins.errori.join(" · ")
                     : ins.cercato && !ins.gruppi.length ? Lingua.t("Niente per «%1».", ins.cercato)
                     : !ins.cercato ? Lingua.t("Cerca un programma: ti mostro tutte le versioni che ci sono (repository di Arch, AUR con le varianti -git e -bin, Flathub) e scegli tu quale installare. «Aggiorna tutto» aggiorna sistema, AUR e Flatpak.") : "")
                  : ins.scheda === "rimuovi"
                  ? (elencaP.running ? Lingua.t("Cerco tra i programmi installati…")
                     : !ins.filtro && !ins.installati.length ? Lingua.t("Scrivi delle lettere: trovo tutto quello che è installato e le contiene (pacchetti, AUR, Flatpak), oppure «Tutti gli installati». I pacchetti vitali sono bloccati; quelli che servono ad altri programmi restano.")
                     : !ins.filtro ? Lingua.t("%1 installati: %2 scelti.", ins.installati.length, ins.daTogliere.length)
                     : !ins.installati.length ? Lingua.t("Niente di installato contiene «%1».", ins.filtro)
                     : Lingua.t("%1 installati contengono «%2»: %3 scelti.", ins.installati.length, ins.filtro, ins.daTogliere.length))
                  : ""
            color: ins.errori.length && !cercaP.running && ins.scheda === "cerca" ? Tema.allarme : Tema.tenue
            font.family: Tema.font; font.pixelSize: 13
        }

        // ── Aggiornamenti: cosa aspetta, da tutte le fonti (come la pagina Updates di Shelly) ──
        Flickable {
            visible: ins.scheda === "aggiornamenti"
            width: parent.width; height: parent.height - y
            clip: true; contentHeight: aggCol.implicitHeight + 10
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: aggCol
                width: parent.width; spacing: 6
                Text {
                    width: parent.width; wrapMode: Text.Wrap
                    text: ins.aggLeggo ? Lingua.t("Guardo cosa aspetta un aggiornamento…")
                        : !ins.agg ? ""
                        : !ins.agg.voci.length ? Lingua.t("È tutto aggiornato: niente da fare.")
                        : Lingua.t("%1 aggiornamenti: %2 di Arch, %3 dell'AUR, %4 Flatpak.", ins.agg.voci.length,
                                   ins.agg.conteggio.repo ?? 0, ins.agg.conteggio.aur ?? 0, ins.agg.conteggio.flatpak ?? 0)
                    color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13
                }
                Row {
                    visible: !!ins.agg && ins.agg.voci.length > 0
                    spacing: 8
                    Pulsante { testo: Lingua.t("Aggiorna tutto"); pieno: true; icona: "system_update_alt"; onPremuto: ins.aggiornaTutto() }
                    Pulsante { testo: Lingua.t("Rileggi"); icona: "refresh"; onPremuto: ins.leggiAggiornamenti() }
                }
                Repeater {
                    model: ins.agg?.voci ?? []
                    Rectangle {
                        required property var modelData
                        width: aggCol.width; height: 42; radius: Tema.raggio
                        color: Qt.rgba(1, 1, 1, 0.03)
                        Row {
                            anchors { left: parent.left; leftMargin: 14; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                            spacing: 10
                            Text { width: 64; text: ins.nomeFonte(modelData).split(" · ")[0]; color: ins.coloreFonte(modelData.fonte); font.family: Tema.font; font.pixelSize: 12 }
                            Text { width: parent.width - 64 - 180; elide: Text.ElideRight; text: modelData.id; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14 }
                            Text { text: modelData.vecchia ? modelData.vecchia + " → " + modelData.nuova : modelData.nuova; color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12 }
                        }
                    }
                }
                Text {
                    visible: !!ins.agg && ins.agg.errori.length > 0
                    width: parent.width; wrapMode: Text.Wrap
                    text: ins.agg ? ins.agg.errori.join(" · ") : ""
                    color: Tema.allarme; font.family: Tema.font; font.pixelSize: 12
                }
            }
        }

        // ── Cerca: i programmi trovati ──
        ListView {
            id: lista
            visible: ins.scheda === "cerca" && !ins.scelto
            width: parent.width; height: parent.height - y
            clip: true; spacing: 6
            model: ins.gruppi
            boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle {
                required property var modelData
                width: lista.width; height: 62; radius: Tema.raggio
                color: tg.containsMouse ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.12) : Qt.rgba(1, 1, 1, 0.03)
                Behavior on color { ColorAnimation { duration: Tema.durata } }
                Column {
                    anchors { left: parent.left; leftMargin: 14; right: fonti.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    spacing: 3
                    Row {
                        spacing: 8
                        Text { text: modelData.nome; color: Tema.testo; font.family: Tema.font; font.pixelSize: 15; font.weight: Font.Medium }
                        Text { visible: modelData.installato; text: Lingua.t("installato"); color: "#7fe0a8"; font.family: Tema.font; font.pixelSize: 11
                               anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text { width: parent.width; elide: Text.ElideRight; text: modelData.descrizione; color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12 }
                }
                Row {
                    id: fonti
                    anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    spacing: 6
                    Repeater {
                        model: [...new Set(modelData.varianti.map(v => ins.nomeFonte(v).split(" · ")[0] + (v.tipo === "git" || v.tipo === "bin" ? " · " + v.tipo : "")))]
                        Rectangle {
                            required property string modelData
                            width: tf.implicitWidth + 14; height: 20; radius: 10
                            color: "transparent"; border.color: Qt.rgba(1, 1, 1, 0.18)
                            Text { id: tf; anchors.centerIn: parent; text: parent.modelData; color: Tema.oroChiaro; font.family: Tema.font; font.pixelSize: 11 }
                        }
                    }
                }
                MouseArea { id: tg; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { ins.scelto = parent.modelData; parent.modelData.varianti.filter(v => v.fonte === "flatpak").forEach(v => ins.leggiVersioni(v)); } }
            }
        }

        // ── Cerca: un programma, con le sue varianti e versioni ──
        Flickable {
            visible: ins.scheda === "cerca" && !!ins.scelto
            width: parent.width; height: parent.height - y
            clip: true; contentHeight: dett.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: dett
                width: parent.width; spacing: 10
                Text { text: ins.scelto?.nome ?? ""; color: Tema.testo; font.family: Tema.font; font.pixelSize: 20; font.weight: Font.Medium }
                Text { width: parent.width; wrapMode: Text.Wrap; text: ins.scelto?.descrizione ?? ""; color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13 }
                Text { text: Lingua.t("Le versioni che ci sono: scegli quella che vuoi."); color: Tema.oro; font.family: Tema.font; font.pixelSize: 12
                       font.letterSpacing: 1 }
                Repeater {
                    model: ins.scelto?.varianti ?? []
                    Rectangle {
                        id: var_
                        required property var modelData
                        readonly property string k: modelData.fonte + ":" + modelData.id
                        readonly property var vers: ins.versioni[k] ?? null
                        property bool aperte: false
                        width: dett.width; height: cv.implicitHeight + 20; radius: Tema.raggio
                        color: modelData.installato ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.07) : Qt.rgba(1, 1, 1, 0.03)
                        border.color: modelData.installato ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.35) : Tema.bordo
                        Column {
                            id: cv
                            x: 14; y: 10; width: parent.width - 28; spacing: 6
                            Item {
                                width: parent.width; height: 34
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - azioni.width - 10
                                    spacing: 2
                                    Row {
                                        spacing: 8
                                        Text { text: ins.nomeFonte(var_.modelData); color: ins.coloreFonte(var_.modelData.fonte); font.family: Tema.font; font.pixelSize: 12; font.weight: Font.Medium }
                                        Text { text: var_.modelData.id; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14 }
                                        Text { text: var_.modelData.versione || (var_.vers?.[0]?.versione ?? ""); color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13 }
                                    }
                                    Text {
                                        width: parent.width; elide: Text.ElideRight
                                        text: [var_.modelData.installato ? Lingua.t("installato") : "",
                                               var_.modelData.fonte === "aur" ? Lingua.t("ricetta della comunità, si compila sul tuo PC") : "",
                                               var_.modelData.tipo === "git" ? Lingua.t("l'ultimo codice, non una versione stabile") : "",
                                               var_.modelData.tipo === "bin" ? Lingua.t("già compilato da chi lo sviluppa") : "",
                                               var_.modelData.voti ? Lingua.t("%1 voti", var_.modelData.voti) : "",
                                               var_.modelData.vecchio ? Lingua.t("segnato come non aggiornato") : "",
                                               var_.modelData.fonte === "flatpak" ? (var_.modelData.verificato ? Lingua.t("verificato") : Lingua.t("non verificato")) + " · " + Lingua.t("isolato dal sistema") : "",
                                               var_.modelData.fonte === "repo" ? Lingua.t("pacchetto ufficiale di Arch") : ""].filter(x => x).join(" · ")
                                        color: var_.modelData.vecchio ? "#ffb347" : Tema.tenue; font.family: Tema.font; font.pixelSize: 11
                                    }
                                }
                                Row {
                                    id: azioni
                                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                    spacing: 8
                                    Pulsante { visible: var_.modelData.fonte === "repo"; testo: var_.aperte ? Lingua.t("Chiudi") : Lingua.t("Altre versioni")
                                               onPremuto: { var_.aperte = !var_.aperte; if (var_.aperte) ins.leggiVersioni(var_.modelData); } }
                                    Pulsante { testo: var_.modelData.installato ? Lingua.t("Reinstalla") : Lingua.t("Installa"); pieno: !var_.modelData.installato
                                               onPremuto: ins.installa(var_.modelData, "") }
                                }
                            }
                            Text {
                                visible: var_.aperte && !var_.vers
                                text: Lingua.t("Leggo le versioni nell'archivio di Arch…"); color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
                            }
                            Text {
                                visible: var_.aperte && !!var_.vers
                                width: parent.width; wrapMode: Text.Wrap
                                text: var_.vers && var_.vers.length ? Lingua.t("Dall'archivio di Arch: anche le versioni vecchie (se l'ultima ti dà problemi). Il prossimo aggiornamento la riporta all'ultima.")
                                                                    : Lingua.t("Nessuna versione nell'archivio.")
                                color: Tema.tenue; font.family: Tema.font; font.pixelSize: 11
                            }
                            // la scheda del programma, come in Shelly: cosa scarichi, cosa occupa, dipendenze, licenza
                            Row {
                                spacing: 8
                                Pulsante { testo: ins.dettAperti[var_.k] ? Lingua.t("Nascondi la scheda") : Lingua.t("Scheda del programma"); icona: "info"
                                           onPremuto: ins.apriDettagli(var_.modelData) }
                            }
                            Text {
                                visible: !!ins.dettAperti[var_.k] && !ins.dettagli[var_.k]
                                text: Lingua.t("Leggo la scheda…"); color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
                            }
                            Text {
                                visible: !!ins.dettAperti[var_.k] && !!ins.dettagli[var_.k]
                                width: parent.width; wrapMode: Text.Wrap
                                text: ins.testoDettagli(ins.dettagli[var_.k])
                                color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
                            }
                            Flow {
                                visible: var_.aperte && !!var_.vers
                                width: parent.width; spacing: 6
                                Repeater {
                                    model: var_.vers ?? []
                                    Pulsante { required property var modelData; testo: modelData.versione; onPremuto: ins.installa(var_.modelData, modelData.versione) }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Consigliati: il catalogo di CielOS ──
        Flickable {
            visible: ins.scheda === "consigliati"
            width: parent.width; height: parent.height - y
            clip: true; contentHeight: cons.implicitHeight + 10
            boundsBehavior: Flickable.StopAtBounds
            Consigliati { id: cons; width: parent.width }
        }

        // ── Rimuovi: gli installati che contengono quelle lettere ──
        Row {
            visible: ins.scheda === "rimuovi" && ins.installati.length > 0
            spacing: 8
            Pulsante { testo: Lingua.t("Tutti"); onPremuto: ins.esclusi = ({}) }
            Pulsante { testo: Lingua.t("Nessuno"); onPremuto: { const e = {}; ins.installati.forEach(v => e[v.fonte + ":" + v.id] = true); ins.esclusi = e; } }
            Pulsante { testo: Lingua.t("Tutti gli installati"); icona: "apps"; onPremuto: ins.elenca("") }
            Pulsante { testo: ins.sicuro ? Lingua.t("Sicuro? Tolgo %1 programmi", ins.daTogliere.length) : Lingua.t("Togli i selezionati (%1)", ins.daTogliere.length)
                       pericolo: true; pieno: ins.sicuro; attivo: ins.daTogliere.length > 0; onPremuto: ins.togli() }
        }
        ListView {
            id: listaR
            visible: ins.scheda === "rimuovi"
            width: parent.width; height: parent.height - y
            clip: true; spacing: 4
            model: ins.installati
            boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle {
                id: ri
                required property var modelData
                readonly property string k: modelData.fonte + ":" + modelData.id
                readonly property bool spuntato: !modelData.protetto && !ins.esclusi[k]
                width: listaR.width; height: 40; radius: 10
                color: tr2.containsMouse && !modelData.protetto ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.1) : Qt.rgba(1, 1, 1, 0.03)
                Row {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    spacing: 10
                    Text { text: ri.modelData.protetto ? "lock" : ri.spuntato ? "check_box" : "check_box_outline_blank"
                           font.family: Tema.icone; font.pixelSize: 20; color: ri.modelData.protetto ? Tema.tenue : Tema.oro
                           anchors.verticalCenter: parent.verticalCenter }
                    Text { width: 70; text: ins.nomeFonte(ri.modelData).split(" · ")[0]; color: ins.coloreFonte(ri.modelData.fonte); font.family: Tema.font; font.pixelSize: 12
                           anchors.verticalCenter: parent.verticalCenter }
                    Text { text: ri.modelData.nome; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: ri.modelData.versione; color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: ri.modelData.protetto ? Lingua.t("vitale: non si toglie") : !ri.modelData.esplicito ? Lingua.t("dipendenza") : ""
                           color: Tema.tenue; font.family: Tema.font; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea {
                    id: tr2; anchors.fill: parent; hoverEnabled: true; enabled: !ri.modelData.protetto; cursorShape: Qt.PointingHandCursor
                    onClicked: { const e = Object.assign({}, ins.esclusi); e[ri.k] = ri.spuntato; ins.esclusi = e; ins.sicuro = false; }
                }
            }
        }
    }
}
