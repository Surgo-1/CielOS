pragma Singleton
// L'aspetto di CielOS in un posto solo: colori, font, misure. Le preferenze dell'utente stanno in
// ~/.config/cielos/tema.json (si cambiano a mano o a voce con Ciel, e si vedono subito: il file è seguito).
// Ogni chiave del file sostituisce quella di serie, es. {"oro": "#7fd0ff", "barra": 52}.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: tema

    property var utente: ({})
    function v(nome, serie) { return utente[nome] !== undefined ? utente[nome] : serie; }

    // colori (la notte di Ciel: blu profondo e oro, come il blocco e il login)
    readonly property color fondo: v("fondo", "#0b1029")
    readonly property color fondoAlto: v("fondoAlto", "#141b3d")
    readonly property color superficie: v("superficie", Qt.rgba(0.04, 0.06, 0.16, 0.96))
    readonly property color oro: v("oro", "#ffbf3f")
    readonly property color oroChiaro: v("oroChiaro", "#ffd98a")
    readonly property color testo: v("testo", "#eef2ff")
    readonly property color tenue: v("tenue", "#9aa6c8")
    readonly property color allarme: v("allarme", "#ff5a5a")
    readonly property color bordo: v("bordo", Qt.rgba(1, 0.75, 0.25, 0.3))

    // font
    readonly property string font: v("font", "Rubik")
    readonly property string icone: v("icone", "Material Symbols Rounded")

    // misure
    readonly property int barra: v("barra", 46)              // larghezza della barra
    readonly property int raggio: v("raggio", 14)            // arrotondamento di riquadri e pulsanti
    readonly property int margine: v("margine", 10)
    readonly property bool animazioni: v("animazioni", true)
    readonly property int durata: animazioni ? 180 : 0
    readonly property string lato: v("lato", "sinistra")     // dove sta la barra: sinistra, destra, alto, basso
    readonly property bool orizzontale: lato === "alto" || lato === "basso"
    readonly property bool suonoNotifiche: v("suono_notifiche", false)

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/cielos/tema.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { tema.utente = JSON.parse(text()) || {}; } catch (e) { console.warn("tema.json:", e); } }
        onLoadFailed: tema.utente = ({})
    }
}
