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

    // colori (la notte di Ciel: blu profondo e oro, come il blocco e il login). «modo» chiaro cambia i valori di
    // serie: cieltema li scrive già in tema.json, qui restano solo per un tema.json vecchio o incompleto.
    readonly property string modo: v("modo", "scuro")
    readonly property bool chiaro: modo === "chiaro"
    readonly property color fondo: v("fondo", chiaro ? "#f4efe6" : "#0b1029")
    readonly property color fondoAlto: v("fondoAlto", chiaro ? "#e8e0d3" : "#141b3d")
    readonly property color superficie: v("superficie", chiaro ? Qt.rgba(0.98, 0.96, 0.92, 0.96)
                                                               : Qt.rgba(0.04, 0.06, 0.16, 0.96))
    // le superfici derivate: pannelli con un po' di luce in più (schede, campi, righe), e l'ombra
    // che li stacca dal fondo. Si calcolano dall'accento e dal testo, così valgono per ogni tema.
    function alfa(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }
    function mescola(a, b, t) {
        if (typeof a === "string") a = Qt.color(a);
        if (typeof b === "string") b = Qt.color(b);
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
    }
    function schiarisci(c, t) { return mescola(c, Qt.rgba(1, 1, 1, c.a), t); }
    readonly property color superficieAlta: mescola(superficie, testo, 0.055)
    readonly property color superficieBassa: mescola(superficie, Qt.rgba(0, 0, 0, 1), 0.22)
    readonly property color superficieNetta: Qt.rgba(superficieAlta.r, superficieAlta.g, superficieAlta.b, 1)
    readonly property color fondoGradiente: mescola(fondo, fondoAlto, 0.55)
    readonly property color bordoTenue: alfa(testo, 0.09)
    readonly property color bordoForte: alfa(oro, 0.58)
    readonly property color accentoSoft: alfa(oro, 0.13)
    readonly property color accentoMedio: alfa(oro, 0.26)
    readonly property color accentoForte: alfa(oro, 0.42)
    readonly property color accentoGlow: alfa(oro, 0.22)
    readonly property color ombra: Qt.rgba(0, 0, 0, 0.42)
    readonly property color biancoTenue: alfa(testo, 0.05)
    readonly property color testoDebole: alfa(testo, 0.55)
    // il vetro dei pannelli: una luce in alto che si spegne in basso, per staccarli dal fondo
    readonly property color vetroAlto: mescola(superficie, testo, 0.075)
    readonly property color vetroBasso: mescola(superficie, Qt.rgba(0, 0, 0, 1), 0.16)
    function scurisci(c, t) { return mescola(c, Qt.rgba(0, 0, 0, c.a), t); }
    function conAlfa(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }
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
    readonly property int barra: v("barra", 52)              // larghezza della barra
    readonly property int iconaBarra: v("icona_barra", 21)   // misura delle icone della barra
    readonly property int spazioBarra: v("barra_spazio", 12) // spazio tra gli elementi della barra
    // cosa si vede nella barra (Impostazioni → Barra): niente è obbligatorio tranne i due angoli
    readonly property bool mostraNucleo: v("barra_mostra_nucleo", true)
    readonly property bool mostraWorkspaces: v("barra_mostra_workspaces", true)
    readonly property bool mostraLayout: v("barra_mostra_layout", true)
    readonly property bool mostraVassoio: v("barra_mostra_vassoio", true)
    readonly property bool mostraMedia: v("barra_mostra_media", true)
    readonly property bool mostraSistema: v("barra_mostra_sistema", true)
    readonly property bool mostraSensori: v("barra_mostra_sensori", true)
    readonly property bool mostraLuce: v("barra_mostra_luce", true)
    readonly property bool mostraVolume: v("barra_mostra_volume", true)
    readonly property bool mostraRete: v("barra_mostra_rete", true)
    readonly property bool mostraOrologio: v("barra_mostra_orologio", true)
    readonly property bool mostraSpegni: v("barra_mostra_spegni", true)
    // il layout delle finestre di Hyprland: lo cambia l'icona nella barra (o cieltema imposta finestre_layout=…)
    readonly property string finestreLayout: v("finestre_layout", "dwindle")
    readonly property bool orologio24: v("orologio_24h", true)  // orologio a 24 ore (se no AM/PM)
    readonly property real scurisciSfondo: v("scurisci_sfondo", 0)  // velo nero sullo sfondo (0 = com'è)
    readonly property int raggio: v("raggio", 14)            // arrotondamento di riquadri e pulsanti
    readonly property int raggioGrande: raggio + 8
    readonly property int raggioPiccolo: Math.max(3, raggio - 5)
    readonly property int margine: v("margine", 10)
    readonly property bool animazioni: v("animazioni", true)
    readonly property int durata: animazioni ? 180 : 0
    readonly property string lato: v("lato", "sinistra")     // dove sta la barra: sinistra, destra, alto, basso
    readonly property bool orizzontale: lato === "alto" || lato === "basso"
    readonly property bool suonoNotifiche: v("suono_notifiche", false)
    readonly property bool avatar: v("avatar", false)              // il cerchio di Ciel in un angolo (di serie no)
    // l'IA di CielOS: «ia» spenta toglie avatar e riquadro di Ciel dalla shell (e il ponte di CielFox non risponde);
    // «ia_cielfox» spegne solo il browser. Tutto il resto delle scelte di Ciel sta in Impostazioni → Ciel.
    readonly property bool ia: v("ia", "accesa") !== "spenta"
    readonly property bool iaCielfox: ia && v("ia_cielfox", true)
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
