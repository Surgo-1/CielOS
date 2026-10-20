// Un grafico piccolo: gli ultimi valori (0..massimo) come area sfumata con la linea sopra. Ridisegna solo quando
// arrivano valori nuovi. La linea ha un alone leggero: si legge anche sopra le superfici più chiare.
import QtQuick
import qs.servizi

Canvas {
    id: g
    property var valori: []
    property real massimo: 100
    property color colore: Tema.oro
    property bool griglia: true
    property int punti: 60
    onValoriChanged: requestPaint()
    onColoreChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const c = getContext("2d");
        c.reset();
        if (width <= 0 || height <= 0 || valori.length < 2) return;
        const w = width, h = height, n = Math.max(1, punti - 1);
        const x = i => w - (valori.length - 1 - i) * w / n;
        const y = v => h - Math.max(0, Math.min(1, v / Math.max(1e-9, massimo))) * (h - 2) - 1;

        // la riga di metà: un riferimento discreto, non un reticolo
        if (griglia) {
            c.beginPath();
            c.moveTo(0, h - 0.5);
            c.lineTo(w, h - 0.5);
            c.strokeStyle = Tema.alfa(Tema.testo, 0.06);
            c.lineWidth = 1;
            c.stroke();
        }

        c.beginPath();
        c.moveTo(x(0), h);
        for (let i = 0; i < valori.length; i++) c.lineTo(x(i), y(valori[i]));
        c.lineTo(w, h);
        c.closePath();
        const sf = c.createLinearGradient(0, 0, 0, h);
        sf.addColorStop(0, Tema.alfa(colore, 0.32));
        sf.addColorStop(1, Tema.alfa(colore, 0.01));
        c.fillStyle = sf;
        c.fill();

        c.beginPath();
        for (let i = 0; i < valori.length; i++) i ? c.lineTo(x(i), y(valori[i])) : c.moveTo(x(i), y(valori[i]));
        c.strokeStyle = Tema.alfa(colore, 0.20);
        c.lineWidth = 6;
        c.lineCap = "round";
        c.lineJoin = "round";
        c.stroke();

        c.beginPath();
        for (let i = 0; i < valori.length; i++) i ? c.lineTo(x(i), y(valori[i])) : c.moveTo(x(i), y(valori[i]));
        c.strokeStyle = colore;
        c.lineWidth = 2;
        c.lineJoin = "round";
        c.stroke();
    }
}
