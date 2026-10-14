// La finestra della password per le azioni da amministratore: la shell Ciel è l'agente polkit della sessione
// (al posto di polkit-gnome, che hypr-user.lua ferma quando Ciel è la shell attiva).
// Per le richieste del guardiano di CielOS (org.cielos.guardiano.*) dice in chiaro cosa succederà (il testo viene
// dal guardiano, non da Ciel); per le altre app mostra la loro richiesta. La password va a polkit: né la shell né
// Ciel la tengono. Esc o «Annulla» rifiutano. In prova (CIELOS_PROVA=1) l'agente non si registra.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Polkit
import qs.servizi

Scope {
    id: pk

    Loader {
        active: !Pannelli.prova
        sourceComponent: PolkitAgent { id: agente
            onIsRegisteredChanged: console.log("polkit: agente", isRegistered ? "registrato" : "non registrato") }
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
        color: Qt.rgba(0.02, 0.03, 0.09, 0.7)
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "ciel-polkit"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: pk.aperta ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        onVisibleChanged: if (visible) { campo.text = ""; campo.forceActiveFocus(); entra.restart(); }

        Rectangle {
            id: carta
            anchors.centerIn: parent
            ParallelAnimation {              // compare piano; chiudendosi sparisce subito (niente attese sulla password)
                id: entra
                NumberAnimation { target: carta; property: "opacity"; from: 0; to: 1; duration: Tema.durata; easing.type: Easing.OutCubic }
                NumberAnimation { target: carta; property: "scale"; from: 0.97; to: 1; duration: Tema.durata; easing.type: Easing.OutCubic }
            }
            width: 480
            height: colonna.implicitHeight + 48
            radius: Tema.raggio + 4
            color: Tema.superficie
            border.color: pk.flusso?.failed ? Tema.allarme : Tema.bordo
            Behavior on border.color { ColorAnimation { duration: 200 } }

            Column {
                id: colonna
                x: 24; y: 24
                width: parent.width - 48
                spacing: 14

                Row {
                    spacing: 12
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "admin_panel_settings"; font.family: Tema.icone; font.pixelSize: 30; color: Tema.oro
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            text: pk.diCiel ? Lingua.t("Ciel chiede un'azione da amministratore") : Lingua.t("Serve la password di amministratore")
                            color: Tema.testo; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.Medium
                        }
                        Text {
                            text: pk.diCiel ? Lingua.t("Approvi tu: Ciel non vede la password") : (pk.flusso?.actionId ?? "")
                            color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
                        }
                    }
                }

                Rectangle {                      // cosa succederà, dal guardiano (o dall'app che chiede)
                    width: parent.width
                    height: cosa.implicitHeight + 24
                    radius: Tema.raggio
                    color: Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.08)
                    border.color: Tema.bordo
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
                    border.color: pk.flusso?.failed ? Tema.allarme : campo.activeFocus ? Tema.oro : Tema.bordo
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
                            color: modelData[1] ? Tema.oro : (t.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent")
                            border.color: Tema.bordo
                            opacity: modelData[1] && !campo.text ? 0.5 : 1
                            Text {
                                anchors.centerIn: parent
                                text: parent.modelData[0]
                                color: parent.modelData[1] ? Tema.fondo : Tema.testo
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
