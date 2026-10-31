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
        exclusiveZone: Tema.barra
        WlrLayershell.namespace: "ciel-barra"
        
        // FONDO GLASSMORPHISM AVANZATO
        Rectangle {
            id: fondoBarra
            anchors.fill: parent
            radius: Tema.raggioBarra ? Tema.raggioBarra : 12
            
            // Glassmorphism con blur sottofondo
            layer.enabled: Tema.glassmorphism
            layer.textureSize: Qt.size(width * 1.3, height * 1.3)
            
            // Gradiente dinamico migliorato
            gradient: Gradient {
                orientation: finestra.oriz ? Gradient.Horizontal : Gradient.Vertical
                GradientStop { position: 0; color: Tema.alfa(Tema.primario, 0.08) }
                GradientStop { position: 0.4; color: Tema.fondo }
                GradientStop { position: 0.8; color: Tema.scurisci(Tema.fondo, 0.05) }
                GradientStop { position: 1; color: Tema.scurisci(Tema.fondo, 0.12) }
            }
            
            // BORDO LUCE PROFESSIONALE
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                color: "transparent"
                radius: finestra.oriz ? 0 : (Tema.raggioBarra ? Tema.raggioBarra - 1 : 11)
                border.color: Tema.alfa(Tema.bordoForte, 0.35)
                border.width: 1
                
                // Ombra moderna
                opacity: 0.92
            }
            
            // Effetto "light rays" aurore boreale
            Rectangle {
                id: aurora
                visible: Tema.auroraBoreale
                x: finestra.oriz ? -width/2 : 0
                y: finestra.oriz ? 0 : -height/2
                width: finestra.oriz ? width*1.5 : 2
                height: finestra.oriz ? 2 : height*1.5
                color: Tema.alfa(Tema.primario, 0.12)
                opacity: 0.5
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
                // Animazione hover 3D
                states: [
                    State {
                        name: "hovered"
                        when: mouseArea.containsMouse
                        PropertyChanges { target: icon; scale: 1.08 }
                    }
                ]
                transitions: [
                    Transition {
                        from: "*"; to: "hovered"
                        NumberAnimation { properties: "scale"; duration: 200; easing.type: Easing.OutBack }
                    }
                ]
            }
            MouseArea { 
                id: ma_sveglio
                anchors.fill: parent 
                cursorShape: Qt.PointingHandCursor 
            }
            Icona { 
                visible: Strumenti.sveglio
                nome: "coffee" 
                onPremuto: Strumenti.fai(["sveglio", "no"])
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onEntered: icon.opacity = 0.8
                    onExited: icon.opacity = 1
                }
            }
            MouseArea { 
                id: ma_luce
                anchors.fill: parent 
                cursorShape: Qt.PointingHandCursor 
            }
            Icona { 
                visible: Strumenti.luce
                nome: "nightlight" 
                onPremuto: Strumenti.fai(["luce", "no"])
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                }
            }
            MouseArea { 
                id: ma_non_disturbare
                anchors.fill: parent 
                cursorShape: Qt.PointingHandCursor 
            }
            Icona { 
                visible: Pannelli.nonDisturbare
                nome: "notifications_off" 
                colore: Tema.tenue 
                onPremuto: Pannelli.nonDisturbare = false
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onEntered: icon.color = Tema.allarme
                    onExited: icon.color = Tema.tenue
                }
            }
            Layout { visible: Tema.mostraLayout }
            Vassoio { visible: Tema.mostraVassoio; finestra: finestra }
            Media {}
            Sistema { visible: Tema.mostraSistema }
            SensoriBarra { visible: Tema.mostraSensori }
            Batteria { attiva: Tema.mostraBatteria }
            Luce { schermo: finestra.modelData.name }
            Volume { visible: Tema.mostraVolume }
            Rete { visible: Tema.mostraRete }
            // il bluetooth: solo sui PC che ce l'hanno (la scheda si vede dall'adattatore, non da un file di
            // configurazione), e si spegne come tutto il resto (Impostazioni → Barra)
            Bluetooth { id: bt; visible: Tema.mostraBluetooth && bt.presente }
            Orologio { visible: Tema.mostraOrologio }
            Spegni { visible: Tema.mostraSpegni }
        }
    }
}
