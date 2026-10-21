// Il disegno in miniatura di un layout di Hyprland: tre rettangoli che si spostano con calma quando il layout
// cambia. Serve alla schedina dell'icona nella barra: si vede subito come si dividerà lo schermo.
import QtQuick
import qs.servizi

Item {
    id: a
    property string tipo: "dwindle"          // dwindle, master, scrolling
    property bool acceso: false
    property color colore: acceso ? Tema.oro : Tema.tenue
    readonly property real colonna: (a.width - 14) / 3
    implicitWidth: 54
    implicitHeight: 38

    Rectangle {                              // la finestra grande (o la prima colonna)
        x: 1; y: 1
        width: a.tipo === "scrolling" ? a.colonna : a.tipo === "master" ? a.width * 0.52 : a.width * 0.6
        height: a.height - 2
        radius: 3
        color: a.colore
        opacity: 0.9
        Behavior on width { NumberAnimation { duration: Tema.durata * 1.5; easing.type: Easing.OutCubic } }
    }
    Rectangle {                              // la seconda
        x: a.tipo === "scrolling" ? a.colonna + 6 : a.tipo === "master" ? a.width * 0.52 + 5 : a.width * 0.6 + 5
        y: 1
        width: a.tipo === "scrolling" ? a.colonna : a.tipo === "master" ? a.width * 0.48 - 5 : a.width * 0.4 - 6
        height: a.tipo === "master" ? (a.height - 8) / 2 : a.height - 2
        radius: 3
        color: a.colore
        opacity: 0.62
        Behavior on x { NumberAnimation { duration: Tema.durata * 1.5; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: Tema.durata * 1.5; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: Tema.durata * 1.5; easing.type: Easing.OutCubic } }
    }
    Rectangle {                              // la terza: solo per master e scrolling
        visible: a.tipo !== "dwindle"
        x: a.tipo === "scrolling" ? 2 * (a.colonna + 6) : a.width * 0.52 + 5
        y: a.tipo === "master" ? (a.height - 8) / 2 + 5 : 1
        width: a.tipo === "scrolling" ? a.colonna : a.width * 0.48 - 5
        height: a.tipo === "master" ? (a.height - 8) / 2 : a.height - 2
        radius: 3
        color: a.colore
        opacity: 0.4
        Behavior on x { NumberAnimation { duration: Tema.durata * 1.5; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: Tema.durata * 1.5; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: Tema.durata * 1.5; easing.type: Easing.OutCubic } }
    }
}
