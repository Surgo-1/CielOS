pragma Singleton
// La luminosità dei monitor esterni via DDC/CI (ddcutil; i bus /dev/i2c-* sono già tuoi con l'ACL della sessione).
// Cerca i monitor una volta sola, la prima volta che serve (ddcutil detect impiega un paio di secondi), poi legge e
// scrive per bus (veloce). Le scritture si raccolgono: trascinando la barra parte un comando solo, alla fine.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: l
    property var schermi: ({})           // nome dello schermo (DVI-D-1) → { bus, valore }
    property bool pronta: false          // la ricerca è finita
    property bool cercata: false
    property var inAttesa: ({})          // nome → valore da scrivere

    function cerca() {
        if (cercata) return;
        cercata = true;
        trova.running = true;
    }
    property var differite: ({})         // richieste arrivate prima che la ricerca finisse
    function imposta(nome, valore) {
        if (!pronta) { cerca(); differite[nome] = valore; return; }
        const s = schermi[nome];
        if (!s) return;
        valore = Math.max(0, Math.min(100, Math.round(valore)));
        const n = Object.assign({}, schermi);
        n[nome] = { bus: s.bus, valore: valore };
        schermi = n;
        inAttesa[nome] = valore;
        scrivi.restart();
    }

    Process {
        id: trova
        command: ["sh", "-c", "ddcutil detect --brief 2>/dev/null | awk '/I2C bus:/{b=$3; sub(\"/dev/i2c-\",\"\",b)} /DRM connector:/{c=$3; sub(/^card[0-9]+-/,\"\",c); print b\" \"c}' | " +
                  "while read b c; do v=$(ddcutil --bus $b getvcp 10 --brief 2>/dev/null | awk '/^VCP/{print $4}'); [ -n \"$v\" ] && echo \"$c $b $v\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = {};
                text.split("\n").filter(x => x).forEach(r => { const p = r.split(" "); m[p[0]] = { bus: p[1], valore: Number(p[2]) }; });
                l.schermi = m;
                l.pronta = true;
                for (const n in l.differite) l.imposta(n, l.differite[n]);
                l.differite = {};
            }
        }
    }
    // lo stesso comando di caelestia («brightness setFor SCHERMO 0.7»): Ciel non cambia
    IpcHandler {
        target: "brightness"
        function setFor(schermo: string, valore: string): void { l.imposta(schermo, Number(valore) * 100); }
        function set(valore: string): void { l.cerca(); for (const n in l.schermi) l.imposta(n, Number(valore) * 100); }
        function get(schermo: string): string { return String((l.schermi[schermo]?.valore ?? 0) / 100); }
    }

    Timer {
        id: scrivi
        interval: 250
        onTriggered: {
            const cmd = Object.keys(l.inAttesa).map(n => `ddcutil --bus ${l.schermi[n].bus} setvcp 10 ${l.inAttesa[n]} --noverify`).join("; ");
            l.inAttesa = {};
            if (cmd) Quickshell.execDetached(["sh", "-c", cmd]);
        }
    }
}
