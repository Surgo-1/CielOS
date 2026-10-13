// Il blocco dello schermo di CielOS: su ogni schermo la notte di Ciel (blocco/Contenuto.qml), la password con PAM.
// Si blocca con: Super+L (scorciatoia cielos:blocco), «qs … ipc call lock lock» (come caelestia: Ciel e le
// automazioni non cambiano), loginctl lock-session, prima della sospensione, e dopo 10 minuti senza toccare niente
// (non mentre suona qualcosa). Sicurezza: se il pannello non si carica, c'è comunque un campo password semplice.
// In prova (CIELOS_PROVA=1) non blocca mai davvero.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import qs.servizi
import "blocco"

Scope {
    id: b

    function blocca() {
        if (Pannelli.prova) { console.log("prova: avrei bloccato lo schermo"); return; }
        Pannelli.chiudi();
        serratura.locked = true;
    }

    // l'id non si chiama «pam»: dentro Contenuto «pam» è una sua proprietà, e ({ pam: pam }) puntava a se stessa
    // (vuota): i tasti non arrivavano a PAM e non si poteva più sbloccare (14/10)
    Pam {
        id: serraturaPam
        onSbloccato: serratura.locked = false
    }

    WlSessionLock {
        id: serratura
        locked: false

        WlSessionLockSurface {
            id: superficie
            color: Tema.fondo

            Item {                              // il pannello (con le sue stelle) e i margini che gli servono
                anchors.fill: parent
                anchors.margins: 48
                Loader {
                    id: pannello
                    anchors.fill: parent
                    sourceComponent: Contenuto {
                        lock: ({ pam: serraturaPam, unlocking: false })
                    }
                }
            }

            // riserva: se il pannello non c'è, o non è collegato alla password, un campo semplice (mai chiuso fuori)
            Rectangle {
                visible: pannello.status !== Loader.Ready || !pannello.item || pannello.item.pam !== serraturaPam
                anchors.centerIn: parent
                width: 380; height: 54; radius: 27
                color: Tema.superficie
                border.color: serraturaPam.state ? Tema.allarme : Tema.oro
                focus: visible
                Keys.onPressed: e => serraturaPam.handleKey(e)
                Text {
                    anchors.centerIn: parent
                    text: serraturaPam.buffer.length ? "●".repeat(Math.min(serraturaPam.buffer.length, 20)) : "Password"
                    color: Tema.testo; font.family: Tema.font; font.pixelSize: 18
                }
            }
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { b.blocca(); }
        function isLocked(): bool { return serratura.locked; }
    }
    GlobalShortcut { appid: "ciel"; name: "blocco"; description: "Blocca lo schermo"; onPressed: b.blocca() }

    // loginctl lock-session e la sospensione (logind, sul bus di sistema)
    Process {
        id: logind
        running: !Pannelli.prova
        command: ["dbus-monitor", "--system",
                  "type='signal',interface='org.freedesktop.login1.Session',member='Lock'",
                  "type='signal',interface='org.freedesktop.login1.Manager',member='PrepareForSleep'"]
        property bool sonno: false
        stdout: SplitParser {
            onRead: r => {
                if (r.includes("member=Lock")) b.blocca();
                else if (r.includes("member=PrepareForSleep")) logind.sonno = true;
                else if (logind.sonno && r.includes("boolean true")) { logind.sonno = false; b.blocca(); }
                else if (r.includes("boolean")) logind.sonno = false;
            }
        }
    }

    // dopo 10 minuti senza toccare niente (non se suona musica o un video)
    IdleMonitor {
        enabled: !Pannelli.prova && Tema.v("blocco_dopo_s", 600) > 0 && !Mpris.players.values.some(p => p.isPlaying)
        timeout: Math.max(60, Tema.v("blocco_dopo_s", 600))
        onIsIdleChanged: if (isIdle && !serratura.locked) b.blocca()
    }
}
