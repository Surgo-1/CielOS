// Una voce dei menu (quello delle app del vassoio): icona, testo, spunta o freccia del sottomenu.
import QtQuick
import Quickshell.Widgets
import qs.servizi

Rectangle {
    id: m
    property string testo
    property string iconaUrl            // un'icona dell'app (immagine)…
    property string iconaFont           // …o una Material Symbol
    property bool attiva: true
    property bool spunta: false         // è una casella da spuntare
    property bool spuntata: false
    property bool sotto: false          // apre un sottomenu
    signal premuto()
    width: parent ? parent.width : 220
    height: 32
    radius: Tema.raggio / 1.5
    color: tocco.containsMouse && attiva ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.16) : "transparent"
    Behavior on color { ColorAnimation { duration: Tema.durata } }
    opacity: attiva ? 1 : 0.4

    Row {
        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
        spacing: 10
        Item {
            width: 18; height: 18
            anchors.verticalCenter: parent.verticalCenter
            Text {
                anchors.centerIn: parent
                visible: m.spunta || m.iconaFont !== ""
                text: m.spunta ? (m.spuntata ? "check_box" : "check_box_outline_blank") : m.iconaFont
                font.family: Tema.icone; font.pixelSize: 18; color: Tema.oroChiaro
            }
            IconImage {
                anchors.fill: parent
                visible: !m.spunta && m.iconaFont === "" && m.iconaUrl !== ""
                source: m.iconaUrl
                asynchronous: true
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: m.width - 70
            text: m.testo; elide: Text.ElideRight
            color: Tema.testo; font.family: Tema.font; font.pixelSize: 13
        }
    }
    Text {
        visible: m.sotto
        anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
        text: "chevron_right"; font.family: Tema.icone; font.pixelSize: 18; color: Tema.tenue
    }
    MouseArea {
        id: tocco
        anchors.fill: parent
        hoverEnabled: true
        enabled: m.attiva
        cursorShape: Qt.PointingHandCursor
        onClicked: m.premuto()
    }
}
