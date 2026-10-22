// La barra: su ogni schermo, a sinistra (di serie), a destra, in alto o in basso (Tema.lato). In cima Ciel e i workspace, in fondo vassoio, musica (se suona),
// sistema, luminosità, volume, rete, ora e spegnimento; il layout delle finestre sta con gli altri strumenti.
// Ferma quando non succede niente (nessuna animazione continua: la GPU è tua).
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
        color: "transparent"
        exclusionMode: Pannelli.prova ? ExclusionMode.Ignore : ExclusionMode.Normal
        exclusiveZone: Tema.barra           // lo spazio della barra: le finestre cominciano dopo
        WlrLayershell.namespace: "ciel-barra"

        // il fondo: una notte appena più chiara verso l'interno, così la barra non è un rettangolo piatto
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: finestra.oriz ? Gradient.Horizontal : Gradient.Vertical
                GradientStop { position: 0; color: Tema.fondoAlto }
                GradientStop { position: 0.45; color: Tema.fondo }
                GradientStop { position: 1; color: Tema.scurisci(Tema.fondo, 0.18) }
            }
        }
        // un velo d'accento sul bordo verso lo schermo: la luce che entra dalla scrivania
        Rectangle {
            x: Tema.lato === "sinistra" ? parent.width - 1 : 0
            y: Tema.lato === "alto" ? parent.height - 1 : 0
            width: finestra.oriz ? parent.width : 1
            height: finestra.oriz ? 1 : parent.height
            color: Tema.oro
            opacity: 0.32
        }
        Rectangle {                      // il filo d'oro, più netto, subito sopra
            x: Tema.lato === "sinistra" ? parent.width - 2 : 0
            y: Tema.lato === "alto" ? parent.height - 2 : 0
            width: finestra.oriz ? parent.width : 1
            height: finestra.oriz ? 1 : parent.height
            gradient: Gradient {
                orientation: finestra.oriz ? Gradient.Horizontal : Gradient.Vertical
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.15; color: Tema.bordoForte }
                GradientStop { position: 0.85; color: Tema.bordoForte }
                GradientStop { position: 1; color: "transparent" }
            }
        }
        Rectangle {                      // il bordo esterno, appena più chiaro del fondo
            x: Tema.lato === "destra" ? parent.width - 1 : 0
            y: Tema.lato === "basso" ? parent.height - 1 : 0
            width: finestra.oriz ? parent.width : 1
            height: finestra.oriz ? 1 : parent.height
            color: Tema.alfa(Tema.testo, 0.05)
        }

        Grid {                           // all'inizio: Ciel e i workspace
            x: finestra.oriz ? Tema.margine + 2 : (parent.width - width) / 2
            y: finestra.oriz ? (parent.height - height) / 2 : Tema.margine + 2
            columns: finestra.oriz ? 2 : 1
            spacing: Tema.spazioBarra
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter
            Nucleo { visible: Tema.mostraNucleo }
            Workspaces { visible: Tema.mostraWorkspaces; schermo: finestra.modelData }
        }

        Grid {                           // alla fine: il resto
            x: finestra.oriz ? parent.width - width - Tema.margine - 2 : (parent.width - width) / 2
            y: finestra.oriz ? (parent.height - height) / 2 : parent.height - height - Tema.margine - 2
            // 24 colonne bastano a tenere in fila tutto quello che si può accendere; in verticale resta una colonna
            columns: finestra.oriz ? 24 : 1
            spacing: Tema.spazioBarra
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter
            // gli strumenti accesi (Super+A → Strumenti): si vedono solo mentre sono accesi; un clic li spegne
            Icona {
                visible: Strumenti.registra; nome: "radio_button_checked"; colore: Tema.allarme
                onPremuto: Strumenti.fai(["registra", "ferma"])
                SequentialAnimation on opacity {
                    running: Strumenti.registra && Tema.animazioni; loops: Animation.Infinite
                    NumberAnimation { from: 1; to: 0.35; duration: 800 }
                    NumberAnimation { from: 0.35; to: 1; duration: 800 }
                }
            }
            Icona { visible: Strumenti.sveglio; nome: "coffee"; onPremuto: Strumenti.fai(["sveglio", "no"]) }
            Icona { visible: Strumenti.luce; nome: "nightlight"; onPremuto: Strumenti.fai(["luce", "no"]) }
            Icona { visible: Pannelli.nonDisturbare; nome: "notifications_off"; colore: Tema.tenue; onPremuto: Pannelli.nonDisturbare = false }
            Layout { visible: Tema.mostraLayout }
            Vassoio { visible: Tema.mostraVassoio; finestra: finestra }
            Media {}
            Sistema { visible: Tema.mostraSistema }
            SensoriBarra { visible: Tema.mostraSensori }
            Batteria { attiva: Tema.mostraBatteria }
            Luce { schermo: finestra.modelData.name }
            Volume { visible: Tema.mostraVolume }
            Rete { visible: Tema.mostraRete }
            Orologio { visible: Tema.mostraOrologio }
            Spegni { visible: Tema.mostraSpegni }
        }
    }
}
