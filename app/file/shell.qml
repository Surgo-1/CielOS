// File, il file manager di CielOS (sul modello di Dolphin): a sinistra luoghi, segnalibri, dischi e chiavette
// (monta, smonta, espelli) e il cestino; in cima le schede (Ctrl+T, Ctrl+W, Ctrl+Tab); F3 divide la vista in due
// riquadri affiancati (si trascina dall'uno all'altro). Griglia con anteprime o dettagli (Ctrl+1 / Ctrl+2), zoom con
// Ctrl+rotella, file nascosti con Ctrl+H, F4 un terminale nella cartella. Tasto destro: apri, apri con, taglia, copia,
// incolla, rinomina, cestino, comprimi, estrai, proprietà, copia il percorso, terminale qui, segnalibro.
// Le operazioni le fa cielfile (un processo per operazione: la finestra non si blocca mai).
// Si apre con ciel-file [CARTELLA], dal lanciatore («File») o con Super+E.
//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import qs.servizi
import "Icone.js" as I

ShellRoot {
    id: app
    // la vista (ricordata in ~/.config/cielos/file.json)
    property string vista: "griglia"
    property int zoom: 64
    property bool nascosti: false
    property string ordina: "nome"
    property bool inverti: false
    property bool diviso: false
    property var segnalibri: []
    // le schede: il percorso del riquadro sinistro di ognuna
    property var schede: [Quickshell.env("CIEL_FILE_DOVE") || Quickshell.env("HOME")]
    property int scheda: 0
    property var attivo: sinistro
    // appunti, cestino, dispositivi, messaggi
    property var appunti: ({ file: [], taglia: false })
    property var cestino: []
    property var dispositivi: []
    property string messaggio: ""
    property bool errore: false
    property int lavori: 0
    readonly property string home: Quickshell.env("HOME")
    readonly property string conf: (Quickshell.env("XDG_CONFIG_HOME") || home + "/.config") + "/cielos/file.json"

    // ── operazioni ───────────────────────────────────────────────────────────────────────────────────────────
    function op(args, dopo) {
        const proc = operazione.createObject(app, { command: [Percorsi.bin("cielfile"), ...args], dopo: dopo ?? null });
        app.lavori++;
        proc.running = true;
    }
    Component {
        id: operazione
        Process {
            id: pr
            property var dopo: null
            stdout: StdioCollector {
                onStreamFinished: {
                    let r = {};
                    try { r = JSON.parse(text); } catch (e) {}
                    if (r.errori && r.errori.length) { app.errore = true; app.messaggio = r.errori.join(" · "); }
                    if (pr.dopo) pr.dopo(r);
                }
            }
            onExited: { app.lavori--; pr.destroy(); }
        }
    }
    function avvisa(t) { app.errore = false; app.messaggio = t; }
    function apriFile(f) { Quickshell.execDetached(["xdg-open", f]); }
    function copia(files, taglia) {
        if (!files.length) return;
        appunti = { file: files, taglia: taglia };
        Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | wl-copy -t text/uri-list', "_", files.map(f => "file://" + encodeURI(f)).join("\r\n")]);
        avvisa((taglia ? "Tagliati " : "Copiati ") + files.length + (files.length === 1 ? " elemento" : " elementi") + ": Ctrl+V per incollare");
    }
    function incolla(dove) {
        if (!appunti.file.length || dove === "cestino:") return;
        const n = appunti.file.length, t = appunti.taglia;
        avvisa((t ? "Sposto " : "Copio ") + n + "…");
        op([t ? "sposta" : "copia", dove, ...appunti.file], r => { if (r.ok) avvisa((t ? "Spostati " : "Copiati ") + (r.fatti?.length ?? n)); });
        if (t) appunti = { file: [], taglia: false };
    }
    function lascia(evento, dove) {
        const files = (evento.urls ?? []).map(u => decodeURIComponent(String(u).replace(/^file:\/\//, ""))).filter(f => f && f !== dove);
        if (!files.length) return;
        const copiare = evento.proposedAction === Qt.CopyAction || (evento.modifiers & Qt.ControlModifier)
                        || !files.every(f => !f.startsWith("/") || f.split("/")[1] === dove.split("/")[1]);
        evento.accept(copiare ? Qt.CopyAction : Qt.MoveAction);
        op([copiare ? "copia" : "sposta", dove, ...files], r => { if (r.ok) avvisa((copiare ? "Copiati " : "Spostati ") + (r.fatti?.length ?? 0) + " in " + dove.split("/").pop()); });
    }
    property var daCancellare: null              // { files, perSempre }: aspetta la conferma
    function cancella(files, perSempre) {
        if (!files.length) return;
        if (attivo.cestino) { daCancellare = { files: files, perSempre: true, cestino: true }; return; }
        if (perSempre) { daCancellare = { files: files, perSempre: true }; return; }
        op(["cestino", ...files], r => { if (r.ok) avvisa(files.length + (files.length === 1 ? " elemento" : " elementi") + " nel cestino (Ctrl+Z non c'è: lo recuperi dal cestino)"); });
    }
    function conferma() {
        const c = daCancellare; daCancellare = null;
        if (!c) return;
        if (c.svuota) op(["svuota"], () => leggiCestino());
        else op(["elimina", ...c.files], r => { if (r.ok) avvisa("Eliminati per sempre: " + c.files.length); if (c.cestino) leggiCestino(); });
    }
    function rinomina(f, nome) { op(["rinomina", f, nome]); }
    function nuovaCartella(pannello) {
        op(["cartella", pannello.percorso, "Nuova cartella"], r => { if (r.fatti) Qt.callLater(() => { pannello.scelti = {}; pannello.rinomina = r.fatti[0]; }); });
    }
    function cerca(pannello, dove, testo) { op(["cerca", dove, testo], r => pannello.risultati = r.risultati ?? []); }
    function leggiCestino() { op(["cestino-elenco"], r => cestino = r.voci ?? []); }
    function leggiDispositivi() { op(["dispositivi"], r => dispositivi = r.dispositivi ?? []); }
    function terminale(dove) { Quickshell.execDetached([Tema.terminale || "foot", "--working-directory=" + dove]); }

    // ── vista ricordata, segnalibri ──────────────────────────────────────────────────────────────────────────
    FileView {
        id: memoria
        path: app.conf
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                app.vista = d.vista ?? app.vista; app.zoom = d.zoom ?? app.zoom; app.nascosti = d.nascosti ?? false;
                app.ordina = d.ordina ?? "nome"; app.inverti = d.inverti ?? false; app.segnalibri = d.segnalibri ?? [];
            } catch (e) {}
        }
    }
    function salva() {
        memoria.setText(JSON.stringify({ vista: vista, zoom: zoom, nascosti: nascosti, ordina: ordina, inverti: inverti, segnalibri: segnalibri }, null, 2));
    }
    onVistaChanged: salvaPoi.restart(); onZoomChanged: salvaPoi.restart(); onNascostiChanged: salvaPoi.restart()
    onOrdinaChanged: salvaPoi.restart(); onInvertiChanged: salvaPoi.restart(); onSegnalibriChanged: salvaPoi.restart()
    Timer { id: salvaPoi; interval: 800; onTriggered: app.salva() }
    function segnalibro(f) {
        segnalibri = segnalibri.includes(f) ? segnalibri.filter(x => x !== f) : segnalibri.concat([f]);
    }
    // le cartelle dell'utente (xdg-user-dirs)
    property var luoghi: [["home", "Casa", home]]
    Process {
        running: true
        command: ["sh", "-c", "for d in DESKTOP DOCUMENTS DOWNLOAD PICTURES MUSIC VIDEOS; do echo \"$d $(xdg-user-dir $d)\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const icone = { DESKTOP: ["desktop_windows", "Scrivania"], DOCUMENTS: ["description", "Documenti"], DOWNLOAD: ["download", "Scaricati"],
                                PICTURES: ["image", "Immagini"], MUSIC: ["music_note", "Musica"], VIDEOS: ["movie", "Video"] };
                const l = [["home", "Casa", app.home]];
                for (const r of text.trim().split("\n")) {
                    const [k, ...dove] = r.split(" ");
                    const d = dove.join(" ");
                    if (d && d !== app.home && icone[k]) l.push([icone[k][0], d.split("/").pop(), d]);
                }
                app.luoghi = l;
            }
        }
    }
    Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: app.leggiDispositivi() }

    // ── il menu del tasto destro e i dialoghi ────────────────────────────────────────────────────────────────
    property var menuDi: null                    // { pannello, voce, x, y }
    function menu(pannello, voce, punto) { menuDi = { pannello: pannello, voce: voce, x: punto.x, y: punto.y }; }
    property var apriCon: null                   // { file, mime, app: [] }
    property var proprieta: null

    FloatingWindow {
        id: finestra
        title: "File — " + (app.attivo.cestino ? "Cestino" : app.attivo.percorso.split("/").pop() || "/")
        implicitWidth: 1180
        implicitHeight: 760
        color: Tema.fondo
        visible: true
        onVisibleChanged: if (!visible) Qt.quit()

        Item {
            id: tutto
            anchors.fill: parent
            focus: true
            // le scorciatoie della finestra (quelle dei file le ha il riquadro)
            Keys.onPressed: e => {
                const ctrl = e.modifiers & Qt.ControlModifier;
                if (ctrl && e.key === Qt.Key_T) { app.schede = app.schede.concat([app.attivo.percorso === "cestino:" ? app.home : app.attivo.percorso]); app.scheda = app.schede.length - 1; }
                else if (ctrl && e.key === Qt.Key_W) { if (app.schede.length > 1) { const s = app.schede.slice(); s.splice(app.scheda, 1); app.schede = s; app.scheda = Math.min(app.scheda, s.length - 1); } else Qt.quit(); }
                else if (ctrl && e.key === Qt.Key_Tab) app.scheda = (app.scheda + 1) % app.schede.length;
                else if (ctrl && e.key === Qt.Key_H) app.nascosti = !app.nascosti;
                else if (ctrl && e.key === Qt.Key_1) app.vista = "griglia";
                else if (ctrl && e.key === Qt.Key_2) app.vista = "dettagli";
                else if (ctrl && e.key === Qt.Key_Plus || ctrl && e.key === Qt.Key_Equal) app.zoom = Math.min(160, app.zoom + 16);
                else if (ctrl && e.key === Qt.Key_Minus) app.zoom = Math.max(32, app.zoom - 16);
                else if (e.key === Qt.Key_F3) app.diviso = !app.diviso;
                else if (e.key === Qt.Key_F4) app.terminale(app.attivo.cestino ? app.home : app.attivo.percorso);
                else if (e.key === Qt.Key_F5) app.attivo.percorso = app.attivo.percorso;
                else return;
                e.accepted = true;
            }

            // ── a sinistra: luoghi, segnalibri, dispositivi, cestino
            Rectangle {
                id: lato
                width: 230; height: parent.height
                color: Qt.rgba(0, 0, 0, 0.15)
                Flickable {
                    anchors { fill: parent; margins: 10 }
                    contentHeight: colLato.implicitHeight
                    clip: true
                    Column {
                        id: colLato
                        width: parent.width
                        spacing: 2
                        component Voce: Rectangle {
                            id: vl
                            property string icona
                            property string testo
                            property string dove
                            property string sotto: ""
                            property color coloreIcona: Tema.oroChiaro
                            signal destro(var punto)
                            readonly property bool qui: app.attivo.percorso === dove
                            width: colLato.width; height: sotto ? 46 : 34; radius: 10
                            color: qui ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.18) : mv.containsMouse || dl.containsDrag ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                            border.color: dl.containsDrag ? Tema.oro : "transparent"
                            Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: vl.icona; font.family: Tema.icone; font.pixelSize: 19; color: vl.coloreIcona }
                            Column {
                                x: 40; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 48
                                Text { width: parent.width; elide: Text.ElideRight; text: vl.testo; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
                                Text { visible: vl.sotto !== ""; width: parent.width; elide: Text.ElideRight; text: vl.sotto; color: Tema.tenue; font.family: Tema.font; font.pixelSize: 11 }
                            }
                            DropArea { id: dl; anchors.fill: parent; enabled: vl.dove !== "" && vl.dove !== "cestino:"; keys: ["text/uri-list"]
                                       onDropped: e => app.lascia(e, vl.dove) }
                            MouseArea { id: mv; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        onClicked: m => { if (m.button === Qt.RightButton) vl.destro(mapToItem(null, m.x, m.y)); else if (vl.dove) app.attivo.vai(vl.dove); } }
                        }
                        Text { text: "Luoghi"; leftPadding: 8; bottomPadding: 4; color: Tema.oro; font.family: Tema.font; font.pixelSize: 12; font.letterSpacing: 1 }
                        Repeater { model: app.luoghi; Voce { required property var modelData; icona: modelData[0]; testo: modelData[1]; dove: modelData[2] } }
                        Voce { icona: "computer"; testo: "Il sistema"; dove: "/" }
                        Voce { icona: "delete"; testo: "Cestino"; dove: "cestino:"; sotto: app.cestino.length ? app.cestino.length + " elementi" : "" }
                        Item { width: 1; height: 10; visible: app.segnalibri.length > 0 }
                        Text { visible: app.segnalibri.length > 0; text: "Segnalibri"; leftPadding: 8; bottomPadding: 4; color: Tema.oro; font.family: Tema.font; font.pixelSize: 12; font.letterSpacing: 1 }
                        Repeater { model: app.segnalibri
                                   Voce { required property string modelData; icona: "bookmark"; testo: modelData.split("/").pop(); dove: modelData
                                          onDestro: app.segnalibro(modelData) } }
                        Item { width: 1; height: 10; visible: app.dispositivi.length > 0 }
                        Text { visible: app.dispositivi.length > 0; text: "Dischi e chiavette"; leftPadding: 8; bottomPadding: 4; color: Tema.oro; font.family: Tema.font; font.pixelSize: 12; font.letterSpacing: 1 }
                        Repeater {
                            model: app.dispositivi
                            Voce {
                                id: vd
                                required property var modelData
                                icona: modelData.rimovibile ? "usb" : "hard_drive"
                                testo: modelData.etichetta
                                sotto: I.dimensione(modelData.dimensione) + (modelData.montato ? "" : " · non montato")
                                dove: modelData.montato
                                coloreIcona: modelData.montato ? Tema.oroChiaro : Tema.tenue
                                Text {
                                    anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                    text: vd.modelData.montato ? (vd.modelData.rimovibile ? "eject" : "") : "play_arrow"
                                    font.family: Tema.icone; font.pixelSize: 18; color: em.containsMouse ? Tema.oro : Tema.tenue
                                    MouseArea { id: em; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: vd.modelData.montato
                                                    ? app.op(["espelli", vd.modelData.dispositivo], r => { if (r.ok) app.avvisa("Puoi staccare «" + vd.modelData.etichetta + "»"); app.leggiDispositivi(); })
                                                    : app.op(["monta", vd.modelData.dispositivo], r => { app.leggiDispositivi(); if (r.montato) app.attivo.vai(r.montato); }) }
                                }
                                MouseArea {                  // non montato: un clic lo monta e lo apre
                                    anchors.fill: parent; enabled: !vd.modelData.montato; cursorShape: Qt.PointingHandCursor
                                    onClicked: app.op(["monta", vd.modelData.dispositivo], r => { app.leggiDispositivi(); if (r.montato) app.attivo.vai(r.montato); })
                                }
                            }
                        }
                    }
                }
            }

            // ── a destra: schede, riquadri, barra in fondo
            Item {
                id: destra
                anchors { left: lato.right; right: parent.right; top: parent.top; bottom: parent.bottom }

                Row {
                    id: barraSchede
                    x: 8; y: 6
                    height: 34
                    spacing: 4
                    Repeater {
                        model: app.schede
                        Rectangle {
                            required property string modelData
                            required property int index
                            width: Math.min(200, ts.implicitWidth + 50); height: 32; radius: 16
                            color: app.scheda === index ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.18) : ms.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                            Text { id: ts; x: 14; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 44; elide: Text.ElideRight
                                   text: index === app.scheda ? (app.attivo === sinistro || !app.diviso ? (sinistro.cestino ? "Cestino" : sinistro.percorso.split("/").pop() || "/") : (modelData.split("/").pop() || "/")) : (modelData === "cestino:" ? "Cestino" : modelData.split("/").pop() || "/")
                                   color: Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
                            MouseArea { id: ms; anchors.fill: parent; hoverEnabled: true; onClicked: app.scheda = index }
                            Text { visible: app.schede.length > 1; anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                   text: "close"; font.family: Tema.icone; font.pixelSize: 15; color: Tema.tenue
                                   MouseArea { anchors.fill: parent; anchors.margins: -4
                                               onClicked: { const s = app.schede.slice(); s.splice(index, 1); app.schede = s; app.scheda = Math.min(app.scheda, s.length - 1); } } }
                        }
                    }
                    Text { width: 32; height: 32; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                           text: "add"; font.family: Tema.icone; font.pixelSize: 20; color: Tema.tenue
                           MouseArea { anchors.fill: parent; onClicked: { app.schede = app.schede.concat([app.attivo.cestino ? app.home : app.attivo.percorso]); app.scheda = app.schede.length - 1; } } }
                }
                // i comandi della vista
                Row {
                    anchors { right: parent.right; rightMargin: 10; verticalCenter: barraSchede.verticalCenter }
                    spacing: 2
                    Repeater {
                        model: [["grid_view", "Griglia (Ctrl+1)", () => app.vista = "griglia", app.vista === "griglia"],
                                ["view_list", "Dettagli (Ctrl+2)", () => app.vista = "dettagli", app.vista === "dettagli"],
                                ["vertical_split", "Dividi (F3)", () => app.diviso = !app.diviso, app.diviso],
                                ["visibility", "File nascosti (Ctrl+H)", () => app.nascosti = !app.nascosti, app.nascosti],
                                ["terminal", "Terminale qui (F4)", () => app.terminale(app.attivo.cestino ? app.home : app.attivo.percorso), false]]
                        Rectangle {
                            required property var modelData
                            width: 34; height: 32; radius: 10
                            color: modelData[3] ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.2) : mc.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                            Text { anchors.centerIn: parent; text: modelData[0]; font.family: Tema.icone; font.pixelSize: 19; color: Tema.oroChiaro }
                            MouseArea { id: mc; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: modelData[2]() }
                        }
                    }
                }

                Item {
                    id: riquadri
                    anchors { left: parent.left; right: parent.right; top: barraSchede.bottom; bottom: piede.top; margins: 6 }
                    WheelHandler {
                        acceptedModifiers: Qt.ControlModifier
                        onWheel: e => app.zoom = Math.max(32, Math.min(160, app.zoom + (e.angleDelta.y > 0 ? 8 : -8)))
                    }
                    Pannello {
                        id: sinistro
                        gestore: app
                        attivo: app.attivo === sinistro
                        width: app.diviso ? (parent.width - 6) / 2 : parent.width
                        height: parent.height
                        Component.onCompleted: { percorso = app.schede[0]; storia = [percorso]; forceActiveFocus(); }
                        onCambiato: { const s = app.schede.slice(); s[app.scheda] = percorso; app.schede = s; }
                    }
                    Pannello {
                        id: destro
                        visible: app.diviso
                        gestore: app
                        attivo: app.attivo === destro
                        x: (parent.width + 6) / 2
                        width: (parent.width - 6) / 2
                        height: parent.height
                        Component.onCompleted: { percorso = app.schede[0]; storia = [percorso]; }
                    }
                    Connections {
                        target: app
                        function onSchedaChanged() { sinistro.vai(app.schede[app.scheda]); app.attivo = sinistro; sinistro.forceActiveFocus(); }
                        function onDivisoChanged() { if (!app.diviso) { app.attivo = sinistro; sinistro.forceActiveFocus(); } else if (destro.percorso === "") destro.vai(sinistro.percorso); }
                    }
                }

                // in fondo: quanti, scelti, spazio, i messaggi
                Item {
                    id: piede
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 30
                    Text {
                        x: 14; anchors.verticalCenter: parent.verticalCenter
                        text: app.attivo.quanti + (app.attivo.quanti === 1 ? " elemento" : " elementi") +
                              (app.attivo.selezione.length ? " · " + app.attivo.selezione.length + " scelti" : "") +
                              (app.lavori > 0 ? " · lavoro…" : "")
                        color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
                    }
                    Text {
                        anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                        width: parent.width * 0.6; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight
                        text: app.messaggio
                        color: app.errore ? Tema.allarme : Tema.tenue; font.family: Tema.font; font.pixelSize: 12
                    }
                    Timer { running: app.messaggio !== ""; interval: 7000; onTriggered: app.messaggio = "" }
                }
            }

            // ── il menu del tasto destro
            MouseArea { anchors.fill: parent; visible: app.menuDi !== null; onPressed: app.menuDi = null }
            Rectangle {
                id: menuBox
                visible: app.menuDi !== null
                readonly property var m: app.menuDi
                readonly property var sel: m ? m.pannello.selezione : []
                readonly property bool uno: sel.length === 1
                readonly property bool cartellaSel: !!m && !!m.voce && m.voce.cartella
                x: m ? Math.min(m.x, parent.width - width - 8) : 0
                y: m ? Math.min(m.y, parent.height - height - 8) : 0
                width: 290; height: vociMenu.implicitHeight + 12; radius: 12
                color: Tema.fondoAlto; border.color: Tema.bordo
                Column {
                    id: vociMenu
                    x: 6; y: 6; width: parent.width - 12
                    component VM: Rectangle {
                        property string icona; property string testo; property string tasti: ""
                        property bool mostra: true
                        signal scelto()
                        visible: mostra; width: vociMenu.width; height: mostra ? 32 : 0; radius: 8
                        color: mvm.containsMouse ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.16) : "transparent"
                        Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: parent.icona; font.family: Tema.icone; font.pixelSize: 17; color: Tema.oroChiaro }
                        Text { x: 38; anchors.verticalCenter: parent.verticalCenter; text: parent.testo; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
                        Text { anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                               text: parent.tasti; color: Tema.tenue; font.family: Tema.font; font.pixelSize: 11 }
                        MouseArea { id: mvm; anchors.fill: parent; hoverEnabled: true; onClicked: { app.menuDi = null; parent.scelto(); } }
                    }
                    // su dei file
                    VM { mostra: !!menuBox.m?.voce && !menuBox.m.pannello.cestino; icona: "open_in_new"; testo: "Apri"; tasti: "Invio"; onScelto: menuBox.m.pannello.apri(menuBox.m.voce) }
                    VM { mostra: menuBox.uno && !menuBox.cartellaSel && !menuBox.m?.pannello.cestino; icona: "apps"; testo: "Apri con…"
                         onScelto: { const f = menuBox.sel[0]; app.op(["apri-con", f], r => app.apriCon = { file: f, mime: r.mime, app: r.app ?? [] }); } }
                    VM { mostra: menuBox.cartellaSel; icona: "tab"; testo: "Apri in una scheda nuova"
                         onScelto: { app.schede = app.schede.concat([menuBox.m.voce.percorso]); } }
                    VM { mostra: menuBox.sel.length > 0 && !menuBox.m?.pannello.cestino; icona: "content_cut"; testo: "Taglia"; tasti: "Ctrl+X"; onScelto: app.copia(menuBox.sel, true) }
                    VM { mostra: menuBox.sel.length > 0 && !menuBox.m?.pannello.cestino; icona: "content_copy"; testo: "Copia"; tasti: "Ctrl+C"; onScelto: app.copia(menuBox.sel, false) }
                    VM { mostra: app.appunti.file.length > 0 && !menuBox.m?.pannello.cestino; icona: "content_paste"; testo: "Incolla"; tasti: "Ctrl+V"
                         onScelto: app.incolla(menuBox.cartellaSel && menuBox.uno ? menuBox.m.voce.percorso : menuBox.m.pannello.percorso) }
                    VM { mostra: menuBox.uno && !menuBox.m?.pannello.cestino; icona: "edit"; testo: "Rinomina"; tasti: "F2"; onScelto: menuBox.m.pannello.rinomina = menuBox.sel[0] }
                    VM { mostra: menuBox.sel.length > 0 && !menuBox.m?.pannello.cestino; icona: "folder_zip"; testo: "Comprimi (.zip)"
                         onScelto: { const s = menuBox.sel; const base = s.length === 1 ? s[0].split("/").pop().replace(/\.[^.]+$/, "") : "Archivio";
                                     app.op(["comprimi", menuBox.m.pannello.percorso + "/" + base + ".zip", ...s]); } }
                    VM { mostra: menuBox.uno && I.archivio(menuBox.sel[0] ?? "") && !menuBox.m?.pannello.cestino; icona: "unarchive"; testo: "Estrai qui"
                         onScelto: app.op(["estrai", menuBox.sel[0]], r => { if (r.ok) app.avvisa("Estratto in " + (r.fatti?.[0] ?? "").split("/").pop()); }) }
                    VM { mostra: menuBox.uno && !menuBox.m?.pannello.cestino; icona: "link"; testo: "Copia il percorso"
                         onScelto: Quickshell.execDetached(["wl-copy", menuBox.sel[0]]) }
                    VM { mostra: menuBox.cartellaSel && menuBox.uno; icona: "bookmark"; testo: app.segnalibri.includes(menuBox.sel[0] ?? "") ? "Togli dai segnalibri" : "Aggiungi ai segnalibri"
                         onScelto: app.segnalibro(menuBox.sel[0]) }
                    VM { mostra: menuBox.sel.length > 0 && !menuBox.m?.pannello.cestino; icona: "delete"; testo: "Nel cestino"; tasti: "Canc"; onScelto: app.cancella(menuBox.sel, false) }
                    VM { mostra: menuBox.sel.length > 0; icona: "delete_forever"; testo: "Elimina per sempre"; tasti: "Maiusc+Canc"
                         onScelto: app.daCancellare = { files: menuBox.sel, perSempre: true, cestino: menuBox.m.pannello.cestino } }
                    VM { mostra: menuBox.sel.length > 0 && !!menuBox.m?.pannello.cestino; icona: "restore_from_trash"; testo: "Ripristina"
                         onScelto: app.op(["ripristina", ...menuBox.sel], () => app.leggiCestino()) }
                    VM { mostra: menuBox.sel.length > 0 && !menuBox.m?.pannello.cestino; icona: "info"; testo: "Proprietà"
                         onScelto: { const s = menuBox.sel; app.proprieta = { caricamento: true }; app.op(["proprieta", ...s], r => app.proprieta = Object.assign({ files: s }, r)); } }
                    // sulla cartella (clic nel vuoto)
                    VM { mostra: !menuBox.m?.voce && !menuBox.m?.pannello.cestino; icona: "create_new_folder"; testo: "Nuova cartella"; tasti: "Ctrl+Maiusc+N"
                         onScelto: app.nuovaCartella(menuBox.m.pannello) }
                    VM { mostra: !menuBox.m?.voce && !menuBox.m?.pannello.cestino; icona: "note_add"; testo: "Nuovo file di testo"
                         onScelto: { const pn = menuBox.m.pannello; app.op(["nuovo", pn.percorso, "Nuovo documento.txt"], r => { if (r.fatti) Qt.callLater(() => pn.rinomina = r.fatti[0]); }); } }
                    VM { mostra: !menuBox.m?.voce && !menuBox.m?.pannello.cestino; icona: "terminal"; testo: "Terminale qui"; tasti: "F4"
                         onScelto: app.terminale(menuBox.m.pannello.percorso) }
                    VM { mostra: !menuBox.m?.voce && !menuBox.m?.pannello.cestino; icona: "select_all"; testo: "Seleziona tutto"; tasti: "Ctrl+A"
                         onScelto: menuBox.m.pannello.tutti() }
                    VM { mostra: !!menuBox.m?.pannello.cestino && app.cestino.length > 0; icona: "delete_sweep"; testo: "Svuota il cestino"
                         onScelto: app.daCancellare = { svuota: true, files: [] } }
                }
            }

            // ── dialoghi: conferma, apri con, proprietà
            Rectangle {
                anchors.fill: parent
                visible: app.daCancellare !== null || app.apriCon !== null || app.proprieta !== null
                color: Qt.rgba(0, 0, 0, 0.45)
                MouseArea { anchors.fill: parent; onClicked: { app.daCancellare = null; app.apriCon = null; app.proprieta = null; } }
            }
            Rectangle {
                visible: app.daCancellare !== null
                anchors.centerIn: parent
                width: 440; height: colConf.implicitHeight + 36; radius: Tema.raggio + 2
                color: Tema.fondoAlto; border.color: Tema.allarme
                Column {
                    id: colConf
                    x: 18; y: 18; width: parent.width - 36; spacing: 14
                    Text { width: parent.width; wrapMode: Text.Wrap
                           text: app.daCancellare?.svuota ? "Svuotare il cestino? I file spariscono per sempre."
                                 : "Eliminare per sempre " + (app.daCancellare?.files.length === 1 ? "«" + app.daCancellare.files[0].split("/").pop() + "»" : (app.daCancellare?.files.length ?? 0) + " elementi") + "? Non si recupera."
                           color: Tema.testo; font.family: Tema.font; font.pixelSize: 14 }
                    Row {
                        anchors.right: parent.right; spacing: 8
                        Rectangle { width: 90; height: 32; radius: 16; color: Qt.rgba(1, 1, 1, 0.08)
                                    Text { anchors.centerIn: parent; text: "Annulla"; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
                                    MouseArea { anchors.fill: parent; onClicked: app.daCancellare = null } }
                        Rectangle { width: 110; height: 32; radius: 16; color: Tema.allarme
                                    Text { anchors.centerIn: parent; text: "Elimina"; color: "white"; font.family: Tema.font; font.pixelSize: 13 }
                                    MouseArea { anchors.fill: parent; onClicked: app.conferma() } }
                    }
                }
            }
            Rectangle {
                visible: app.apriCon !== null
                anchors.centerIn: parent
                width: 420; height: Math.min(parent.height - 80, colAc.implicitHeight + 36); radius: Tema.raggio + 2
                color: Tema.fondoAlto; border.color: Tema.bordo
                clip: true
                Column {
                    id: colAc
                    x: 18; y: 18; width: parent.width - 36; spacing: 6
                    Text { text: "Apri «" + (app.apriCon?.file.split("/").pop() ?? "") + "» con"; color: Tema.testo; font.family: Tema.font; font.pixelSize: 15 }
                    Text { text: app.apriCon?.mime ?? ""; color: Tema.tenue; font.family: Tema.font; font.pixelSize: 11 }
                    Text { visible: (app.apriCon?.app.length ?? 0) === 0; text: "Nessun programma installato dichiara di saper aprire questo tipo di file."
                           width: parent.width; wrapMode: Text.Wrap; color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13 }
                    Repeater {
                        model: app.apriCon?.app ?? []
                        Rectangle {
                            required property var modelData
                            width: colAc.width; height: 38; radius: 10
                            color: ma.containsMouse ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.15) : "transparent"
                            Image { x: 10; anchors.verticalCenter: parent.verticalCenter; width: 22; height: 22; sourceSize.width: 22; sourceSize.height: 22
                                    source: Quickshell.iconPath(modelData.icona, true) }
                            Text { x: 42; anchors.verticalCenter: parent.verticalCenter; text: modelData.nome + (modelData.predefinito ? "  (quello di sempre)" : "")
                                   color: Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
                            MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true
                                        onClicked: { Quickshell.execDetached(["gtk-launch", modelData.id.replace(/\.desktop$/, ""), app.apriCon.file]); app.apriCon = null; } }
                            Text { anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                   visible: !modelData.predefinito && ma.containsMouse; text: "rendi predefinito"; color: Tema.oroChiaro; font.family: Tema.font; font.pixelSize: 11
                                   MouseArea { anchors.fill: parent; anchors.margins: -4
                                               onClicked: { Quickshell.execDetached(["xdg-mime", "default", modelData.id, app.apriCon.mime]); app.avvisa(modelData.nome + " aprirà sempre questi file"); app.apriCon = null; } } }
                        }
                    }
                }
            }
            Rectangle {
                visible: app.proprieta !== null
                anchors.centerIn: parent
                width: 460; height: colPr.implicitHeight + 36; radius: Tema.raggio + 2
                color: Tema.fondoAlto; border.color: Tema.bordo
                readonly property var pr: app.proprieta ?? ({})
                Column {
                    id: colPr
                    x: 18; y: 18; width: parent.width - 36; spacing: 8
                    Text { text: parent.parent.pr.caricamento ? "Calcolo…" : (parent.parent.pr.nome ?? ""); width: parent.width; elide: Text.ElideMiddle
                           color: Tema.testo; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.Medium }
                    Repeater {
                        model: {
                            const r = app.proprieta;
                            if (!r || r.caricamento) return [];
                            return [["Dove", r.percorso], ["Tipo", r.tipo], ["Dimensione", I.dimensione(r.dimensione ?? 0) + (r.file > 1 ? " in " + r.file + " file" : "")],
                                    ["Modificato", r.modificato], ["Ultimo accesso", r.accesso], ["Proprietario", r.proprietario + " (" + r.gruppo + ")"],
                                    ["Permessi", r.permessi], ["Collegamento a", r.collegamento], ["Spazio libero lì", I.dimensione(r.libero ?? 0)]].filter(x => x[1]);
                        }
                        Row {
                            required property var modelData
                            spacing: 10
                            Text { width: 130; text: modelData[0]; color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13 }
                            Text { width: colPr.width - 140; wrapMode: Text.WrapAnywhere; text: modelData[1]; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
                        }
                    }
                    Row {
                        visible: !!app.proprieta && !app.proprieta.caricamento && (app.proprieta.files?.length ?? 0) === 1
                        spacing: 8
                        Text { text: "Eseguibile"; color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13; width: 130; anchors.verticalCenter: parent.verticalCenter }
                        Rectangle {
                            readonly property bool acceso: app.proprieta ? (parseInt(app.proprieta.permessi ?? "0", 8) & 0o100) !== 0 : false
                            width: 44; height: 24; radius: 12; color: acceso ? Tema.oro : Qt.rgba(1, 1, 1, 0.12)
                            Rectangle { width: 18; height: 18; radius: 9; y: 3; x: parent.acceso ? 23 : 3; color: parent.acceso ? Tema.fondo : Tema.testo }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: { const pr = app.proprieta; const m = parseInt(pr.permessi, 8) ^ 0o111;
                                                     app.op(["permessi", pr.files[0], m.toString(8)], () => app.op(["proprieta", ...pr.files], r => app.proprieta = Object.assign({ files: pr.files }, r))); } }
                        }
                    }
                }
            }
        }
    }
}
