// La password del blocco: i tasti arrivano qui (handleKey), si vedono solo i pallini, Invio la controlla con PAM
// (~/cielos/shell/pam/passwd). Stati: "" (niente), "sbagliata", "errore", "troppi".
import QtQuick
import Quickshell
import Quickshell.Services.Pam

Scope {
    id: p
    property string buffer: ""
    property string state: ""
    property string lockMessage: ""
    readonly property alias passwd: contesto
    signal flashMsg
    signal sbloccato

    function handleKey(e) {
        if (contesto.active || state === "troppi") return;
        if (e.key === Qt.Key_Enter || e.key === Qt.Key_Return) {
            if (buffer.length) contesto.start();
        } else if (e.key === Qt.Key_Backspace) {
            buffer = (e.modifiers & Qt.ControlModifier) ? "" : buffer.slice(0, -1);
        } else if (e.key === Qt.Key_Escape) {
            buffer = "";
        } else if (/^[^\x00-\x1F\x7F-\x9F]+$/.test(e.text)) {
            buffer += e.text;
        }
    }

    PamContext {
        id: contesto
        config: "passwd"
        configDirectory: Quickshell.shellPath("pam")
        onMessageChanged: {
            if (message.startsWith("The account is locked")) p.lockMessage = message;
        }
        onResponseRequiredChanged: {
            if (!responseRequired) return;
            respond(p.buffer);
            p.buffer = "";
        }
        onCompleted: r => {
            if (r === PamResult.Success) { p.state = ""; p.sbloccato(); return; }
            p.state = r === PamResult.MaxTries ? "troppi" : r === PamResult.Error ? "errore" : "sbagliata";
            p.flashMsg();
            reset.restart();
        }
    }
    Timer { id: reset; interval: 4000; onTriggered: if (p.state !== "troppi") p.state = "" }
}
