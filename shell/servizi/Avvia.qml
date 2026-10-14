pragma Singleton
// Tutto quello che la shell apre passa da qui: ogni programma nel suo «scope» (bin/ciel-apri), fuori dal servizio
// della shell. Altrimenti riavviare la shell chiudeva anche le app aperte dal lanciatore (14/10: Claude Desktop,
// e quasi un aggiornamento di Shelly a metà).
import QtQuick
import Quickshell

Singleton {
    readonly property string apri: Quickshell.env("HOME") + "/cielos/bin/ciel-apri"

    // un comando (lista) a nome NOME
    function comando(nome, cmd) {
        Quickshell.execDetached([apri, nome, "--"].concat(cmd));
    }
    // una voce del menu delle applicazioni (DesktopEntry)
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
