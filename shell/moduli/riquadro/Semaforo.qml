// Il pallino della stima: verde (gira bene), giallo (gira, ma lento), rosso (non ci sta o troppo lento).
import QtQuick
import qs.servizi

Rectangle {
    property string colore: "giallo"
    width: 10; height: 10; radius: 5
    color: colore === "verde" ? "#5fd38a" : colore === "rosso" ? Tema.allarme : "#f2c14e"
}
