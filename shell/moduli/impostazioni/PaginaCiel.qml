// Impostazioni → Ciel: le impostazioni dell'assistente che si cambiano a mano (voce, iniziativa, avatar, cosa fa in
// sottofondo). L'elenco e i controlli dei valori sono in ~/assistente-vocale/configura.py (impostazioni / imposta):
// cambia una riga di config.yaml lasciando i commenti. La mente si sceglie nel riquadro (Super+A → Modelli).
// Ciel legge config.yaml quando parte: dopo una modifica c'è «Riavvia Ciel».
import QtQuick
import Quickshell
import Quickshell.Io
import qs.servizi

Column {
    id: p
    width: parent ? parent.width : 500
    spacing: 12
    readonly property string configura: Quickshell.env("HOME") + "/assistente-vocale/configura.py"
    property var voci: []
    property bool letto: false
    property bool manca: false
    property bool cambiato: false
    property string avviso: ""
    readonly property var gruppi: [...new Set(voci.map(v => v.gruppo))]
    readonly property var nomiScelte: ({
        piper: Lingua.t("Piper (Paola, velocissima)"), kokoro: Lingua.t("Kokoro (Sara, la più chiara)"), coro: Lingua.t("Coro (quattro voci)"),
        tua_voce: Lingua.t("La tua voce"), voce: Lingua.t("Qualsiasi voce (solo con le cuffie)"), wake: Lingua.t("Il suo nome"), off: Lingua.t("Non si interrompe")
    })

    function leggi() { if (!lettura.running) lettura.running = true; }
    function imposta(k, v) {
        scrittura.command = ["python3", configura, "imposta", k, String(v)];
        scrittura.running = true;
    }
    Component.onCompleted: leggi()

    Process {
        id: lettura
        command: ["python3", p.configura, "impostazioni"]
        stdout: StdioCollector {
            onStreamFinished: { try { p.voci = JSON.parse(text); p.manca = false; } catch (e) { p.manca = true; } p.letto = true; }
        }
    }
    Process {
        id: scrittura
        stdout: StdioCollector {
            onStreamFinished: {
                let r = {};
                try { r = JSON.parse(text); } catch (e) { r = { ok: false, messaggio: text.trim().slice(0, 160) }; }
                if (r.ok) { p.cambiato = true; p.avviso = ""; } else p.avviso = r.messaggio ?? "";
            }
        }
        onExited: p.leggi()
    }
    Process { id: riavvio; command: ["systemctl", "--user", "try-restart", "assistente.service"]; onExited: p.cambiato = false }

    Text {
        visible: p.letto && p.manca
        width: parent.width; wrapMode: Text.WordWrap
        text: Lingua.t("Ciel, l'assistente, non è installata su questo PC. Per installarla: «cielos-ciel» nel terminale.")
        color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13
    }

    // dopo una modifica: Ciel la legge quando riparte
    Rectangle {
        visible: p.cambiato || p.avviso !== ""
        width: parent.width; height: 44; radius: Tema.raggio
        color: p.avviso ? Qt.rgba(Tema.allarme.r, Tema.allarme.g, Tema.allarme.b, 0.12) : Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.1)
        border.color: p.avviso ? Tema.allarme : Tema.bordo
        Text {
            anchors { left: parent.left; leftMargin: 12; right: riavvia.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
            elide: Text.ElideRight
            text: p.avviso || Lingua.t("Salvato. Ciel lo usa dal prossimo avvio.")
            color: p.avviso ? Tema.allarme : Tema.testo; font.family: Tema.font; font.pixelSize: 13
        }
        Chip {
            id: riavvia
            visible: p.cambiato && !p.avviso
            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
            testo: riavvio.running ? Lingua.t("Riparte…") : Lingua.t("Riavvia Ciel adesso"); icona: "restart_alt"
            onPremuto: if (!riavvio.running) riavvio.running = true
        }
    }

    Text {
        visible: p.letto && !p.manca
        width: parent.width; wrapMode: Text.WordWrap
        text: Lingua.t("La mente (il modello con cui pensa) si sceglie in Super+A → Modelli → «Usa per Ciel».")
        color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
    }

    Repeater {
        model: p.gruppi
        Column {
            id: gruppo
            required property string modelData
            width: p.width
            spacing: 10
            Titoletto { testo: Lingua.t(gruppo.modelData) }
            Repeater {
                model: p.voci.filter(v => v.gruppo === gruppo.modelData)
                Loader {
                    id: voce
                    required property var modelData
                    width: gruppo.width
                    sourceComponent: modelData.tipo === "vero" ? cVero : modelData.tipo === "scelta" ? cScelta
                                   : modelData.tipo === "testo" ? cTesto : cNumero
                }
            }
        }
    }

    Component {
        id: cVero
        Interruttore {
            readonly property var v: parent.modelData
            testo: Lingua.t(v.etichetta); spiega: v.spiega ? Lingua.t(v.spiega) : ""
            acceso: v.valore === true; attivo: v.valore !== null
            onCambiato: x => p.imposta(v.chiave, x ? "true" : "false")
        }
    }
    // tendine e cursori non hanno la riga di spiegazione: gliela mette sotto questa colonna
    component ConSpiega: Column {
        id: cs
        readonly property var v: parent.modelData
        default property alias dentro: corpo.data
        width: p.width; spacing: 2
        Item { id: corpo; width: cs.width; height: childrenRect.height }
        Text { visible: !!cs.v.spiega; width: cs.width; wrapMode: Text.WordWrap
               text: Lingua.t(cs.v.spiega ?? ""); color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12 }
    }
    Component {
        id: cScelta
        ConSpiega {
            id: cc
            Tendina {
                width: cc.width
                testo: Lingua.t(cc.v.etichetta)
                voci: cc.v.scelte.map(s => ({ testo: p.nomiScelte[s] ?? s, valore: s }))
                valore: cc.v.valore
                onScelto: x => p.imposta(cc.v.chiave, x)
            }
        }
    }
    Component {
        id: cNumero
        ConSpiega {
            id: cn
            Cursore {
                width: cn.width
                testo: Lingua.t(cn.v.etichetta)
                min: cn.v.limiti[0]; max: cn.v.limiti[1]
                passo: cn.v.tipo === "intero" ? 1 : 0.01; decimali: cn.v.tipo === "intero" ? 0 : 2
                valore: cn.v.valore ?? cn.v.limiti[0]
                onCambiato: x => p.imposta(cn.v.chiave, x)
            }
        }
    }
    Component {
        id: cTesto
        Column {
            readonly property var v: parent.modelData
            spacing: 6
            Text { text: Lingua.t(parent.v.etichetta); color: Tema.testo; font.family: Tema.font; font.pixelSize: 14 }
            Rectangle {
                width: Math.min(360, p.width); height: 34; radius: Tema.raggio - 4
                color: Qt.rgba(0.02, 0.03, 0.1, 0.9)
                border.color: campo.activeFocus ? Tema.oro : Tema.bordo
                TextInput {
                    id: campo
                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                    verticalAlignment: TextInput.AlignVCenter
                    text: parent.parent.v.valore ?? ""
                    color: Tema.testo; font.family: Tema.font; font.pixelSize: 13; clip: true; selectByMouse: true
                    // salva con Invio o uscendo dal campo (solo se è cambiato)
                    function salva() { const v = parent.parent.v; if (text !== (v.valore ?? "")) p.imposta(v.chiave, text); }
                    onAccepted: { salva(); focus = false; }
                    onEditingFinished: salva()
                }
            }
            Text {
                visible: !!parent.v.spiega; width: p.width; wrapMode: Text.WordWrap
                text: Lingua.t(parent.v.spiega ?? ""); color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
            }
        }
    }
}
