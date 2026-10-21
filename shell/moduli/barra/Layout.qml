// L'icona del layout delle finestre: un clic passa al successivo (affiancate → una grande → colonne), la rotella
// fa lo stesso, e la schedina mostra le tre possibilità con un disegno che si muove. Il layout lo applica subito
// Hyprland e la scelta resta in ~/.config/cielos/cielos.json (cieltema), quindi vale anche dopo il riavvio.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.servizi

Icona {
    id: l
    readonly property var modelli: [
        { nome: "dwindle",   titolo: Lingua.t("Affiancate"), icona: "view_quilt",
          cosa: Lingua.t("Le finestre si dividono lo spazio") },
        { nome: "master",    titolo: Lingua.t("Una grande"), icona: "view_column",
          cosa: Lingua.t("La finestra attiva grande, le altre di lato") },
        { nome: "scrolling", titolo: Lingua.t("Colonne"), icona: "view_carousel",
          cosa: Lingua.t("Le finestre in colonne che scorrono") }
    ]
    property string mostrato: Tema.finestreLayout
    readonly property int indice: Math.max(0, modelli.findIndex(m => m.nome === mostrato))
    nome: modelli[indice]?.icona ?? "view_quilt"
    colore: Tema.oroChiaro

    Connections {
        target: Tema
        function onFinestreLayoutChanged() { l.mostrato = Tema.finestreLayout; }
    }
    onMostratoChanged: salto.restart()
    onPremuto: mouse => { if (mouse.button === Qt.LeftButton) { l.cambia(); scheda.aperta = true; } }
    onRotella: ruota => {
        const nomi = modelli.map(m => m.nome);
        const verso = ruota.angleDelta.y > 0 ? 1 : nomi.length - 1;
        l.cambia(nomi[(nomi.indexOf(mostrato) + verso) % nomi.length]);
    }

    function cambia(nuovo) {
        const nomi = modelli.map(m => m.nome);
        const prossimo = nuovo ?? nomi[(nomi.indexOf(mostrato) + 1) % nomi.length];
        if (!prossimo || prossimo === mostrato) return;
        mostrato = prossimo;                 // il disegno parte subito
        // la Hyprland di CielOS usa il parser Lua: «keyword» non basta più, si passa da eval
        applica.command = ["hyprctl", "eval", 'hl.config({ general = { layout = "' + prossimo + '" } })'];
        applica.running = true;
        salva.command = [Percorsi.bin("cieltema"), "imposta", "finestre_layout=" + prossimo];
        salva.running = true;
    }

    // il saltino dell'icona quando cambia layout
    SequentialAnimation {
        id: salto
        running: false
        NumberAnimation { target: l; property: "scale"; from: 1; to: 1.2; duration: 110; easing.type: Easing.OutCubic }
        NumberAnimation { target: l; property: "scale"; from: 1.2; to: 1; duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
    }

    Process {
        id: applica
        command: ["hyprctl", "keyword", "general:layout", "dwindle"]
        onExited: if (exitCode !== 0) console.warn("layout: hyprctl non ha applicato", command)
    }
    Process {
        id: salva
        command: [Percorsi.bin("cieltema"), "imposta", "finestre_layout=dwindle"]
        onExited: if (exitCode !== 0) console.warn("layout: cieltema non ha salvato la scelta")
    }

    Schedina {
        id: scheda
        icona: l
        titolo: Lingua.t("Layout delle finestre")
        larghezza: 300

        // il disegno grande: è lui che si anima quando cambi layout
        Row {
            spacing: 12
            AnteprimaLayout {
                width: 92; height: 58
                tipo: l.mostrato
                acceso: true
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.parent.width - 116
                spacing: 3
                Text {
                    text: l.modelli[l.indice]?.titolo ?? ""
                    color: Tema.oro; font.family: Tema.font; font.pixelSize: 15; font.weight: Font.Medium
                }
                Text {
                    width: parent.width; wrapMode: Text.WordWrap
                    text: l.modelli[l.indice]?.cosa ?? ""
                    color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
                }
            }
        }
        Repeater {
            model: l.modelli
            Rectangle {
                required property var modelData
                width: scheda.larghezza - 32; height: 48
                radius: Tema.raggioPiccolo + 2
                color: l.mostrato === modelData.nome ? Tema.accentoSoft : Tema.biancoTenue
                border.width: l.mostrato === modelData.nome ? 1 : 0
                border.color: Tema.alfa(Tema.oro, 0.45)
                scale: l.mostrato === modelData.nome ? 1 : 0.98
                Behavior on color { ColorAnimation { duration: Tema.durata } }
                Behavior on scale { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 9; anchors.rightMargin: 9
                    spacing: 10
                    AnteprimaLayout {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 44; height: 30
                        tipo: modelData.nome
                        acceso: l.mostrato === modelData.nome
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.titolo
                        color: l.mostrato === modelData.nome ? Tema.testo : Tema.tenue
                        font.family: Tema.font; font.pixelSize: 13
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: l.mostrato === modelData.nome ? "check" : ""
                        visible: text !== ""
                        font.family: Tema.icone; font.pixelSize: 17; color: Tema.oro
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { l.cambia(modelData.nome); scheda.aperta = false; }
                }
            }
        }
    }
}
