// Le icone delle app in background (Steam, Discord…): clic per aprirle, clic destro per il loro menu.
// Mouse sopra: il nome dell'app e cosa dice di sé.
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
            readonly property bool sopra: containsMouse
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                scheda.aperta = false;
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
            Schedina {
                id: scheda
                icona: voce
                larghezza: 240
                titolo: voce.modelData.tooltipTitle || voce.modelData.title || voce.modelData.id
                Text {
                    readonly property string d: (voce.modelData.tooltipDescription || "").replace(/<[^>]*>/g, "")
                    visible: d !== ""
                    width: parent.width
                    text: d
                    wrapMode: Text.WordWrap; maximumLineCount: 4; elide: Text.ElideRight
                    color: Tema.testo; font.family: Tema.font; font.pixelSize: 13
                }
                Text {
                    text: voce.modelData.onlyMenu ? "Clic: il suo menu" : "Clic: aprila · destro: il suo menu"
                    color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
                }
            }
        }
    }
}
