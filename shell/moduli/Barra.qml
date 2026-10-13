// La barra: su ogni schermo, a sinistra (di serie), a destra, in alto o in basso (Tema.lato). In cima Ciel e i workspace, in fondo vassoio, musica (se suona),
// sistema, luminosità, volume, rete, ora e spegnimento. Ferma quando non succede niente (nessuna animazione continua: la GPU è tua).
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.servizi
import "barra"

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: finestra
        required property ShellScreen modelData
        readonly property bool oriz: Tema.orizzontale
        screen: modelData
        anchors {
            left: Tema.lato !== "destra"
            right: Tema.lato !== "sinistra"
            top: Tema.lato !== "basso"
            bottom: Tema.lato !== "alto"
        }
        implicitWidth: Tema.barra
        implicitHeight: Tema.barra
        color: Tema.fondo
        exclusionMode: Pannelli.prova ? ExclusionMode.Ignore : ExclusionMode.Normal
        exclusiveZone: Tema.barra           // lo spazio della barra: le finestre cominciano dopo
        WlrLayershell.namespace: "ciel-barra"

        Rectangle {                      // il filo d'oro sul bordo verso lo schermo
            x: Tema.lato === "sinistra" ? parent.width - 1 : 0
            y: Tema.lato === "alto" ? parent.height - 1 : 0
            width: finestra.oriz ? parent.width : 1
            height: finestra.oriz ? 1 : parent.height
            color: Tema.bordo
        }

        Grid {                           // all'inizio: Ciel e i workspace
            x: finestra.oriz ? Tema.margine + 2 : (parent.width - width) / 2
            y: finestra.oriz ? (parent.height - height) / 2 : Tema.margine + 2
            columns: finestra.oriz ? 2 : 1
            spacing: Tema.margine + 4
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter
            Nucleo {}
            Workspaces { schermo: finestra.modelData }
        }

        Grid {                           // alla fine: il resto
            x: finestra.oriz ? parent.width - width - Tema.margine - 2 : (parent.width - width) / 2
            y: finestra.oriz ? (parent.height - height) / 2 : parent.height - height - Tema.margine - 2
            columns: finestra.oriz ? 9 : 1
            spacing: Tema.margine + 2
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter
            Vassoio { finestra: finestra }
            Media {}
            Sistema {}
            Luce { schermo: finestra.modelData.name }
            Volume {}
            Rete {}
            Orologio {}
            Spegni {}
        }
    }
}
