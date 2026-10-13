// Il volume dell'uscita audio: rotella per alzare e abbassare, clic per il muto. Mouse sopra: una schedina con
// la barra del volume e l'uscita da usare (cuffie, casse, HDMI…).
import QtQuick
import Quickshell.Services.Pipewire
import qs.servizi

Icona {
    id: v
    readonly property PwNode uscita: Pipewire.defaultAudioSink
    readonly property bool muto: uscita?.audio?.muted ?? false
    readonly property real livello: uscita?.audio?.volume ?? 0
    readonly property var uscite: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    nome: muto || livello === 0 ? "volume_off" : livello < 0.4 ? "volume_down" : "volume_up"
    colore: muto ? Tema.tenue : Tema.oroChiaro
    PwObjectTracker { objects: [uscita] }
    onPremuto: if (uscita?.audio) uscita.audio.muted = !uscita.audio.muted
    onRotella: r => imposta(livello + (r.angleDelta.y > 0 ? 0.05 : -0.05))

    function imposta(x) {
        if (uscita?.audio) uscita.audio.volume = Math.max(0, Math.min(1, x));
    }

    Schedina {
        id: scheda
        icona: v
        titolo: "Audio"
        larghezza: 280

        Row {
            spacing: 10
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: v.nome; font.family: Tema.icone; font.pixelSize: 20
                color: v.muto ? Tema.tenue : Tema.oroChiaro
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (v.uscita?.audio) v.uscita.audio.muted = !v.muto }
            }
            Item {                                   // la barra del volume: clic o trascina
                id: guida
                anchors.verticalCenter: parent.verticalCenter
                width: 180; height: 22
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width; height: 6; radius: 3
                    color: Qt.rgba(1, 1, 1, 0.1)
                    Rectangle {
                        width: parent.width * v.livello; height: parent.height; radius: 3
                        color: v.muto ? Tema.tenue : Tema.oro
                        Behavior on width { NumberAnimation { duration: 90 } }
                    }
                }
                Rectangle {
                    x: guida.width * v.livello - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14; height: 14; radius: 7
                    color: Tema.oroChiaro
                    Behavior on x { NumberAnimation { duration: 90 } }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onPressed: m => v.imposta(m.x / guida.width)
                    onPositionChanged: m => { if (pressed) v.imposta(m.x / guida.width); }
                    onWheel: r => v.imposta(v.livello + (r.angleDelta.y > 0 ? 0.05 : -0.05))
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(v.livello * 100) + "%"
                color: Tema.testo; font.family: Tema.font; font.pixelSize: 13
            }
        }
        Repeater {                                   // le uscite: quella in uso è accesa
            model: v.uscite.length > 1 ? v.uscite : []
            Bottone {
                required property PwNode modelData
                icona: modelData === v.uscita ? "check" : (modelData.description || modelData.name).match(/hdmi|displayport/i) ? "tv" : "speaker"
                testo: {
                    const t = modelData.nickname || modelData.description || modelData.name;
                    return t.length > 34 ? t.slice(0, 33) + "…" : t;
                }
                acceso: modelData === v.uscita
                onPremuto: Pipewire.preferredDefaultAudioSink = modelData
            }
        }
    }
}
