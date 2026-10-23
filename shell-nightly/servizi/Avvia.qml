pragma Singleton
// Tutto quello che la Nightly apre passa da bin/ciel-apri: ogni programma nel suo «scope», fuori dal servizio della
// shell. Riavviare la shell (o la Nightly) non chiude le app che hai aperto.
import QtQuick
import Quickshell

Singleton {
    readonly property string apri: Percorsi.bin("ciel-apri")

    function comando(nome, cmd) {
        Quickshell.execDetached([apri, nome, "--"].concat(cmd));
    }
    function app(e) {
        if (!e) return;
        let cmd = e.command;
        if (e.runInTerminal) cmd = [Tema.terminale || "foot", "-e"].concat(cmd);
        if (e.workingDirectory)
            Quickshell.execDetached({ command: [apri, e.id, "--"].concat(cmd), workingDirectory: e.workingDirectory });
        else
            comando(e.id, cmd);
    }
}
