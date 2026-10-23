pragma Singleton
// Dove stanno i comandi di CielOS. La Nightly è solo il comparto grafico: i comandi (cieltema, cielrete, cielplugin,
// cielmodelli, cielapri…) restano quelli di CielOS, nella sua radice: CIELOS_DIR, o ~/cielos, o /usr/share/cielos.
import QtQuick
import Quickshell

Singleton {
    readonly property string radice: Quickshell.env("CIELOS_DIR") || (Quickshell.env("HOME") + "/cielos")
    function bin(nome) { return radice + "/bin/" + nome }
}
