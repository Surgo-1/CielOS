pragma Singleton
// Ciel per la shell: cosa sta facendo (da $XDG_RUNTIME_DIR/ciel-stato.json, scritto da Ciel solo quando cambia
// qualcosa e seguito con inotify) e il canale per scriverle (il suo cruscotto, con il gettone di ciel-cruscotto.url).
// Se Ciel non c'è (spenta, o un PC senza Ciel) la shell funziona lo stesso: viva = false.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: ciel

    readonly property string rt: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    property var info: ({})
    property real adesso: Date.now() / 1000
    readonly property bool viva: (info.t ?? 0) > adesso - 90
    readonly property string stato: viva ? (info.stato ?? "idle") : "spenta"
    readonly property string nome: viva ? (info.nome ?? "Ciel") : "Ciel"
    readonly property color colore: viva ? (info.colore ?? "#ffbf3f") : "#6b7086"
    readonly property string frase: info.frase ?? ""

    FileView {
        path: ciel.rt + "/ciel-stato.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try { ciel.info = JSON.parse(text()); } catch (e) {}
            ciel.adesso = Date.now() / 1000;
        }
        onLoadFailed: ciel.info = ({})
    }
    Timer { interval: 30000; running: true; repeat: true; onTriggered: ciel.adesso = Date.now() / 1000 }

    FileView {
        id: indirizzo
        path: ciel.rt + "/ciel-cruscotto.url"
        blockLoading: true
        printErrors: false
        // a ogni avvio di Ciel il gettone cambia: seguito con inotify, così la prima richiesta dopo un riavvio
        // non parte con quello vecchio (reload() qui sotto non basta: può arrivare dopo)
        watchChanges: true
        onFileChanged: reload()
    }

    // una richiesta al cruscotto: fatto(risposta) oppure errore(testo)
    function chiama(dati, fatto, errore) {
        indirizzo.reload();
        const url = indirizzo.text().trim();
        if (!url) { if (errore) errore("Ciel è spenta."); return; }
        const p = url.split("?");
        const x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            if (x.status !== 200) { if (errore) errore("Ciel non risponde: forse si sta ancora svegliando."); return; }
            try { fatto(JSON.parse(x.responseText)); } catch (e) { if (errore) errore(String(e)); }
        };
        x.open("POST", p[0].replace(/\/$/, "") + "/api/gui?" + p[1]);
        x.setRequestHeader("Content-Type", "application/json");
        x.send(JSON.stringify(dati));
    }
}
