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
    // l'accento scelto, ma mai illeggibile: se sul fondo non si vedrebbe (contrasto sotto 3:1, es. un accento quasi
    // nero su un fondo scuro) lo schiarisce verso il colore del testo finché si legge. Vale per scritte, icone e pulsanti.
    readonly property color accentoScelto: v("oro", "#ffbf3f")
    readonly property color oro: leggibile(accentoScelto, fondo)
    function _lum(c) {
        const f = x => x <= 0.03928 ? x / 12.92 : Math.pow((x + 0.055) / 1.055, 2.4);
        return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
    }
    function contrasto(a, b) {
        const la = _lum(a), lb = _lum(b);
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
    }
    function leggibile(c, su) {
        const verso = _lum(su) < 0.5 ? testo : Qt.color("#000000");
        for (let t = 0; t <= 1.0001; t += 0.1) {
            const m = Qt.tint(c, Qt.rgba(verso.r, verso.g, verso.b, t));
            if (contrasto(m, su) >= 3) return m;
        }
        return verso;
    }
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
    readonly property bool avatar: v("avatar", false)              // il cerchio di Ciel in un angolo (di serie no)
    readonly property string sfondo: v("sfondo", "")              // vuoto: nessuna immagine, solo il colore di fondo
    readonly property string terminale: v("terminale", "foot")     // per le app da aprire nel terminale

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/cielos/tema.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { tema.utente = JSON.parse(text()) || {}; } catch (e) { console.warn("tema.json:", e); } }
        onLoadFailed: tema.utente = ({})
    }
}
