pragma Singleton
// L'aspetto della shell Nightly: un'altra CielOS, non un altro tema. Vetro quasi nero, fili di luce ciano, oro per
// la voce di Ciel; testo monospaziato per i numeri, maiuscoletto spaziato per le etichette, angoli a mirino.
// Le preferenze dell'utente restano quelle di CielOS (~/.config/cielos/tema.json), lette e non scritte: accento,
// sfondo, terminale, IA. La Nightly non tocca niente della stabile.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: tema

    property var utente: ({})
    property bool pronto: false
    function v(nome, serie) { return utente[nome] !== undefined ? utente[nome] : serie; }

    // ── il vuoto: il fondo della notte ──
    readonly property color vuoto: "#04060c"
    readonly property color vuotoAlto: "#080d18"
    // ── il vetro: le superfici. Più chiare in alto, quasi trasparenti in basso ──
    readonly property color vetroAlto: Qt.rgba(0.09, 0.13, 0.21, 0.86)
    readonly property color vetroBasso: Qt.rgba(0.03, 0.05, 0.10, 0.80)
    readonly property color vetroNetto: Qt.rgba(0.05, 0.08, 0.14, 0.97)
    // ── le luci: ciano per i fili e i dati, oro per Ciel ──
    readonly property color ciano: "#5fe8ff"
    readonly property color cianoFondo: Qt.rgba(0.37, 0.91, 1.0, 0.12)
    readonly property string accentoUtente: String(v("accento", "#f0c469"))
    readonly property color oro: accentoUtente
    readonly property color oroChiaro: schiarisci(Qt.color(accentoUtente), 0.22)
    readonly property color testo: "#e6efff"
    readonly property color tenue: "#7f90ab"
    readonly property color allarme: "#ff6b7a"
    readonly property color buono: "#6ef2b5"

    // ── misure ──
    readonly property int barra: 46
    readonly property int margine: 14
    readonly property int raggio: 14
    readonly property int raggioPiccolo: 8
    readonly property string font: v("font", "Rubik")
    readonly property string mono: "JetBrainsMono Nerd Font Mono"
    readonly property string icone: "Material Symbols Rounded"
    readonly property int icona: 19
    readonly property bool animazioni: v("animazioni", true) !== false
    readonly property int durata: animazioni ? 170 : 0

    readonly property string terminale: v("terminale", "foot")
    readonly property bool ia: v("ia", "accesa") !== "spenta"
    readonly property string sfondoImmagine: String(v("sfondo", ""))
    readonly property string lato: v("lato", "alto")          // la barra: alto o basso (la Nightly nasce così)
    readonly property bool orizzontale: true

    function alfa(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    function mescola(a, b, t) {
        if (typeof a === "string") a = Qt.color(a);
        if (typeof b === "string") b = Qt.color(b);
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
    }
    function schiarisci(c, t) { return mescola(c, Qt.rgba(1, 1, 1, c.a), t) }

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/cielos/tema.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { tema.utente = JSON.parse(text()) || {}; } catch (e) {} tema.pronto = true; }
        onLoadFailed: tema.utente = ({})
    }
    Timer { interval: 1200; running: !tema.pronto; onTriggered: tema.pronto = true }
}
