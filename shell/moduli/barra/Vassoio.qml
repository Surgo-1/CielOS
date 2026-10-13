// Le icone delle app in background (Steam, Discord…): clic per aprirle, clic destro per il loro menu.
import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs.servizi

Column {
    id: v
    required property var finestra
    spacing: 6

    Repeater {
        model: SystemTray.items.values.filter(i => i.status !== Status.Passive)
        MouseArea {
            id: voce
            required property SystemTrayItem modelData
            width: 22; height: 22
            anchors.horizontalCenter: parent.horizontalCenter
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton && modelData.hasMenu) {
                    const p = voce.mapToItem(null, voce.width + 8, 0);
                    modelData.display(v.finestra, p.x, p.y);
                } else if (mouse.button === Qt.LeftButton && !modelData.onlyMenu) {
                    modelData.activate();
                } else if (modelData.hasMenu) {
                    const p = voce.mapToItem(null, voce.width + 8, 0);
                    modelData.display(v.finestra, p.x, p.y);
                }
            }
            IconImage {
                anchors.fill: parent
                source: voce.modelData.icon
                asynchronous: true
            }
        }
    }
}
