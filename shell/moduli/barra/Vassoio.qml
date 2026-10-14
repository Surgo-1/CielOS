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

Grid {
    id: v
    columns: Tema.orizzontale ? 20 : 1
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter
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

    // true se l'ha aperta; false se per lei c'è solo il menu
    function apri(item) {
        if (v.senzaApri[item.id]) {
            const e = DesktopEntries.heuristicLookup(item.id);
            if (e) { Avvia.app(e); return true; }
            return false;
        }
        item.activate();
        return true;
    }

    Repeater {
        model: v.voci
        MouseArea {
            id: voce
            required property SystemTrayItem modelData
            width: 22; height: 22
            readonly property bool sopra: containsMouse
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor

            function menu() {
                if (!modelData.hasMenu) return;
                scheda.livelli = [];
                scheda.menu = true;
                scheda.aperta = true;
            }
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton || modelData.onlyMenu) { scheda.menu && scheda.aperta ? scheda.aperta = false : menu(); return; }
                scheda.aperta = false;
                if (!v.apri(modelData)) menu();
            }
            IconImage {
                anchors.fill: parent
                source: voce.modelData.icon
                asynchronous: true
            }
            QsMenuOpener {
                id: apriMenu
                menu: scheda.livelli.length ? scheda.livelli[scheda.livelli.length - 1] : voce.modelData.menu
            }
            Schedina {
                id: scheda
                icona: voce
                larghezza: 260
                property bool menu: false        // false: chi è (mouse sopra); true: il suo menu (clic destro)
                property var livelli: []         // i sottomenu aperti, uno dentro l'altro
                attesa: menu ? 600 : 200
                spaziatura: menu ? 2 : 10
                onApertaChanged: if (!aperta) menu = false
                Component.onCompleted: if (vetrina) menu = true      // in vetrina: il menu, da guardare
                titolo: menu ? "" : (voce.modelData.tooltipTitle || voce.modelData.title || voce.modelData.id)

                // chi è
                Text {
                    readonly property string d: (voce.modelData.tooltipDescription || "").replace(/<[^>]*>/g, "")
                    visible: !scheda.menu && d !== ""
                    width: parent.width
                    text: d
                    wrapMode: Text.WordWrap; maximumLineCount: 4; elide: Text.ElideRight
                    color: Tema.testo; font.family: Tema.font; font.pixelSize: 13
                }
                Text {
                    visible: !scheda.menu
                    text: voce.modelData.onlyMenu ? "Clic: il suo menu" : "Clic: aprila · destro: il suo menu"
                    color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
                }

                // il menu
                VoceMenu {
                    visible: scheda.menu && scheda.livelli.length > 0
                    testo: "Indietro"; iconaFont: "chevron_left"
                    onPremuto: scheda.livelli = scheda.livelli.slice(0, -1)
                }
                Repeater {
                    model: scheda.menu ? apriMenu.children : null
                    Item {
                        id: riga
                        required property QsMenuEntry modelData
                        width: parent.width
                        height: modelData.isSeparator ? 9 : vm.height
                        Rectangle {
                            visible: riga.modelData.isSeparator
                            anchors.verticalCenter: parent.verticalCenter
                            x: 6; width: parent.width - 12; height: 1
                            color: Tema.bordo
                        }
                        VoceMenu {
                            id: vm
                            visible: !riga.modelData.isSeparator
                            width: parent.width
                            testo: riga.modelData.text.replace(/_(?=\S)/g, "")
                            iconaUrl: riga.modelData.icon
                            attiva: riga.modelData.enabled
                            spunta: riga.modelData.buttonType !== QsMenuButtonType.None
                            spuntata: riga.modelData.checkState === Qt.Checked
                            sotto: riga.modelData.hasChildren
                            onPremuto: {
                                if (riga.modelData.hasChildren) { scheda.livelli = [...scheda.livelli, riga.modelData]; return; }
                                riga.modelData.triggered();
                                scheda.aperta = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
