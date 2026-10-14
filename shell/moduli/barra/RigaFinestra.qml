// Una finestra nella schedina di un workspace: icona dell'app e titolo. Clic: ci vai; clic destro: la porti nel
// workspace che guardi (se non è già lì); clic centrale: la chiudi.
import QtQuick
import Quickshell
import qs.servizi

Rectangle {
    id: r
    required property var finestra
    property bool diQui: false
    signal vai()
    signal porta()
    signal chiudi()
    readonly property string classe: finestra?.lastIpcObject?.class ?? finestra?.wayland?.appId ?? ""
    width: parent ? parent.width : 280
    height: 34; radius: 17
    color: tocco.containsMouse || finestra?.activated ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.22)
                                                      : Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.08)
    border.color: finestra?.urgent ? Tema.allarme : Tema.bordo
    Behavior on color { ColorAnimation { duration: Tema.durata } }
    Row {
        anchors.left: parent.left; anchors.leftMargin: 12
        anchors.right: parent.right; anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        Image {
            id: ic
            anchors.verticalCenter: parent.verticalCenter
            readonly property var voce: r.classe ? DesktopEntries.heuristicLookup(r.classe) : null
            source: r.classe ? Quickshell.iconPath(voce?.icon || r.classe.toLowerCase(), true) : ""
            visible: source != ""
            sourceSize.width: 18; sourceSize.height: 18
            width: 18; height: 18
        }
        Text {
            visible: !ic.visible
            anchors.verticalCenter: parent.verticalCenter
            text: "web_asset"; font.family: Tema.icone; font.pixelSize: 17; color: Tema.oroChiaro
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 26
            elide: Text.ElideRight
            text: r.finestra?.title || r.classe
            color: Tema.testo; font.family: Tema.font; font.pixelSize: 13
        }
    }
    MouseArea {
        id: tocco
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: m => {
            if (m.button === Qt.MiddleButton) r.chiudi();
            else if (m.button === Qt.RightButton) { if (!r.diQui) r.porta(); }
            else r.vai();
        }
    }
}
