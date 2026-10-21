// CielGiochi: i giochi che hai su Steam, con ProtonDB e l'anti-cheat su Linux, dentro CielOS.
// A sinistra i giochi (cerca per nome: è la prima cosa che si vuole fare con cento giochi in libreria); a destra
// il giudizio di ProtonDB, l'anti-cheat (Are We Anti-Cheat Yet?: se è «no» la scheda video non conta), i requisiti
// minimi e consigliati di Steam, e cosa dicono di questo PC (RAM, VRAM, disco: i numeri veri; CPU e scheda video si
// mostrano da confrontare, perché un confronto tra nomi sarebbe una bugia). «ProtonDB» e «Anti-cheat» aprono le loro
// pagine in CielFox. Al posto di «Can You RUN It» — che misura un PC Windows e vuole il suo componente nel browser —
// c'è la domanda che conta su Linux.
// I dati li prende cielgiochi (che tiene la cache: la seconda volta è istantaneo). Si apre con ciel-giochi.
//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import qs.servizi

ShellRoot {
    id: app
    property var giochi: []
    property var hardware: null
    property string steam: ""
    property string cerca: ""
    property int scelto: -1
    property var proton: ({})              // appid → giudizio di ProtonDB (arriva quando si sceglie il gioco)
    property var requisiti: null
    property bool staCaricando: false      // l'elenco
    property bool staChiedendo: false      // ProtonDB e requisiti del gioco scelto
    property int dettagliDi: -1            // l'appid di cui stanno arrivando ProtonDB e requisiti
    property string messaggio: ""
    property bool errore: false
    readonly property var visibili: {
        const q = cerca.trim().toLowerCase();
        return app.giochi.filter(g => !q || g.nome.toLowerCase().includes(q));
    }
    readonly property var gioco: scelto >= 0 && scelto < visibili.length ? visibili[scelto] : null

    function avvisa(t, e) { messaggio = t; errore = !!e; }

    function caricaElenco() {
        if (elenco.running) return;
        staCaricando = true;
        elenco.running = true;
    }
    function scegli(i) {
        scelto = i;
        caricaDettagli(gioco);
    }
    // ProtonDB e requisiti seguono sempre il gioco scelto: anche quando la ricerca cambia la lista e il primo
    // risultato diventa un altro (prima la scheda restava quella del gioco precedente).
    function caricaDettagli(g) {
        if (!g) { requisiti = null; dettagliDi = -1; staChiedendo = false; return; }
        if (dettagliDi === g.appid && (chiediProton.running || chiediRequisiti.running)) return;
        dettagliDi = g.appid;
        proton = Object.assign({}, proton);
        requisiti = null;
        staChiedendo = true;
        chiediProton.command = [Percorsi.bin("cielgiochi"), "proton", g.appid, "--json"];
        chiediProton.running = true;
        chiediRequisiti.command = [Percorsi.bin("cielgiochi"), "requisiti", g.appid, "--json"];
        chiediRequisiti.running = true;
    }
    function apriProton() {
        if (gioco) Quickshell.execDetached([Percorsi.bin("cielfox"), app.proton[gioco.appid]?.pagina ?? ("https://www.protondb.com/app/" + gioco.appid)]);
    }
    function apriAntiCheat() {
        if (!gioco) return;
        avvisa(Lingua.t("Cerco l'anti-cheat di «%1»…", gioco.nome));
        apri.running = true;
    }
    function tonoAntiCheat(t) {
        return ({ ok: "#7fe0a8", limite: "#ffb347", no: Tema.allarme })[t] ?? Tema.tenue;
    }
    function colore(t) {
        return ({ platinum: "#a7d8e8", gold: "#ffbf3f", silver: "#c8d0d8", bronze: "#c98b5a",
                  borked: "#ff6b6b", pending: Tema.tenue, native: "#7fe0a8" })[t] ?? Tema.tenue;
    }
    readonly property var nomiRequisiti: ({ os: "Sistema operativo", cpu: "Processore", ram: "Memoria", gpu: "Scheda video",
                                            directx: "DirectX/Vulkan", disco: "Spazio su disco", note: "Note" })
    readonly property var nomiControlli: ({ ok: ["check_circle", "#7fe0a8"], no: ["cancel", "#ff6b6b"], "?": ["help", "#ffb347"] })

    Process {
        id: elenco
        command: [Percorsi.bin("cielgiochi"), "elenco", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    app.giochi = d.giochi ?? [];
                    app.hardware = d.hardware ?? null;
                    app.steam = d.steam ?? "";
                    // «ciel-giochi APPID» apre già su quel gioco
                    const voluto = Quickshell.env("CIEL_GIOCHI_SCELTO") || "";
                    const i = voluto ? app.giochi.findIndex(g => String(g.appid) === voluto) : 0;
                    app.scelto = app.giochi.length ? Math.max(0, i) : -1;
                    if (app.scelto >= 0) Qt.callLater(() => app.scegli(app.scelto));
                    if (!app.giochi.length) app.avvisa(app.steam ? Lingua.t("Nessun gioco installato in %1", app.steam) : Lingua.t("Steam non c'è: CielGiochi guarda le sue librerie."));
                } catch (e) { app.avvisa(Lingua.t("Non riesco a leggere l'elenco dei giochi."), true); }
                app.staCaricando = false;
            }
        }
    }
    Process {
        id: chiediProton
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const p = JSON.parse(text);
                    const m = Object.assign({}, app.proton); m[p.appid] = p; app.proton = m;
                } catch (e) {}
                app.staChiedendo = false;
            }
        }
    }
    Process {
        id: chiediRequisiti
        stdout: StdioCollector {
            onStreamFinished: {
                try { app.requisiti = JSON.parse(text); } catch (e) { app.requisiti = null; }
                app.staChiedendo = false;
            }
        }
    }
    Process {
        id: apri
        command: [Percorsi.bin("cielgiochi"), "apri", ""]
        onRunningChanged: if (!running && gioco) app.avvisa(Lingua.t("Apro l'anti-cheat di %1 in CielFox.", gioco.nome))
    }
    onGiocoChanged: {
        if (gioco) {
            apri.command = [Percorsi.bin("cielgiochi"), "apri", gioco.appid];
            caricaDettagli(gioco);
        } else {
            requisiti = null;
            dettagliDi = -1;
            staChiedendo = false;
        }
    }
    Component.onCompleted: { caricaElenco(); Qt.callLater(() => campo.forceActiveFocus()); }

    // per le prove: quando la finestra ha davvero i dati lo dice e si chiude (CIEL_GIOCHI_PROVA=1)
    readonly property bool prova: Quickshell.env("CIEL_GIOCHI_PROVA") === "1"
    Timer {
        running: app.prova; interval: 400; repeat: true
        onTriggered: {
            if (app.staCaricando || !app.requisiti || !app.gioco) return;
            console.log("CIELGIOCHI giochi=" + app.giochi.length + " scelto=" + app.gioco.nome +
                        " proton=" + (app.proton[app.gioco.appid]?.giudizio ?? "-") +
                        " anticheat=" + (app.requisiti.anticheat?.stato ?? "-") +
                        " controlli=" + (app.requisiti.confronto?.controlli?.length ?? 0));
            Qt.quit();
        }
    }

    FloatingWindow {
        id: finestra
        title: "CielGiochi"
        implicitWidth: 1120
        implicitHeight: 700
        color: Tema.fondo
        visible: true
        onVisibleChanged: if (!visible) Qt.quit()

        Rectangle {
            anchors.fill: parent
            z: -1
            gradient: Gradient {
                GradientStop { position: 0; color: Tema.fondoAlto }
                GradientStop { position: 0.45; color: Tema.fondo }
                GradientStop { position: 1; color: Tema.scurisci(Tema.fondo, 0.12) }
            }
        }
        Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 64
                    color: Tema.conAlfa(Tema.testo, 0.02)
                    Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Tema.bordoTenue } }

        Text { x: 22; y: 18; text: "sports_esports"; font.family: Tema.icone; font.pixelSize: 26; color: Tema.oro }
        Text { x: 58; y: 14; text: "CielGiochi"; color: Tema.testo; font.family: Tema.font; font.pixelSize: 18; font.weight: Font.DemiBold }
        Text { x: 58; y: 38; text: Lingua.t("ProtonDB e l'anti-cheat su Linux, dentro CielOS"); color: Tema.tenue; font.family: Tema.font; font.pixelSize: 11 }

        // la ricerca: con cento giochi in libreria si cerca, non si scorre
        Rectangle {
            anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
            width: 300; height: 36; radius: 18
            color: Qt.rgba(1, 1, 1, 0.05)
            border.width: 1; border.color: campo.activeFocus ? Tema.oro : Tema.bordo
            Text { id: lente; x: 12; anchors.verticalCenter: parent.verticalCenter; text: "search"; font.family: Tema.icone; font.pixelSize: 18; color: Tema.tenue }
            TextInput {
                id: campo
                anchors { left: lente.right; leftMargin: 8; right: aggirati.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                color: Tema.testo; font.family: Tema.font; font.pixelSize: 13; clip: true; selectByMouse: true
                onTextChanged: { app.cerca = text; app.scelto = app.visibili.length ? 0 : -1; }
                Keys.onDownPressed: app.scelto = Math.min(app.visibili.length - 1, app.scelto + 1)
                Keys.onUpPressed: app.scelto = Math.max(0, app.scelto - 1)
                Keys.onEscapePressed: { text = ""; app.cerca = ""; }
                Text { visible: !parent.text; anchors.verticalCenter: parent.verticalCenter; text: Lingua.t("Cerca un gioco"); color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13 }
            }
            Text { id: aggirati; visible: campo.text !== ""; anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                   text: "close"; font.family: Tema.icone; font.pixelSize: 16; color: Tema.tenue
                   MouseArea { anchors.fill: parent; anchors.margins: -5; onClicked: { campo.text = ""; campo.forceActiveFocus(); } } }
        }

        // ── a sinistra: i giochi
        Rectangle {
            id: lista
            anchors { left: parent.left; top: parent.top; topMargin: 64; bottom: piede.top }
            width: 330
            color: Tema.conAlfa(Tema.fondo, 0.55)
            Rectangle { anchors { right: parent.right; top: parent.top; bottom: parent.bottom } width: 1; color: Tema.bordoTenue }
            ListView {
                anchors { fill: parent; margins: 8 }
                clip: true
                model: app.visibili
                spacing: 4
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: ListView.view.width; height: 54; radius: Tema.raggioPiccolo + 4
                    color: index === app.scelto ? Tema.accentoSoft : area.containsMouse ? Tema.biancoTenue : "transparent"
                    border.width: index === app.scelto ? 1 : 0; border.color: Tema.alfa(Tema.oro, 0.24)
                    Text { id: punto; x: 12; anchors.verticalCenter: parent.verticalCenter; text: "sports_esports"
                           font.family: Tema.icone; font.pixelSize: 20; color: Tema.oroChiaro }
                    Column {
                        anchors { left: punto.right; leftMargin: 10; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        Text { width: parent.width; elide: Text.ElideRight; text: modelData.nome; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
                        Row {
                            spacing: 6
                            Text { text: app.proton[modelData.appid]?.giudizio ?? (modelData.proton?.giudizio ?? "—")
                                   color: app.colore(app.proton[modelData.appid]?.tier ?? modelData.proton?.tier)
                                   font.family: Tema.font; font.pixelSize: 11; font.weight: Font.Medium }
                            Text { text: Lingua.t("%1 GB", String(modelData.giga).replace(".", Lingua.virgola)); color: Tema.tenue; font.family: Tema.font; font.pixelSize: 11 }
                        }
                    }
                    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: app.scegli(index) }
                }
            }
            Text { anchors.centerIn: parent; width: parent.width - 40; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                   visible: app.staCaricando; text: Lingua.t("Guardo le librerie di Steam…"); color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12 }
            Text { anchors.centerIn: parent; width: parent.width - 40; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                   visible: !app.staCaricando && !app.giochi.length; text: Lingua.t("Nessun gioco di Steam. Installa un gioco e riapri CielGiochi.")
                   color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12 }
            Text { anchors.centerIn: parent; width: parent.width - 40; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                   visible: !app.staCaricando && app.giochi.length > 0 && !app.visibili.length
                   text: Lingua.t("Nessun gioco si chiama così. Esc svuota la ricerca.")
                   color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12 }
        }

        // ── a destra: il gioco scelto
        Flickable {
            id: dettaglio
            anchors { left: lista.right; right: parent.right; top: lista.top; bottom: piede.top }
            contentHeight: colonna.implicitHeight + 40
            clip: true
            Column {
                id: colonna
                x: 22; y: 18; width: dettaglio.width - 44
                spacing: 14
                Text { width: parent.width; text: app.gioco ? app.gioco.nome : Lingua.t("Scegli un gioco"); elide: Text.ElideRight
                       color: Tema.testo; font.family: Tema.font; font.pixelSize: 22; font.weight: Font.DemiBold }
                Row {
                    spacing: 8
                    visible: !!app.gioco
                    component Tasto: Rectangle {
                        id: t
                        property string icona
                        property string testo
                        signal premuto()
                        height: 34; radius: 10; width: riga.width + 26
                        color: ma.containsMouse ? Tema.accentoSoft : Tema.biancoTenue
                        border.width: 1; border.color: Tema.bordoTenue
                        Row {
                            id: riga
                            anchors.centerIn: parent
                            spacing: 6
                            Text { text: t.icona; font.family: Tema.icone; font.pixelSize: 17; color: Tema.oroChiaro; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: t.testo; color: Tema.testo; font.family: Tema.font; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: t.premuto() }
                    }
                    Tasto { icona: "open_in_new"; testo: "ProtonDB"; onPremuto: app.apriProton() }
                    Tasto { icona: "shield"; testo: Lingua.t("Anti-cheat su Linux"); onPremuto: app.apriAntiCheat() }
                    Tasto { icona: "refresh"; testo: Lingua.t("Aggiorna"); onPremuto: { app.proton = ({}); app.caricaElenco(); } }
                }

                // ProtonDB e anti-cheat affiancati: sono le due risposte che si cercano insieme
                Row {
                    width: parent.width
                    spacing: 14
                    // ProtonDB
                    Rectangle {
                        width: (parent.width - 14) / 2
                        height: pcol.implicitHeight + 26
                        radius: Tema.raggio + 2
                        color: Tema.conAlfa(Tema.testo, 0.03); border.width: 1; border.color: Tema.bordoTenue
                        Column {
                            id: pcol
                            x: 14; y: 12; width: parent.width - 28
                            spacing: 5
                            Row {
                                spacing: 8
                                Text { text: "ProtonDB"; color: Tema.oro; font.family: Tema.font; font.pixelSize: 11; font.letterSpacing: 1 }
                                Text { visible: app.staChiedendo && !app.proton[app.gioco?.appid]; text: Lingua.t("· chiedo…"); color: Tema.tenue; font.family: Tema.font; font.pixelSize: 11 }
                            }
                            Text {
                                readonly property var p: app.gioco ? app.proton[app.gioco.appid] : null
                                text: p ? (p.giudizio ?? "—") + (p.prove ? Lingua.t(" · %1 prove", p.prove) : "") +
                                          (p.migliore && p.migliore !== p.tier ? Lingua.t(" · il migliore: %1", app.nomiTier(p.migliore)) : "") : "—"
                                color: app.colore(p?.tier); font.family: Tema.font; font.pixelSize: 17; font.weight: Font.DemiBold
                            }
                            Text {
                                readonly property var p: app.gioco ? app.proton[app.gioco.appid] : null
                                visible: !!p?.errore
                                width: parent.width; wrapMode: Text.Wrap
                                text: Lingua.t("ProtonDB non risponde (%1): il giudizio resta quello che c'era.", p?.errore ?? "")
                                color: Tema.tenue; font.family: Tema.font; font.pixelSize: 11
                            }
                            Text {
                                width: parent.width; wrapMode: Text.Wrap
                                text: Lingua.t("Quanto bene gira con Proton (il traduttore di Windows): platino è «come su Windows», rotto è «non parte».")
                                color: Tema.tenue; font.family: Tema.font; font.pixelSize: 11
                            }
                        }
                    }

                    // l'anti-cheat su Linux: è la vera domanda per chi gioca con Proton
                    Rectangle {
                        width: (parent.width - 14) / 2
                        height: acol.implicitHeight + 26
                        radius: Tema.raggio + 2
                        color: Tema.conAlfa(Tema.testo, 0.03); border.width: 1; border.color: Tema.bordoTenue
                        Column {
                            id: acol
                            x: 14; y: 12; width: parent.width - 28
                            spacing: 5
                            Row {
                                spacing: 8
                                Text { text: Lingua.t("Anti-cheat su Linux"); color: Tema.oro; font.family: Tema.font; font.pixelSize: 11; font.letterSpacing: 1 }
                                Text { visible: app.staChiedendo && !app.requisiti; text: Lingua.t("· chiedo…"); color: Tema.tenue; font.family: Tema.font; font.pixelSize: 11 }
                            }
                            Text {
                                readonly property var a: app.requisiti ? app.requisiti.anticheat : null
                                text: !a || a.errore ? "—" : a.trovato ? a.stato : Lingua.t("non c'è nella tabella")
                                color: a && a.trovato ? app.tonoAntiCheat(a.tono) : Tema.tenue
                                font.family: Tema.font; font.pixelSize: 17; font.weight: Font.DemiBold
                            }
                            Text {
                                readonly property var a: app.requisiti ? app.requisiti.anticheat : null
                                visible: !!a && a.trovato && (a.anticheat ?? []).length > 0
                                width: parent.width; wrapMode: Text.Wrap
                                text: a ? (a.anticheat ?? []).join(" · ") + (a.nativo ? Lingua.t(" · il gioco ha anche una versione Linux") : "") : ""
                                color: Tema.testo; font.family: Tema.font; font.pixelSize: 12
                            }
                            Repeater {
                                model: app.requisiti?.anticheat?.note ?? []
                                Text { required property string modelData; width: acol.width; wrapMode: Text.Wrap
                                       text: "· " + modelData; color: Tema.tenue; font.family: Tema.font; font.pixelSize: 11 }
                            }
                            Text {
                                width: parent.width; wrapMode: Text.Wrap
                                text: app.requisiti?.anticheat?.errore
                                      ? Lingua.t("Are We Anti-Cheat Yet? non risponde: %1", app.requisiti.anticheat.errore)
                                      : app.requisiti?.anticheat?.trovato
                                        ? Lingua.t("Se l'anti-cheat non funziona su Linux, il gioco online non parte qualunque sia la tua scheda video. I dati sono di areweanticheatyet.com.")
                                        : Lingua.t("Non ha un anti-cheat, o non è nella tabella: per un gioco in single player non è un problema. I dati sono di areweanticheatyet.com.")
                                color: Tema.tenue; font.family: Tema.font; font.pixelSize: 11
                            }
                        }
                    }
                }

                // i requisiti e il confronto con questo PC
                Rectangle {
                    width: parent.width
                    height: rcol.implicitHeight + 26
                    radius: Tema.raggio + 2
                    color: Tema.conAlfa(Tema.testo, 0.03); border.width: 1; border.color: Tema.bordoTenue
                    Column {
                        id: rcol
                        x: 14; y: 12; width: parent.width - 28
                        spacing: 6
                        Row {
                            spacing: 8
                            Text { text: Lingua.t("Requisiti e questo PC"); color: Tema.oro; font.family: Tema.font; font.pixelSize: 11; font.letterSpacing: 1 }
                            Text { visible: app.staChiedendo && !app.requisiti; text: Lingua.t("· chiedo a Steam…"); color: Tema.tenue; font.family: Tema.font; font.pixelSize: 11 }
                        }
                        Text { visible: !!app.requisiti?.errore; width: parent.width; wrapMode: Text.Wrap
                               text: Lingua.t("Steam non ha risposto: %1", app.requisiti?.errore ?? ""); color: Tema.allarme; font.family: Tema.font; font.pixelSize: 11 }
                        Repeater {
                            model: app.requisiti?.minimi ? Object.keys(app.requisiti.minimi) : []
                            Text {
                                required property string modelData
                                width: rcol.width; wrapMode: Text.Wrap; textFormat: Text.StyledText
                                text: "<b>" + (app.nomiRequisiti[modelData] ?? modelData) + ":</b> " + app.requisiti.minimi[modelData]
                                color: Tema.testo; font.family: Tema.font; font.pixelSize: 12
                            }
                        }
                        Rectangle { visible: !!app.requisiti?.confronto; width: parent.width; height: 1; color: Tema.bordoTenue }
                        Text { visible: !!app.requisiti?.confronto; text: Lingua.t("Cosa dice di questo PC"); color: Tema.oro; font.family: Tema.font; font.pixelSize: 11; font.letterSpacing: 1 }
                        Repeater {
                            model: app.requisiti?.confronto?.controlli ?? []
                            Row {
                                required property var modelData
                                spacing: 8
                                Text { text: (app.nomiControlli[modelData.stato] ?? app.nomiControlli["?"])[0]; font.family: Tema.icone; font.pixelSize: 16
                                       color: (app.nomiControlli[modelData.stato] ?? app.nomiControlli["?"])[1] }
                                Text {
                                    width: rcol.width - 30; wrapMode: Text.Wrap
                                    text: modelData.cosa + ": " + Lingua.t("serve %1, hai %2", app.misura(modelData.serve, modelData.unita), app.misura(modelData.hai, modelData.unita))
                                    color: Tema.testo; font.family: Tema.font; font.pixelSize: 12
                                }
                            }
                        }
                        Text {
                            readonly property var c: app.requisiti?.confronto
                            visible: !!c
                            width: parent.width; wrapMode: Text.Wrap
                            text: c ? (c.esito === "ok" ? Lingua.t("Ci stai dentro, per i numeri.")
                                    : c.esito === "no" ? Lingua.t("Non ci stai, per i numeri: manca qualcosa qui sopra.")
                                    : Lingua.t("I numeri tornano. CPU e scheda video vanno confrontate a mano: un confronto tra nomi non sarebbe onesto.")) : ""
                            color: c && c.esito === "no" ? Tema.allarme : c && c.esito === "ok" ? "#7fe0a8" : Tema.tenue
                            font.family: Tema.font; font.pixelSize: 12
                        }
                        Text {
                            readonly property var cons: app.requisiti && app.requisiti.consigliati ? app.requisiti.consigliati : null
                            visible: !!cons && Object.keys(cons).length > 0
                            width: parent.width; wrapMode: Text.Wrap; textFormat: Text.StyledText
                            text: cons ? "<b>" + Lingua.t("Consigliati") + ":</b> " + Object.keys(cons)
                                  .map(k => (app.nomiRequisiti[k] ?? k) + " " + cons[k]).join(" · ") : ""
                            color: Tema.tenue; font.family: Tema.font; font.pixelSize: 11
                        }
                    }
                }
                Text { width: parent.width; wrapMode: Text.Wrap
                       visible: !!app.hardware
                       text: Lingua.t("Questo PC: %1 · %2 GB di RAM · %3", app.hardware?.cpu ?? "—", String(app.hardware?.ram ?? "—").replace(".", Lingua.virgola), app.hardware?.gpu ?? "—")
                             + (app.hardware?.vram ? Lingua.t(" (%1 GB di VRAM)", String(app.hardware.vram).replace(".", Lingua.virgola)) : "")
                       color: Tema.tenue; font.family: Tema.font; font.pixelSize: 11 }
            }
        }

        // in fondo: dove sono i giochi, i messaggi
        Item {
            id: piede
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 30
            Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: Tema.bordoTenue }
            Text { x: 22; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; width: parent.width * 0.45
                   text: Lingua.t("%1 giochi · %2", app.giochi.length, app.steam || "—")
                   color: Tema.tenue; font.family: Tema.font; font.pixelSize: 11 }
            Text { anchors { right: parent.right; rightMargin: 22; verticalCenter: parent.verticalCenter }
                   width: parent.width * 0.5; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight
                   text: app.messaggio; color: app.errore ? Tema.allarme : Tema.tenue; font.family: Tema.font; font.pixelSize: 11 }
        }
    }

    function nomiTier(t) { return ({ platinum: "platino", gold: "oro", silver: "argento", bronze: "bronzo", borked: "rotto" })[t] ?? t; }
    function misura(v, unita) {
        if (v === null || v === undefined || v === "") return "—";
        return typeof v === "number" ? String(v).replace(".", Lingua.virgola) + (unita ? " " + unita : "") : v;
    }
}
