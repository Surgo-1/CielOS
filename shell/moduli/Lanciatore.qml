// Il lanciatore, che è anche Ciel: scrivi, e sotto compaiono le app che corrispondono, più «Chiedi a Ciel».
// Frecce per scegliere, Invio per aprire l'app o mandare la domanda (Maiusc+Invio: Ciel risponde anche a voce),
// Esc per chiudere. Se inizi con «?» la prima scelta è Ciel. A campo vuoto: le app che apri più spesso.
// Le domande vanno a Ciel come dalla sua finestra (stessa conversazione); le sue conferme («La attivo?») compaiono
// qui con Sì / No (o i tasti S e N).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import qs.servizi

Scope {
    id: l

    property string testo: ""
    property int scelta: 0
    // conversazione con Ciel
    property string attesa: ""           // id del messaggio di cui aspettiamo la risposta
    property string domanda: ""
    property string risposta: ""
    property string errore: ""
    property string domandaCiel: ""
    property int puntini: 0
    property var usi: ({})               // app -> volte che l'hai aperta (per l'ordine)

    readonly property bool soloCiel: testo.startsWith("?")
    readonly property var app: {
        const q = testo.trim().toLowerCase();
        const tutte = DesktopEntries.applications.values.filter(a => !a.noDisplay);
        if (!q)
            return tutte.filter(a => (usi[a.id] ?? 0) > 0).sort((a, b) => (usi[b.id] ?? 0) - (usi[a.id] ?? 0)).slice(0, 6);
        if (soloCiel)
            return [];
        const punti = a => {
            const n = (a.name ?? "").toLowerCase();
            if (n.startsWith(q)) return 100;
            if (n.split(/[\s\-_.]+/).some(p => p.startsWith(q))) return 80;
            if (n.includes(q)) return 60;
            const altro = [a.genericName, a.comment, ...(a.keywords ?? []), a.id].join(" ").toLowerCase();
            return altro.includes(q) ? 30 : 0;
        };
        return tutte.map(a => [a, punti(a) + Math.min(20, usi[a.id] ?? 0)]).filter(x => x[1] > 20)
            .sort((a, b) => b[1] - a[1]).slice(0, 7).map(x => x[0]);
    }
    // le righe: app, e (se hai scritto qualcosa) Ciel; con «?» Ciel viene prima
    readonly property int righe: app.length + (testo.trim() ? 1 : 0)
    readonly property int rigaCiel: !testo.trim() ? -1 : soloCiel ? 0 : app.length

    function apri() { Pannelli.apri("lanciatore"); }
    function chiudi() { Pannelli.chiudi(); }

    function lancia(a) {
        const u = Object.assign({}, usi);
        u[a.id] = (u[a.id] ?? 0) + 1;
        usi = u;
        memoria.setText(JSON.stringify(u));
        a.execute();
        chiudi();
    }
    function chiediCiel(t, aVoce) {
        t = t.replace(/^\?\s*/, "").trim();
        if (!t || attesa) return;
        domanda = t; risposta = ""; errore = ""; domandaCiel = ""; testo = "";
        attesa = "…";
        Ciel.chiama({ azione: "scrivi", testo: t, voce: aVoce, conferme: true }, r => {
            if (!r.ok) { l.errore = r.messaggio || "Messaggio rifiutato."; l.attesa = ""; return; }
            if (!r.id) { l.risposta = "(consegnato: la risposta è nella finestra di Ciel)"; l.attesa = ""; return; }
            l.attesa = r.id;
        }, e => { l.errore = e; l.attesa = ""; });
    }
    function conferma(si) {
        if (!domandaCiel || !attesa) return;
        Ciel.chiama({ azione: "conferma", id: attesa, si: si }, _ => {}, _ => {});
        domandaCiel = "";
    }
    function invio(aVoce) {
        if (scelta === rigaCiel) chiediCiel(testo, aVoce);
        else {
            const i = rigaCiel >= 0 && scelta > rigaCiel ? scelta - 1 : scelta;
            if (app[i]) lancia(app[i]);
            else if (testo.trim()) chiediCiel(testo, aVoce);
        }
    }

    onTestoChanged: scelta = 0

    GlobalShortcut { appid: "ciel"; name: "lanciatore"; description: "Lanciatore e Ciel"
        onPressed: Pannelli.lanciatore ? l.chiudi() : l.apri() }
    GlobalShortcut { appid: "ciel"; name: "sessione"; description: "Menu di spegnimento"
        onPressed: Pannelli.sessione ? Pannelli.chiudi() : Pannelli.apri("sessione") }
    IpcHandler {
        target: "lanciatore"
        function apri(): void { l.apri(); }
        function chiudi(): void { l.chiudi(); }
        function scrivi(t: string): void { l.apri(); campo.text = t; }
    }

    FileView {                           // quante volte apri ogni app (per l'ordine), in ~/.local/state/cielos
        id: memoria
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/cielos/lanciatore.json"
        printErrors: false
        atomicWrites: true
        onLoaded: { try { l.usi = JSON.parse(text()) || {}; } catch (e) {} }
    }

    Timer {                              // la risposta di Ciel (e le sue domande)
        interval: 450; repeat: true
        running: l.attesa !== "" && l.attesa !== "…"
        onTriggered: {
            l.puntini = (l.puntini + 1) % 4;
            Ciel.chiama({ azione: "risposta", id: l.attesa }, r => {
                l.domandaCiel = r.stato === "domanda" ? (r.domanda || "") : "";
                if (r.stato === "fatto") { l.risposta = r.risposta || "(nessuna risposta)"; l.attesa = ""; }
                else if (r.stato === "sconosciuta") { l.errore = "Ciel si è riavviata nel frattempo."; l.attesa = ""; }
            }, e => { l.errore = e; l.attesa = ""; });
        }
    }

    PanelWindow {
        id: finestra
        visible: Pannelli.lanciatore
        screen: Quickshell.screens.find(s => s.name === Pannelli.schermo) ?? Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "ciel-lanciatore"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: Pannelli.lanciatore ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        onVisibleChanged: if (visible) { l.testo = ""; campo.text = ""; campo.forceActiveFocus(); memoria.reload(); }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.02, 0.03, 0.09, 0.35)
            MouseArea { anchors.fill: parent; onClicked: l.chiudi() }
        }

        Rectangle {
            id: scheda
            width: Math.min(680, parent.width - 80)
            height: colonna.implicitHeight + 32
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.2
            radius: Tema.raggio + 4
            color: Tema.superficie
            border.color: Qt.rgba(1, 0.75, 0.25, 0.45)
            MouseArea { anchors.fill: parent }

            Column {
                id: colonna
                x: 18; y: 16
                width: parent.width - 36
                spacing: 10

                Rectangle {                      // il campo
                    width: parent.width; height: 50; radius: Tema.raggio
                    color: Qt.rgba(0.02, 0.03, 0.1, 0.9)
                    border.color: campo.activeFocus ? Qt.rgba(1, 0.75, 0.25, 0.7) : Qt.rgba(1, 1, 1, 0.12)
                    Text {
                        id: lente
                        anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                        text: l.soloCiel || l.attesa ? "auto_awesome" : "search"
                        font.family: Tema.icone; font.pixelSize: 22; color: Tema.oro
                    }
                    TextInput {
                        id: campo
                        anchors { left: lente.right; leftMargin: 12; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                        color: Tema.testo; selectionColor: Qt.rgba(1, 0.75, 0.25, 0.4)
                        font.family: Tema.font; font.pixelSize: 18
                        clip: true
                        onTextChanged: l.testo = text
                        Keys.onPressed: e => {
                            if (l.domandaCiel && !text && (e.key === Qt.Key_S || e.key === Qt.Key_N)) {
                                l.conferma(e.key === Qt.Key_S); e.accepted = true; return;
                            }
                            if (e.key === Qt.Key_Escape) l.chiudi();
                            else if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab) l.scelta = Math.min(l.righe - 1, l.scelta + 1);
                            else if (e.key === Qt.Key_Up) l.scelta = Math.max(0, l.scelta - 1);
                            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                                l.invio((e.modifiers & Qt.ShiftModifier) !== 0);
                                if (l.attesa) text = "";
                            } else return;
                            e.accepted = true;
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !campo.text
                            text: l.attesa ? "Ciel sta pensando" + ".".repeat(l.puntini) : "Cerca un'app o chiedi a Ciel…"
                            color: Tema.tenue; font: campo.font
                        }
                    }
                }

                Repeater {                       // le righe: app e Ciel
                    model: l.righe
                    Rectangle {
                        id: riga
                        required property int index
                        readonly property bool ciel: index === l.rigaCiel
                        readonly property var voce: ciel ? null : l.app[l.rigaCiel >= 0 && index > l.rigaCiel ? index - 1 : index]
                        readonly property bool attiva: l.scelta === index
                        width: colonna.width; height: 46; radius: Tema.raggio - 2
                        color: attiva ? Qt.rgba(1, 0.75, 0.25, 0.14) : sopra.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                        Row {
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            spacing: 12
                            Item {
                                width: 28; height: 28
                                IconImage {
                                    anchors.fill: parent
                                    visible: !riga.ciel
                                    source: riga.voce ? (Quickshell.iconPath(riga.voce.icon, true) || Quickshell.iconPath("application-x-executable", true)) : ""
                                    asynchronous: true
                                }
                                Rectangle {
                                    visible: riga.ciel
                                    anchors.centerIn: parent
                                    width: 18; height: 18; radius: 9
                                    color: Ciel.colore
                                }
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    text: riga.ciel ? "Chiedi a " + Ciel.nome : (riga.voce?.name ?? "")
                                    color: riga.ciel ? Tema.oroChiaro : Tema.testo
                                    font.family: Tema.font; font.pixelSize: 15; font.weight: riga.ciel ? Font.Medium : Font.Normal
                                }
                                Text {
                                    width: colonna.width - 80
                                    visible: text !== ""
                                    text: riga.ciel ? "«" + l.testo.replace(/^\?\s*/, "") + "»" : (riga.voce?.genericName || riga.voce?.comment || "")
                                    color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12; elide: Text.ElideRight
                                }
                            }
                        }
                        MouseArea {
                            id: sopra
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: l.scelta = riga.index
                            onClicked: { l.scelta = riga.index; l.invio(false); }
                        }
                    }
                }

                // la conversazione con Ciel
                Text {
                    visible: l.domanda !== "" && l.righe === 0
                    width: parent.width
                    text: "Tu: " + l.domanda
                    color: Tema.tenue; font.family: Tema.font; font.pixelSize: 14; wrapMode: Text.WordWrap
                    maximumLineCount: 3; elide: Text.ElideRight
                }
                Column {
                    visible: l.domandaCiel !== ""
                    width: parent.width
                    spacing: 10
                    Text {
                        width: parent.width
                        text: l.domandaCiel
                        color: Tema.oroChiaro; font.family: Tema.font; font.pixelSize: 16; wrapMode: Text.WordWrap
                    }
                    Row {
                        spacing: 10
                        Repeater {
                            model: [["Sì (S)", true], ["No (N)", false]]
                            Rectangle {
                                required property var modelData
                                width: 110; height: 36; radius: 18
                                color: si.containsMouse ? Qt.rgba(1, 0.75, 0.25, 0.25) : Qt.rgba(1, 0.75, 0.25, 0.1)
                                border.color: Qt.rgba(1, 0.75, 0.25, 0.6)
                                Text { anchors.centerIn: parent; text: parent.modelData[0]; color: Tema.testo; font.family: Tema.font; font.pixelSize: 15 }
                                MouseArea { id: si; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: l.conferma(parent.modelData[1]) }
                            }
                        }
                    }
                }
                Text {
                    visible: (l.risposta !== "" || l.errore !== "") && l.righe === 0
                    width: parent.width
                    text: l.errore || l.risposta
                    color: l.errore ? "#ffb3b3" : Tema.testo
                    font.family: Tema.font; font.pixelSize: 16; wrapMode: Text.WordWrap
                    textFormat: Text.PlainText
                    maximumLineCount: 16; elide: Text.ElideRight
                }
            }
        }
    }
}
