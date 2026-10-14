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
        titolo: Lingua.t("Audio")
        larghezza: 280

        Cursore {
            icona: v.nome
            valore: v.livello
            spento: v.muto
            onCambiato: x => v.imposta(x)
            onIconaPremuta: if (v.uscita?.audio) v.uscita.audio.muted = !v.muto
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
