// Una riga della conversazione: tu, Ciel (testo in markdown), uno strumento usato (si apre per vedere l'uscita),
// una richiesta di permesso (con l'anteprima delle modifiche), un avviso o un errore.
import QtQuick
import qs.servizi

Item {
    id: v
    required property var model                   // la riga del ListModel (con le proprietà richieste va dichiarata)
    required property int index
    readonly property var dati: model
    property real larghezza: 600
    signal rispondi(string idc, bool si, bool sempre)
    signal apriChiudi(int i)
    width: larghezza
    height: corpo.height + 6

    readonly property var icone: ({ list_dir: "folder_open", read_file: "description", search: "search",
                                     write_file: "edit_document", edit_file: "edit", run_command: "terminal" })

    Item {
        id: corpo
        width: parent.width
        height: v.dati.tipo === "tu" ? tu.height
              : v.dati.tipo === "ciel" ? ciel.implicitHeight
              : v.dati.tipo === "strumento" ? str.height
              : v.dati.tipo === "permesso" ? perm.height
              : nota.implicitHeight + 8

        // ── tu
        Rectangle {
            id: tu
            visible: v.dati.tipo === "tu"
            anchors.right: parent.right
            width: Math.min(parent.width * 0.8, tuTesto.implicitWidth + 32)
            height: tuTesto.implicitHeight + 22
            radius: 16
            color: Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.16)
            Text {
                id: tuTesto
                x: 16; y: 11
                width: Math.min(implicitWidth, v.larghezza * 0.8 - 32)
                text: v.dati.testo; wrapMode: Text.Wrap
                color: Tema.testo; font.family: Tema.font; font.pixelSize: 14
            }
        }

        // ── Ciel
        TextEdit {
            id: ciel
            visible: v.dati.tipo === "ciel"
            width: parent.width
            readOnly: true; selectByMouse: true
            textFormat: TextEdit.MarkdownText
            text: v.dati.testo
            wrapMode: TextEdit.Wrap
            color: Tema.testo; font.family: Tema.font; font.pixelSize: 14
            selectionColor: Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.4)
            onLinkActivated: l => Qt.openUrlExternally(l)
        }

        // ── uno strumento
        Rectangle {
            id: str
            visible: v.dati.tipo === "strumento"
            width: parent.width
            height: 34 + (v.dati.aperto && v.dati.testo ? uscita.height + 10 : 0)
            radius: 10
            color: Qt.rgba(1, 1, 1, 0.03)
            border.color: Qt.rgba(1, 1, 1, 0.06)
            Row {
                x: 12; height: 34; spacing: 9
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: v.icone[v.dati.nome] ?? "extension"
                    font.family: Tema.icone; font.pixelSize: 17; color: Tema.oroChiaro
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: v.dati.etichetta; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13; font.weight: Font.Medium
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, v.larghezza - 200)
                    elide: Text.ElideMiddle
                    text: v.dati.dettaglio; color: Tema.tenue; font.family: "JetBrains Mono"; font.pixelSize: 12
                }
            }
            Text {                                    // stato: in corso, fatto, errore
                anchors { right: parent.right; rightMargin: 12; top: parent.top; topMargin: 8 }
                text: v.dati.stato === "corre" ? "progress_activity" : v.dati.stato === "ok" ? "check" : "close"
                font.family: Tema.icone; font.pixelSize: 17
                color: v.dati.stato === "errore" ? Tema.allarme : v.dati.stato === "ok" ? "#5fd38a" : Tema.tenue
                RotationAnimation on rotation { running: v.dati.stato === "corre"; from: 0; to: 360; duration: 1000; loops: Animation.Infinite }
            }
            Rectangle {
                id: uscita
                visible: v.dati.aperto && !!v.dati.testo
                x: 10; y: 34
                width: parent.width - 20
                height: Math.min(uscitaTesto.implicitHeight + 16, 320)
                radius: 8
                color: Qt.rgba(0, 0, 0, 0.25)
                clip: true
                Flickable {
                    anchors.fill: parent; anchors.margins: 8
                    contentHeight: uscitaTesto.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    TextEdit {
                        id: uscitaTesto
                        width: parent.width
                        readOnly: true; selectByMouse: true
                        text: v.dati.testo; wrapMode: TextEdit.WrapAnywhere
                        color: Tema.tenue; font.family: "JetBrains Mono"; font.pixelSize: 12
                    }
                }
            }
            MouseArea {
                width: parent.width; height: 34
                cursorShape: Qt.PointingHandCursor
                onClicked: v.apriChiudi(v.index)
            }
        }

        // ── permesso
        Rectangle {
            id: perm
            visible: v.dati.tipo === "permesso"
            width: parent.width
            height: pc.implicitHeight + 24
            radius: 12
            color: Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, v.dati.stato === "attesa" ? 0.1 : 0.04)
            border.color: v.dati.stato === "attesa" ? Tema.oro : Tema.bordo
            Column {
                id: pc
                x: 14; y: 12; width: parent.width - 28
                spacing: 8
                Text {
                    width: parent.width; wrapMode: Text.Wrap
                    text: "<b>" + v.dati.etichetta + "</b> " + v.dati.dettaglio.replace(/</g, "&lt;") + " — " + v.dati.motivo
                    textFormat: Text.StyledText
                    color: Tema.testo; font.family: Tema.font; font.pixelSize: 13
                }
                Rectangle {
                    visible: !!v.dati.anteprima
                    width: parent.width
                    height: Math.min(diffTesto.implicitHeight + 14, 260)
                    radius: 8; color: Qt.rgba(0, 0, 0, 0.3); clip: true
                    Flickable {
                        anchors.fill: parent; anchors.margins: 7
                        contentHeight: diffTesto.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        Text {
                            id: diffTesto
                            width: parent.width
                            textFormat: Text.StyledText
                            wrapMode: Text.WrapAnywhere
                            font.family: "JetBrains Mono"; font.pixelSize: 12; color: Tema.tenue
                            text: (v.dati.anteprima || "").split("\n").map(r => {
                                const s = r.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/ /g, "&nbsp;");
                                return r.startsWith("+") && !r.startsWith("+++") ? "<font color='#5fd38a'>" + s + "</font>"
                                     : r.startsWith("-") && !r.startsWith("---") ? "<font color='" + Tema.allarme + "'>" + s + "</font>" : s;
                            }).join("<br>")
                        }
                    }
                }
                Row {
                    visible: v.dati.stato === "attesa"
                    spacing: 8
                    Repeater {
                        model: [[Lingua.t("Sì"), true, false, true], [Lingua.t("Sì, per questa sessione"), true, true, false], [Lingua.t("No"), false, false, false]]
                        Rectangle {
                            required property var modelData
                            width: et.implicitWidth + 26; height: 32; radius: 16
                            color: modelData[3] ? (t.containsMouse ? Qt.lighter(Tema.oro, 1.1) : Tema.oro)
                                 : t.containsMouse ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.2) : Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.07)
                            border.color: modelData[3] ? "transparent" : Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.45)
                            Text { id: et; anchors.centerIn: parent; text: parent.modelData[0]; color: parent.modelData[3] ? Tema.fondo : Tema.testo; font.family: Tema.font; font.pixelSize: 13; font.weight: Font.Medium }
                            MouseArea { id: t; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: v.rispondi(v.dati.idc, parent.modelData[1], parent.modelData[2]) }
                        }
                    }
                }
                Text {
                    visible: v.dati.stato !== "attesa"
                    text: v.dati.stato === "si" ? Lingua.t("Permesso.") : Lingua.t("Non permesso.")
                    color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
                }
            }
        }

        // ── avviso / errore
        Text {
            id: nota
            visible: v.dati.tipo === "avviso" || v.dati.tipo === "errore"
            y: 4
            width: parent.width; wrapMode: Text.Wrap
            text: v.dati.testo
            color: v.dati.tipo === "errore" ? Tema.allarme : Tema.oroChiaro
            font.family: Tema.font; font.pixelSize: 13
        }
    }
}
