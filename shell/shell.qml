// Ciel, la shell di CielOS: barra, lanciatore (che è anche Ciel), notifiche, volume, sessione, blocco, impostazioni, password da amministratore (agente polkit).
// Una sola istanza di Quickshell, leggera: niente si muove se non succede qualcosa.
//   qs -p ~/cielos/shell                       (CIELOS_PROVA=1: accanto a un'altra shell, solo da guardare)
//@ pragma UseQApplication
import QtQuick
import Quickshell
import "moduli"
import qs.servizi

ShellRoot {
    id: radice
    Sfondo {}
    Barra {}
    Notifiche {}
    Osd {}
    Sessione {}
    Lanciatore {}
    Blocco {}
    Impostazioni {}
    Polkit {}

    // l'avatar di Ciel (il cerchio in un angolo, i sottotitoli, le menti) nello stesso processo: solo se lo scegli
    // (Impostazioni → Sistema → avatar; di serie spento, 14/10). Non in prova: il suo socket è dell'avatar acceso.
    readonly property bool _prova: Quickshell.env("CIELOS_PROVA") === "1"
    Loader {
        active: !radice._prova && Tema.avatar
        source: "file://" + Quickshell.env("HOME") + "/assistente-vocale/avatar/shell.qml"
    }
    // senza avatar resta il riquadro per scriverle (Super+Spazio): con l'avatar è lui a caricarlo
    Loader {
        active: !radice._prova && !Tema.avatar
        source: "file://" + Quickshell.env("HOME") + "/assistente-vocale/avatar/Chiedi.qml"
    }
}
