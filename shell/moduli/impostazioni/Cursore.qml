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
    height: 50
    property real mostrato: valore
    property bool trascina: false
    Binding on mostrato { when: !c.trascina; value: c.valore }
    // lasciato il cursore resta dov'è finché arriva il valore nuovo (o 3 s): rimettere subito «trascina» a false
    // riportava il valore vecchio, e prima lo mandava pure (gli slider di Tastiera e mouse tornavano indietro: 15/10)
    onValoreChanged: if (attesa.running) { attesa.stop(); trascina = false; }
    Timer { id: attesa; interval: 3000; onTriggered: c.trascina = false }
    function da(x) {
        const v = min + Math.max(0, Math.min(1, x / guida.width)) * (max - min);
        return Math.round(v / passo) * passo;
    }
    Text { text: c.testo; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14 }
    Text { anchors.right: parent.right; text: c.mostrato.toFixed(c.decimali).replace(".", Lingua.virgola) + c.unita
           color: Tema.oroChiaro; font.family: Tema.font; font.pixelSize: 13 }
    Item {
        id: guida
        x: 8; y: 24; width: parent.width - 16; height: 24      // margine: il pallino agli estremi non viene tagliato
        readonly property real quota: (c.mostrato - c.min) / Math.max(1e-9, c.max - c.min)
        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 6; radius: 3; color: Qt.rgba(1, 1, 1, 0.1)
            Rectangle { width: parent.width * guida.quota; height: parent.height; radius: 3; color: Tema.oro } }
        Rectangle { x: guida.width * guida.quota - 8; anchors.verticalCenter: parent.verticalCenter
                    width: 16; height: 16; radius: 8; color: Tema.testo; border.color: Tema.oro; border.width: 2 }
        MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onPressed: m => { attesa.stop(); c.trascina = true; c.mostrato = c.da(m.x); }
            onPositionChanged: m => { if (pressed) c.mostrato = c.da(m.x); }
            onReleased: m => { const v = c.da(m.x); c.mostrato = v; c.cambiato(v); attesa.restart(); }
        }
    }
}
