// I workspace dello schermo: dieci per schermo (il gruppo di quello attivo: qui 1-10 sul principale, 11-20
// sull'altro). Quello che guardi è d'oro; uno con finestre mostra l'icona della sua app principale (con un numerino
// se ce n'è più d'una); uno libero è un cerchietto vuoto; uno che chiede attenzione (finestra urgente) pulsa rosso.
// Rotella: avanti e indietro. Mouse sopra: le finestre di quel workspace; clic su una per andarci, clic destro per
// portarla nel workspace che guardi, clic centrale per chiuderla. Trascinando un file sopra un workspace (dal file
// manager o da un'altra app), dopo un attimo ci va: lo lasci nell'app che è là.
// Sotto, i workspace speciali (Super+M musica, Super+D comunicazione, Super+S…): un'icona per ognuno che esiste,
// accesa quando è aperto su questo schermo. Clic: lo apre o lo chiude.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.servizi

Item {
    id: ws
    required property ShellScreen schermo
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(schermo)
    readonly property int attivo: monitor?.activeWorkspace?.id ?? 1
    readonly property int base: Math.floor((Math.max(1, attivo) - 1) / 10) * 10
    readonly property bool icone: Tema.v("ws_icone", true)          // tema.json «ws_icone»: le icone delle app
    property string specialeAperto: ""                               // «music», «communication»… su questo schermo
    implicitWidth: tutto.implicitWidth
    implicitHeight: tutto.implicitHeight

    function vai(n) { Pannelli.dispatch(`hl.dsp.focus({ workspace = ${n} })`, `workspace ${n}`); }
    function indirizzo(t) { const a = String(t.address); return a.startsWith("0x") ? a : "0x" + a; }
    function focalizza(t) {
        const a = indirizzo(t);
        Pannelli.dispatch(`hl.dsp.focus({ window = "address:${a}" })`, `focuswindow address:${a}`);
    }
    function portaQui(t) {
        const a = indirizzo(t);
        Pannelli.dispatch(`hl.dsp.window.move({ window = "address:${a}", workspace = ${ws.attivo}, follow = false })`,
                          `movetoworkspacesilent ${ws.attivo},address:${a}`);
    }
    function chiudi(t) {
        const a = indirizzo(t);
        Pannelli.dispatch(`hl.dsp.window.close({ window = "address:${a}" })`, `closewindow address:${a}`);
    }
    function alternaSpeciale(nome) {
        Pannelli.dispatch(`hl.dsp.workspace.toggle_special("${nome}")`, `togglespecialworkspace ${nome}`);
    }

    // l'icona di un'app dalla sua classe (dalle voci .desktop; se non si trova, niente: resta il punto)
    function iconaApp(classe) {
        if (!classe) return "";
        const e = DesktopEntries.heuristicLookup(classe);
        return Quickshell.iconPath(e?.icon || classe.toLowerCase(), true);
    }
    function classeDi(t) { return t?.lastIpcObject?.class || t?.wayland?.appId || ""; }
    // la finestra «principale» di un workspace: quella attiva se c'è, sennò la prima
    function principale(finestre) { return finestre.find(t => t.activated) ?? finestre[0]; }

    // i workspace speciali conosciuti (gli altri hanno un'icona generica)
    readonly property var speciali: ({
        "music": ["music_note", Lingua.t("Musica")], "communication": ["forum", Lingua.t("Comunicazione")],
        "todo": ["checklist", Lingua.t("Cose da fare")], "sysmon": ["monitoring", Lingua.t("Sistema")],
        "special": ["star", Lingua.t("Speciale")], "scratchpad": ["edit_note", Lingua.t("Appunti")]
    })
    readonly property var elencoSpeciali: {
        const nomi = Hyprland.workspaces.values.filter(w => w.id < 0 && w.toplevels.values.length > 0)
                                               .map(w => w.name.replace(/^special:/, ""));
        if (specialeAperto && !nomi.includes(specialeAperto)) nomi.push(specialeAperto);
        const ordine = Object.keys(speciali);
        return nomi.sort((a, b) => (ordine.indexOf(a) + 1 || 99) - (ordine.indexOf(b) + 1 || 99));
    }

    // quale speciale è aperto qui: l'evento «activespecial» di Hyprland («special:music,HDMI-A-1» o «,HDMI-A-1»)
    Connections {
        target: Hyprland
        function onRawEvent(e) {
            if (e.name !== "activespecial") return;
            const i = e.data.lastIndexOf(",");
            if (e.data.slice(i + 1) === ws.monitor?.name)
                ws.specialeAperto = e.data.slice(0, i).replace(/^special:/, "");
        }
    }
    Component.onCompleted: Hyprland.refreshMonitors()       // all'avvio della shell può essere già aperto
    Connections {
        target: ws.monitor
        function onLastIpcObjectChanged() {
            const n = ws.monitor?.lastIpcObject?.specialWorkspace?.name;
            if (n !== undefined) ws.specialeAperto = n.replace(/^special:/, "");
        }
    }

    MouseArea {                         // la rotella su tutta la colonna
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: r => Pannelli.dispatch(`hl.dsp.focus({ workspace = "r${r.angleDelta.y > 0 ? "-" : "+"}1" })`,
                                        `workspace r${r.angleDelta.y > 0 ? "-" : "+"}1`)
    }

    Grid {
    id: tutto
    columns: Tema.orizzontale ? 3 : 1
    spacing: 10
    verticalItemAlignment: Grid.AlignVCenter
    horizontalItemAlignment: Grid.AlignHCenter

    Grid {
    columns: Tema.orizzontale ? 10 : 1
    spacing: 7
    verticalItemAlignment: Grid.AlignVCenter
    horizontalItemAlignment: Grid.AlignHCenter
    Repeater {
        model: 10
        Item {
            id: punto
            required property int index
            readonly property int numero: ws.base + index + 1
            readonly property bool qui: numero === ws.attivo
            readonly property var spazio: Hyprland.workspaces.values.find(w => w.id === numero)
            readonly property var finestre: spazio ? spazio.toplevels.values : []
            readonly property bool pieno: finestre.length > 0
            readonly property bool urgente: (spazio?.urgent ?? false) || finestre.some(t => t.urgent)
            readonly property bool sopra: tocco.containsMouse
            readonly property string iconaSrc: ws.icone && pieno ? ws.iconaApp(ws.classeDi(ws.principale(finestre))) : ""
            readonly property bool conIcona: iconaSrc !== ""
            readonly property int lungo: conIcona ? (qui ? 30 : 24) : qui ? 26 : 12      // nel verso della barra
            width: Tema.orizzontale ? lungo : Tema.barra - 20
            height: Tema.orizzontale ? Tema.barra - 20 : lungo
            Behavior on width { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }

            // senza icona: il punto (pieno, vuoto o la barretta d'oro)
            Rectangle {
                visible: !punto.conIcona
                anchors.centerIn: parent
                readonly property int corto: punto.qui ? 8 : punto.pieno ? 8 : 7
                width: punto.qui && Tema.orizzontale ? parent.width : corto
                height: punto.qui && !Tema.orizzontale ? parent.height : corto
                radius: width / 2
                color: punto.urgente ? Tema.allarme : punto.qui ? Tema.oro : punto.pieno ? Tema.tenue : "transparent"
                border.width: punto.qui || punto.pieno || punto.urgente ? 0 : 1.5
                border.color: Qt.rgba(0.6, 0.65, 0.78, 0.6)
            }
            // con icona: la pastiglia (d'oro se è quello che guardi) e l'icona dell'app
            Rectangle {
                visible: punto.conIcona
                anchors.centerIn: parent
                width: Tema.orizzontale ? parent.width : 26
                height: Tema.orizzontale ? 26 : parent.height
                radius: 8
                color: punto.qui ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.28)
                     : punto.sopra ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.12) : "transparent"
                border.width: punto.qui ? 1.5 : 0
                border.color: Tema.oro
                Behavior on color { ColorAnimation { duration: Tema.durata } }
                Image {
                    anchors.centerIn: parent
                    source: punto.iconaSrc
                    sourceSize.width: 18; sourceSize.height: 18
                    width: 18; height: 18
                    opacity: punto.qui || punto.sopra ? 1 : 0.7
                }
                Rectangle {                  // più di una finestra: il numerino
                    visible: punto.finestre.length > 1
                    anchors.right: parent.right; anchors.bottom: parent.bottom
                    anchors.rightMargin: -3; anchors.bottomMargin: -3
                    width: 13; height: 13; radius: 6.5
                    color: Tema.fondo
                    border.width: 1; border.color: Tema.bordo
                    Text {
                        anchors.centerIn: parent
                        text: punto.finestre.length > 9 ? "9+" : punto.finestre.length
                        color: Tema.testo; font.family: Tema.font; font.pixelSize: 8; font.bold: true
                    }
                }
            }
            // urgente: un alone rosso che respira
            Rectangle {
                visible: punto.urgente
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height) + 6; height: width; radius: width / 2
                color: "transparent"; border.width: 2; border.color: Tema.allarme
                SequentialAnimation on opacity {
                    running: punto.urgente && Tema.animazioni; loops: Animation.Infinite
                    NumberAnimation { from: 0.9; to: 0.15; duration: 700 }
                    NumberAnimation { from: 0.15; to: 0.9; duration: 700 }
                }
            }
            MouseArea {
                id: tocco
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { scheda.aperta = false; ws.vai(punto.numero); }
            }
            // trascinando un file (o un testo) sopra il workspace, dopo un attimo ci va: lo lasci nell'app di là
            DropArea {
                anchors.fill: parent
                onEntered: drag => { drag.accepted = true; if (!punto.qui) attesaDrop.restart(); }
                onExited: attesaDrop.stop()
                onDropped: drop => { attesaDrop.stop(); ws.vai(punto.numero); }
                Timer { id: attesaDrop; interval: 450; onTriggered: ws.vai(punto.numero) }
            }
            Schedina {
                id: scheda
                icona: punto
                inAlto: true
                larghezza: 300
                titolo: "Workspace " + punto.numero + (punto.finestre.length > 1 ? Lingua.t(" · %1 finestre", punto.finestre.length) : "")
                Text {
                    visible: !punto.pieno
                    text: Lingua.t("Vuoto.")
                    color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13
                }
                Repeater {
                    model: punto.finestre
                    RigaFinestra {
                        required property var modelData
                        finestra: modelData
                        diQui: punto.qui
                        onVai: { scheda.aperta = false; ws.focalizza(modelData); }
                        onPorta: ws.portaQui(modelData)
                        onChiudi: ws.chiudi(modelData)
                    }
                }
                Text {
                    visible: punto.pieno
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: punto.qui ? Lingua.t("Clic: vai alla finestra · clic centrale: chiudila")
                                    : Lingua.t("Clic: vai · clic destro: portala qui · clic centrale: chiudila")
                    color: Tema.tenue; font.family: Tema.font; font.pixelSize: 11
                }
            }
        }
    }
    }

    // la linea tra i numeri e gli speciali (solo se ce n'è qualcuno)
    Rectangle {
        visible: ws.elencoSpeciali.length > 0
        width: Tema.orizzontale ? 1 : Tema.barra - 30
        height: Tema.orizzontale ? Tema.barra - 30 : 1
        color: Tema.bordo
    }

    Grid {
    columns: Tema.orizzontale ? Math.max(1, ws.elencoSpeciali.length) : 1
    spacing: 4
    Repeater {
        model: ws.elencoSpeciali
        Icona {
            id: sp
            required property string modelData
            readonly property bool aperto: modelData === ws.specialeAperto
            readonly property var spazio: Hyprland.workspaces.values.find(w => w.name === "special:" + modelData)
            readonly property var finestre: spazio ? spazio.toplevels.values : []
            implicitWidth: Tema.barra - 18
            nome: (ws.speciali[modelData] ?? ["layers"])[0]
            dimensione: 18
            colore: finestre.some(t => t.urgent) ? Tema.allarme : aperto ? Tema.oro : Tema.tenue
            Rectangle {                      // aperto: la pastiglia d'oro dietro
                z: -1
                anchors.fill: parent
                radius: Tema.raggio / 1.5
                color: Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.22)
                border.width: 1.5; border.color: Tema.oro
                visible: sp.aperto
            }
            onPremuto: mouse => { schedaSp.aperta = false; ws.alternaSpeciale(sp.modelData); }
            DropArea {                       // trascinando sopra: lo apre (se è chiuso), per lasciarci il file
                anchors.fill: parent
                onEntered: drag => { drag.accepted = true; if (!sp.aperto) attesaSp.restart(); }
                onExited: attesaSp.stop()
                Timer { id: attesaSp; interval: 450; onTriggered: if (!sp.aperto) ws.alternaSpeciale(sp.modelData) }
            }
            Schedina {
                id: schedaSp
                icona: sp
                larghezza: 300
                titolo: (ws.speciali[sp.modelData] ?? [null, sp.modelData])[1] + (sp.aperto ? Lingua.t(" · aperto") : "")
                Text {
                    visible: sp.finestre.length === 0
                    text: Lingua.t("Nessuna finestra.")
                    color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13
                }
                Repeater {
                    model: sp.finestre
                    RigaFinestra {
                        required property var modelData
                        finestra: modelData
                        diQui: false
                        onVai: { schedaSp.aperta = false; ws.focalizza(modelData); }
                        onPorta: ws.portaQui(modelData)
                        onChiudi: ws.chiudi(modelData)
                    }
                }
                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: sp.aperto ? Lingua.t("Clic sull'icona nella barra: lo chiude. Clic destro su una finestra: portala nel workspace che guardi.") : Lingua.t("Clic sull'icona nella barra: lo apre. Clic destro su una finestra: portala nel workspace che guardi.")
                    color: Tema.tenue; font.family: Tema.font; font.pixelSize: 11
                }
            }
        }
    }
    }
    }
}
