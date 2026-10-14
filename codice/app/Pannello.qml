// Le impostazioni di Ciel Codice: i servizi in cloud (con la chiave da incollare e il link per crearla) e i plugin
// (server MCP: si aggiungono con un nome e il comando che li avvia, si accendono, spengono, tolgono).
import QtQuick
import qs.servizi

Rectangle {
    id: pa
    property var fornitori: []
    property var plugin: []
    signal comando(var d)
    signal chiudi()
    color: Tema.fondo

    component Campo: Rectangle {
        property alias testo: inp.text
        property alias segreto: inp.echoMode
        property string suggerimento
        signal invio()
        height: 36; radius: 10
        color: Qt.rgba(0.02, 0.03, 0.1, 0.9)
        border.color: inp.activeFocus ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.7) : Qt.rgba(1, 1, 1, 0.12)
        TextInput {
            id: inp
            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
            verticalAlignment: TextInput.AlignVCenter
            color: Tema.testo; font.family: Tema.font; font.pixelSize: 13; clip: true
            passwordCharacter: "●"
            onAccepted: parent.invio()
            Text { anchors.verticalCenter: parent.verticalCenter; visible: !inp.text; text: parent.parent.suggerimento; color: Tema.tenue; font: inp.font }
        }
    }
    component Bottone: Rectangle {
        property string testo
        property bool pieno: false
        property bool pericolo: false
        signal premuto()
        readonly property color base: pericolo ? Tema.allarme : Tema.oro
        width: et.implicitWidth + 24; height: 32; radius: 16
        color: pieno ? base : tb.containsMouse ? Qt.rgba(base.r, base.g, base.b, 0.2) : Qt.rgba(base.r, base.g, base.b, 0.07)
        border.color: pieno ? "transparent" : Qt.rgba(base.r, base.g, base.b, 0.45)
        Text { id: et; anchors.centerIn: parent; text: parent.testo; color: parent.pieno ? Tema.fondo : Tema.testo; font.family: Tema.font; font.pixelSize: 13; font.weight: Font.Medium }
        MouseArea { id: tb; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.premuto() }
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 28
        contentHeight: col.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        Column {
            id: col
            width: parent.width
            spacing: 14

            Row {
                spacing: 12
                Text { text: "arrow_back"; font.family: Tema.icone; font.pixelSize: 22; color: Tema.oro
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pa.chiudi() } }
                Text { text: Lingua.t("Impostazioni di Codice"); color: Tema.testo; font.family: Tema.font; font.pixelSize: 20; font.weight: Font.Medium }
            }

            Text { text: Lingua.t("Modelli in cloud"); color: Tema.oro; font.family: Tema.font; font.pixelSize: 12; font.letterSpacing: 2; font.capitalization: Font.AllUppercase }
            Text {
                width: parent.width; wrapMode: Text.Wrap
                text: Lingua.t("Hanno un piano gratuito, ma serve un account tuo: crei la chiave sul loro sito e la incolli qui. Resta sul PC (leggibile solo da te). Quello che scrivi a un servizio in cloud esce dal PC: per il codice privato usa i modelli locali.")
                color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13
            }
            Repeater {
                model: pa.fornitori.filter(f => f.chiave)
                Rectangle {
                    id: fr
                    required property var modelData
                    width: col.width; height: fc.implicitHeight + 24; radius: 12
                    color: Qt.rgba(1, 1, 1, 0.03); border.color: Tema.bordo
                    Column {
                        id: fc
                        x: 16; y: 12; width: parent.width - 32; spacing: 8
                        Row {
                            spacing: 10
                            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 9; height: 9; radius: 5; color: fr.modelData.pronto ? "#5fd38a" : Tema.tenue }
                            Text { text: fr.modelData.nome; color: Tema.testo; font.family: Tema.font; font.pixelSize: 15; font.weight: Font.Medium }
                            Text { anchors.baseline: parent.children[1].baseline; text: fr.modelData.gratis ?? ""; color: Tema.oroChiaro; font.family: Tema.font; font.pixelSize: 12 }
                        }
                        Text { width: parent.width; wrapMode: Text.Wrap; text: fr.modelData.nota ?? ""; color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12 }
                        Row {
                            spacing: 8
                            Campo { id: chiave; width: 380; segreto: TextInput.Password; suggerimento: fr.modelData.pronto ? Lingua.t("Chiave salvata (incollane un'altra per cambiarla)") : Lingua.t("Incolla qui la chiave")
                                onInvio: salva.premuto() }
                            Bottone { id: salva; testo: Lingua.t("Salva"); pieno: true; onPremuto: { pa.comando({ cmd: "chiave", fornitore: fr.modelData.id, valore: chiave.testo }); chiave.testo = ""; } }
                            Bottone { visible: fr.modelData.pronto; testo: Lingua.t("Togli"); pericolo: true; onPremuto: pa.comando({ cmd: "chiave", fornitore: fr.modelData.id, valore: "" }) }
                            Bottone { visible: !!fr.modelData.iscrizione; testo: Lingua.t("Crea la chiave ↗"); onPremuto: Qt.openUrlExternally(fr.modelData.iscrizione) }
                        }
                    }
                }
            }

            Item { width: 1; height: 8 }
            Text { text: Lingua.t("Plugin"); color: Tema.oro; font.family: Tema.font; font.pixelSize: 12; font.letterSpacing: 2; font.capitalization: Font.AllUppercase }
            Text {
                width: parent.width; wrapMode: Text.Wrap
                text: Lingua.t("Server MCP, lo standard dei plugin per agenti: danno a Codice strumenti in più (GitHub, database, documentazione, browser…). Ognuno si avvia con un comando, per esempio «npx -y @modelcontextprotocol/server-memory» oppure «uvx mcp-server-git». Partono solo mentre una conversazione li usa.")
                color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13
            }
            Repeater {
                model: pa.plugin
                Rectangle {
                    id: pr
                    required property var modelData
                    width: col.width; height: 54; radius: 12
                    color: Qt.rgba(1, 1, 1, 0.03); border.color: Tema.bordo
                    opacity: modelData.attivo === false ? 0.6 : 1
                    Column {
                        anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter; right: azioni.left; rightMargin: 10 }
                        Text { text: pr.modelData.nome; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.Medium }
                        Text { width: parent.width; elide: Text.ElideRight; text: pr.modelData.comando.join(" "); color: Tema.tenue; font.family: "JetBrains Mono"; font.pixelSize: 12 }
                    }
                    Row {
                        id: azioni
                        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 8
                        Bottone { testo: pr.modelData.attivo === false ? Lingua.t("Accendi") : Lingua.t("Spegni"); onPremuto: pa.comando({ cmd: "plugin_attiva", nome: pr.modelData.nome, si: pr.modelData.attivo === false }) }
                        Bottone { testo: Lingua.t("Togli"); pericolo: true; onPremuto: pa.comando({ cmd: "plugin_togli", nome: pr.modelData.nome }) }
                    }
                }
            }
            Row {
                spacing: 8
                Campo { id: pNome; width: 160; suggerimento: "nome" }
                Campo { id: pCmd; width: 440; suggerimento: "comando (es. npx -y @modelcontextprotocol/server-memory)"; onInvio: aggiungi.premuto() }
                Bottone {
                    id: aggiungi
                    testo: Lingua.t("Aggiungi"); pieno: true
                    onPremuto: {
                        const c = pCmd.testo.trim().split(/\s+/).filter(x => x);
                        if (!pNome.testo.trim() || !c.length) return;
                        pa.comando({ cmd: "plugin_aggiungi", nome: pNome.testo.trim().replace(/\W+/g, "_"), comando: c });
                        pNome.testo = ""; pCmd.testo = "";
                    }
                }
            }
            Item { width: 1; height: 8 }
            Text {
                width: parent.width; wrapMode: Text.Wrap
                text: "Istruzioni per tutti i progetti: ~/.config/cielos/codice/AGENTS.md · per un progetto: AGENTS.md nella sua cartella."
                color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
            }
        }
    }
}
