// Impostazioni → Tastiera e mouse: lingua della tastiera, ripetizione dei tasti, velocità e accelerazione del
// mouse, scorrimento, mancini, il fuoco che segue il mouse; per i portatili il touchpad. Tutto vale subito.
import QtQuick
import qs.servizi

Column {
    id: p
    width: parent ? parent.width : 500
    spacing: 12
    readonly property var i: Impostati.stato?.scelte?.input ?? ({})
    readonly property bool touchpad: Impostati.stato?.input?.touchpad ?? false
    function metti(k, v) { Impostati.fai(["input", k + "=" + v]); }
    readonly property var layout: [["it", Lingua.t("Italiano")], ["us", Lingua.t("Inglese (Stati Uniti)")], ["gb", Lingua.t("Inglese (Regno Unito)")], ["de", Lingua.t("Tedesco")],
                                   ["fr", Lingua.t("Francese")], ["es", Lingua.t("Spagnolo")], ["pt", Lingua.t("Portoghese")], ["br", Lingua.t("Portoghese (Brasile)")],
                                   ["ch", Lingua.t("Svizzero")], ["nl", Lingua.t("Olandese")], ["pl", Lingua.t("Polacco")], ["ru", Lingua.t("Russo")], ["ua", Lingua.t("Ucraino")],
                                   ["ro", Lingua.t("Rumeno")], ["gr", Lingua.t("Greco")], ["tr", Lingua.t("Turco")], ["se", Lingua.t("Svedese")], ["no", Lingua.t("Norvegese")],
                                   ["dk", Lingua.t("Danese")], ["fi", Lingua.t("Finlandese")], ["jp", Lingua.t("Giapponese")], ["kr", Lingua.t("Coreano")], ["cn", Lingua.t("Cinese")]]

    Titoletto { testo: Lingua.t("Tastiera") }
    Tendina {
        width: parent.width
        testo: Lingua.t("Lingua della tastiera")
        voci: p.layout.map(l => ({ testo: l[1] + " (" + l[0] + ")", valore: l[0] }))
        valore: p.i.kb_layout ?? "it"
        onScelto: v => p.metti("kb_layout", v)
    }
    Cursore {
        width: parent.width; testo: Lingua.t("Prima che un tasto tenuto premuto si ripeta")
        min: 150; max: 800; passo: 10; unita: " ms"
        valore: p.i.repeat_delay ?? 250
        onCambiato: v => p.metti("repeat_delay", Math.round(v))
    }
    Cursore {
        width: parent.width; testo: Lingua.t("Velocità della ripetizione")
        min: 10; max: 60; passo: 1; unita: Lingua.t(" al secondo")
        valore: p.i.repeat_rate ?? 35
        onCambiato: v => p.metti("repeat_rate", Math.round(v))
    }
    Interruttore { width: parent.width; testo: Lingua.t("Tastierino numerico acceso all'avvio"); acceso: p.i.numlock_by_default ?? false
                   onCambiato: v => p.metti("numlock_by_default", v ? 1 : 0) }

    Titoletto { testo: Lingua.t("Mouse") }
    Cursore {
        width: parent.width; testo: Lingua.t("Velocità")
        min: -1; max: 1; passo: 0.05; decimali: 2
        valore: p.i.sensitivity ?? 0
        onCambiato: v => p.metti("sensitivity", v.toFixed(2))
    }
    Column {
        spacing: 6; width: parent.width
        Text { text: Lingua.t("Accelerazione"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 14 }
        Text { width: parent.width; wrapMode: Text.Wrap; text: Lingua.t("«Piatta»: il cursore si muove sempre in proporzione alla mano (la preferiscono nei giochi).")
               color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12 }
        Row {
            spacing: 6
            Chip { testo: Lingua.t("adattiva"); acceso: (p.i.accel_profile ?? "adaptive") === "adaptive"; onPremuto: p.metti("accel_profile", "adaptive") }
            Chip { testo: Lingua.t("piatta"); acceso: p.i.accel_profile === "flat"; onPremuto: p.metti("accel_profile", "flat") }
        }
    }
    Interruttore { width: parent.width; testo: Lingua.t("Scorrimento naturale"); spiega: Lingua.t("La pagina segue la rotella come un dito sullo schermo.")
                   acceso: p.i.natural_scroll ?? false; onCambiato: v => p.metti("natural_scroll", v ? 1 : 0) }
    Interruttore { width: parent.width; testo: Lingua.t("Mancino"); spiega: Lingua.t("Scambia il tasto sinistro e il destro.")
                   acceso: p.i.left_handed ?? false; onCambiato: v => p.metti("left_handed", v ? 1 : 0) }
    Interruttore { width: parent.width; testo: Lingua.t("La finestra sotto il mouse prende la tastiera")
                   acceso: (p.i.follow_mouse ?? 1) === 1; onCambiato: v => p.metti("follow_mouse", v ? 1 : 0) }

    Titoletto { visible: p.touchpad; testo: Lingua.t("Touchpad") }
    Interruttore { visible: p.touchpad; width: parent.width; testo: Lingua.t("Tocca per cliccare")
                   acceso: p.i["touchpad.tap_to_click"] ?? true; onCambiato: v => p.metti("touchpad.tap_to_click", v ? 1 : 0) }
    Interruttore { visible: p.touchpad; width: parent.width; testo: Lingua.t("Scorrimento naturale")
                   acceso: p.i["touchpad.natural_scroll"] ?? true; onCambiato: v => p.metti("touchpad.natural_scroll", v ? 1 : 0) }
    Interruttore { visible: p.touchpad; width: parent.width; testo: Lingua.t("Spento mentre scrivi")
                   acceso: p.i["touchpad.disable_while_typing"] ?? true; onCambiato: v => p.metti("touchpad.disable_while_typing", v ? 1 : 0) }
    Cursore {
        visible: p.touchpad
        width: parent.width; testo: Lingua.t("Velocità dello scorrimento")
        min: 0.2; max: 3; passo: 0.1; decimali: 1; unita: "×"
        valore: p.i["touchpad.scroll_factor"] ?? 1
        onCambiato: v => p.metti("touchpad.scroll_factor", v.toFixed(1))
    }
}
