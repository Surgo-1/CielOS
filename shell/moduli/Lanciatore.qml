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
        const lista = DesktopEntries.applications.values;
        // LibreWolf è il motore di CielFox: con CielFox installato non serve vederlo due volte
        const cielfox = lista.some(a => a.id === "cielfox");
        const app = lista.filter(a => !a.noDisplay && !(cielfox && a.id === "librewolf"));
        const tutte = q ? app.concat(Strumenti.azioni) : app;     // gli strumenti solo cercandoli
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
        chiudi();
        if (a.fai) a.fai(); else Avvia.app(a);
    }
    function chiediCiel(t, aVoce) {
        t = t.replace(/^\?\s*/, "").trim();
        if (!t || attesa) return;
        domanda = t; risposta = ""; errore = ""; domandaCiel = ""; testo = "";
        attesa = "…";
        Ciel.chiama({ azione: "scrivi", testo: t, voce: aVoce, conferme: true }, r => {
            if (!r.ok) { l.errore = r.messaggio || Lingua.t("Messaggio rifiutato."); l.attesa = ""; return; }
            if (!r.id) { l.risposta = Lingua.t("(consegnato: la risposta è nella finestra di Ciel)"); l.attesa = ""; return; }
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
                if (r.stato === "fatto") { l.risposta = r.risposta || Lingua.t("(nessuna risposta)"); l.attesa = ""; }
                else if (r.stato === "sconosciuta") { l.errore = Lingua.t("Ciel si è riavviata nel frattempo."); l.attesa = ""; }
            }, e => { l.errore = e; l.attesa = ""; });
        }
    }

    PanelWindow {
        id: finestra
        visible: Pannelli.lanciatore || scheda.opacity > 0     // resta il tempo di svanire
        screen: Quickshell.screens.find(s => s.name === Pannelli.schermo) ?? Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "ciel-lanciatore"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: Pannelli.lanciatore && !Pannelli.prova ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        onVisibleChanged: if (visible) { l.testo = ""; campo.text = ""; campo.forceActiveFocus(); memoria.reload(); }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.01, 0.02, 0.06, 0.42)
            opacity: Pannelli.lanciatore ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
            MouseArea { anchors.fill: parent; enabled: Pannelli.lanciatore; onClicked: l.chiudi() }
        }

        // l'ombra della carta
        Rectangle {
            width: scheda.width + 26; height: scheda.height
            anchors.horizontalCenter: parent.horizontalCenter
            y: scheda.y + 12
            radius: scheda.radius + 13
            color: Tema.ombra
            opacity: scheda.opacity * 0.6
        }

        Rectangle {
            id: scheda
            width: Math.min(720, parent.width - 80)
            height: colonna.implicitHeight + 36
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.17 + (Pannelli.lanciatore ? 0 : -12)     // scende appena mentre compare
            opacity: Pannelli.lanciatore ? 1 : 0
            scale: Pannelli.lanciatore ? 1 : 0.975
            Behavior on y { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
            radius: Tema.raggio + 8
            gradient: Gradient {
                GradientStop { position: 0; color: Tema.vetroAlto }
                GradientStop { position: 0.55; color: Tema.superficie }
                GradientStop { position: 1; color: Tema.vetroBasso }
            }
            border.color: Tema.alfa(Tema.oro, 0.40)
            border.width: 1
            MouseArea { anchors.fill: parent }

            Rectangle {                          // filo d'accento in cima
                x: 26; y: 0; width: 64; height: 2; radius: 1
                color: Tema.oro
            }

            Column {
                id: colonna
                x: 20; y: 18
                width: parent.width - 40
                spacing: 12

                Row {                            // la testata: chi sta rispondendo
                    width: parent.width
                    spacing: 9
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8; height: 8; radius: 4
                        color: Ciel.viva ? Ciel.colore : Tema.tenue
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: l.soloCiel ? Lingua.t("Chiedi a %1", Ciel.nome) : Lingua.t("Cerca, chiedi, apri")
                        color: Tema.oro; font.family: Tema.font; font.pixelSize: 12; font.letterSpacing: 1.8
                        font.capitalization: Font.AllUppercase; font.weight: Font.Medium
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 320; height: 1
                        color: Tema.bordoTenue
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: l.attesa ? Lingua.t("Ciel sta pensando") + ".".repeat(l.puntini) : Lingua.t("Invio per aprire")
                        color: Tema.tenue; font.family: Tema.font; font.pixelSize: 11
                    }
                }

                Rectangle {                      // il campo
                    width: parent.width; height: 58; radius: Tema.raggio + 2
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.rgba(0.01, 0.02, 0.08, 0.72) }
                        GradientStop { position: 1; color: Qt.rgba(0.02, 0.03, 0.10, 0.55) }
                    }
                    border.width: campo.activeFocus ? 1.5 : 1
                    border.color: campo.activeFocus ? Tema.alfa(Tema.oro, 0.75) : Tema.bordoTenue
                    Behavior on border.color { ColorAnimation { duration: Tema.durata } }
                    Rectangle {                  // la targhetta dell'icona
                        id: lenteSfondo
                        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                        width: 38; height: 38; radius: Tema.raggioPiccolo + 4
                        color: Tema.accentoSoft
                        border.width: 1; border.color: Tema.alfa(Tema.oro, 0.20)
                        Text {
                            id: lente
                            anchors.centerIn: parent
                            text: l.soloCiel || l.attesa ? "auto_awesome" : "search"
                            font.family: Tema.icone; font.pixelSize: 21; color: Tema.oro
                        }
                    }
                    TextInput {
                        id: campo
                        anchors { left: lenteSfondo.right; leftMargin: 13; right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                        color: Tema.testo; selectionColor: Tema.accentoForte
                        font.family: Tema.font; font.pixelSize: 19
                        clip: true
                        onTextChanged: l.testo = text
                        Keys.onPressed: e => {
                            if (l.domandaCiel && !text && (e.key === Qt.Key_S || e.key === Qt.Key_Y || e.key === Qt.Key_N)) {
                                l.conferma(e.key !== Qt.Key_N); e.accepted = true; return;
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
                            text: l.attesa ? Lingua.t("Ciel sta pensando") + ".".repeat(l.puntini) : Lingua.t("Cerca un'app o chiedi a Ciel…")
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
                        width: colonna.width; height: 52; radius: Tema.raggio
                        color: attiva ? Tema.accentoSoft : sopra.containsMouse ? Tema.biancoTenue : "transparent"
                        border.width: attiva ? 1 : 0
                        border.color: Tema.alfa(Tema.oro, 0.24)
                        Behavior on color { ColorAnimation { duration: Tema.durata } }
                        // la barretta d'accento a sinistra della riga scelta
                        Rectangle {
                            visible: riga.attiva
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            width: 3; height: 24; radius: 1.5
                            color: Tema.oro
                        }
                        Row {
                            anchors { left: parent.left; leftMargin: 12; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            spacing: 12
                            Rectangle {              // la targhetta dell'icona
                                width: 36; height: 36; radius: 10
                                color: riga.ciel ? Tema.accentoSoft : Qt.rgba(1, 1, 1, 0.055)
                                border.width: 1
                                border.color: riga.ciel ? Tema.alfa(Tema.oro, 0.25) : Tema.bordoTenue
                                readonly property string icona: riga.voce && !riga.voce.simbolo
                                    ? (Quickshell.iconPath(riga.voce.icon, true) || Quickshell.iconPath("application-x-executable", true)) : ""
                                Text {                   // uno strumento (o un'app senza icona): l'icona Material
                                    anchors.centerIn: parent
                                    visible: !riga.ciel && (!!riga.voce?.simbolo || (!!riga.voce && !parent.icona))
                                    text: riga.voce?.simbolo || "apps"
                                    font.family: Tema.icone; font.pixelSize: 22; color: riga.voce?.simbolo ? Tema.oro : Tema.tenue
                                }
                                IconImage {
                                    anchors.centerIn: parent
                                    width: 24; height: 24
                                    visible: !riga.ciel && !!parent.icona
                                    source: parent.icona
                                    asynchronous: true
                                }
                                Rectangle {
                                    visible: riga.ciel
                                    anchors.centerIn: parent
                                    width: 17; height: 17; radius: 8.5
                                    color: Ciel.colore
                                }
                            }
                            Column {
                                width: parent.width - 100
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1
                                Text {
                                    width: parent.width; elide: Text.ElideRight
                                    text: riga.ciel ? Lingua.t("Chiedi a %1", Ciel.nome) : (riga.voce?.name ?? "")
                                    color: riga.ciel ? Tema.oroChiaro : Tema.testo
                                    font.family: Tema.font; font.pixelSize: 15; font.weight: riga.ciel ? Font.Medium : Font.Normal
                                }
                                Text {
                                    width: parent.width
                                    visible: text !== ""
                                    text: riga.ciel ? "«" + l.testo.replace(/^\?\s*/, "") + "»" : (riga.voce?.genericName || riga.voce?.comment || "")
                                    color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12; elide: Text.ElideRight
                                }
                            }
                            Text {                   // la freccia che compare sulla riga scelta
                                anchors.verticalCenter: parent.verticalCenter
                                visible: riga.attiva
                                text: "arrow_forward"; font.family: Tema.icone; font.pixelSize: 17; color: Tema.oro
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
                    text: Lingua.t("Tu: ") + l.domanda
                    color: Tema.tenue; font.family: Tema.font; font.pixelSize: 14; wrapMode: Text.WordWrap
                    maximumLineCount: 3; elide: Text.ElideRight
                }
                Rectangle {                     // la domanda di conferma
                    visible: l.domandaCiel !== ""
                    width: parent.width
                    height: confermaCol.implicitHeight + 24
                    radius: Tema.raggio
                    color: Tema.accentoSoft
                    border.width: 1; border.color: Tema.alfa(Tema.oro, 0.30)
                    Rectangle { anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                width: 3; radius: 1.5; color: Tema.oro }
                    Column {
                        id: confermaCol
                        x: 16; y: 12
                        width: parent.width - 28
                        spacing: 10
                        Text {
                            width: parent.width
                            text: l.domandaCiel
                            color: Tema.oroChiaro; font.family: Tema.font; font.pixelSize: 15; wrapMode: Text.WordWrap
                        }
                        Row {
                            spacing: 10
                            Repeater {
                                model: [[Lingua.t("Sì (S)"), true], [Lingua.t("No (N)"), false]]
                                Rectangle {
                                    required property var modelData
                                    width: 116; height: 36; radius: 18
                                    color: si.containsMouse ? Tema.accentoMedio : Tema.accentoSoft
                                    border.width: 1; border.color: Tema.alfa(Tema.oro, 0.5)
                                    Text { anchors.centerIn: parent; text: parent.modelData[0]; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14 }
                                    MouseArea { id: si; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: l.conferma(parent.modelData[1]) }
                                }
                            }
                        }
                    }
                }
                Rectangle {                     // la risposta (o l'errore)
                    visible: (l.risposta !== "" || l.errore !== "") && l.righe === 0
                    width: parent.width
                    height: risposta.implicitHeight + 26
                    radius: Tema.raggio
                    color: l.errore ? Tema.conAlfa(Tema.allarme, 0.10) : Tema.biancoTenue
                    border.width: 1
                    border.color: l.errore ? Tema.conAlfa(Tema.allarme, 0.35) : Tema.bordoTenue
                    Text {
                        id: risposta
                        x: 16; y: 13
                        width: parent.width - 30
                        text: l.errore || l.risposta
                        color: l.errore ? "#ffb3b3" : Tema.testo
                        font.family: Tema.font; font.pixelSize: 15; wrapMode: Text.WordWrap
                        textFormat: Text.PlainText
                        maximumLineCount: 16; elide: Text.ElideRight
                    }
                }

                // a campo vuoto, senza risultati: cosa si può fare
                Text {
                    visible: l.righe === 0 && !l.testo.trim() && l.risposta === "" && l.errore === "" && !l.attesa
                    width: parent.width
                    text: Lingua.t("Scrivi il nome di un'app, oppure una domanda per %1. Inizia con «?» per parlare solo con lei.", Ciel.nome)
                    color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13; wrapMode: Text.WordWrap
                    lineHeight: 1.15
                }

                Rectangle {                     // i tasti, in fondo
                    width: parent.width; height: 1; color: Tema.bordoTenue
                }
                Row {
                    width: parent.width
                    spacing: 14
                    Repeater {
                        model: [["↑↓", Lingua.t("scegli")], ["Invio", Lingua.t("apri")], ["Maiusc+Invio", Lingua.t("a voce")], ["Esc", Lingua.t("chiudi")]]
                        Row {
                            required property var modelData
                            spacing: 6
                            Rectangle {
                                height: 20; width: tasto.implicitWidth + 12; radius: 5
                                color: Tema.biancoTenue; border.width: 1; border.color: Tema.bordoTenue
                                Text { id: tasto; anchors.centerIn: parent; text: parent.parent.modelData[0]
                                       color: Tema.testo; font.family: Tema.font; font.pixelSize: 11; font.weight: Font.Medium }
                            }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: parent.modelData[1]
                                   color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12 }
                        }
                    }
                    Item { width: 1; height: 1 }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Lingua.t("%1 app", l.app.length)
                        color: Tema.tenue; font.family: Tema.font; font.pixelSize: 11
                    }
                }
            }
        }
    }
}
