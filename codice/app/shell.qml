// Ciel Codice, l'app: una finestra normale (si affianca alle altre). A sinistra i progetti e le loro conversazioni,
// a destra la conversazione con l'agente. In cima: il modello (locale o in cloud) e i permessi del progetto.
// Il lavoro lo fa il motore (ciel-codice servi, ~/cielos/codice/cielcodice), con cui l'app parla a righe di JSON.
// Si apre dal lanciatore o con: ciel-codice app (Super+A → Codice ora è la pagina degli agenti da scaricare)
//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import qs.servizi

ShellRoot {
    id: app

    property var progetti: []
    property var fornitori: []
    property var plugin: []
    property string fornitore: ""
    property string modello: ""
    property string progetto: ""                 // id del progetto aperto
    property string sessione: ""
    property var sessioni: []
    property var suggerimenti: []
    property var modelliPer: ({})
    property bool lavora: false
    property bool pensa: false
    property var toccati: []
    property bool scelta: false                  // il menu dei modelli è aperto
    property bool pannello: false                // le impostazioni sono aperte
    readonly property var p: progetti.find(x => x.id === progetto) ?? null
    readonly property var modi: [["piano", Lingua.t("Piano"), Lingua.t("Solo lettura: guarda e propone")],
                                 ["chiedi", Lingua.t("Chiedi"), Lingua.t("Chiede prima di ogni modifica e comando")],
                                 ["progetto", Lingua.t("Progetto"), Lingua.t("Modifica da solo nel progetto, chiede per i comandi")],
                                 ["libero", Lingua.t("Libero"), Lingua.t("Fa da solo; i comandi girano isolati")]]

    function manda(d) { motore.write(JSON.stringify(d) + "\n"); }

    function voce(o) {
        return Object.assign({ tipo: "", testo: "", nome: "", etichetta: "", dettaglio: "", idc: "", stato: "",
                               motivo: "", anteprima: "", aperto: false }, o);
    }
    function aggiungiTesto(tipo, delta) {
        const n = conv.count;
        if (n && conv.get(n - 1).tipo === tipo && conv.get(n - 1).stato === "scrive")
            conv.setProperty(n - 1, "testo", conv.get(n - 1).testo + delta);
        else
            conv.append(voce({ tipo: tipo, testo: delta, stato: "scrive" }));
    }
    function chiudiTesto() {
        const n = conv.count;
        if (n && conv.get(n - 1).stato === "scrive") conv.setProperty(n - 1, "stato", "");
    }
    function trova(idc, tipo) {
        for (let i = conv.count - 1; i >= 0; i--)
            if (conv.get(i).idc === idc && conv.get(i).tipo === tipo) return i;
        return -1;
    }

    function ricevi(d) {
        switch (d.ev) {
        case "stato":
            progetti = d.progetti; fornitori = d.fornitori; plugin = d.plugin;
            if (!modello) { fornitore = d.fornitore ?? ""; modello = d.modello ?? ""; }
            if (!progetti.length) manda({ cmd: "suggerimenti" });
            break;
        case "suggerimenti": suggerimenti = d.cartelle; break;
        case "progetto_aggiunto": apriProgetto(d.id); break;
        case "sessioni": if (d.progetto === progetto) sessioni = d.sessioni; break;
        case "sessione":
            sessione = d.id; fornitore = d.fornitore; modello = d.modello;
            conv.clear();
            for (const x of d.vista)
                conv.append(voce({ tipo: x.tipo, testo: x.testo, nome: x.nome ?? "", etichetta: x.etichetta ?? "",
                                   dettaglio: x.dettaglio ?? "", idc: x.id ?? "", stato: x.tipo === "strumento" ? (x.ok ? "ok" : "errore") : "" }));
            toccati = [];
            Qt.callLater(() => lista.positionViewAtEnd());
            break;
        case "testo": pensa = false; aggiungiTesto("ciel", d.delta); break;
        case "pensiero": pensa = true; break;
        case "fine_messaggio": chiudiTesto(); break;
        case "strumento":
            chiudiTesto();
            conv.append(voce({ tipo: "strumento", nome: d.nome, etichetta: d.etichetta, dettaglio: d.dettaglio, idc: d.id, stato: "corre" }));
            break;
        case "esito": {
            const i = trova(d.id, "strumento");
            if (i >= 0) { conv.setProperty(i, "stato", d.ok ? "ok" : "errore"); conv.setProperty(i, "testo", d.testo); }
            const j = trova(d.id, "permesso");
            if (j >= 0 && conv.get(j).stato === "attesa") conv.setProperty(j, "stato", "no");
            break;
        }
        case "permesso":
            conv.append(voce({ tipo: "permesso", etichetta: d.etichetta, dettaglio: d.dettaglio, idc: d.id, motivo: d.motivo,
                               anteprima: d.anteprima ?? "", stato: "attesa" }));
            break;
        case "avviso": conv.append(voce({ tipo: "avviso", testo: d.messaggio })); break;
        case "errore": chiudiTesto(); conv.append(voce({ tipo: "errore", testo: d.messaggio })); break;
        case "fine": chiudiTesto(); lavora = false; pensa = false; toccati = d.toccati ?? []; break;
        case "annullato":
            conv.append(voce({ tipo: "avviso", testo: d.file.length ? Lingua.t("Rimessi com'erano: %1", d.file.map(f => f.split("/").pop()).join(", ")) : Lingua.t("Niente da annullare.") }));
            toccati = [];
            break;
        case "modelli": {
            const m = Object.assign({}, modelliPer); m[d.fornitore] = d.modelli; modelliPer = m;
            break;
        }
        }
    }

    function apriProgetto(id) {
        progetto = id; sessioni = []; conv.clear(); sessione = "";
        manda({ cmd: "sessioni", progetto: id });
        manda({ cmd: "apri", progetto: id });
    }
    function invia() {
        const t = campo.text.trim();
        if (!t || lavora || !progetto) return;
        conv.append(voce({ tipo: "tu", testo: t }));
        campo.text = ""; lavora = true; toccati = [];
        manda({ cmd: "invia", testo: t });
        lista.positionViewAtEnd();
    }
    function apriScelta() {
        scelta = !scelta;
        if (scelta) for (const f of fornitori) if (f.pronto) manda({ cmd: "modelli", fornitore: f.id });
    }

    Process {
        id: motore
        command: [(Quickshell.env("CIELOS_DIR") || Quickshell.env("HOME") + "/cielos") + "/bin/ciel-codice", "servi"]
        running: true
        stdinEnabled: true
        stdout: SplitParser { onRead: riga => { try { app.ricevi(JSON.parse(riga)); } catch (e) { console.log("codice:", e, riga.slice(0, 200)); } } }
        onExited: code => { app.lavora = false; conv.append(app.voce({ tipo: "errore", testo: Lingua.t("Il motore si è fermato (%1): riapri Codice.", code) })); }
    }
    ListModel { id: conv }

    // anche da fuori (Ciel, terminale): qs -p ~/cielos/codice/app ipc call codice progetto ~/cielos
    IpcHandler {
        target: "codice"
        function progetto(cartella: string): void { app.manda({ cmd: "aggiungi_progetto", cartella: cartella }); }
        function invia(testo: string): void { campo.text = testo; app.invia(); }
        function modello(fornitore: string, id: string): void { app.fornitore = fornitore; app.modello = id; app.manda({ cmd: "usa", fornitore: fornitore, modello: id }); }
        function impostazioni(): void { app.pannello = true; }
        function modo(valore: string): void { if (app.progetto) app.manda({ cmd: "modo", progetto: app.progetto, valore: valore }); }
    }

    FloatingWindow {
        id: finestra
        title: Lingua.t("Ciel Codice")
        implicitWidth: 1200
        implicitHeight: 800
        color: Tema.fondo
        visible: true
        onVisibleChanged: if (!visible) Qt.quit()

        Row {
            anchors.fill: parent

            // ── a sinistra: progetti e conversazioni
            Rectangle {
                id: lato
                width: 280; height: parent.height
                color: Tema.fondoAlto
                Column {
                    x: 16; y: 18; width: parent.width - 32
                    spacing: 6
                    Row {
                        spacing: 8
                        Text { text: "✦"; color: Tema.oro; font.pixelSize: 22 }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: Lingua.t("Ciel Codice"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 18; font.weight: Font.Medium }
                    }
                    Item { width: 1; height: 12 }
                    Item {
                        width: parent.width; height: 24
                        Text { anchors.verticalCenter: parent.verticalCenter; text: Lingua.t("Progetti"); color: Tema.oro; font.family: Tema.font; font.pixelSize: 11; font.letterSpacing: 2; font.capitalization: Font.AllUppercase }
                        Text {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            text: "add"; font.family: Tema.icone; font.pixelSize: 20; color: Tema.oro
                            MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor
                                onClicked: { app.progetto = ""; app.manda({ cmd: "suggerimenti" }); } }
                        }
                    }
                    Repeater {
                        model: app.progetti
                        Column {
                            id: pc
                            required property var modelData
                            width: parent.width
                            readonly property bool aperto: modelData.id === app.progetto
                            Rectangle {
                                width: parent.width; height: 36; radius: 9
                                color: pc.aperto ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.16) : pm.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                                Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: pc.aperto ? "folder_open" : "folder"; font.family: Tema.icone; font.pixelSize: 18; color: Tema.oroChiaro }
                                Text { x: 36; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 44; elide: Text.ElideRight
                                       text: pc.modelData.nome; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14 }
                                MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: app.apriProgetto(pc.modelData.id) }
                            }
                            Column {
                                visible: pc.aperto
                                x: 22; width: parent.width - 22
                                Rectangle {
                                    width: parent.width; height: 30; radius: 8
                                    color: nm.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                                    Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: Lingua.t("+ Nuova conversazione"); color: Tema.oroChiaro; font.family: Tema.font; font.pixelSize: 13 }
                                    MouseArea { id: nm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: app.manda({ cmd: "apri", progetto: app.progetto }) }
                                }
                                Repeater {
                                    model: pc.aperto ? app.sessioni.slice(0, 12) : []
                                    Rectangle {
                                        required property var modelData
                                        width: parent.width; height: 30; radius: 8
                                        color: modelData.id === app.sessione ? Qt.rgba(1, 1, 1, 0.07) : sm.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent"
                                        Text { x: 10; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 36; elide: Text.ElideRight
                                               text: parent.modelData.titolo || "(vuota)"; color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13 }
                                        Text {
                                            visible: sm.containsMouse
                                            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                            text: "delete"; font.family: Tema.icone; font.pixelSize: 15; color: Tema.tenue
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: app.manda({ cmd: "elimina_sessione", progetto: app.progetto, sessione: parent.parent.modelData.id }) }
                                        }
                                        MouseArea { id: sm; anchors.fill: parent; anchors.rightMargin: 28; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: app.manda({ cmd: "apri", progetto: app.progetto, sessione: parent.modelData.id }) }
                                    }
                                }
                            }
                        }
                    }
                }
                Rectangle {                                // in fondo: impostazioni
                    anchors { bottom: parent.bottom; bottomMargin: 14; left: parent.left; leftMargin: 16; right: parent.right; rightMargin: 16 }
                    height: 36; radius: 9
                    color: im.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                    Row {
                        x: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                        Text { text: "settings"; font.family: Tema.icone; font.pixelSize: 18; color: Tema.oroChiaro }
                        Text { text: Lingua.t("Modelli in cloud e plugin"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
                    }
                    MouseArea { id: im; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: app.pannello = true }
                }
            }

            // ── a destra
            Item {
                id: destra
                width: parent.width - lato.width; height: parent.height

                // nessun progetto aperto: aggiungine uno
                Column {
                    visible: !app.progetto
                    anchors.centerIn: parent
                    width: Math.min(620, parent.width - 80)
                    spacing: 14
                    Text { text: Lingua.t("Su cosa lavoriamo?"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 24; font.weight: Font.Medium }
                    Text { width: parent.width; wrapMode: Text.Wrap; text: Lingua.t("Un progetto è una cartella: Codice lavora lì dentro (legge, modifica, esegue) secondo i permessi che scegli.")
                           color: Tema.tenue; font.family: Tema.font; font.pixelSize: 14 }
                    Row {
                        spacing: 8
                        Rectangle {
                            width: 470; height: 40; radius: 10
                            color: Qt.rgba(0.02, 0.03, 0.1, 0.9)
                            border.color: cartella.activeFocus ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.7) : Qt.rgba(1, 1, 1, 0.12)
                            TextInput {
                                id: cartella
                                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                                verticalAlignment: TextInput.AlignVCenter
                                color: Tema.testo; font.family: "JetBrains Mono"; font.pixelSize: 13; clip: true
                                onAccepted: aggiungi.clic()
                                Text { anchors.verticalCenter: parent.verticalCenter; visible: !cartella.text; text: "~/percorso/della/cartella"; color: Tema.tenue; font: cartella.font }
                            }
                        }
                        Rectangle {
                            id: aggiungi
                            function clic() { if (cartella.text.trim()) { app.manda({ cmd: "aggiungi_progetto", cartella: cartella.text.trim() }); cartella.text = ""; } }
                            width: 110; height: 40; radius: 20; color: Tema.oro
                            Text { anchors.centerIn: parent; text: Lingua.t("Aggiungi"); color: Tema.fondo; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.Medium }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: aggiungi.clic() }
                        }
                    }
                    Text { visible: app.suggerimenti.length > 0; text: Lingua.t("Cartelle con git nella tua home:"); color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13 }
                    Flow {
                        width: parent.width; spacing: 8
                        Repeater {
                            model: app.suggerimenti
                            Rectangle {
                                required property var modelData
                                width: st.implicitWidth + 24; height: 32; radius: 16
                                color: sgm.containsMouse ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.2) : Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.07)
                                border.color: Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.4)
                                Text { id: st; anchors.centerIn: parent; text: parent.modelData.nome; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
                                MouseArea { id: sgm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: app.manda({ cmd: "aggiungi_progetto", cartella: parent.modelData.cartella }) }
                            }
                        }
                    }
                }

                // un progetto aperto
                Item {
                    visible: !!app.progetto
                    anchors.fill: parent

                    Item {                                  // in cima
                        id: cima
                        width: parent.width; height: 64
                        Column {
                            x: 24; anchors.verticalCenter: parent.verticalCenter
                            Text { text: app.p?.nome ?? ""; color: Tema.testo; font.family: Tema.font; font.pixelSize: 17; font.weight: Font.Medium }
                            Text { text: (app.p?.cartella ?? "").replace(Quickshell.env("HOME"), "~"); color: Tema.tenue; font.family: "JetBrains Mono"; font.pixelSize: 11 }
                        }
                        Row {
                            anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                            spacing: 6
                            Repeater {
                                model: app.modi
                                Rectangle {
                                    required property var modelData
                                    readonly property bool scelto: (app.p?.modo ?? "progetto") === modelData[0]
                                    width: mt.implicitWidth + 20; height: 28; radius: 14
                                    color: scelto ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.25) : mm.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                                    border.color: scelto ? Tema.oro : Tema.bordo
                                    Text { id: mt; anchors.centerIn: parent; text: parent.modelData[1]; color: parent.scelto ? Tema.testo : Tema.tenue; font.family: Tema.font; font.pixelSize: 12 }
                                    MouseArea { id: mm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: app.manda({ cmd: "modo", progetto: app.progetto, valore: parent.modelData[0] }) }
                                }
                            }
                            Item { width: 8; height: 1 }
                            Rectangle {                     // il modello
                                id: bottoneModello
                                width: Math.min(300, mtx.implicitWidth + 44); height: 32; radius: 16
                                color: bm.containsMouse || app.scelta ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.2) : Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.08)
                                border.color: Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.45)
                                Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: app.fornitore === "ollama" ? "computer" : "cloud"; font.family: Tema.icone; font.pixelSize: 16; color: Tema.oroChiaro }
                                Text { id: mtx; x: 34; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 44; elide: Text.ElideMiddle
                                       text: app.modello ? app.modello.replace(/^hf\.co\//, "") : Lingua.t("Scegli un modello"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 12 }
                                MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: app.apriScelta() }
                            }
                        }
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Tema.bordo }
                    }

                    ListView {                              // la conversazione
                        id: lista
                        anchors { top: cima.bottom; topMargin: 12; bottom: piede.top; bottomMargin: 8; left: parent.left; leftMargin: 28; right: parent.right; rightMargin: 28 }
                        clip: true; spacing: 10
                        boundsBehavior: Flickable.StopAtBounds
                        model: conv
                        property bool infondo: true
                        onMovementEnded: infondo = atYEnd
                        onContentHeightChanged: if (infondo) Qt.callLater(positionViewAtEnd)
                        delegate: Voce {
                            larghezza: lista.width
                            onRispondi: (idc, si, sempre) => {
                                const j = app.trova(idc, "permesso");
                                if (j >= 0) conv.setProperty(j, "stato", si ? "si" : "no");
                                app.manda({ cmd: "permesso", id: idc, si: si, sempre: sempre });
                            }
                            onApriChiudi: i => conv.setProperty(i, "aperto", !conv.get(i).aperto)
                        }
                        Text {
                            visible: conv.count === 0
                            anchors.centerIn: parent
                            width: parent.width * 0.7; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                            text: Lingua.t("Chiedi qualcosa sul progetto: spiegare il codice, correggere un errore, aggiungere una funzione, scrivere i test…")
                            color: Tema.tenue; font.family: Tema.font; font.pixelSize: 15
                        }
                    }

                    Item {                                  // in fondo: scrivi
                        id: piede
                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                        height: Math.min(220, campo.contentHeight + 26) + 46
                        Row {
                            x: 28; y: 2; spacing: 10; height: 26
                            Text {
                                visible: app.lavora
                                anchors.verticalCenter: parent.verticalCenter
                                text: app.pensa ? Lingua.t("Ciel pensa…") : Lingua.t("Ciel lavora…")
                                color: Tema.oroChiaro; font.family: Tema.font; font.pixelSize: 12
                            }
                            Text {
                                visible: !app.lavora && app.toccati.length > 0
                                anchors.verticalCenter: parent.verticalCenter
                                text: Lingua.t("↶ Annulla le modifiche di questo turno (%1 file)", app.toccati.length)
                                color: Tema.oroChiaro; font.family: Tema.font; font.pixelSize: 12; font.underline: am.containsMouse
                                MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: app.manda({ cmd: "annulla_turno" }) }
                            }
                        }
                        Rectangle {
                            anchors { left: parent.left; leftMargin: 24; right: parent.right; rightMargin: 24; bottom: parent.bottom; bottomMargin: 16 }
                            height: Math.min(220, campo.contentHeight + 26)
                            radius: 14
                            color: Qt.rgba(0.02, 0.03, 0.1, 0.9)
                            border.color: campo.activeFocus ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.7) : Qt.rgba(1, 1, 1, 0.12)
                            Flickable {
                                id: scorri
                                anchors { left: parent.left; leftMargin: 14; right: invia.left; rightMargin: 10; top: parent.top; topMargin: 13; bottom: parent.bottom; bottomMargin: 13 }
                                contentHeight: campo.contentHeight; clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                TextEdit {
                                    id: campo
                                    width: scorri.width
                                    wrapMode: TextEdit.Wrap
                                    color: Tema.testo; font.family: Tema.font; font.pixelSize: 14
                                    selectionColor: Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.4)
                                    focus: true
                                    Keys.onPressed: e => {
                                        if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && !(e.modifiers & Qt.ShiftModifier)) {
                                            app.invia(); e.accepted = true;
                                        }
                                    }
                                    Text { visible: !campo.text; text: app.lavora ? Lingua.t("Ciel sta lavorando…") : Lingua.t("Chiedi a Ciel Codice… (Invio manda, Maiusc+Invio va a capo)"); color: Tema.tenue; font: campo.font }
                                }
                            }
                            Rectangle {
                                id: invia
                                anchors { right: parent.right; rightMargin: 8; bottom: parent.bottom; bottomMargin: 6 }
                                width: 36; height: 36; radius: 18
                                color: app.lavora ? Qt.rgba(Tema.allarme.r, Tema.allarme.g, Tema.allarme.b, 0.85) : campo.text.trim() ? Tema.oro : Qt.rgba(1, 1, 1, 0.08)
                                Text { anchors.centerIn: parent; text: app.lavora ? "stop" : "arrow_upward"; font.family: Tema.icone; font.pixelSize: 20; color: app.lavora || campo.text.trim() ? Tema.fondo : Tema.tenue }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: app.lavora ? app.manda({ cmd: "ferma" }) : app.invia() }
                            }
                        }
                    }
                }

                // il menu dei modelli
                Rectangle {
                    visible: app.scelta
                    anchors { top: parent.top; topMargin: 56; right: parent.right; rightMargin: 20 }
                    width: 420; height: Math.min(parent.height - 120, sc.implicitHeight + 20)
                    radius: 12
                    color: Tema.fondoAlto
                    border.color: Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.45)
                    Flickable {
                        anchors.fill: parent; anchors.margins: 10
                        contentHeight: sc.implicitHeight; clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        Column {
                            id: sc
                            width: parent.width
                            spacing: 2
                            Repeater {
                                model: app.fornitori.filter(f => f.pronto)
                                Column {
                                    id: fcol
                                    required property var modelData
                                    width: sc.width
                                    Text { topPadding: 8; bottomPadding: 4; leftPadding: 6; text: fcol.modelData.nome; color: Tema.oro; font.family: Tema.font; font.pixelSize: 11; font.letterSpacing: 1.5; font.capitalization: Font.AllUppercase }
                                    Text {
                                        visible: !(app.modelliPer[fcol.modelData.id]?.length)
                                        leftPadding: 6; text: app.modelliPer[fcol.modelData.id] ? Lingua.t("nessun modello che sappia usare gli strumenti") : "carico…"
                                        color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
                                    }
                                    Repeater {
                                        model: app.modelliPer[fcol.modelData.id] ?? []
                                        Rectangle {
                                            required property var modelData
                                            width: sc.width; height: 30; radius: 8
                                            color: modelData.id === app.modello ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.2) : mo.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                                            Text { x: 8; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 70; elide: Text.ElideMiddle
                                                   text: parent.modelData.nome; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
                                            Text { anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                                   visible: fcol.modelData.id !== "ollama" && parent.modelData.gratis; text: "gratis"; color: "#5fd38a"; font.family: Tema.font; font.pixelSize: 11 }
                                            MouseArea { id: mo; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: { app.fornitore = fcol.modelData.id; app.modello = parent.modelData.id; app.scelta = false;
                                                             app.manda({ cmd: "usa", fornitore: fcol.modelData.id, modello: parent.modelData.id }); } }
                                        }
                                    }
                                }
                            }
                            Text {
                                topPadding: 10; leftPadding: 6; width: sc.width; wrapMode: Text.Wrap
                                text: Lingua.t("Altri modelli: scaricali dal riquadro (Super+A → Scarica modelli) o collega un servizio in cloud nelle impostazioni.")
                                color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
                            }
                        }
                    }
                }

                Pannello {
                    visible: app.pannello
                    anchors.fill: parent
                    fornitori: app.fornitori
                    plugin: app.plugin
                    onComando: d => app.manda(d)
                    onChiudi: app.pannello = false
                }
            }
        }
    }
}
