// La barra: verticale a sinistra di ogni schermo. In cima Ciel e i workspace, in fondo vassoio, musica (se suona),
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
        screen: modelData
        anchors { left: true; top: true; bottom: true }
        implicitWidth: Tema.barra
        color: Tema.fondo
        exclusionMode: Pannelli.prova ? ExclusionMode.Ignore : ExclusionMode.Normal
        exclusiveZone: Tema.barra           // lo spazio della barra: le finestre cominciano dopo
        WlrLayershell.namespace: "cielos-barra"

        Rectangle {                      // il filo d'oro sul bordo
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
            width: 1
            color: Tema.bordo
        }

        Column {
            anchors { top: parent.top; topMargin: Tema.margine + 2; horizontalCenter: parent.horizontalCenter }
            spacing: Tema.margine + 4
            Nucleo { anchors.horizontalCenter: parent.horizontalCenter }
            Workspaces { anchors.horizontalCenter: parent.horizontalCenter; schermo: finestra.modelData }
        }

        Column {
            anchors { bottom: parent.bottom; bottomMargin: Tema.margine + 2; horizontalCenter: parent.horizontalCenter }
            spacing: Tema.margine + 2
            Vassoio { anchors.horizontalCenter: parent.horizontalCenter; finestra: finestra }
            Media { anchors.horizontalCenter: parent.horizontalCenter }
            Sistema { anchors.horizontalCenter: parent.horizontalCenter }
            Luce { anchors.horizontalCenter: parent.horizontalCenter; schermo: finestra.modelData.name }
            Volume { anchors.horizontalCenter: parent.horizontalCenter }
            Rete { anchors.horizontalCenter: parent.horizontalCenter }
            Orologio { anchors.horizontalCenter: parent.horizontalCenter }
            Spegni { anchors.horizontalCenter: parent.horizontalCenter }
        }
    }
}
