// Il centro di controllo della Nightly (l'icona a destra nella barra): un pannello di vetro sotto la barra con le
// quattro cose che si toccano davvero — volume, luminosità, Wi-Fi, IA — e in fondo le scorciatoie.
// I comandi sono quelli di CielOS: pactl/brightnessctl/nmcli/cieltema, niente logica doppia.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import qs.servizi
import "../componenti"

Scope {
    id: c
    readonly property PwNode uscita: Pipewire.defaultAudioSink
    property int luce: -1                  // percentuale dello schermo, -1 finché non la leggo
    property bool wifi: false
    property bool ia: Tema.ia

    function leggiLuce() { if (!luceP.running) luceP.running = true; }
    function leggiWifi() { if (!wifiP.running) wifiP.running = true; }
    function impostaLuce(v) {
        luce = Math.max(1, Math.min(100, Math.round(v)));
        Quickshell.execDetached(["brightnessctl", "set", luce + "%"]);
    }
    function cambiaWifi() {
        Quickshell.execDetached(["nmcli", "radio", "wifi", wifi ? "off" : "on"]);
        wifi = !wifi;
    }
    function cambiaIa() {
        Quickshell.execDetached([Percorsi.bin("cieltema"), "imposta", "ia=" + (ia ? "spenta" : "accesa")]);
        ia = !ia;
    }

    PwObjectTracker { objects: [c.uscita] }

    Process {
        id: luceP
        command: ["sh", "-c", "brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d %"]
        stdout: StdioCollector { onStreamFinished: { const n = parseInt(text.trim(), 10); if (!isNaN(n)) c.luce = n; } }
    }
    Process {
        id: wifiP
        command: ["sh", "-c", "nmcli radio wifi 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: c.wifi = text.trim() === "enabled" }
    }
    Timer {
        interval: 30000; running: Pannelli.aperto === "centro"; repeat: true
        onTriggered: { c.leggiLuce(); c.leggiWifi(); }
    }
    Connections {
        target: Pannelli
        function onApertoChanged() { if (Pannelli.aperto === "centro") { c.leggiLuce(); c.leggiWifi(); } }
    }

    PanelWindow {
        id: finestra
        visible: Pannelli.aperto === "centro"
        screen: Quickshell.screens.find(s => s.name === Pannelli.schermo) ?? Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "nightly-centro"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: Pannelli.aperto === "centro" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.01, 0.02, 0.05, 0.28)
            MouseArea { anchors.fill: parent; onClicked: Pannelli.chiudi() }
            Keys.onEscapePressed: Pannelli.chiudi()
        }

        Hud {
            width: 360
            height: 372
            anchors.right: parent.right
            anchors.rightMargin: Tema.margine + 4
            y: Tema.barra + Tema.margine * 2 + 8

            MouseArea { anchors.fill: parent }

            Column {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                Text {
                    text: Lingua.t("CENTRO DI CONTROLLO").toUpperCase()
                    color: Tema.ciano
                    font.family: Tema.font; font.pixelSize: 9; font.letterSpacing: 2.6
                }

                // ── volume ──
                Column {
                    width: parent.width
                    spacing: 6
                    Row {
                        width: parent.width
                        Text { text: Lingua.t("Volume"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 12 }
                        Item { width: parent.width - 190; height: 1 }
                        Text {
                            text: Math.round((c.uscita?.audio?.volume ?? 0) * 100) + "%"
                            color: Tema.tenue; font.family: Tema.mono; font.pixelSize: 11
                        }
                    }
                    Rectangle {
                        width: parent.width; height: 6; radius: 3
                        color: Tema.alfa(Tema.ciano, 0.16)
                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, c.uscita?.audio?.volume ?? 0))
                            height: parent.height; radius: 3
                            color: Tema.ciano
                        }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -8
                            onPressed: m => { if (c.uscita?.audio) c.uscita.audio.volume = Math.max(0, Math.min(1, m.x / parent.width)); }
                            onPositionChanged: m => { if (pressed && c.uscita?.audio) c.uscita.audio.volume = Math.max(0, Math.min(1, m.x / parent.width)); }
                        }
                    }
                }

                // ── luminosità ──
                Column {
                    width: parent.width
                    spacing: 6
                    Row {
                        width: parent.width
                        Text { text: Lingua.t("Luminosità"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 12 }
                        Item { width: parent.width - 190; height: 1 }
                        Text {
                            text: (c.luce < 0 ? "—" : c.luce) + "%"
                            color: Tema.tenue; font.family: Tema.mono; font.pixelSize: 11
                        }
                    }
                    Rectangle {
                        width: parent.width; height: 6; radius: 3
                        color: Tema.alfa(Tema.ciano, 0.16)
                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(100, c.luce < 0 ? 0 : c.luce)) / 100
                            height: parent.height; radius: 3
                            color: Tema.oro
                        }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -8
                            onPressed: m => c.impostaLuce(m.x / parent.width * 100)
                            onPositionChanged: m => { if (pressed) c.impostaLuce(m.x / parent.width * 100); }
                        }
                    }
                }

                // ── interruttori ──
                Row {
                    width: parent.width
                    spacing: 10
                    Repeater {
                        model: [
                            { nome: Lingua.t("Wi-Fi"), acceso: c.wifi, fai: () => c.cambiaWifi() },
                            { nome: Lingua.t("IA di Ciel"), acceso: c.ia, fai: () => c.cambiaIa() }
                        ]
                        Rectangle {
                            required property var modelData
                            width: (parent.width - 10) / 2
                            height: 44
                            radius: Tema.raggioPiccolo
                            color: modelData.acceso ? Tema.cianoFondo : Tema.alfa(Tema.testo, 0.04)
                            border.width: 1
                            border.color: modelData.acceso ? Tema.alfa(Tema.ciano, 0.5) : Tema.alfa(Tema.testo, 0.12)
                            Text {
                                anchors.centerIn: parent
                                text: modelData.nome + (modelData.acceso ? "  ●" : "  ○")
                                color: modelData.acceso ? Tema.testo : Tema.tenue
                                font.family: Tema.font; font.pixelSize: 12
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: modelData.fai() }
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Tema.alfa(Tema.ciano, 0.16) }

                // ── in fondo: i posti dove si va ──
                Row {
                    width: parent.width
                    spacing: 10
                    Repeater {
                        model: [
                            { icona: "power_settings_new", testo: Lingua.t("Sessione"), fai: () => Pannelli.mostra("sessione") },
                            { icona: "terminal", testo: Lingua.t("Terminale"), fai: () => { Pannelli.chiudi(); Avvia.comando("terminale", [Tema.terminale]); } },
                            { icona: "settings", testo: Lingua.t("Impostazioni"), fai: () => { Pannelli.chiudi(); Avvia.comando("impostazioni", [Tema.terminale, "-e", Percorsi.bin("cielos-tui"), "impostazioni"]); } }
                        ]
                        Rectangle {
                            required property var modelData
                            width: (parent.width - 20) / 3
                            height: 46
                            radius: Tema.raggioPiccolo
                            color: "transparent"
                            border.width: 1
                            border.color: Tema.alfa(Tema.testo, 0.12)
                            Column {
                                anchors.centerIn: parent
                                spacing: 2
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.icona; color: Tema.ciano
                                    font.family: Tema.icone; font.pixelSize: 18
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.testo; color: Tema.tenue
                                    font.family: Tema.font; font.pixelSize: 10
                                }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: modelData.fai() }
                        }
                    }
                }
            }
        }
    }
}
