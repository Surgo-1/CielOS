pragma Singleton
// Lo stato degli strumenti (bin/cielstrumenti): registrazione dello schermo e «resta sveglio» dai loro file in
// $XDG_RUNTIME_DIR/cielos (la shell li guarda, senza chiedere niente a nessuno); la luce notturna si rilegge quando
// serve (aggiorna()). fai(…) lancia un comando di cielstrumenti fuori dalla shell; dopoArea(…) prima lascia chiudere
// i pannelli, così il mirino trova lo schermo libero.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: s
    readonly property string motore: Percorsi.bin("cielstrumenti")
    readonly property string cartella: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/cielos/"
    property bool registra: false
    property bool sveglio: false
    property bool luce: false

    function fai(args) { Avvia.comando("cielstrumenti", [motore].concat(args)); ancora.restart(); }
    function dopoArea(args) {
        Pannelli.chiudi();
        Avvia.comando("cielstrumenti", ["sh", "-c", "sleep 0.35; exec \"$0\" \"$@\"", motore].concat(args));
    }
    function aggiorna() { if (!stato.running) stato.running = true; }
    function vista(v) { Pannelli.strumento(v); }

    // gli strumenti nel lanciatore: si trovano scrivendo (come le app); «simbolo» è l'icona Material
    readonly property var azioni: [
        { id: "strumento:registra", name: Lingua.t("Registra lo schermo"), comment: "Super+Shift+R", simbolo: "videocam",
          keywords: ["record", "video", "registrazione", "screen"], fai: () => s.dopoArea(registra ? ["registra", "ferma"] : ["registra"]) },
        { id: "strumento:registra-audio", name: Lingua.t("Registra lo schermo con l'audio"), comment: "Super+Ctrl+R", simbolo: "volume_up",
          keywords: ["record", "video", "audio"], fai: () => s.dopoArea(["registra", "audio"]) },
        { id: "strumento:testo", name: Lingua.t("Copia il testo dallo schermo"), comment: "Super+Shift+T · OCR", simbolo: "text_fields",
          keywords: ["ocr", "text", "testo", "leggi"], fai: () => s.dopoArea(["testo"]) },
        { id: "strumento:qr", name: Lingua.t("Leggi un codice QR"), comment: "", simbolo: "qr_code_scanner",
          keywords: ["qr", "codice", "scan"], fai: () => s.dopoArea(["qr"]) },
        { id: "strumento:colore", name: Lingua.t("Prendi un colore dallo schermo"), comment: "Super+Shift+C", simbolo: "colorize",
          keywords: ["color", "colore", "picker", "contagocce"], fai: () => s.dopoArea(["colore"]) },
        { id: "strumento:luce", name: Lingua.t("Luce notturna"), comment: s.luce ? Lingua.t("accesa: la spegne") : Lingua.t("schermo più caldo, la sera"),
          simbolo: "nightlight", keywords: ["night", "notte", "notturna", "caldo"], fai: () => s.fai(["luce"]) },
        { id: "strumento:sveglio", name: Lingua.t("Resta sveglio"), comment: s.sveglio ? Lingua.t("acceso: lo spegne") : Lingua.t("niente blocco né sospensione"),
          simbolo: "coffee", keywords: ["awake", "caffè", "sveglio", "idle"], fai: () => s.fai(["sveglio"]) },
        { id: "strumento:nondisturbare", name: Lingua.t("Non disturbare"), comment: Pannelli.nonDisturbare ? Lingua.t("acceso: lo spegne") : "",
          simbolo: "notifications_off", keywords: ["dnd", "notifiche", "silenzio"], fai: () => { Pannelli.nonDisturbare = !Pannelli.nonDisturbare; } },
        { id: "strumento:appunti", name: Lingua.t("Cronologia degli appunti"), comment: "Super+V", simbolo: "content_paste",
          keywords: ["clipboard", "appunti", "copia", "incolla"], fai: () => s.vista("appunti") },
        { id: "strumento:emoji", name: Lingua.t("Emoji"), comment: "Super+.", simbolo: "mood", keywords: ["emoji", "faccine"], fai: () => s.vista("emoji") },
        { id: "strumento:scorciatoie", name: Lingua.t("Scorciatoie da tastiera"), comment: "Super+K", simbolo: "keyboard",
          keywords: ["keybindings", "tasti", "scorciatoie"], fai: () => s.vista("scorciatoie") },
        { id: "strumento:wifi", name: Lingua.t("QR del Wi-Fi"), comment: Lingua.t("per collegare un telefono"), simbolo: "qr_code_2",
          keywords: ["wifi", "password", "qr"], fai: () => s.vista("wifi") },
        { id: "strumento:velocita", name: Lingua.t("Velocità di internet e del disco"), comment: "", simbolo: "speed",
          keywords: ["speedtest", "velocità", "internet", "disco"], fai: () => s.vista("velocita") },
        { id: "strumento:stacca", name: Lingua.t("Stacca la finestra"), comment: "Super+O", simbolo: "picture_in_picture",
          keywords: ["pop", "pin", "finestra", "sopra"], fai: () => Quickshell.execDetached([s.motore, "finestra", "stacca"]) }
    ]

    FileView {
        path: s.cartella + "registrazione.pid"
        watchChanges: true; printErrors: false
        onFileChanged: reload()
        onLoaded: s.registra = text().trim() !== ""
        onLoadFailed: s.registra = false
    }
    FileView {
        path: s.cartella + "resta-sveglio.pid"
        watchChanges: true; printErrors: false
        onFileChanged: reload()
        onLoaded: s.sveglio = text().trim() !== ""
        onLoadFailed: s.sveglio = false
    }
    Process {
        id: stato
        command: [s.motore, "stato", "--json"]
        stdout: StdioCollector {
            onStreamFinished: { try { const r = JSON.parse(text); s.luce = r.luce; s.registra = r.registra; s.sveglio = r.sveglio; } catch (e) {} }
        }
    }
    Timer { id: ancora; interval: 900; onTriggered: s.aggiorna() }      // il comando ci mette un attimo
    Component.onCompleted: aggiorna()
}
