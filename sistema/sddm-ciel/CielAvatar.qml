// Il cerchio magico: alone, raggi, due anelli di simboli che ruotano in versi opposti, esagramma e nucleo.
// idle: rotazione lenta e respiro | ascolto: più luminoso | pensa: gira veloce e scintilla | parla: pulsa con la voce
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

Item {
    id: av

    property color colore: "#ffbf3f"
    property string stato: "idle"
    property real livello: 0
    property string umore: "sereno"     // allegra, irritata, stanca, annoiata, curiosa, orgogliosa
    property bool sonno: false          // di notte o quando sei via: gira pianissimo e si affievolisce
    property point occhio: Qt.point(0, 0)   // verso il cursore: il nucleo "guarda" lì
    property bool sopra: false          // il mouse è sul nucleo
    property real musica: 0             // volume della musica della DJ: gli anelli pulsano a tempo
    // versione leggera (le menti staccate, quando sono tante): niente bagliore sfocato, raggi e anello di codice
    // (a quella misura non si leggono), rune senza scintillio. Ogni sfocatura ridisegnata a ogni fotogramma costa
    property bool leggero: false
    property string simbolo: ""         // il simbolo della mente (un'icona di Material Symbols) al centro del nucleo
    Behavior on musica { NumberAnimation { duration: 70 } }

    readonly property real s: Math.min(width, height)
    readonly property real cx: width / 2
    readonly property real cy: height / 2

    // ---------------------------------------------------------------- movimento
    property real t: 0                  // secondi dall'avvio
    property real angolo: 0             // gradi, integrati fotogramma per fotogramma: cambiare velocità non dà scatti
    readonly property real fattoreUmore: ({ "allegra": 1.35, "irritata": 1.9, "stanca": 0.5, "annoiata": 0.6,
                                            "curiosa": 1.15, "orgogliosa": 1.1 })[umore] || 1
    property real velocita: (stato === "pensa" ? 55 : stato === "ascolto" ? 14 : stato === "parla" ? 16 : 5)
                            * fattoreUmore * (sonno ? 0.25 : 1)
    Behavior on velocita { NumberAnimation { duration: 900; easing.type: Easing.InOutQuad } }

    property real voce: livello         // volume della voce, ammorbidito
    Behavior on voce { NumberAnimation { duration: 90 } }

    // (leggera: niente respiro, così cerchi e nucleo non si ridisegnano a ogni fotogramma)
    readonly property real respiro: leggero ? 0.5 : 0.5 + 0.5 * Math.sin(t * 2 * Math.PI / (sonno ? 9 : 4.5))
    readonly property real scintilla: stato === "pensa" ? 0.5 + 0.5 * Math.sin(t * 11) : 0
    property real energia: stato === "parla" ? 0.65 + 0.35 * voce
                         : stato === "pensa" ? 0.55 + 0.25 * scintilla
                         : stato === "ascolto" ? 0.75
                         : (sonno ? 0.18 + 0.12 * respiro : 0.35 + 0.15 * respiro)
                           * (umore === "stanca" ? 0.75 : umore === "allegra" || umore === "orgogliosa" ? 1.2 : 1)
                           + (sopra ? 0.25 : 0) + 0.45 * musica
    Behavior on energia { NumberAnimation { duration: 250 } }

    FrameAnimation {
        running: av.visible && av.opacity > 0
        onTriggered: {
            av.t += frameTime;
            if (!av.leggero)                 // leggera: i cerchi interni restano fermi, gira tutta insieme (sotto)
                av.angolo = (av.angolo + frameTime * av.velocita) % 360000;
            // irritata: un leggero tremolio
            av.tremolio = av.umore === "irritata" && !av.sonno ? (Math.random() - 0.5) * 2.2 : av.tremolio * 0.8;
        }
    }

    property real tremolio: 0
    property real ox: occhio.x * s * 0.045       // quanto il nucleo si sposta verso il cursore
    property real oy: occhio.y * s * 0.045
    Behavior on ox { NumberAnimation { duration: 350; easing.type: Easing.OutQuad } }
    Behavior on oy { NumberAnimation { duration: 350; easing.type: Easing.OutQuad } }

    function conAlfa(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }

    // lampo del nucleo quando una mente rientra portando la risposta
    property real flash: 0
    function lampo() { animLampo.restart(); }
    NumberAnimation { id: animLampo; target: av; property: "flash"; from: 1; to: 0; duration: 650; easing.type: Easing.OutCubic }

    // ---------------------------------------------------------------- bagliore (copia sfocata sotto la scena)
    MultiEffect {
        visible: !av.leggero
        source: scena
        anchors.fill: scena
        blurEnabled: true
        blurMax: 48
        blur: 1.0
        brightness: 0.25
        opacity: 0.45 + 0.55 * av.energia
    }

    Item {
        id: scena
        anchors.fill: parent
        rotation: av.leggero ? (av.t * av.velocita * 0.6) % 360 : av.tremolio
        scale: 1 + 0.07 * av.musica
        // leggera: tutta la scena diventa un'immagine sola, che gira (si ridisegna solo se cambia: colore, voce)
        layer.enabled: av.leggero
        layer.smooth: true

        // alone
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: av.cx; centerY: av.cy; focalX: av.cx; focalY: av.cy
                    centerRadius: av.s * 0.5
                    GradientStop { position: 0.0; color: av.conAlfa(av.colore, 0.55 * av.energia) }
                    GradientStop { position: 0.35; color: av.conAlfa(av.colore, 0.16 * av.energia) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
                PathAngleArc { centerX: av.cx; centerY: av.cy; radiusX: av.s * 0.5; radiusY: av.s * 0.5; startAngle: 0; sweepAngle: 360 }
            }
        }

        // raggi
        Repeater {
            model: av.leggero ? 0 : 30
            Rectangle {
                required property int index
                readonly property real caso: (Math.sin(index * 12.9898) * 43758.5453) % 1       // casuale ma fisso
                readonly property real lunghezza: av.s * 0.5 * (0.55 + 0.45 * Math.abs(caso)) * (1 + 0.25 * av.voce)
                width: 1.4
                height: lunghezza
                x: av.cx - width / 2
                y: av.cy - height
                antialiasing: true
                opacity: (0.25 + 0.75 * Math.abs(Math.sin(av.t * (0.6 + Math.abs(caso)) + index))) * av.energia
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.45; color: av.conAlfa(av.colore, 0.8) }
                    GradientStop { position: 0.75; color: "transparent" }
                }
                transform: Rotation { origin.x: 0.7; origin.y: height; angle: index * 12 + av.angolo * 0.25 }
            }
        }

        // anello esterno tratteggiato
        Shape {
            anchors.fill: parent
            rotation: av.angolo * 0.5
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: av.conAlfa(av.colore, 0.85)
                strokeWidth: 1.6
                fillColor: "transparent"
                strokeStyle: ShapePath.DashLine
                dashPattern: [5, 3]
                PathAngleArc { centerX: av.cx; centerY: av.cy; radiusX: av.s * 0.445; radiusY: av.s * 0.445; startAngle: 0; sweepAngle: 360 }
            }
        }

        // anelli pieni
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: av.conAlfa(av.colore, 0.9); strokeWidth: 1.3; fillColor: "transparent"
                PathAngleArc { centerX: av.cx; centerY: av.cy; radiusX: av.s * 0.405; radiusY: av.s * 0.405; startAngle: 0; sweepAngle: 360 }
            }
            ShapePath {
                strokeColor: av.conAlfa(av.colore, 0.7); strokeWidth: 1.1; fillColor: "transparent"
                PathAngleArc { centerX: av.cx; centerY: av.cy; radiusX: av.s * 0.33; radiusY: av.s * 0.33; startAngle: 0; sweepAngle: 360 }
            }
            ShapePath {
                strokeColor: av.conAlfa(av.colore, 0.55); strokeWidth: 1.0; fillColor: "transparent"
                PathAngleArc { centerX: av.cx; centerY: av.cy; radiusX: av.s * 0.235; radiusY: av.s * 0.235; startAngle: 0; sweepAngle: 360 }
            }
        }

        // anello di rune (ruota in un verso)
        Item {
            anchors.fill: parent
            rotation: -av.angolo * 0.8
            Repeater {
                model: 24
                Text {
                    required property int index
                    readonly property real a: index / 24 * 2 * Math.PI
                    text: "ᚠᚢᚦᚨᚱᚲᚷᚹᚺᚾᛁᛃᛇᛈᛉᛊᛏᛒᛖᛗᛚᛜᛞᛟ".charAt(index)
                    font.family: "Noto Sans Runic"
                    font.pixelSize: av.s * 0.058
                    color: av.colore
                    opacity: av.leggero ? 0.85 : 0.75 + 0.25 * Math.sin(av.t * 2 + index)
                    x: av.cx + Math.cos(a) * av.s * 0.367 - width / 2
                    y: av.cy + Math.sin(a) * av.s * 0.367 - height / 2
                    rotation: a * 180 / Math.PI + 90
                }
            }
        }

        // anello di codice (ruota nell'altro verso)
        Item {
            anchors.fill: parent
            transform: Translate { x: av.ox * 0.35; y: av.oy * 0.35 }
            rotation: av.angolo * 1.3
            Repeater {
                model: av.leggero ? 0 : 36
                Text {
                    required property int index
                    readonly property real a: index / 36 * 2 * Math.PI
                    text: "CIEL·7F3A·SIEL·01·9C0E·10·B4D2·ANALISI·".charAt(index)
                    font.family: "monospace"
                    font.pixelSize: av.s * 0.04
                    font.bold: true
                    color: av.colore
                    opacity: 0.6
                    x: av.cx + Math.cos(a) * av.s * 0.283 - width / 2
                    y: av.cy + Math.sin(a) * av.s * 0.283 - height / 2
                    rotation: a * 180 / Math.PI + 90
                }
            }
        }

        // esagramma
        Shape {
            anchors.fill: parent
            transform: Translate { x: av.ox * 0.55; y: av.oy * 0.55 }
            rotation: -av.angolo * 0.2
            preferredRendererType: Shape.CurveRenderer
            opacity: 0.5 + 0.4 * av.energia
            ShapePath {
                id: triangolo1
                readonly property real r: av.s * 0.225
                readonly property real o: -Math.PI / 2
                strokeColor: av.conAlfa(av.colore, 0.7); strokeWidth: 1.0; fillColor: "transparent"
                startX: av.cx + Math.cos(triangolo1.o) * triangolo1.r; startY: av.cy + Math.sin(triangolo1.o) * triangolo1.r
                PathLine { x: av.cx + Math.cos(triangolo1.o + 2.0944) * triangolo1.r; y: av.cy + Math.sin(triangolo1.o + 2.0944) * triangolo1.r }
                PathLine { x: av.cx + Math.cos(triangolo1.o + 4.1888) * triangolo1.r; y: av.cy + Math.sin(triangolo1.o + 4.1888) * triangolo1.r }
                PathLine { x: av.cx + Math.cos(triangolo1.o) * triangolo1.r; y: av.cy + Math.sin(triangolo1.o) * triangolo1.r }
            }
            ShapePath {
                id: triangolo2
                readonly property real r: av.s * 0.225
                readonly property real o: Math.PI / 2
                strokeColor: av.conAlfa(av.colore, 0.7); strokeWidth: 1.0; fillColor: "transparent"
                startX: av.cx + Math.cos(triangolo2.o) * triangolo2.r; startY: av.cy + Math.sin(triangolo2.o) * triangolo2.r
                PathLine { x: av.cx + Math.cos(triangolo2.o + 2.0944) * triangolo2.r; y: av.cy + Math.sin(triangolo2.o + 2.0944) * triangolo2.r }
                PathLine { x: av.cx + Math.cos(triangolo2.o + 4.1888) * triangolo2.r; y: av.cy + Math.sin(triangolo2.o + 4.1888) * triangolo2.r }
                PathLine { x: av.cx + Math.cos(triangolo2.o) * triangolo2.r; y: av.cy + Math.sin(triangolo2.o) * triangolo2.r }
            }
        }

        // nucleo: respira a riposo, pulsa con la voce
        Shape {
            id: nucleo
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            transform: Translate { x: av.ox; y: av.oy }
            readonly property real r: av.s * 0.15 * (1 + 0.08 * av.respiro + 0.6 * av.voce + 0.15 * av.scintilla
                                                     + (av.umore === "orgogliosa" ? 0.1 : 0) + (av.sopra ? 0.12 : 0)
                                                     + 0.5 * av.flash)
            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: av.cx; centerY: av.cy; focalX: av.cx; focalY: av.cy
                    centerRadius: nucleo.r
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.95) }
                    GradientStop { position: 0.25; color: Qt.lighter(av.colore, 1.4) }
                    GradientStop { position: 0.6; color: av.conAlfa(av.colore, 0.5) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
                PathAngleArc { centerX: av.cx; centerY: av.cy; radiusX: nucleo.r; radiusY: nucleo.r; startAngle: 0; sweepAngle: 360 }
            }
        }
    }

    // il simbolo della mente, scuro sul nucleo chiaro (cambia con una dissolvenza)
    Text {
        id: segno
        property string mostrato: av.simbolo
        text: mostrato
        visible: mostrato !== ""
        font.family: "Material Symbols Rounded"
        font.pixelSize: Math.max(10, av.s * 0.15)
        color: Qt.rgba(0.08, 0.06, 0.12, 0.82)
        x: av.cx - width / 2 + av.ox
        y: av.cy - height / 2 + av.oy
        scale: 1 + 0.4 * av.voce + 0.3 * av.flash
        opacity: 0.85
        Behavior on opacity { NumberAnimation { duration: 220 } }
    }
    onSimboloChanged: cambioSegno.restart()
    SequentialAnimation {
        id: cambioSegno
        NumberAnimation { target: segno; property: "opacity"; to: 0; duration: 200 }
        ScriptAction { script: segno.mostrato = av.simbolo }
        NumberAnimation { target: segno; property: "opacity"; to: 0.85; duration: 300 }
    }

    // dorme: tre "z" che salgono e svaniscono
    Repeater {
        model: 3
        Text {
            required property int index
            readonly property real fase: ((av.t / 3.2) + index / 3) % 1
            visible: av.sonno
            text: "z"
            font.family: "Noto Serif Display"
            font.italic: true
            font.pixelSize: av.s * (0.07 + 0.05 * fase)
            color: av.colore
            opacity: Math.sin(fase * Math.PI) * 0.8
            x: av.cx + av.s * (0.12 + 0.18 * fase)
            y: av.cy - av.s * (0.12 + 0.3 * fase)
        }
    }
}
