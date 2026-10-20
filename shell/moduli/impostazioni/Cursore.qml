// Un cursore da trascinare (min..max, passo), con il valore scritto accanto; manda il valore quando lo lasci.
import QtQuick
import qs.servizi

Item {
    id: c
    property string testo
    property real min: 0
    property real max: 100
    property real passo: 1
    property real valore: 0
    property string unita: ""
    property int decimali: 0
    signal cambiato(real v)
    width: parent ? parent.width : 400
    height: 54
    property real mostrato: valore
    property bool trascina: false
    Binding on mostrato { when: !c.trascina && !attesa.running; value: c.valore }
    // lasciato il cursore resta dov'è finché arriva il valore nuovo (o 3 s): rimettere subito «trascina» a false
    // riportava il valore vecchio, e prima lo mandava pure (gli slider di Tastiera e mouse tornavano indietro: 15/10)
    onValoreChanged: if (attesa.running) { attesa.stop(); c.trascina = false; }
    Timer { id: attesa; interval: 3000; onTriggered: c.trascina = false }
    function da(x) {
        const v = min + Math.max(0, Math.min(1, x / guida.width)) * (max - min);
        return Math.round(v / passo) * passo;
    }
    Text {
        text: c.testo; color: Tema.testo; font.family: Tema.font
        font.pixelSize: 14; font.weight: Font.Medium
    }
    Rectangle {
        anchors { right: parent.right; top: parent.top }
        width: val.implicitWidth + 16; height: 22; radius: 11
        color: Tema.accentoSoft; border.width: 1; border.color: Tema.bordoTenue
        Text {
            id: val
            anchors.centerIn: parent
            text: c.mostrato.toFixed(c.decimali).replace(".", Lingua.virgola) + c.unita
            color: Tema.oroChiaro; font.family: Tema.font; font.pixelSize: 12; font.weight: Font.Medium
        }
    }
    Item {
        id: guida
        x: 8; y: 27; width: parent.width - 16; height: 26      // margine: il pallino agli estremi non viene tagliato
        readonly property real quota: (c.mostrato - c.min) / Math.max(1e-9, c.max - c.min)
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: 7; radius: 3.5
            color: Tema.conAlfa(Tema.testo, 0.08)
            border.width: 1; border.color: Tema.bordoTenue
            Rectangle {
                width: parent.width * guida.quota; height: parent.height; radius: 3.5
                color: Tema.oro
                Behavior on width { NumberAnimation { duration: 90 } }
            }
        }
        Rectangle {
            x: guida.width * guida.quota - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: c.trascina ? 24 : 20; height: width; radius: width / 2
            color: Tema.conAlfa(Tema.oro, 0.18)
            Behavior on width { NumberAnimation { duration: 120 } }
        }
        Rectangle {
            x: guida.width * guida.quota - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 14; height: 14; radius: 7
            color: Tema.testo
            border.width: 2; border.color: Tema.oro
        }
        MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onPressed: m => { attesa.stop(); c.trascina = true; c.mostrato = c.da(m.x); }
            onPositionChanged: m => { if (pressed) c.mostrato = c.da(m.x); }
            onReleased: m => {
                const v = c.da(m.x);
                c.mostrato = v; c.cambiato(v); attesa.restart();   // resta finché arriva il valore (o 3 s)
            }
            onCanceled: { c.trascina = false; attesa.stop(); }
        }
    }
}
