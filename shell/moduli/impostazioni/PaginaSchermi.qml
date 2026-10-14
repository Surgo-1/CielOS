// Impostazioni → Schermi: per ogni schermo risoluzione e frequenza (tutte quelle che dichiara), scala, rotazione,
// posizione rispetto agli altri, specchio, spento; frequenza variabile (VRR: FreeSync, G-Sync compatibile,
// Adaptive Sync), colori a 10 bit, HDR. Ogni cambio si prova subito: se non confermi entro 15 s torna com'era
// (uno schermo nero o una frequenza sbagliata non ti lasciano mai bloccato).
import QtQuick
import qs.servizi

Column {
    id: p
    width: parent ? parent.width : 500
    spacing: 14
    property int prova: 0                    // secondi alla fine della prova (0 = nessuna prova in corso)
    readonly property var schermi: Impostati.stato?.schermi ?? []
    readonly property var scelte: Impostati.stato?.scelte?.schermi ?? ({})

    function cambia(nome, kv) {
        Impostati.fai(["schermo", nome, ...kv], r => { if (r.ok !== false) p.prova = 15; });
    }
    Timer { running: p.prova > 0; interval: 1000; repeat: true
            onTriggered: { p.prova--; if (p.prova === 0) Impostati.fai(["schermo-annulla"]); } }

    Text {
        width: parent.width; wrapMode: Text.Wrap
        text: "Ogni cambio si vede subito. Se lo schermo resta nero o non ti piace, non toccare niente: dopo 15 secondi torna com'era."
        color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
    }

    // la prova in corso: tieni o torna indietro
    Rectangle {
        visible: p.prova > 0
        width: parent.width; height: 54; radius: Tema.raggio
        color: Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.15); border.color: Tema.oro
        Text { anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
               text: "Va bene così? Torno indietro tra " + p.prova + " s"; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14 }
        Row {
            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            spacing: 8
            Chip { testo: "Tieni"; icona: "check"; acceso: true; onPremuto: p.prova = 0 }
            Chip { testo: "Torna indietro"; icona: "undo"; onPremuto: { p.prova = 0; Impostati.fai(["schermo-annulla"]); } }
        }
    }

    Text {
        visible: p.schermi.length === 0
        text: Impostati.stato ? "Nessuno schermo trovato (Hyprland non risponde?)" : "Leggo gli schermi…"
        color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13
    }

    Repeater {
        model: p.schermi
        Rectangle {
            id: sc
            required property var modelData
            readonly property var s: modelData
            readonly property var mio: p.scelte[s.nome] ?? ({})
            readonly property var altri: p.schermi.filter(x => x.nome !== s.nome)
            width: p.width
            height: col.implicitHeight + 28
            radius: Tema.raggio
            color: Qt.rgba(1, 1, 1, 0.03); border.color: Tema.bordo
            Column {
                id: col
                x: 16; y: 14; width: parent.width - 32
                spacing: 12
                Row {
                    spacing: 10
                    Text { text: "monitor"; font.family: Tema.icone; font.pixelSize: 24; color: Tema.oroChiaro }
                    Column {
                        Text { text: sc.s.nome + (sc.s.spento ? " (spento)" : ""); color: Tema.testo; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.Medium }
                        Text { text: [sc.s.marca, sc.s.modello].filter(x => x).join(" ") + " · " + sc.s.l + "×" + sc.s.a + " a " + Math.round(sc.s.hz) + " Hz, scala " + sc.s.scala
                               color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12 }
                    }
                }
                Tendina {
                    width: parent.width
                    testo: "Risoluzione e frequenza"
                    voci: sc.s.modi
                    valore: sc.s.modi.find(m => m.l === sc.s.l && m.a === sc.s.a && Math.abs(m.hz - sc.s.hz) < 0.6)?.valore ?? ""
                    onScelto: v => p.cambia(sc.s.nome, ["mode=" + v])
                }
                Column {
                    spacing: 6; width: parent.width
                    Text { text: "Scala (testi e finestre più grandi)"; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14 }
                    Flow {
                        width: parent.width; spacing: 6
                        Repeater {
                            model: [1, 1.25, 1.5, 1.75, 2, 2.5, 3]
                            Chip { required property real modelData
                                   testo: String(modelData).replace(".", ",") + "×"; acceso: Math.abs(sc.s.scala - modelData) < 0.01
                                   onPremuto: p.cambia(sc.s.nome, ["scale=" + modelData]) }
                        }
                    }
                }
                Column {
                    spacing: 6; width: parent.width
                    Text { text: "Rotazione"; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14 }
                    Flow {
                        width: parent.width; spacing: 6
                        Repeater {
                            model: [[0, "normale"], [1, "90°"], [2, "180°"], [3, "270°"], [4, "specchiato"]]
                            Chip { required property var modelData
                                   testo: modelData[1]; acceso: sc.s.rotazione === modelData[0]
                                   onPremuto: p.cambia(sc.s.nome, ["transform=" + modelData[0]]) }
                        }
                    }
                }
                Column {
                    visible: sc.altri.length > 0
                    spacing: 6; width: parent.width
                    Text { text: "Posizione"; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14 }
                    Flow {
                        width: parent.width; spacing: 6
                        Repeater {
                            model: sc.altri
                            Row {
                                required property var modelData
                                spacing: 6
                                readonly property real lw: sc.s.l / sc.s.scala
                                readonly property real lh: sc.s.a / sc.s.scala
                                readonly property real ow: modelData.l / modelData.scala
                                readonly property real oh: modelData.a / modelData.scala
                                Chip { testo: "a sinistra di " + modelData.nome
                                       onPremuto: p.cambia(sc.s.nome, ["position=" + Math.round(modelData.x - parent.lw) + "x" + modelData.y]) }
                                Chip { testo: "a destra di " + modelData.nome
                                       onPremuto: p.cambia(sc.s.nome, ["position=" + Math.round(modelData.x + parent.ow) + "x" + modelData.y]) }
                                Chip { testo: "sopra"
                                       onPremuto: p.cambia(sc.s.nome, ["position=" + modelData.x + "x" + Math.round(modelData.y - parent.lh)]) }
                                Chip { testo: "sotto"
                                       onPremuto: p.cambia(sc.s.nome, ["position=" + modelData.x + "x" + Math.round(modelData.y + parent.oh)]) }
                            }
                        }
                    }
                }
                Column {
                    spacing: 6; width: parent.width
                    Text { text: "Frequenza variabile (VRR: FreeSync, G-Sync compatibile, Adaptive Sync)"; width: parent.width; wrapMode: Text.Wrap
                           color: Tema.testo; font.family: Tema.font; font.pixelSize: 14 }
                    Text { text: "Toglie lo «strappo» delle immagini nei giochi senza il ritardo del V-Sync. «Solo a schermo intero» è la scelta più sicura: sul desktop alcuni schermi sfarfallano."
                           width: parent.width; wrapMode: Text.Wrap; color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12 }
                    Flow {
                        width: parent.width; spacing: 6
                        Repeater {
                            model: [[0, "spenta"], [2, "solo a schermo intero"], [1, "sempre"]]
                            Chip { required property var modelData
                                   testo: modelData[1]; acceso: (sc.mio.vrr ?? (sc.s.vrr ? 1 : 0)) === modelData[0]
                                   onPremuto: p.cambia(sc.s.nome, ["vrr=" + modelData[0]]) }
                        }
                    }
                }
                Interruttore {
                    width: parent.width
                    testo: "Colori a 10 bit"
                    spiega: "Sfumature più morbide, se lo schermo e il cavo li reggono (DisplayPort o HDMI 2.0 e oltre)."
                    acceso: (sc.mio.bitdepth ?? sc.s.bitdepth) === 10
                    onCambiato: v => p.cambia(sc.s.nome, ["bitdepth=" + (v ? 10 : 8)])
                }
                Interruttore {
                    width: parent.width
                    testo: "HDR"
                    spiega: "Per schermi HDR: più luminosità e contrasto nei giochi e nei video che lo supportano. Ancora giovane su Linux: se i colori sembrano spenti, toglilo."
                    acceso: (sc.mio.cm ?? (sc.s.hdr ? "hdr" : "srgb")) === "hdr"
                    onCambiato: v => p.cambia(sc.s.nome, ["cm=" + (v ? "hdr" : "srgb")] .concat(v && (sc.mio.bitdepth ?? sc.s.bitdepth) !== 10 ? ["bitdepth=10"] : []))
                }
                Tendina {
                    visible: sc.altri.length > 0
                    width: parent.width
                    testo: "Specchio (mostra lo stesso di un altro schermo)"
                    voci: [{ testo: "no", valore: "" }].concat(sc.altri.map(o => ({ testo: "come " + o.nome, valore: o.nome })))
                    valore: sc.mio.mirror ?? ""
                    onScelto: v => p.cambia(sc.s.nome, ["mirror=" + v])
                }
                Interruttore {
                    visible: sc.altri.length > 0
                    width: parent.width
                    testo: "Spento"
                    spiega: "Lo schermo resta collegato ma CielOS non lo usa."
                    acceso: sc.mio.disabled === true
                    onCambiato: v => p.cambia(sc.s.nome, ["disabled=" + (v ? 1 : 0)])
                }
            }
        }
    }
}
