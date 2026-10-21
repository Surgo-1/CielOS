// Il monitor di sistema di CielOS: una finestra normale. Tre pagine:
//   Panoramica  processore (ogni core: uso, frequenza, temperatura), memoria, scheda video, rete, dischi, con i
//               grafici dell'ultimo minuto
//   Processi    quelli che usano di più; si ordinano per CPU o memoria; i tuoi si chiudono (due clic)
//   Sensori     tutte le temperature, ventole e consumi del PC; ognuno si può mettere nella barra
// Il motore è cielmonitor (una riga JSON al secondo, solo finché la finestra è aperta). Si apre con ciel-monitor,
// dal lanciatore («Monitor di sistema») o dalla schedina del sistema nella barra.
//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import qs.servizi

ShellRoot {
    id: app
    property var dati: null
    property int pagina: Math.max(0, Math.min(2, Number(Quickshell.env("MONITOR_PAGINA") || 0) || 0))
    property string ordine: "cpu"
    property bool discendente: true          // dal più grande al più piccolo (come Task Manager); sul nome, dalla A
    property string cerca: ""                // il filtro dei processi: nome o PID, mentre scrivi
    property int daChiudere: -1
    property var storia: ({ cpu: [], mem: [], gpu: [], giu: [], su: [] })
    property var sensori: []
    property var inBarra: []                       // gli id dei sensori scelti per la barra
    readonly property string fileSensori: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/cielos/sensori.json"

    function aggiungi(nome, v) {
        const s = Object.assign({}, storia);
        s[nome] = (s[nome] || []).concat([v]).slice(-60);
        storia = s;
    }
    // i processi come li vuole chi guarda: filtrati dalla ricerca e ordinati per la colonna scelta (su o giù)
    function elenco() {
        if (!dati) return [];
        const q = cerca.trim().toLowerCase();
        const l = dati.processi.filter(p => !q || p.nome.toLowerCase().includes(q) || String(p.pid).includes(q));
        const k = ordine === "memoria" || ordine === "pid" || ordine === "nome" ? ordine : "cpu";
        l.sort((a, b) => {
            const r = k === "nome" ? a.nome.localeCompare(b.nome) : (a[k] ?? 0) - (b[k] ?? 0);
            return discendente ? -r : r;
        });
        return l;
    }
    function ordina(k) {
        if (ordine === k) discendente = !discendente;
        else { ordine = k; discendente = k !== "nome"; }
    }
    function gb(b) { return b == null ? "–" : (b / 2 ** 30).toFixed(1).replace(".", Lingua.virgola) + " GB"; }
    function mb(b) { return b == null ? "–" : (b / 2 ** 20).toFixed(0) + " MB"; }
    function velocita(b) {
        if (b < 1024) return b.toFixed(0) + " B/s";
        if (b < 1024 ** 2) return (b / 1024).toFixed(0) + " KB/s";
        return (b / 1024 ** 2).toFixed(1).replace(".", Lingua.virgola) + " MB/s";
    }
    function caldo(t) { return t == null ? Tema.tenue : t >= 85 ? Tema.allarme : t >= 70 ? "#ffb347" : Tema.oro; }
    function durata(s) {
        const g = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return (g ? g + Lingua.t(" g ") : "") + (h ? h + " h " : "") + m + " min";
    }

    Process {
        id: motore
        running: true
        command: [Percorsi.bin("cielmonitor"), "segui", "1"]
        stdout: SplitParser {
            onRead: riga => {
                let d;
                try { d = JSON.parse(riga); } catch (e) { return; }
                app.dati = d;
                app.aggiungi("cpu", d.cpu.uso);
                app.aggiungi("mem", 100 * d.memoria.usata / Math.max(1, d.memoria.totale));
                if (d.gpu.length && d.gpu[0].uso != null) app.aggiungi("gpu", d.gpu[0].uso);
                let giu = 0, su = 0;
                for (const k in d.rete) { giu += d.rete[k].ricevuti; su += d.rete[k].inviati; }
                app.aggiungi("giu", giu); app.aggiungi("su", su);
            }
        }
    }
    // i sensori: ogni 2 s, solo sulla loro pagina
    Process {
        id: leggiSensori
        command: [Percorsi.bin("cielimposta"), "sensori"]
        stdout: StdioCollector { onStreamFinished: { try { app.sensori = JSON.parse(text).sensori; } catch (e) {} } }
    }
    Timer { running: app.pagina === 2; triggeredOnStart: true; interval: 2000; repeat: true
            onTriggered: if (!leggiSensori.running) leggiSensori.running = true }
    FileView {
        id: scelti
        path: app.fileSensori
        printErrors: false
        onLoaded: { try { app.inBarra = (JSON.parse(text()).barra ?? []).map(s => s.id); } catch (e) {} }
    }
    function alternaBarra(s) {
        let elenco = [];
        try { elenco = JSON.parse(scelti.text()).barra ?? []; } catch (e) {}
        if (elenco.some(x => x.id === s.id)) elenco = elenco.filter(x => x.id !== s.id);
        else elenco.push({ id: s.id, nome: s.nome, chip: s.chip, tipo: s.tipo, percorso: s.percorso, divisore: s.divisore ?? 1, unita: s.unita });
        scelti.setText(JSON.stringify({ barra: elenco }, null, 2));
        app.inBarra = elenco.map(x => x.id);
    }
    Process { id: chiudi }

    FloatingWindow {
        title: Lingua.t("Monitor di sistema")
        implicitWidth: 1080
        implicitHeight: 760
        color: Tema.fondo
        visible: true
        onVisibleChanged: if (!visible) Qt.quit()
        Shortcut { sequence: "Escape"; onActivated: Qt.quit() }

        // il fondo: una notte appena più chiara su cui poggiano schede e riquadri
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: Tema.fondoAlto }
                GradientStop { position: 0.35; color: Tema.fondo }
                GradientStop { position: 1; color: Tema.scurisci(Tema.fondo, 0.15) }
            }
        }
        Rectangle {                           // la barra in cima
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 64
            color: Tema.conAlfa(Tema.testo, 0.03)
            Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Tema.bordoTenue }
        }
        Rectangle { x: 26; y: 62; width: 64; height: 2; radius: 1; color: Tema.oro }

        // in cima: le pagine
        Row {
            id: schede
            x: 18; y: 14
            spacing: 8
            Repeater {
                model: [["monitoring", Lingua.t("Panoramica")], ["list", Lingua.t("Processi")], ["thermostat", Lingua.t("Sensori")]]
                Rectangle {
                    required property var modelData
                    required property int index
                    width: riga.implicitWidth + 30; height: 38; radius: 19
                    color: app.pagina === index ? Tema.accentoMedio
                         : tocco.containsMouse ? Tema.accentoSoft : "transparent"
                    border.width: 1
                    border.color: app.pagina === index ? Tema.alfa(Tema.oro, 0.55) : "transparent"
                    Behavior on color { ColorAnimation { duration: Tema.durata } }
                    Row {
                        id: riga
                        anchors.centerIn: parent; spacing: 8
                        Text { text: modelData[0]; font.family: Tema.icone; font.pixelSize: 18
                               color: app.pagina === index ? Tema.oro : Tema.oroChiaro }
                        Text { text: modelData[1]; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14
                               font.weight: app.pagina === index ? Font.Medium : Font.Normal
                               anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { id: tocco; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: app.pagina = index }
                }
            }
        }
        Text {
            anchors { right: parent.right; rightMargin: 20; verticalCenter: schede.verticalCenter }
            text: app.dati ? Lingua.t("acceso da %1 · carico %2", app.durata(app.dati.acceso_da), app.dati.cpu.carico.join(" ")) : Lingua.t("Leggo…")
            color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
        }

        Flickable {
            id: scorri
            anchors { left: parent.left; right: parent.right; top: schede.bottom; bottom: parent.bottom; margins: 18; topMargin: 14 }
            contentHeight: contenuto.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Item {
                id: contenuto
                width: parent.width
                implicitHeight: ([panoramica, processi, pSensori][app.pagina] ?? panoramica).implicitHeight

                // ── Panoramica ────────────────────────────────────────────────────────────────────────────────
                Column {
                    id: panoramica
                    visible: app.pagina === 0
                    width: parent.width
                    spacing: 14
                    Grid {
                        width: parent.width
                        columns: 4
                        spacing: 12
                        readonly property real lato: (width - 36) / 4
                        Riquadro {
                            width: parent.lato; height: 150
                            titolo: Lingua.t("Processore")
                            valore: app.dati ? Math.round(app.dati.cpu.uso) + "%" : "–"
                            dettaglio: app.dati ? (app.dati.cpu.temp != null ? Math.round(app.dati.cpu.temp) + " °C · " : "") + app.dati.cpu.core.length + " thread" : ""
                            storia: app.storia.cpu
                        }
                        Riquadro {
                            width: parent.lato; height: 150
                            titolo: Lingua.t("Memoria")
                            valore: app.dati ? app.gb(app.dati.memoria.usata) : "–"
                            dettaglio: app.dati ? Lingua.t("di %1", app.gb(app.dati.memoria.totale)) + (app.dati.memoria.swap_totale ? " · swap " + app.gb(app.dati.memoria.swap_usata) : "") : ""
                            storia: app.storia.mem
                            colore: "#7fd0ff"
                        }
                        Riquadro {
                            readonly property var g: app.dati && app.dati.gpu.length ? app.dati.gpu[0] : null
                            width: parent.lato; height: 150
                            titolo: Lingua.t("Scheda video")
                            valore: g && g.uso != null ? Math.round(g.uso) + "%" : g ? "–" : Lingua.t("nessuna")
                            dettaglio: g ? [g.temp != null ? Math.round(g.temp) + " °C" : "", g.vram_totale ? app.mb(g.vram_usata) + Lingua.t(" di ") + app.gb(g.vram_totale) : "",
                                            g.watt != null ? Math.round(g.watt) + " W" : ""].filter(x => x).join(" · ") : ""
                            storia: app.storia.gpu
                            colore: "#b18cff"
                        }
                        Riquadro {
                            width: parent.lato; height: 150
                            titolo: Lingua.t("Rete")
                            valore: app.storia.giu.length ? "↓ " + app.velocita(app.storia.giu.slice(-1)[0]) : "–"
                            dettaglio: app.storia.su.length ? "↑ " + app.velocita(app.storia.su.slice(-1)[0]) : ""
                            storia: app.storia.giu
                            massimo: Math.max(1024, ...app.storia.giu)
                            colore: "#7fe0a8"
                        }
                    }

                    // ogni core
                    Text { text: Lingua.t("Core per core"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.Medium }
                    Text {
                        width: parent.width; wrapMode: Text.Wrap
                        text: app.dati ? app.dati.cpu.nome + (app.dati.cpu.core.some(c => c.temp != null) ? "" :
                              Lingua.t(" · questo processore non dà la temperatura di ogni core") + (Object.keys(app.dati.cpu.temp_ccd).length ? Lingua.t(" (solo per gruppo di core, sotto)") : "")) : ""
                        color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
                    }
                    Grid {
                        width: parent.width
                        columns: Math.max(4, Math.min(8, Math.floor(width / 120)))
                        spacing: 8
                        Repeater {
                            model: app.dati ? app.dati.cpu.core : []
                            Rectangle {
                                required property var modelData
                                width: (parent.width - (parent.columns - 1) * 8) / parent.columns; height: 74
                                radius: 10
                                color: Qt.rgba(1, 1, 1, 0.04)
                                border.color: Qt.rgba(1, 1, 1, 0.07)
                                Rectangle {                      // l'uso: la barra che riempie dal basso
                                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 1 }
                                    height: (parent.height - 2) * modelData.uso / 100
                                    radius: 9
                                    color: Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.22)
                                    Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                                }
                                Column {
                                    x: 10; y: 8; spacing: 1
                                    Text { text: "CPU " + modelData.n + (modelData.core !== modelData.n ? " · core " + modelData.core : "")
                                           color: Tema.tenue; font.family: Tema.font; font.pixelSize: 11 }
                                    Text { text: Math.round(modelData.uso) + "%"; color: Tema.testo; font.family: Tema.font; font.pixelSize: 18; font.weight: Font.Medium }
                                    Text {
                                        text: (modelData.mhz ? (modelData.mhz / 1000).toFixed(2).replace(".", Lingua.virgola) + " GHz" : "") +
                                              (modelData.temp != null ? "  " + Math.round(modelData.temp) + " °C" : "")
                                        color: app.caldo(modelData.temp); font.family: Tema.font; font.pixelSize: 11
                                    }
                                }
                            }
                        }
                    }
                    Row {
                        visible: app.dati && Object.keys(app.dati.cpu.temp_ccd).length > 0
                        spacing: 16
                        Repeater {
                            model: app.dati ? Object.keys(app.dati.cpu.temp_ccd) : []
                            Text { required property string modelData
                                   text: Lingua.t("Gruppo %1: ", modelData.replace("ccd", "")) + Math.round(app.dati.cpu.temp_ccd[modelData]) + " °C"
                                   color: app.caldo(app.dati.cpu.temp_ccd[modelData]); font.family: Tema.font; font.pixelSize: 13 }
                        }
                    }

                    // dischi
                    Text { text: Lingua.t("Dischi"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.Medium }
                    Repeater {
                        model: app.dati ? app.dati.dischi.volumi : []
                        Item {
                            required property var modelData
                            width: panoramica.width; height: 34
                            readonly property real pieno: 1 - modelData.libero / Math.max(1, modelData.totale)
                            Text { id: dn; width: 240; elide: Text.ElideMiddle; anchors.verticalCenter: parent.verticalCenter
                                   text: modelData.punto + "  (" + modelData.fs + ")"; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
                            Rectangle {
                                anchors { left: dn.right; leftMargin: 12; right: dl.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                                height: 8; radius: 4; color: Qt.rgba(1, 1, 1, 0.08)
                                Rectangle { width: parent.width * parent.parent.pieno; height: parent.height; radius: 4
                                            color: parent.parent.pieno > 0.9 ? Tema.allarme : Tema.oro }
                            }
                            Text { id: dl; anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                   text: Lingua.t("%1 liberi di %2", app.gb(modelData.libero), app.gb(modelData.totale))
                                   color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12 }
                        }
                    }
                }

                // ── Processi ──────────────────────────────────────────────────────────────────────────────────
                Column {
                    id: processi
                    visible: app.pagina === 1
                    width: parent.width
                    spacing: 10

                    // la ricerca, quella che mancava: filtra mentre scrivi su nome e PID; Esc svuota.
                    Rectangle {
                        width: processi.width; height: 40; radius: 20
                        color: Tema.conAlfa(Tema.testo, 0.04)
                        border.width: 1
                        border.color: campoCerca.activeFocus ? Tema.alfa(Tema.oro, 0.55) : Tema.bordoTenue
                        Text { id: lente; x: 14; anchors.verticalCenter: parent.verticalCenter
                               text: "search"; font.family: Tema.icone; font.pixelSize: 18; color: Tema.tenue }
                        Text {
                            visible: !campoCerca.text
                            anchors { left: lente.right; leftMargin: 10; verticalCenter: parent.verticalCenter }
                            text: Lingua.t("Cerca un processo (nome o PID)")
                            color: Tema.tenue; font.family: Tema.font; font.pixelSize: 14
                        }
                        TextInput {
                            id: campoCerca
                            anchors { left: lente.right; leftMargin: 10; right: pulisci.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            text: app.cerca
                            onTextChanged: app.cerca = text
                            color: Tema.testo; font.family: Tema.font; font.pixelSize: 14
                            selectionColor: Tema.accentoMedio; selectedTextColor: Tema.testo
                            clip: true
                            Keys.onEscapePressed: { text = ""; app.cerca = ""; }
                        }
                        Rectangle {
                            id: pulisci
                            visible: campoCerca.text.length > 0
                            width: 26; height: 26; radius: 13
                            anchors { right: parent.right; rightMargin: 7; verticalCenter: parent.verticalCenter }
                            color: toccoPulisci.containsMouse ? Tema.accentoSoft : "transparent"
                            Text { anchors.centerIn: parent; text: "close"; font.family: Tema.icone; font.pixelSize: 16; color: Tema.tenue }
                            MouseArea { id: toccoPulisci; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: { cerca.text = ""; app.cerca = ""; } }
                        }
                    }

                    // l'intestazione: si clicca su una colonna per ordinare, di nuovo per girarla (▲ / ▼)
                    Rectangle {
                        width: processi.width; height: 30; radius: 7
                        color: Tema.conAlfa(Tema.testo, 0.035)
                        Repeater {
                            model: [["nome", Lingua.t("Processo"), 10, 280, Text.AlignLeft],
                                    ["pid", "PID", 300, 80, Text.AlignLeft],
                                    ["cpu", "CPU", 390, 110, Text.AlignRight],
                                    ["memoria", Lingua.t("Memoria"), 510, 110, Text.AlignRight]]
                            Item {
                                required property var modelData
                                x: modelData[2]; width: modelData[3]; height: parent.height
                                Text {
                                    width: parent.width; anchors.verticalCenter: parent.verticalCenter
                                    horizontalAlignment: modelData[4]
                                    text: modelData[1] + (app.ordine === modelData[0] ? (app.discendente ? " ▾" : " ▴") : "")
                                    color: app.ordine === modelData[0] ? Tema.oro : Tema.tenue
                                    font.family: Tema.font; font.pixelSize: 11; font.letterSpacing: 1
                                    font.capitalization: Font.AllUppercase
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: app.ordina(modelData[0]) }
                            }
                        }
                    }
                    Repeater {
                        model: app.elenco()
                        Rectangle {
                            required property var modelData
                            required property int index
                            width: processi.width; height: 34; radius: 8
                            color: sopra.containsMouse ? Tema.accentoSoft
                                 : index % 2 ? Tema.conAlfa(Tema.testo, 0.018) : "transparent"
                            MouseArea { id: sopra; anchors.fill: parent; hoverEnabled: true }
                            Text { x: 10; width: 280; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter
                                   text: modelData.nome; color: modelData.mio ? Tema.testo : Tema.tenue; font.family: Tema.font; font.pixelSize: 13 }
                            Text { x: 300; width: 80; anchors.verticalCenter: parent.verticalCenter; text: modelData.pid
                                   color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12 }
                            Text { x: 390; width: 110; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter
                                   text: modelData.cpu.toFixed(1).replace(".", Lingua.virgola) + "%"; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
                            Text { x: 510; width: 110; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter
                                   text: app.mb(modelData.memoria); color: Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
                            Rectangle {
                                visible: modelData.mio
                                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                readonly property bool conferma: app.daChiudere === modelData.pid
                                width: tc.implicitWidth + 22; height: 26; radius: 13
                                color: conferma ? Tema.allarme : Qt.rgba(1, 1, 1, 0.07)
                                Text { id: tc; anchors.centerIn: parent; text: parent.conferma ? Lingua.t("Sicuro?") : Lingua.t("Chiudi")
                                       color: Tema.testo; font.family: Tema.font; font.pixelSize: 12 }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (parent.conferma) { chiudi.command = [Percorsi.bin("cielmonitor"), "ferma", String(modelData.pid)]; chiudi.running = true; app.daChiudere = -1; }
                                        else app.daChiudere = modelData.pid;
                                    }
                                }
                            }
                        }
                    }

                    // niente da mostrare: dirlo, invece di una tabella vuota senza spiegazione
                    Text {
                        visible: !!app.dati && app.elenco().length === 0
                        width: parent.width; horizontalAlignment: Text.AlignHCenter; topPadding: 16
                        text: Lingua.t("Nessun processo si chiama così. Esc svuota la ricerca.")
                        color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13
                    }

                    // il conto, come la barra di stato del Task Manager: quanti sono, quanto pesano
                    Text {
                        width: parent.width
                        text: app.dati ? Lingua.t("%1 processi su %2 · CPU %3 % · memoria %4",
                                                  app.elenco().length, app.dati.processi.length,
                                                  Math.round(app.dati.processi.reduce((s, p) => s + p.cpu, 0)),
                                                  app.gb(app.dati.processi.reduce((s, p) => s + p.memoria, 0))) : ""
                        color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
                    }
                }

                // ── Sensori ───────────────────────────────────────────────────────────────────────────────────
                Column {
                    id: pSensori
                    visible: app.pagina === 2
                    width: parent.width
                    spacing: 4
                    Text {
                        width: parent.width; wrapMode: Text.Wrap
                        text: Lingua.t("Tutti i sensori del PC. Accendi «nella barra» per vedere quel valore sempre, sotto l'icona del sistema.")
                        color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13
                    }
                    Item { width: 1; height: 6 }
                    Repeater {
                        model: app.sensori
                        Rectangle {
                            required property var modelData
                            readonly property bool scelto: app.inBarra.includes(modelData.id)
                            width: pSensori.width; height: 42; radius: Tema.raggioPiccolo + 2
                            color: Tema.conAlfa(Tema.testo, 0.028)
                            border.width: 1
                            border.color: Tema.bordoTenue
                            Rectangle { x: 0; anchors.verticalCenter: parent.verticalCenter; width: 2; height: 18; radius: 1
                                        color: modelData.tipo === "temp" ? app.caldo(modelData.valore)
                                             : modelData.tipo === "power" ? Tema.oro : Tema.tenue }
                            Text { x: 14; width: 218; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter
                                   text: modelData.chip; color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12 }
                            Text { x: 240; width: 220; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter
                                   text: modelData.nome; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
                            Text { x: 470; anchors.verticalCenter: parent.verticalCenter
                                   text: String(modelData.valore).replace(".", Lingua.virgola) + " " + modelData.unita
                                   color: modelData.tipo === "temp" ? app.caldo(modelData.valore) : Tema.testo
                                   font.family: Tema.font; font.pixelSize: 14; font.weight: Font.Medium }
                            Rectangle {
                                anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                width: tb.implicitWidth + 26; height: 28; radius: 14
                                color: parent.scelto ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.25) : Qt.rgba(1, 1, 1, 0.06)
                                Text { id: tb; anchors.centerIn: parent; text: parent.parent.scelto ? Lingua.t("nella barra ✓") : Lingua.t("nella barra")
                                       color: Tema.testo; font.family: Tema.font; font.pixelSize: 12 }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: app.alternaBarra(modelData) }
                            }
                        }
                    }
                }
            }
        }

        // la striscia che dice dove sei nella pagina, quando c'è altro sotto
        Rectangle {
            readonly property real resto: Math.max(1, scorri.contentHeight - scorri.height)
            visible: scorri.contentHeight > scorri.height + 1
            x: scorri.x + scorri.width + 6
            y: scorri.y + (scorri.height - height) * Math.max(0, Math.min(1, scorri.contentY / resto))
            width: 4
            height: Math.max(42, scorri.height * scorri.height / Math.max(1, scorri.contentHeight))
            radius: 2
            color: Tema.alfa(Tema.testo, 0.2)
        }
    }
}
