// Le icone delle app in background (Steam, Discord…): clic per aprirle, clic destro per il loro menu.
// Mouse sopra: il nome dell'app e cosa dice di sé.
// Le icone «Ayatana» (Steam, molte app GTK/Electron) non sanno «aprirsi» (non hanno il metodo Activate): per loro
// il clic apre l'app dal suo .desktop (le app del vassoio sono a istanza singola: torna su la finestra che c'è),
// o il menu se il .desktop non c'è. Chi sa aprirsi e chi no lo chiede una volta a D-Bus, quando cambiano le icone
// (chi non si lascia esaminare, come Electron, si prova ad aprire normalmente).
import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Services.SystemTray
import qs.servizi

Column {
    id: v
    required property var finestra
    spacing: 6
    property var senzaApri: ({})         // id → true se l'icona non sa aprirsi
    readonly property var voci: SystemTray.items.values.filter(i => i.status !== Status.Passive)
    onVociChanged: if (!chiedi.running) chiedi.running = true

    Process {
        id: chiedi
        command: ["sh", "-c",
            "busctl --user get-property org.kde.StatusNotifierWatcher /StatusNotifierWatcher org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems " +
            "| grep -o '\"[^\"]*\"' | tr -d '\"' | while read x; do s=${x%%/*}; p=/${x#*/}; [ \"$p\" = \"/$x\" ] && p=/StatusNotifierItem; " +
            "id=$(busctl --user get-property \"$s\" \"$p\" org.kde.StatusNotifierItem Id 2>/dev/null | sed 's/^s \"//; s/\"$//'); " +
            "m=$(busctl --user introspect \"$s\" \"$p\" org.kde.StatusNotifierItem 2>/dev/null | grep method); " +
            "[ -n \"$m\" ] && ! echo \"$m\" | grep -q '^\\.Activate ' && echo \"$id\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = {};
                text.split("\n").filter(x => x).forEach(x => m[x] = true);
                v.senzaApri = m;
            }
        }
    }

    function apri(item, finestra, voce) {
        if (v.senzaApri[item.id]) {
            const e = DesktopEntries.heuristicLookup(item.id);
            if (e) { e.execute(); return; }
            if (item.hasMenu) { const p = voce.mapToItem(null, voce.width + 8, 0); item.display(finestra, p.x, p.y); }
            return;
        }
        item.activate();
    }

    Repeater {
        model: v.voci
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
                    v.apri(modelData, v.finestra, voce);
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
