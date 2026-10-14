// Ciel, la shell di CielOS: barra, lanciatore (che è anche Ciel), notifiche, volume, sessione, blocco, impostazioni, password da amministratore (agente polkit).
// Una sola istanza di Quickshell, leggera: niente si muove se non succede qualcosa.
//   qs -p ~/cielos/shell                       (CIELOS_PROVA=1: accanto a un'altra shell, solo da guardare)
//@ pragma UseQApplication
import QtQuick
import Quickshell
import "moduli"

ShellRoot {
    Sfondo {}
    Barra {}
    Notifiche {}
    Osd {}
    Sessione {}
    Lanciatore {}
    Blocco {}
    Impostazioni {}
    Polkit {}

    // l'avatar di Ciel nello stesso processo (prima era un secondo Quickshell: ~300 MB in più). Non in prova (il
    // suo socket è già dell'avatar acceso) e non se Ciel non c'è.
    Loader {
        active: Quickshell.env("CIELOS_PROVA") !== "1" && Quickshell.env("CIELOS_SENZA_AVATAR") !== "1"
        source: "file://" + Quickshell.env("HOME") + "/assistente-vocale/avatar/shell.qml"
    }
}
