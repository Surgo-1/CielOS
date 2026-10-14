pragma Singleton
// La lingua di CielOS: Lingua.t("testo in italiano") → la traduzione. La chiave è la frase italiana (quello che
// manca nel dizionario resta in italiano); segnaposto %1, %2…: Lingua.t("Ripara tutto (%1)", n).
// La lingua: CIELOS_LINGUA, poi ~/.config/cielos/lingua (Impostazioni → Sistema, seguito: cambia subito), poi quella
// del sistema (LANG: italiano se comincia con «it», altrimenti inglese). L'installatore la sceglie con «forzata».
// Le traduzioni: <radice>/lingua/en.json (le stesse dei comandi in Python, lingua/lingua.py).
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: l
    property string forzata: ""
    property string scelta: ""
    readonly property string sistema: {
        const loc = Quickshell.env("LC_ALL") || Quickshell.env("LC_MESSAGES") || Quickshell.env("LANG") || "";
        return loc.startsWith("it") || ["", "C", "POSIX"].includes(loc.split(".")[0]) ? "it" : "en";
    }
    readonly property string codice: [forzata, Quickshell.env("CIELOS_LINGUA") ?? "", scelta].find(v => v === "it" || v === "en") ?? sistema
    readonly property bool inglese: codice === "en"
    readonly property string virgola: inglese ? "." : ","          // il separatore dei decimali
    property var dizionario: ({})

    function t(testo, ...valori) {
        let r = l.codice === "it" ? testo : (l.dizionario[testo] ?? testo);
        for (let i = 0; i < valori.length; i++) r = r.split("%" + (i + 1)).join(String(valori[i]));
        return r;
    }

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/cielos/lingua"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: l.scelta = text().trim()
        onLoadFailed: l.scelta = ""
    }
    FileView {
        path: Percorsi.radice + "/lingua/en.json"
        printErrors: false
        onLoaded: { try { l.dizionario = JSON.parse(text()) || {}; } catch (e) { console.warn("en.json:", e); } }
    }
}
