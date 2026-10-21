// Codice (Super+A → Codice): gli agenti che scrivono codice nel terminale — FreeBuff, OpenCode, Aider, Crush.
// Non sono di CielOS: sono programmi loro, con le loro chiavi e i loro modelli; da qui si scaricano e si aprono.
// Il motore è bin/cielagenti: l'elenco, cosa è installato, e i comandi veri che girano in un terminale davanti a te
// (la password la scrivi tu). Dopo l'installa il riquadro si riapre qui: lo stato si rilegge all'apertura.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.servizi

Item {
    id: cd
    readonly property string motore: Percorsi.bin("cielagenti")
    property var agenti: []                       // [{ id, nome, comando, icona, spiega, come, installato }]

    function apri() { aggiorna(); forceActiveFocus(); }
    function aggiorna() { if (!leggi.running) leggi.running = true; }
    function indietro() { return false; }         // niente sottopagine: Esc torna ai tasti
    function installa(a) {
        Pannelli.chiudi();
        Avvia.comando("codice-" + a.id, [Tema.terminale || "foot", "-e", motore, "installa", a.id]);
    }
    function apriAgente(a) {
        Pannelli.chiudi();
        Avvia.comando("codice-" + a.id, [Tema.terminale || "foot", "-e", motore, "apri", a.id]);
    }

    Process {
        id: leggi
        command: [cd.motore, "elenco", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { cd.agenti = JSON.parse(text).agenti; } catch (e) { cd.agenti = []; }
            }
        }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: corpo.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: corpo
            width: parent.width
            spacing: 10

            Text {
                width: parent.width
                text: Lingua.t("Gli agenti che scrivono codice"); color: Tema.testo
                font.family: Tema.font; font.pixelSize: 16; font.weight: Font.Medium
            }
            Text {
                width: parent.width; wrapMode: Text.WordWrap
                text: Lingua.t("Non sono di CielOS: sono programmi loro. Si installano in un terminale davanti a te (la password la scrivi tu) e si aprono da qui.")
                color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12; lineHeight: 1.1
            }

            Repeater {
                model: cd.agenti
                delegate: Rectangle {
                    id: scheda
                    required property var modelData
                    width: corpo.width; height: 100
                    radius: Tema.raggio + 4
                    color: Tema.vetroAlto
                    border.width: 1
                    border.color: Tema.bordoTenue

                    Row {
                        x: 18
                        width: parent.width - 36
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 14
                        Rectangle {
                            width: 46; height: 46; radius: 23
                            anchors.verticalCenter: parent.verticalCenter
                            color: Tema.accentoSoft
                            border.width: 1; border.color: Tema.alfa(Tema.oro, 0.2)
                            Text {
                                anchors.centerIn: parent
                                text: scheda.modelData.icona; font.family: Tema.icone; font.pixelSize: 24; color: Tema.oro
                            }
                        }
                        Column {
                            width: parent.width - 46 - 14 - pulsanti.width - 14
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3
                            Text {
                                width: parent.width; text: scheda.modelData.nome; color: Tema.testo
                                font.family: Tema.font; font.pixelSize: 16; font.weight: Font.Medium; elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width; wrapMode: Text.WordWrap
                                text: Lingua.t(scheda.modelData.spiega); color: Tema.tenue
                                font.family: Tema.font; font.pixelSize: 12; maximumLineCount: 2
                                elide: Text.ElideRight; lineHeight: 1.05
                            }
                            Row {
                                spacing: 6
                                Rectangle {
                                    width: 6; height: 6; radius: 3
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: scheda.modelData.installato ? "#7fe0a8" : Tema.tenue
                                }
                                Text {
                                    text: scheda.modelData.installato ? Lingua.t("installato")
                                          : Lingua.t("non installato · %1", Lingua.t(scheda.modelData.come))
                                    color: Tema.tenue; font.family: Tema.font; font.pixelSize: 11
                                }
                            }
                        }
                        Row {
                            id: pulsanti
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            Pulsante {
                                visible: !scheda.modelData.installato
                                pieno: true; icona: "download"; testo: Lingua.t("Installa")
                                onPremuto: cd.installa(scheda.modelData)
                            }
                            Pulsante {
                                visible: scheda.modelData.installato
                                pieno: true; icona: "play_arrow"; testo: Lingua.t("Apri")
                                onPremuto: cd.apriAgente(scheda.modelData)
                            }
                        }
                    }
                }
            }

            Text {
                visible: cd.agenti.length === 0
                width: parent.width; wrapMode: Text.WordWrap
                text: leggi.running ? Lingua.t("Leggo l'elenco degli agenti…")
                                    : Lingua.t("Nessun agente da mostrare: manca bin/cielagenti.")
                color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13
            }

            Text {
                width: parent.width; wrapMode: Text.WordWrap
                text: Lingua.t("Dopo l'installazione torna qui (Super+A → Codice): l'agente si apre con «Apri». FreeBuff funziona subito; OpenCode, Aider e Crush vogliono le tue chiavi o un modello locale.")
                color: Tema.tenue; font.family: Tema.font; font.pixelSize: 11; lineHeight: 1.1
            }
        }
    }
}
