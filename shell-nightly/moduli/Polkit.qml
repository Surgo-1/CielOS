// La finestra della password nella Nightly: è l'agente polkit della sessione, come quello della shell stabile.
// Senza, nella sessione Nightly nessuno poteva approvare un'azione da amministratore: «cielos update» rispondeva
// «Non approvata: non ho fatto niente» e la finestra della password non compariva mai (23/10). La password va a
// polkit: né la shell né Ciel la tengono. Esc o «Annulla» rifiutano. In prova (CIELOS_NIGHTLY_PROVA=1) non si registra.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Polkit
import qs.servizi
import "../componenti"

Scope {
    id: pk

    Loader {
        active: !Pannelli.prova
        sourceComponent: PolkitAgent {
            id: agente
            onIsRegisteredChanged: console.log("polkit: agente", isRegistered ? "registrato" : "non registrato")
        }
        onLoaded: pk.agente = item
    }
    property var agente: null
    readonly property var flusso: agente?.flow ?? null
    readonly property bool aperta: !!(agente && agente.isActive && flusso && !flusso.isCompleted)
    readonly property bool diCiel: (flusso?.actionId ?? "").startsWith("org.cielos.guardiano.")

    PanelWindow {
        id: finestra
        visible: pk.aperta
        screen: Quickshell.screens.find(x => x.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "nightly-polkit"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: pk.aperta ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        onVisibleChanged: if (visible) { campo.text = ""; campo.forceActiveFocus(); entra.restart(); }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.01, 0.02, 0.05, 0.62)
            focus: true
            Keys.onEscapePressed: pk.flusso?.cancelAuthenticationRequest()

            Hud {
                id: carta
                width: Math.min(500, parent.width - 80)
                height: colonna.implicitHeight + 48
                anchors.centerIn: parent
                accento: pk.flusso?.failed ? Tema.allarme : (pk.diCiel ? Tema.oro : Tema.ciano)
                opacity: 0
                scale: 0.97

                ParallelAnimation {
                    id: entra
                    NumberAnimation { target: carta; property: "opacity"; from: 0; to: 1; duration: Tema.durata; easing.type: Easing.OutCubic }
                    NumberAnimation { target: carta; property: "scale"; from: 0.97; to: 1; duration: Tema.durata; easing.type: Easing.OutCubic }
                }

                MouseArea { anchors.fill: parent }

                Column {
                    id: colonna
                    x: 24; y: 24
                    width: parent.width - 48
                    spacing: 14

                    Row {
                        spacing: 12
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 46; height: 46; radius: Tema.raggioPiccolo
                            color: Tema.cianoFondo
                            border.width: 1; border.color: Tema.alfa(pk.diCiel ? Tema.oro : Tema.ciano, 0.35)
                            Text {
                                anchors.centerIn: parent
                                text: "admin_panel_settings"
                                font.family: Tema.icone; font.pixelSize: 25
                                color: pk.diCiel ? Tema.oro : Tema.ciano
                            }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                text: pk.diCiel ? Lingua.t("Ciel chiede un'azione da amministratore")
                                                : Lingua.t("Serve la password di amministratore")
                                color: Tema.testo; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.Medium
                            }
                            Text {
                                text: pk.diCiel ? Lingua.t("Approvi tu: Ciel non vede la password") : (pk.flusso?.actionId ?? "")
                                color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
                            }
                        }
                    }

                    // cosa succederà, in chiaro: il testo lo scrive il guardiano (o l'app che chiede)
                    Rectangle {
                        width: parent.width
                        height: cosa.implicitHeight + 24
                        radius: Tema.raggioPiccolo
                        color: Tema.alfa(Tema.oro, 0.08)
                        border.width: 1
                        border.color: Tema.alfa(Tema.ciano, 0.22)
                        Text {
                            id: cosa
                            x: 14; y: 12
                            width: parent.width - 28
                            wrapMode: Text.WordWrap
                            text: pk.flusso?.message ?? ""
                            color: Tema.testo; font.family: Tema.font; font.pixelSize: 15
                        }
                    }

                    Text {
                        visible: !!pk.flusso?.selectedIdentity
                        text: Lingua.t("Password di %1", pk.flusso?.selectedIdentity?.displayName ?? "")
                        color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
                    }

                    Rectangle {
                        width: parent.width; height: 46; radius: 23
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.width: 1
                        border.color: pk.flusso?.failed ? Tema.allarme : campo.activeFocus ? Tema.ciano : Tema.alfa(Tema.ciano, 0.25)
                        TextInput {
                            id: campo
                            anchors { fill: parent; leftMargin: 18; rightMargin: 18 }
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: pk.flusso?.responseVisible ? TextInput.Normal : TextInput.Password
                            passwordCharacter: "●"
                            color: Tema.testo; font.family: Tema.font; font.pixelSize: 16
                            enabled: pk.flusso?.isResponseRequired ?? false
                            focus: true
                            onAccepted: if (text.length && pk.flusso) { pk.flusso.submit(text); text = ""; }
                            Keys.onEscapePressed: pk.flusso?.cancelAuthenticationRequest()
                            Text {
                                visible: !campo.text
                                anchors.verticalCenter: parent.verticalCenter
                                text: (pk.flusso?.inputPrompt || "Password").replace(/:\s*$/, "")
                                color: Tema.tenue; font: campo.font
                            }
                        }
                    }

                    Text {
                        visible: text !== ""
                        width: parent.width; wrapMode: Text.WordWrap
                        text: pk.flusso?.failed ? Lingua.t("Password sbagliata, riprova.") : (pk.flusso?.supplementaryMessage ?? "")
                        color: pk.flusso?.failed || pk.flusso?.supplementaryIsError ? Tema.allarme : Tema.tenue
                        font.family: Tema.font; font.pixelSize: 12
                    }

                    Row {
                        anchors.right: parent.right
                        spacing: 10
                        Repeater {
                            model: [[Lingua.t("Annulla"), false], [Lingua.t("Approva"), true]]
                            Rectangle {
                                required property var modelData
                                width: 110; height: 36; radius: 18
                                color: modelData[1] ? Tema.oro : (t.containsMouse ? Tema.alfa(Tema.ciano, 0.12) : "transparent")
                                border.width: 1
                                border.color: modelData[1] ? Tema.oro : Tema.alfa(Tema.ciano, 0.3)
                                opacity: modelData[1] && !campo.text ? 0.5 : 1
                                Text {
                                    anchors.centerIn: parent
                                    text: parent.modelData[0]
                                    color: parent.modelData[1] ? Tema.vuoto : Tema.testo
                                    font.family: Tema.font; font.pixelSize: 14; font.weight: Font.Medium
                                }
                                MouseArea {
                                    id: t
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!pk.flusso) return;
                                        if (!parent.modelData[1]) pk.flusso.cancelAuthenticationRequest();
                                        else if (campo.text.length) { pk.flusso.submit(campo.text); campo.text = ""; }
                                        campo.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
