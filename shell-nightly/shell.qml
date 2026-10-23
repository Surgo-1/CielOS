// La shell Nightly di CielOS: un altro comparto grafico, sullo stesso sistema nervoso. HUD olografico e vetro/neon:
// barra a capsula, lanciatore e centro di controllo in vetro con gli angoli a mirino. Non tocca la shell stabile:
// è un'altra configurazione (qs -c ciel-nightly), con tasti suoi (ciel-nightly:*).
//   qs -p ~/cielos/shell-nightly            (CIELOS_NIGHTLY_PROVA=1: solo da guardare, niente sfondo)
import QtQuick
import Quickshell
import qs.servizi
import "moduli"

ShellRoot {
    Sfondo {}
    Barra {}
    Lanciatore {}
    Centro {}
    Sessione {}
}
