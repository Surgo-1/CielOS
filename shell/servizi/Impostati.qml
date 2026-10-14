pragma Singleton
// Impostati: le impostazioni di sistema (cielimposta): lo stato letto una volta quando apri una pagina, e i comandi che
// rispondono in JSON. Le pagine leggono «stato» e chiamano fai(…); dopo ogni comando lo stato si rilegge.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.servizi

Singleton {
    id: s
    property var stato: null
    property string messaggio: ""
    property bool errore: false
    property var coda: []
    function aggiorna() { if (!leggi.running) leggi.running = true; }
    function fai(args, dopo) {
        coda = [...coda, { args: args, dopo: dopo }];
        avanti();
    }
    function avanti() {
        if (comando.running || !coda.length) return;
        comando.dopo = coda[0].dopo ?? null;
        comando.command = [Percorsi.bin("cielimposta"), ...coda[0].args];
        coda = coda.slice(1);
        comando.running = true;
    }
    Process {
        id: leggi
        command: [Percorsi.bin("cielimposta"), "stato"]
        stdout: StdioCollector { onStreamFinished: { try { s.stato = JSON.parse(text); } catch (e) {} } }
    }
    Process {
        id: comando
        property var dopo: null
        stdout: StdioCollector {
            onStreamFinished: {
                let r = {};
                try { r = JSON.parse(text); } catch (e) { r = { ok: false, messaggio: text.trim().slice(0, 200) }; }
                s.errore = r.ok === false;
                s.messaggio = r.messaggio ?? (r.errori ? "Hyprland: " + r.errori.slice(0, 160) : "");
                if (comando.dopo) comando.dopo(r);
            }
        }
        onExited: { s.aggiorna(); s.avanti(); }
    }
}
