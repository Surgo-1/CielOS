// Impostazioni → Medico: la visita del PC (cielmedico) con un rimedio per ogni cosa che non va. «Ripara» lo applica:
// quello che serve all'utente subito, quello di sistema passa dal guardiano (la finestra della password). Dopo ogni
// riparazione il medico ricontrolla e dice se il problema c'è ancora.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.servizi

Column {
    id: p
    width: parent ? parent.width : 500
    spacing: 10
    property var visita: null
    property string inCorso: ""          // l'id che si sta riparando ("tutto" per tutti)
    property string esito: ""
    readonly property var colori: ({ problema: "#ff6b6b", attenzione: "#ffb347", consiglio: Tema.tenue, ok: "#7fe0a8" })
    readonly property var icone: ({ problema: "error", attenzione: "warning", consiglio: "lightbulb", ok: "check_circle" })
    readonly property int daRiparare: visita ? visita.voci.filter(v => v.ripara && v.gravita !== "ok").length : 0

    Process {
        id: leggi
        running: true
        command: [Percorsi.bin("cielmedico"), "--json"]
        stdout: StdioCollector { onStreamFinished: { try { p.visita = JSON.parse(text); } catch (e) {} } }
    }
    Process {
        id: cura
        stdout: StdioCollector {
            onStreamFinished: {
                const righe = text.split("\n").filter(r => r.trim().startsWith("fatto") || r.trim().startsWith("non riuscito"));
                p.esito = righe.map(r => r.trim()).join(" · ") || "Fatto.";
            }
        }
        onExited: { p.inCorso = ""; leggi.running = true; }
    }
    function ripara(id) {
        if (cura.running) return;
        p.inCorso = id; p.esito = "";
        cura.command = [Percorsi.bin("cielmedico"), "ripara", id];
        cura.running = true;
    }

    Row {
        spacing: 8
        Chip { testo: leggi.running ? "Visito…" : "Rifai la visita"; icona: "stethoscope"; onPremuto: if (!leggi.running) leggi.running = true }
        Chip {
            visible: p.daRiparare > 1
            testo: p.inCorso === "tutto" ? "Riparo…" : "Ripara tutto (" + p.daRiparare + ")"; icona: "healing"; acceso: true
            onPremuto: p.ripara("tutto")
        }
    }
    Text {
        width: p.width; wrapMode: Text.Wrap
        text: p.visita ? p.visita.riassunto : "Visito il PC…"
        color: Tema.testo; font.family: Tema.font; font.pixelSize: 15; font.weight: Font.Medium
    }
    Text {
        visible: p.esito !== ""; width: p.width; wrapMode: Text.Wrap
        text: p.esito; color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
    }

    Repeater {
        model: p.visita ? p.visita.voci : []
        Rectangle {
            id: voce
            required property var modelData
            readonly property bool male: modelData.gravita !== "ok"
            width: p.width
            height: corpo.implicitHeight + (male ? 20 : 4)
            radius: 10
            color: male ? Qt.rgba(1, 1, 1, 0.04) : "transparent"
            Row {
                id: corpo
                x: 10; y: voce.male ? 10 : 2
                width: parent.width - 20
                spacing: 10
                Text { text: p.icone[voce.modelData.gravita]; font.family: Tema.icone; font.pixelSize: 20; color: p.colori[voce.modelData.gravita] }
                Column {
                    width: parent.width - 30 - (bottone.visible ? bottone.width + 10 : 0)
                    spacing: 3
                    Text {
                        width: parent.width; wrapMode: Text.Wrap
                        text: voce.modelData.titolo + (voce.male || !voce.modelData.dettaglio ? "" : ": " + voce.modelData.dettaglio)
                        color: voce.male ? Tema.testo : Tema.tenue; font.family: Tema.font; font.pixelSize: 13
                    }
                    Text {
                        visible: voce.male && voce.modelData.dettaglio !== ""; width: parent.width; wrapMode: Text.Wrap
                        text: voce.modelData.dettaglio; color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
                    }
                    Text {
                        visible: voce.male && voce.modelData.rimedio !== ""; width: parent.width; wrapMode: Text.Wrap
                        text: voce.modelData.rimedio; color: p.colori[voce.modelData.gravita]; font.family: Tema.font; font.pixelSize: 12
                    }
                }
                Chip {
                    id: bottone
                    visible: voce.male && !!voce.modelData.ripara
                    testo: p.inCorso === voce.modelData.id ? "Riparo…" : "Ripara"; icona: "healing"
                    onPremuto: p.ripara(voce.modelData.id)
                }
            }
        }
    }
}
