// Una riga delle impostazioni: cosa fa, e il controllo giusto per il suo tipo (dallo schema di cieltema).
// colore → campioni e codice; intero/numero → barra; vero → interruttore; scelta → pulsantini;
// tasti → la combinazione e «Cambia»; font → il nome, con l'anteprima. «Di serie» toglie la tua scelta.
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import qs.servizi

Column {
    id: r
    property string chiave
    property var info: ({})
    property var valore
    property bool cambiata: false
    property bool inCattura: false
    signal imposta(var v)
    signal togli()
    signal cattura()
    readonly property string tipo: info?.tipo ?? ""
    readonly property var limiti: info?.limiti ?? null
    spacing: 8

    readonly property var campioni: ["#ffbf3f", "#ff9a6b", "#ff5a5a", "#ff8ac2", "#b18cff", "#5b8cff", "#7fd0ff",
                                     "#6fd08c", "#8fd694", "#eef2ff", "#9aa0ae", "#0b1029", "#0a0a0f", "#f4efe6"]

    Item {
        width: parent.width; height: 20
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 90
            elide: Text.ElideRight
            text: (r.info?.cosa ?? r.chiave).charAt(0).toUpperCase() + (r.info?.cosa ?? r.chiave).slice(1)
            color: Tema.testo; font.family: Tema.font; font.pixelSize: 14
        }
        Text {                           // torna al valore di serie
            visible: r.cambiata
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: "↺ di serie"
            color: dsTocco.containsMouse ? Tema.oroChiaro : Tema.tenue; font.family: Tema.font; font.pixelSize: 12
            MouseArea { id: dsTocco; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor; onClicked: r.togli() }
        }
    }

    Loader {                             // senza larghezza: ogni controllo ha la sua
        sourceComponent: r.tipo === "colore" || r.tipo === "colore_o_accento" ? colore
                       : r.tipo === "intero" || r.tipo === "numero" ? numero
                       : r.tipo === "vero" ? vero
                       : r.tipo === "scelta" ? scelta
                       : r.tipo === "tasti" ? tasti
                       : r.tipo === "font" || r.tipo === "programma" ? carattere
                       : r.tipo === "immagine" ? immagine : null
    }

    Rectangle { width: parent.width; height: 1; color: Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.08) }

    // un campo di testo che manda il valore con Invio
    component Campo: Rectangle {
        id: cm
        property alias testo: inp.text
        property string suggerimento
        signal invio(string t)
        height: 32; radius: 16
        color: Qt.rgba(1, 1, 1, 0.05)
        border.color: inp.activeFocus ? Tema.oro : Tema.bordo
        TextInput {
            id: inp
            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
            verticalAlignment: TextInput.AlignVCenter
            color: Tema.testo; font.family: Tema.font; font.pixelSize: 13
            selectByMouse: true
            clip: true
            onAccepted: { cm.invio(text); focus = false; }
            Text {
                visible: !inp.text && !inp.activeFocus
                anchors.verticalCenter: parent.verticalCenter
                text: cm.suggerimento; color: Tema.tenue; font: inp.font
            }
        }
    }

    Component {
        id: colore
        Column {
            width: r.width
            spacing: 8
            Row {
                spacing: 10
                Rectangle {
                    width: 32; height: 32; radius: 16
                    color: r.valore === "accento" ? Tema.oro : (r.valore || "transparent")
                    border.color: Tema.bordo; border.width: r.valore ? 1 : 2
                }
                Campo {
                    width: 130
                    testo: r.valore && r.valore !== "accento" ? r.valore : ""
                    suggerimento: r.valore === "accento" ? "come l'accento" : "di serie"
                    onInvio: t => r.imposta(t)
                }
                Chip {
                    visible: r.tipo === "colore_o_accento"
                    testo: "come l'accento"; acceso: r.valore === "accento"
                    onPremuto: r.imposta("accento")
                }
            }
            Flow {
                width: parent.width
                spacing: 6
                Repeater {
                    model: r.campioni
                    Rectangle {
                        required property string modelData
                        width: 24; height: 24; radius: 12
                        color: modelData
                        border.color: r.valore === modelData ? Tema.testo : Qt.rgba(1, 1, 1, 0.15)
                        border.width: r.valore === modelData ? 2 : 1
                        scale: cTocco.containsMouse ? 1.15 : 1
                        Behavior on scale { NumberAnimation { duration: 100 } }
                        MouseArea { id: cTocco; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: r.imposta(parent.modelData) }
                    }
                }
            }
        }
    }

    Component {
        id: numero
        Row {
            id: nr
            spacing: 12
            readonly property real min: r.limiti ? r.limiti[0] : 0
            readonly property real max: r.limiti ? r.limiti[1] : 1
            property real mostrato: r.valore ?? min          // segue il dito mentre trascini
            property bool trascina: false
            Binding on mostrato { when: !nr.trascina; value: r.valore ?? nr.min }
            function da(x) {
                const v = min + Math.max(0, Math.min(1, x / guida.width)) * (max - min);
                return r.tipo === "intero" ? Math.round(v) : Math.round(v * 100) / 100;
            }
            Item {
                id: guida
                anchors.verticalCenter: parent.verticalCenter
                width: 280; height: 24
                readonly property real quota: (nr.mostrato - nr.min) / Math.max(0.0001, nr.max - nr.min)
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width; height: 6; radius: 3; color: Qt.rgba(1, 1, 1, 0.1)
                    Rectangle { width: parent.width * guida.quota; height: parent.height; radius: 3
                                color: r.valore === null ? Tema.tenue : Tema.oro }
                }
                Rectangle {
                    x: guida.width * guida.quota - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16; height: 16; radius: 8; color: Tema.oroChiaro
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onPressed: m => { nr.trascina = true; nr.mostrato = nr.da(m.x); }
                    onPositionChanged: m => { if (pressed) nr.mostrato = nr.da(m.x); }
                    onReleased: m => { nr.trascina = false; r.imposta(nr.da(m.x)); }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: r.valore === null && !nr.trascina ? "come Hyprland"
                    : r.tipo === "numero" ? Math.round(nr.mostrato * 100) + "%" : String(nr.mostrato)
                color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13
            }
        }
    }

    Component {
        id: vero
        Rectangle {
            width: 50; height: 28; radius: 14
            color: r.valore ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.85) : Qt.rgba(1, 1, 1, 0.12)
            Behavior on color { ColorAnimation { duration: Tema.durata } }
            Rectangle {
                width: 22; height: 22; radius: 11
                anchors.verticalCenter: parent.verticalCenter
                x: r.valore ? parent.width - width - 3 : 3
                color: r.valore ? Tema.fondo : Tema.testo
                Behavior on x { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: r.imposta(r.valore ? "no" : "sì") }
        }
    }

    Component {
        id: scelta
        Flow {
            width: r.width
            spacing: 8
            Repeater {
                model: r.limiti ?? []
                Chip { required property string modelData; testo: modelData; acceso: r.valore === modelData
                       onPremuto: r.imposta(modelData) }
            }
        }
    }

    Component {
        id: tasti
        Row {
            spacing: 10
            Rectangle {
                width: Math.max(170, etichetta.implicitWidth + 24); height: 32; radius: 8
                color: r.inCattura ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.2) : Qt.rgba(1, 1, 1, 0.05)
                border.color: r.inCattura ? Tema.oro : Tema.bordo
                Text {
                    id: etichetta
                    anchors.centerIn: parent
                    text: r.inCattura ? "Premi la combinazione…" : (r.valore || "nessuna")
                    color: r.valore || r.inCattura ? Tema.testo : Tema.tenue
                    font.family: r.inCattura ? Tema.font : "monospace"; font.pixelSize: 13
                }
            }
            Chip { testo: r.inCattura ? "annulla" : "cambia"; icona: "keyboard"
                   onPremuto: r.inCattura ? r.imposta(r.valore || "nessuno") : r.cattura() }
        }
    }

    Component {
        id: carattere
        Row {
            spacing: 12
            Campo {
                width: 220
                testo: r.valore ?? ""
                suggerimento: r.tipo === "font" ? "nome del font" : "nome del programma"
                onInvio: t => r.imposta(t)
            }
            Text {
                visible: r.tipo === "font"
                anchors.verticalCenter: parent.verticalCenter
                text: "Ciao, sono Ciel"
                color: Tema.tenue; font.family: r.valore ?? Tema.font; font.pixelSize: 15
            }
        }
    }

    // lo sfondo: «nessuno» o una delle immagini in ~/Immagini/Wallpapers (miniature), o un percorso qualsiasi
    Component {
        id: immagine
        Column {
            width: r.width
            spacing: 8
            Row {
                spacing: 8
                Chip { testo: "nessuno"; icona: "block"; acceso: !r.valore; onPremuto: r.imposta("nessuno") }
                Campo {
                    width: 330
                    testo: r.valore ?? ""
                    suggerimento: "percorso di un'immagine"
                    onInvio: t => r.imposta(t)
                }
            }
            Flow {
                width: parent.width
                spacing: 8
                Repeater {
                    model: FolderListModel {
                        folder: "file://" + Quickshell.env("HOME") + "/Immagini/Wallpapers"
                        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
                        showDirs: false
                    }
                    Rectangle {
                        required property string filePath
                        width: 120; height: 68; radius: 8
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.width: r.valore === filePath ? 2 : 1
                        border.color: r.valore === filePath ? Tema.oro : Tema.bordo
                        clip: true
                        Image {
                            anchors.fill: parent; anchors.margins: 2
                            source: "file://" + parent.filePath
                            sourceSize: Qt.size(240, 136)          // miniature piccole: poca memoria
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: r.imposta(parent.filePath) }
                    }
                }
            }
        }
    }
}
