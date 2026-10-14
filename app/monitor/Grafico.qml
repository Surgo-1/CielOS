// Un grafico piccolo: gli ultimi valori (0..massimo) come area sfumata con la linea sopra. Ridisegna solo quando
// arrivano valori nuovi.
import QtQuick
import qs.servizi

Canvas {
    id: g
    property var valori: []
    property real massimo: 100
    property color colore: Tema.oro
    property int punti: 60
    onValoriChanged: requestPaint()
    onColoreChanged: requestPaint()
    onPaint: {
        const c = getContext("2d");
        c.reset();
        if (valori.length < 2) return;
        const w = width, h = height, n = punti - 1;
        const x = i => w - (valori.length - 1 - i) * w / n;
        const y = v => h - Math.max(0, Math.min(1, v / Math.max(1e-9, massimo))) * (h - 2) - 1;
        c.beginPath();
        c.moveTo(x(0), h);
        for (let i = 0; i < valori.length; i++) c.lineTo(x(i), y(valori[i]));
        c.lineTo(w, h);
        c.closePath();
        const sf = c.createLinearGradient(0, 0, 0, h);
        sf.addColorStop(0, Qt.rgba(colore.r, colore.g, colore.b, 0.35));
        sf.addColorStop(1, Qt.rgba(colore.r, colore.g, colore.b, 0.02));
        c.fillStyle = sf;
        c.fill();
        c.beginPath();
        for (let i = 0; i < valori.length; i++) i ? c.lineTo(x(i), y(valori[i])) : c.moveTo(x(i), y(valori[i]));
        c.strokeStyle = colore;
        c.lineWidth = 2;
        c.stroke();
    }
}
