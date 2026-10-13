// Il volume dell'uscita audio: rotella per alzare e abbassare, clic per il muto.
import QtQuick
import Quickshell.Services.Pipewire
import qs.servizi

Icona {
    readonly property PwNode uscita: Pipewire.defaultAudioSink
    readonly property bool muto: uscita?.audio?.muted ?? false
    readonly property real livello: uscita?.audio?.volume ?? 0
    nome: muto || livello === 0 ? "volume_off" : livello < 0.4 ? "volume_down" : "volume_up"
    colore: muto ? Tema.tenue : Tema.oroChiaro
    PwObjectTracker { objects: [uscita] }
    onPremuto: if (uscita?.audio) uscita.audio.muted = !uscita.audio.muted
    onRotella: r => {
        if (!uscita?.audio) return;
        uscita.audio.volume = Math.max(0, Math.min(1, livello + (r.angleDelta.y > 0 ? 0.05 : -0.05)));
    }
}
