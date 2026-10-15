// La Guida (Super+A → Guida, o «cielos wiki»): la wiki di CielOS (wiki/*.md, funziona senza internet) e «Cosa vuol
// dire?»: incolli il testo di un errore e la guida agli errori (wiki/errori.json, «cielos errore») dice cosa significa
// e cosa fare. Le pagine si scelgono a sinistra (i link del testo diventano grassetto: Qt li disegna blu scuro).
import QtQuick
import Quickshell
import Quickshell.Io
import qs.servizi

Item {
    id: g
    readonly property string cartella: Percorsi.radice + "/wiki/"
    property var pagine: []                       // ["00-benvenuto", …]
    property string pagina: "00-benvenuto"
    property var risposte: null                   // le voci trovate da «Cosa vuol dire?» (null: niente cercato)
    property string cercato: ""

    function apri(p) {
        if (p) { chiesta = p; risolvi(); }
        risposte = null; cercato = "";
        if (!elenco.running) elenco.running = true;
        testo.contentY = 0;
    }
    function indietro() { if (risposte !== null) { risposte = null; return true; } return false; }
    function nome(p) {                            // «03-ciel» → «Ciel» (dal titolo # della pagina, se letto)
        return (titoli[p] ?? p.replace(/^\d+-/, "").replace(/-/g, " ")).replace(/^./, c => c.toUpperCase());
    }
    property var titoli: ({})
    property string chiesta: ""                   // la pagina chiesta (anche solo l'inizio del nome: «08», «errori»)
    function risolvi() {
        if (!chiesta || !pagine.length) return;
        pagina = pagine.find(x => x === chiesta) ?? pagine.find(x => x.startsWith(chiesta) || x.includes(chiesta)) ?? pagina;
        chiesta = "";
    }
    function spiega(t) {
        t = t.trim();
        if (!t) return;
        cercato = t;
        errore.command = [Percorsi.bin("cielos"), "errore", "--json", t];
        errore.running = true;
    }
    function link(l) {
        if (/^https?:/.test(l)) { Quickshell.execDetached(["xdg-open", l]); Pannelli.chiudi(); return; }
        const m = l.match(/^([\w-]+)\.md(#.*)?$/);
        if (m) apri(m[1]);
        else if (l.startsWith("#")) testo.contentY = 0;
    }

    Process {
        id: elenco
        command: ["sh", "-c", "cd \"$0\" && for f in *.md; do printf '%s\\t%s\\n' \"${f%.md}\" \"$(head -1 \"$f\" | sed 's/^# *//')\"; done", g.cartella]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = [], t = {};
                for (const r of text.trim().split("\n")) { const [a, b] = r.split("\t"); if (a) { p.push(a); t[a] = b; } }
                g.pagine = p; g.titoli = t; g.risolvi();
            }
        }
    }
    property string contenuto: ""
    FileView { id: file; path: g.cartella + g.pagina + ".md"; printErrors: false; onLoaded: g.contenuto = text().replace(/\[([^\]]+)\]\(([^)]+)\)/g, "**$1**") }   // i link di Qt sono blu scuro: in grassetto (le pagine sono a sinistra)
    Process {
        id: errore
        stdout: StdioCollector { onStreamFinished: { try { g.risposte = JSON.parse(text); } catch (e) { g.risposte = []; } } }
    }

    Row {
        anchors.fill: parent
        spacing: 16

        Column {                                  // a sinistra: le pagine
            id: lato
            width: 190; height: parent.height
            spacing: 2
            Repeater {
                model: g.pagine
                Rectangle {
                    required property string modelData
                    width: lato.width; height: 30; radius: Tema.raggio - 4
                    readonly property bool qui: g.pagina === modelData && g.risposte === null
                    color: qui ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.18) : tp.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                    Text {
                        anchors { left: parent.left; leftMargin: 10; right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                        text: g.nome(modelData); elide: Text.ElideRight
                        color: parent.qui ? Tema.oroChiaro : Tema.testo; font.family: Tema.font; font.pixelSize: 13
                    }
                    MouseArea { id: tp; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: g.apri(modelData) }
                }
            }
        }

        Column {                                  // a destra: «Cosa vuol dire?» e la pagina
            width: parent.width - lato.width - 16; height: parent.height
            spacing: 10
            Rectangle {
                width: parent.width; height: 40; radius: Tema.raggio
                color: Qt.rgba(0.02, 0.03, 0.1, 0.9)
                border.color: campo.activeFocus ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.7) : Qt.rgba(1, 1, 1, 0.12)
                Text { id: lente; anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                       text: "help"; font.family: Tema.icone; font.pixelSize: 20; color: Tema.oro }
                TextInput {
                    id: campo
                    anchors { left: lente.right; leftMargin: 10; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; clip: true
                    onAccepted: g.spiega(text)
                    Text { anchors.verticalCenter: parent.verticalCenter; visible: !campo.text; color: Tema.tenue; font: campo.font
                           text: Lingua.t("Cosa vuol dire? Incolla qui il testo di un errore e premi Invio") }
                }
            }
            Flickable {
                id: testo
                width: parent.width; height: parent.height - y
                contentHeight: corpo.implicitHeight + 20
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: corpo
                    width: testo.width - 12
                    spacing: 12
                    // le risposte di «Cosa vuol dire?»
                    Text {
                        visible: g.risposte !== null
                        width: parent.width; wrapMode: Text.WordWrap
                        text: errore.running ? Lingua.t("Cerco…")
                              : g.risposte && g.risposte.length ? Lingua.t("Per «%1»:", g.cercato.slice(0, 80))
                              : Lingua.t("Non conosco questo errore. Prova il Medico (Impostazioni → Medico), chiedi a Ciel, o manda «cielos segnala».")
                        color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13
                    }
                    Repeater {
                        model: g.risposte ?? []
                        Rectangle {
                            required property var modelData
                            width: corpo.width; height: voce.implicitHeight + 24; radius: Tema.raggio
                            color: Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.07)
                            border.color: Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.3)
                            Text {
                                id: voce
                                x: 14; y: 12; width: parent.width - 28
                                textFormat: Text.MarkdownText; wrapMode: Text.WordWrap
                                text: "### " + modelData.titolo + "\n\n**" + Lingua.t("Cosa significa") + ".** " + modelData.significa
                                      + "\n\n**" + Lingua.t("Cosa fare") + ".** " + modelData.fare
                                color: Tema.testo; font.family: Tema.font; font.pixelSize: 14
                            }
                        }
                    }
                    // la pagina della wiki
                    Text {
                        visible: g.risposte === null
                        width: parent.width
                        textFormat: Text.MarkdownText; wrapMode: Text.WordWrap
                        text: g.contenuto
                        color: Tema.testo; linkColor: Tema.oroChiaro
                        font.family: Tema.font; font.pixelSize: 14
                        onLinkActivated: l => g.link(l)
                        HoverHandler { cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor }
                    }
                }
            }
        }
    }
}
