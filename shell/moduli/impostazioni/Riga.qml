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
    // la riga che dice cosa fa il valore scelto (dettagli del preset), se lo schema ne ha
    readonly property string testoDettaglio: {
        const d = info?.dettagli;
        return d && valore !== undefined && d[String(valore)] ? Lingua.t(d[String(valore)]) : "";
    }
    spacing: 9

    readonly property var campioni: ["#ffbf3f", "#ff9a6b", "#ff5a5a", "#ff8ac2", "#b18cff", "#5b8cff", "#7fd0ff",
                                     "#6fd08c", "#8fd694", "#eef2ff", "#9aa0ae", "#0b1029", "#0a0a0f", "#f4efe6"]

    Item {
        id: testata
        width: parent.width; height: 26
        readonly property bool booleano: r.tipo === "vero"
        readonly property bool acceso: r.valore === true || r.valore === "true" || r.valore === 1
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - (testata.booleano ? 160 : 110)
            elide: Text.ElideRight
            text: (r.info?.titolo ?? r.info?.cosa ?? r.chiave).charAt(0).toUpperCase() + (r.info?.titolo ?? r.info?.cosa ?? r.chiave).slice(1)
            color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.Medium
        }
        Rectangle {                          // interruttore: sui booleani sta qui, accanto al titolo
            id: inter
            visible: testata.booleano
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: 46; height: 26; radius: 13
            color: testata.acceso ? Tema.oro : Tema.conAlfa(Tema.testo, 0.13)
            border.width: 1
            border.color: testata.acceso ? Tema.oroChiaro : Tema.bordoTenue
            Behavior on color { ColorAnimation { duration: Tema.durata } }
            Behavior on border.color { ColorAnimation { duration: Tema.durata } }
            Rectangle {
                width: 18; height: 18; radius: 9; y: 3
                x: testata.acceso ? parent.width - width - 3 : 3
                color: testata.acceso ? Tema.fondo : Tema.testo
                Behavior on x { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: r.imposta(testata.acceso ? "false" : "true") }
        }
        Rectangle {                          // torna al valore di serie
            visible: r.cambiata
            anchors { right: inter.visible ? inter.left : parent.right; rightMargin: inter.visible ? 10 : 0
                      verticalCenter: parent.verticalCenter }
            width: ds.implicitWidth + 16; height: 20; radius: 10
            color: dsTocco.containsMouse ? Tema.accentoSoft : "transparent"
            border.width: 1; border.color: dsTocco.containsMouse ? Tema.alfa(Tema.oro, 0.3) : Tema.bordoTenue
            Text {
                id: ds
                anchors.centerIn: parent
                text: Lingua.t("↺ di serie")
                color: dsTocco.containsMouse ? Tema.oroChiaro : Tema.tenue; font.family: Tema.font; font.pixelSize: 12
            }
            MouseArea { id: dsTocco; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor; onClicked: r.togli() }
        }
    }

    Loader {                             // senza larghezza: ogni controllo ha la sua
        sourceComponent: r.tipo === "colore" || r.tipo === "colore_o_accento" ? colore
                       : r.tipo === "intero" || r.tipo === "numero" ? numero
                       : r.tipo === "vero" ? null
                       : r.tipo === "scelta" ? scelta
                       : r.tipo === "tasti" ? tasti
                       : r.tipo === "font" || r.tipo === "programma" ? carattere
                       : r.tipo === "immagine" ? immagine : null
    }

    Text {                               // cosa cambia il valore scelto (es. i preset: «pixel = squadrato, niente…»)
        visible: !!testoDettaglio
        width: parent.width
        wrapMode: Text.WordWrap
        text: r.testoDettaglio
        color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
    }

    Rectangle { width: parent.width; height: 1; color: Tema.bordoTenue }

    // un campo di testo che manda il valore con Invio
    component Campo: Rectangle {
        id: cm
        property alias testo: inp.text
        property string suggerimento
        signal invio(string t)
        height: 34; radius: Tema.raggioPiccolo + 6
        color: Tema.conAlfa(Tema.testo, 0.05)
        border.width: 1
        border.color: inp.activeFocus ? Tema.alfa(Tema.oro, 0.7) : Tema.bordoTenue
        Behavior on border.color { ColorAnimation { duration: Tema.durata } }
        TextInput {
            id: inp
            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
            verticalAlignment: TextInput.AlignVCenter
            color: Tema.testo; font.family: Tema.font; font.pixelSize: 13
            selectByMouse: true
            clip: true
            selectionColor: Tema.accentoForte
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
            spacing: 9
            Row {
                spacing: 10
                Rectangle {
                    width: 34; height: 34; radius: 17
                    color: r.valore === "accento" ? Tema.oro : (r.valore || "transparent")
                    border.width: r.valore ? 1 : 2
                    border.color: r.valore ? Tema.alfa(Tema.testo, 0.45) : Tema.bordoTenue
                }
                Campo {
                    width: 140
                    testo: r.valore && r.valore !== "accento" ? r.valore : ""
                    suggerimento: r.valore === "accento" ? Lingua.t("come l'accento") : Lingua.t("di serie")
                    onInvio: t => r.imposta(t)
                }
                Chip {
                    visible: r.tipo === "colore_o_accento"
                    testo: Lingua.t("come l'accento"); acceso: r.valore === "accento"
                    onPremuto: r.imposta("accento")
                }
            }
            Flow {
                width: parent.width
                spacing: 7
                Repeater {
                    model: r.campioni
                    Rectangle {
                        required property string modelData
                        width: 26; height: 26; radius: 13
                        color: modelData
                        border.width: r.valore === modelData ? 2.5 : 1
                        border.color: r.valore === modelData ? Tema.testo : Qt.rgba(1, 1, 1, 0.16)
                        scale: cTocco.containsMouse ? 1.14 : 1
                        Behavior on scale { NumberAnimation { duration: 100 } }
                        Text {
                            anchors.centerIn: parent
                            visible: r.valore === modelData
                            text: "check"; font.family: Tema.icone; font.pixelSize: 15
                            color: "#0b1029"
                        }
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
            leftPadding: 8                                   // il pallino a zero esce di mezzo: senza, lo taglia il bordo
            readonly property real min: r.limiti ? r.limiti[0] : 0
            readonly property real max: r.limiti ? r.limiti[1] : 1
            property var esterno: r.valore
            property real mostrato: r.valore ?? min          // segue il dito mentre trascini
            property bool trascina: false
            onEsternoChanged: if (mantieni.running) mantieni.stop()
            Binding on mostrato { when: !nr.trascina && !mantieni.running; value: nr.esterno ?? nr.min }
            Timer { id: mantieni; interval: 2500; onTriggered: nr.mostrato = nr.esterno ?? nr.min }
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
                    width: parent.width; height: 7; radius: 3.5
                    color: Tema.conAlfa(Tema.testo, 0.08)
                    border.width: 1; border.color: Tema.bordoTenue
                    Rectangle { width: parent.width * guida.quota; height: parent.height; radius: 3.5
                                color: r.valore === null ? Tema.tenue : Tema.oro }
                }
                Rectangle {                            // l'alone del cursore
                    x: guida.width * guida.quota - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22; height: 22; radius: 11
                    color: Tema.conAlfa(Tema.oro, nr.trascina ? 0.28 : 0.13)
                }
                Rectangle {
                    x: guida.width * guida.quota - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 15; height: 15; radius: 7.5
                    color: Tema.oroChiaro
                    border.width: 2; border.color: Tema.oro
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onPressed: m => { nr.trascina = true; mantieni.stop(); nr.mostrato = nr.da(m.x); }
                    onPositionChanged: m => { if (pressed) nr.mostrato = nr.da(m.x); }
                    onReleased: m => {
                        const v = nr.da(m.x);
                        nr.mostrato = v; nr.trascina = false; r.imposta(v); mantieni.restart();
                    }
                    onCanceled: { nr.trascina = false; mantieni.stop(); }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 92
                text: r.valore === null && !nr.trascina ? Lingua.t("come Hyprland")
                    : r.tipo === "numero" ? Math.round(nr.mostrato * 100) + "%" : String(nr.mostrato)
                color: Tema.oroChiaro; font.family: Tema.font; font.pixelSize: 13; font.weight: Font.Medium
            }
        }
    }

    Component {
        id: vero
        Rectangle {
            width: 52; height: 30; radius: 15
            color: r.valore ? Tema.oro : Tema.conAlfa(Tema.testo, 0.10)
            border.width: 1
            border.color: r.valore ? Tema.oroChiaro : Tema.bordoTenue
            Behavior on color { ColorAnimation { duration: Tema.durata } }
            Behavior on border.color { ColorAnimation { duration: Tema.durata } }
            Rectangle {
                width: 24; height: 24; radius: 12
                anchors.verticalCenter: parent.verticalCenter
                x: r.valore ? parent.width - width - 3 : 3
                color: r.valore ? Tema.fondo : Tema.testo
                Behavior on x { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
            }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: r.imposta(r.valore ? "false" : "true")
            }
        }
    }

    Component {
        id: scelta
        Flow {
            width: r.width
            spacing: 8
            Repeater {
                model: r.limiti ?? []
                Chip { required property string modelData; testo: Lingua.t(modelData); acceso: r.valore === modelData
                       onPremuto: r.imposta(modelData) }
            }
        }
    }

    Component {
        id: tasti
        Row {
            spacing: 10
            Rectangle {
                width: Math.max(180, etichetta.implicitWidth + 24); height: 34; radius: Tema.raggioPiccolo + 6
                color: r.inCattura ? Tema.accentoMedio : Tema.conAlfa(Tema.testo, 0.05)
                border.width: 1
                border.color: r.inCattura ? Tema.oro : Tema.bordoTenue
                Text {
                    id: etichetta
                    anchors.centerIn: parent
                    text: r.inCattura ? Lingua.t("Premi la combinazione…") : (r.valore || Lingua.t("nessuna"))
                    color: r.valore || r.inCattura ? Tema.testo : Tema.tenue
                    font.family: r.inCattura ? Tema.font : "monospace"; font.pixelSize: 13
                }
            }
            Chip { testo: r.inCattura ? Lingua.t("annulla") : Lingua.t("cambia"); icona: "keyboard"
                   onPremuto: r.inCattura ? r.imposta(r.valore || "nessuno") : r.cattura() }
        }
    }

    Component {
        id: carattere
        Row {
            spacing: 12
            Campo {
                width: 230
                testo: r.valore ?? ""
                suggerimento: r.tipo === "font" ? Lingua.t("nome del font") : Lingua.t("nome del programma")
                onInvio: t => r.imposta(t)
            }
            Text {
                visible: r.tipo === "font"
                anchors.verticalCenter: parent.verticalCenter
                text: Lingua.t("Ciao, sono Ciel")
                color: Tema.tenue; font.family: r.valore ?? Tema.font; font.pixelSize: 15
            }
        }
    }

    // lo sfondo: «nessuno» o una delle immagini in ~/Immagini/Wallpapers (miniature), o un percorso qualsiasi
    Component {
        id: immagine
        Column {
            width: r.width
            spacing: 9
            Row {
                spacing: 8
                Chip { testo: Lingua.t("nessuno"); icona: "block"; acceso: !r.valore; onPremuto: r.imposta("nessuno") }
                Campo {
                    width: 340
                    testo: r.valore ?? ""
                    suggerimento: Lingua.t("percorso di un'immagine")
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
                        width: 128; height: 72; radius: Tema.raggioPiccolo + 2
                        color: Tema.conAlfa(Tema.testo, 0.05)
                        border.width: r.valore === filePath ? 2 : 1
                        border.color: r.valore === filePath ? Tema.oro : Tema.bordoTenue
                        clip: true
                        Image {
                            anchors.fill: parent; anchors.margins: 2
                            source: parent.filePath.startsWith("file:") ? parent.filePath : "file://" + encodeURI(parent.filePath)
                            sourceSize: Qt.size(256, 144)          // miniature piccole: poca memoria
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
