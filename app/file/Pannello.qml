// Un riquadro di file (uno, o due affiancati nella vista divisa): la cartella, a griglia con le anteprime o a
// dettagli, la selezione (clic, Ctrl+clic, Maiusc+clic, Ctrl+A), il trascinamento (sposta; con Ctrl copia; anche
// da e verso altri programmi), il rinomina sul posto (F2), la ricerca nella cartella o in tutte le sottocartelle.
// Le operazioni le fa la finestra (shell.qml) con cielfile: qui solo cosa hai scelto.
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import qs.servizi
import "Icone.js" as I

FocusScope {
    id: p
    required property var gestore                // la finestra: appunti, operazioni, menu, impostazioni di vista
    property string percorso: Quickshell.env("HOME")
    property var storia: [percorso]
    property int pos: 0
    property var scelti: ({})                    // percorso → true
    property int ultimo: -1                      // per Maiusc+clic
    property string rinomina: ""                 // il file che si sta rinominando
    property string ricerca: ""
    property bool profonda: false                // la ricerca guarda anche nelle sottocartelle
    property bool ovunque: false                 // la ricerca guarda in tutto il computer (cielfile cerca-ovunque)
    property bool cercandoOvunque: false
    property bool parziale: false
    property var risultati: []
    property bool attivo: false                  // il riquadro con la tastiera (nella vista divisa)
    readonly property bool cestino: percorso === "cestino:"
    readonly property var elenco: cestino ? app.cestino : (profonda || ovunque) && ricerca ? risultati : null
    readonly property int quanti: elenco ? elenco.length : cartella.count
    readonly property var selezione: Object.keys(scelti)
    signal cambiato()

    function vai(d, nuovo) {
        if (d === percorso) return;
        if (nuovo !== false) { storia = storia.slice(0, pos + 1).concat([d]); pos = storia.length - 1; }
        percorso = d; scelti = ({}); ultimo = -1; rinomina = ""; ricerca = ""; profonda = false; ovunque = false;
        if (d === "cestino:") app.leggiCestino();
        cambiato();
    }
    function indietro() { if (pos > 0) { pos--; vai(storia[pos], false); } }
    function avanti() { if (pos < storia.length - 1) { pos++; vai(storia[pos], false); } }
    function su() { if (!cestino && percorso !== "/") vai(percorso.replace(/\/[^\/]+\/?$/, "") || "/"); }
    function voce(i) {
        if (elenco) {
            const e = elenco[i];
            return e ? (cestino ? { nome: e.nome, percorso: e.uri, cartella: e.cartella, dimensione: e.dimensione, data: null, da: e.da }
                                : { nome: e.split("/").pop(), percorso: e, cartella: false, dimensione: 0, data: null, da: e.slice(0, e.lastIndexOf("/")) }) : null;
        }
        if (i < 0 || i >= cartella.count) return null;
        return { nome: cartella.get(i, "fileName"), percorso: cartella.get(i, "filePath"), cartella: cartella.get(i, "fileIsDir"),
                 dimensione: cartella.get(i, "fileSize"), data: cartella.get(i, "fileModified") };
    }
    function apri(v) {
        if (!v) return;
        if (cestino) return;
        if (v.cartella) vai(v.percorso);
        else app.apriFile(v.percorso);
    }
    function scegli(i, mod) {
        const v = voce(i);
        if (!v) return;
        let s = Object.assign({}, scelti);
        if (mod & Qt.ShiftModifier && ultimo >= 0) {
            if (!(mod & Qt.ControlModifier)) s = {};
            for (let k = Math.min(ultimo, i); k <= Math.max(ultimo, i); k++) s[voce(k).percorso] = true;
        } else if (mod & Qt.ControlModifier) {
            if (s[v.percorso]) delete s[v.percorso]; else s[v.percorso] = true;
            ultimo = i;
        } else {
            s = {}; s[v.percorso] = true; ultimo = i;
        }
        scelti = s;
        vista.currentIndex = i;
    }
    function tutti() { const s = {}; for (let k = 0; k < quanti; k++) s[voce(k).percorso] = true; scelti = s; }
    function cerca() {
        if (ovunque && ricerca.trim()) app.cercaOvunque(p, ricerca.trim());
        else if (profonda && ricerca.trim()) app.cerca(p, percorso, ricerca.trim());
    }

    // ogni cambiamento della cartella (anche un rinomina, che non cambia il numero di file) ridisegna le voci
    property int versione: 0
    Connections {
        target: cartella
        function onDataChanged() { p.versione++; }
        function onRowsInserted() { p.versione++; }
        function onRowsRemoved() { p.versione++; }
        function onModelReset() { p.versione++; }
        function onLayoutChanged() { p.versione++; }
    }
    FolderListModel {
        id: cartella
        folder: p.cestino ? "" : "file://" + p.percorso
        showDirsFirst: true
        showDotAndDotDot: false
        showHidden: p.gestore.nascosti
        caseSensitive: false
        nameFilters: p.ricerca && !p.profonda ? ["*" + p.ricerca + "*"] : []
        sortField: ({ nome: FolderListModel.Name, data: FolderListModel.Time, dimensione: FolderListModel.Size, tipo: FolderListModel.Type })[p.gestore.ordina]
        sortReversed: p.gestore.inverti
        sortCaseSensitive: false
    }

    // la tastiera del riquadro
    Keys.onPressed: e => {
        if (p.rinomina) return;
        const ctrl = e.modifiers & Qt.ControlModifier, alt = e.modifiers & Qt.AltModifier, shift = e.modifiers & Qt.ShiftModifier;
        const k = e.key;
        if (k === Qt.Key_Return || k === Qt.Key_Enter) { p.apri(p.voce(vista.currentIndex)); }
        else if (k === Qt.Key_Backspace || (alt && k === Qt.Key_Up)) p.su();
        else if (alt && k === Qt.Key_Left) p.indietro();
        else if (alt && k === Qt.Key_Right) p.avanti();
        else if (k === Qt.Key_F2 && p.selezione.length === 1) p.rinomina = p.selezione[0];
        else if (k === Qt.Key_Delete) p.gestore.cancella(p.selezione, shift || p.cestino);
        else if (ctrl && k === Qt.Key_A) p.tutti();
        else if (ctrl && k === Qt.Key_C) p.gestore.copia(p.selezione, false);
        else if (ctrl && k === Qt.Key_X) p.gestore.copia(p.selezione, true);
        else if (ctrl && k === Qt.Key_V) p.gestore.incolla(p.percorso);
        else if (ctrl && shift && k === Qt.Key_N) p.gestore.nuovaCartella(p);
        else if (k === Qt.Key_Escape) {           // prima toglie quello che c'è da togliere, poi chiude la finestra
            if (p.gestore.menuDi) p.gestore.menuDi = null;
            else if (p.gestore.apriCon) p.gestore.apriCon = null;
            else if (p.gestore.proprieta) p.gestore.proprieta = null;
            else if (Object.keys(p.scelti).length || p.ricerca || p.profonda || p.ovunque) { p.scelti = ({}); p.ricerca = ""; p.profonda = false; p.ovunque = false; }
            else Qt.quit();
        }
        else if (k === Qt.Key_Up || k === Qt.Key_Down || k === Qt.Key_Left || k === Qt.Key_Right) {
            const passo = p.gestore.vista === "griglia" ? Math.max(1, Math.floor(vista.width / vista.cellWidth)) : 1;
            let i = vista.currentIndex < 0 ? 0 : vista.currentIndex;
            if (k === Qt.Key_Down) i += passo; else if (k === Qt.Key_Up) i -= passo;
            else if (k === Qt.Key_Right && p.gestore.vista === "griglia") i += 1; else if (k === Qt.Key_Left && p.gestore.vista === "griglia") i -= 1;
            i = Math.max(0, Math.min(p.quanti - 1, i));
            p.scegli(i, shift ? Qt.ShiftModifier : 0);
            vista.positionViewAtIndex(i, GridView.Contain);
        } else return;
        e.accepted = true;
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: p.gestore.diviso && p.attivo ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.35) : "transparent"
        radius: Tema.raggio
    }

    // la barra del riquadro: indietro, avanti, su, il percorso (cliccabile, o da scrivere), la ricerca
    Item {
        id: barra
        x: 8; y: 8; width: parent.width - 16; height: 38
        Row {
            id: frecce
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Repeater {
                model: [["arrow_back", () => p.indietro(), p.pos > 0], ["arrow_forward", () => p.avanti(), p.pos < p.storia.length - 1],
                        ["arrow_upward", () => p.su(), !p.cestino && p.percorso !== "/"]]
                Text {
                    required property var modelData
                    width: 30; height: 30; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    text: modelData[0]; font.family: Tema.icone; font.pixelSize: 20
                    color: modelData[2] ? (fm.containsMouse ? Tema.oro : Tema.testo) : Qt.rgba(1, 1, 1, 0.2)
                    MouseArea { id: fm; anchors.fill: parent; hoverEnabled: true; enabled: modelData[2]; onClicked: modelData[1]() }
                }
            }
        }
        Rectangle {
            id: briciole
            anchors { left: frecce.right; leftMargin: 8; right: ovunqueB.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
            height: 34; radius: 17
            color: Qt.rgba(1, 1, 1, 0.05); border.color: scrivi.activeFocus ? Tema.oro : Tema.bordo
            property bool scrivendo: false
            clip: true
            ListView {
                visible: !briciole.scrivendo
                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                orientation: ListView.Horizontal
                interactive: false
                spacing: 0
                model: p.cestino ? ["Cestino"] : ["/"].concat(p.percorso.split("/").filter(x => x))
                onCountChanged: positionViewAtEnd()
                delegate: Row {
                    required property string modelData
                    required property int index
                    height: 34
                    Text { visible: index > 1; text: "chevron_right"; font.family: Tema.icone; font.pixelSize: 16; color: Tema.tenue
                           anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: index === 0 && !p.cestino ? "computer" : (modelData === Quickshell.env("USER") && index === 2 ? "Casa" : modelData)
                        font.family: index === 0 && !p.cestino ? Tema.icone : Tema.font
                        font.pixelSize: index === 0 && !p.cestino ? 17 : 13
                        color: bc.containsMouse ? Tema.oro : Tema.testo
                        leftPadding: 3; rightPadding: 3
                        MouseArea {
                            id: bc; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: if (!p.cestino) p.vai("/" + p.percorso.split("/").filter(x => x).slice(0, index).join("/"))
                        }
                    }
                }
            }
            MouseArea {                          // clic nello spazio vuoto: scrivi il percorso (anche Ctrl+L)
                anchors.fill: parent; z: -1
                onClicked: { briciole.scrivendo = true; scrivi.text = p.cestino ? "" : p.percorso; scrivi.forceActiveFocus(); scrivi.selectAll(); }
            }
            TextInput {
                id: scrivi
                visible: briciole.scrivendo
                anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                verticalAlignment: TextInput.AlignVCenter
                color: Tema.testo; font.family: Tema.font; font.pixelSize: 13; selectByMouse: true; clip: true
                function conferma() { const d = text.replace(/^~/, Quickshell.env("HOME")); briciole.scrivendo = false; p.forceActiveFocus(); p.vai(d.replace(/\/$/, "") || "/"); }
                Keys.onReturnPressed: e => { e.accepted = true; conferma(); }
                Keys.onEnterPressed: e => { e.accepted = true; conferma(); }
                onActiveFocusChanged: if (!activeFocus) briciole.scrivendo = false
                Keys.onEscapePressed: { briciole.scrivendo = false; p.forceActiveFocus(); }
            }
        }
        Rectangle {                              // «Cerca in tutto il computer» (stretto: solo l'icona)
            id: ovunqueB
            readonly property bool corto: barra.width < 760
            anchors { right: cercaBox.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
            width: (corto ? 0 : etO.implicitWidth + 8) + 40; height: 34; radius: 17
            color: p.ovunque ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.22) : (moO.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.05))
            border.color: p.ovunque ? Tema.oro : Tema.bordo
            Row {
                anchors.centerIn: parent; spacing: 6
                Text { text: "travel_explore"; font.family: Tema.icone; font.pixelSize: 18; color: p.ovunque ? Tema.oro : Tema.tenue
                       anchors.verticalCenter: parent.verticalCenter }
                Text { id: etO; visible: !ovunqueB.corto; text: "Cerca in tutto il computer"; color: p.ovunque ? Tema.testo : Tema.tenue
                       font.family: Tema.font; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea {
                id: moO; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: { p.ovunque = !p.ovunque; if (p.ovunque) p.profonda = false; cercaIn.forceActiveFocus(); p.cerca(); }
            }
        }
        Rectangle {
            id: cercaBox
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: cercaIn.activeFocus || p.ricerca ? 260 : 150; height: 34; radius: 17
            Behavior on width { NumberAnimation { duration: Tema.durata } }
            color: Qt.rgba(1, 1, 1, 0.05); border.color: cercaIn.activeFocus ? Tema.oro : Tema.bordo
            Text { id: lente; x: 10; anchors.verticalCenter: parent.verticalCenter; text: "search"; font.family: Tema.icone; font.pixelSize: 18; color: Tema.tenue }
            TextInput {
                id: cercaIn
                anchors { left: lente.right; leftMargin: 6; right: prof.left; rightMargin: 4; verticalCenter: parent.verticalCenter }
                color: Tema.testo; font.family: Tema.font; font.pixelSize: 13; clip: true; selectByMouse: true
                text: p.ricerca
                onTextEdited: { p.ricerca = text; if (p.profonda || p.ovunque) ritarda.restart(); }
                Keys.onReturnPressed: e => { e.accepted = true; p.cerca(); }
                Keys.onEnterPressed: e => { e.accepted = true; p.cerca(); }
                Keys.onEscapePressed: { p.ricerca = ""; p.profonda = false; p.ovunque = false; p.forceActiveFocus(); }
                Text { visible: !parent.text && !parent.activeFocus; text: p.ovunque ? "Cerca ovunque" : "Cerca"; color: Tema.tenue; font: parent.font }
            }
            Timer { id: ritarda; interval: p.ovunque ? 600 : 400; onTriggered: p.cerca() }
            Text {
                id: prof
                anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                visible: (cercaIn.activeFocus || p.ricerca) && !p.ovunque
                text: "account_tree"; font.family: Tema.icone; font.pixelSize: 18
                color: p.profonda ? Tema.oro : Tema.tenue
                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor
                            onClicked: { p.profonda = !p.profonda; p.cerca(); } }
            }
        }
    }
    Text {
        visible: (p.profonda || p.ovunque) && p.ricerca !== ""
        x: 18; y: barra.y + barra.height + 2
        text: p.ovunque ? (p.cercandoOvunque ? "Cerco «" + p.ricerca + "» in tutto il computer…"
                           : "«" + p.ricerca + "» in tutto il computer: " + p.risultati.length + " trovati" +
                             (p.parziale ? " (i dischi lenti non li ho letti tutti)" : ""))
              : "Cerco «" + p.ricerca + "» anche nelle sottocartelle: " + p.risultati.length + " trovati"
        color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
    }

    // il contenuto
    DropArea {
        id: zona
        anchors { left: parent.left; right: parent.right; top: barra.bottom; bottom: parent.bottom; topMargin: (p.profonda || p.ovunque) && p.ricerca ? 22 : 6 }
        keys: ["text/uri-list"]
        onDropped: d => { if (!p.cestino) p.gestore.lascia(d, p.percorso); }
        Rectangle { anchors.fill: parent; radius: Tema.raggio; color: zona.containsDrag ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.06) : "transparent" }

        MouseArea {                              // clic nel vuoto: niente selezionato; destro: il menu della cartella
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: m => { p.forceActiveFocus(); p.gestore.attivo = p; if (m.button === Qt.LeftButton) p.scelti = ({}); }
            onClicked: m => { if (m.button === Qt.RightButton && !p.cestino) { p.scelti = ({}); p.gestore.menu(p, null, mapToItem(null, m.x, m.y)); } }
        }

        GridView {
            id: vista
            anchors { fill: parent; margins: 6 }
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: p.elenco ? p.elenco.length : cartella
            readonly property bool griglia: p.gestore.vista === "griglia"
            // dettagli: le colonne che ci stanno (stretto: via il tipo, poi la data)
            readonly property int wDim: 100
            readonly property int wData: width > 560 ? 140 : 0
            readonly property int wTipo: width > 760 ? 90 : 0
            readonly property int wNome: width - 44 - wDim - wData - wTipo
            cellWidth: griglia ? p.gestore.zoom + 44 : width
            cellHeight: griglia ? p.gestore.zoom + 46 : 34
            currentIndex: -1
            keyNavigationEnabled: false
            header: Item {
                visible: !vista.griglia
                width: vista.width; height: vista.griglia ? 0 : 28
                Row {
                    visible: !vista.griglia
                    x: 44; anchors.verticalCenter: parent.verticalCenter
                    Repeater {
                        model: [["nome", "Nome", vista.wNome], ["dimensione", "Dimensione", vista.wDim], ["data", "Modificato", vista.wData], ["tipo", "Tipo", vista.wTipo]]
                        Text {
                            required property var modelData
                            width: modelData[2]
                            visible: width > 0
                            elide: Text.ElideRight
                            text: modelData[1] + (p.gestore.ordina === modelData[0] ? (p.gestore.inverti ? " ↓" : " ↑") : "")
                            color: p.gestore.ordina === modelData[0] ? Tema.oro : Tema.tenue; font.family: Tema.font; font.pixelSize: 12
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: { if (p.gestore.ordina === modelData[0]) p.gestore.inverti = !p.gestore.inverti; else { p.gestore.ordina = modelData[0]; p.gestore.inverti = false; } } }
                        }
                    }
                }
            }
            delegate: Item {
                id: d
                required property int index
                readonly property var v: (p.elenco, cartella.count, p.versione, p.voce(index))
                readonly property bool scelto: !!v && !!p.scelti[v.percorso]
                width: vista.cellWidth; height: vista.cellHeight
                visible: !!v

                Rectangle {
                    anchors { fill: parent; margins: 3 }
                    radius: 10
                    color: d.scelto ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.22)
                         : sopra.containsMouse || dropCartella.containsDrag ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                    border.color: dropCartella.containsDrag ? Tema.oro : vista.currentIndex === d.index && p.attivo ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.5) : "transparent"
                }
                // griglia: icona o anteprima, nome sotto
                Item {
                    visible: vista.griglia
                    anchors.fill: parent
                    Item {
                        id: riquadroIcona
                        width: p.gestore.zoom; height: p.gestore.zoom
                        anchors.horizontalCenter: parent.horizontalCenter; y: 8
                        Text {
                            anchors.centerIn: parent
                            visible: anteprima.status !== Image.Ready
                            text: d.v ? I.icona(d.v.nome, d.v.cartella) : ""
                            font.family: Tema.icone; font.pixelSize: p.gestore.zoom * 0.8
                            color: d.v ? I.colore(d.v.nome, d.v.cartella) : Tema.tenue
                        }
                        Image {
                            id: anteprima
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: true
                            sourceSize.width: 256; sourceSize.height: 256
                            source: d.v && !p.cestino && !d.v.cartella && I.immagine(d.v.nome) && d.v.dimensione < 60e6 ? "file://" + d.v.percorso : ""
                        }
                    }
                    Text {
                        visible: p.rinomina !== (d.v?.percorso ?? "")
                        anchors { top: riquadroIcona.bottom; topMargin: 4; horizontalCenter: parent.horizontalCenter }
                        width: parent.width - 10
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WrapAnywhere; maximumLineCount: 2; elide: Text.ElideRight
                        text: d.v?.nome ?? ""
                        color: (d.v?.nome ?? "").startsWith(".") ? Tema.tenue : Tema.testo; font.family: Tema.font; font.pixelSize: 12
                    }
                }
                // dettagli: icona piccola, nome, dimensione, data, tipo
                Row {
                    visible: !vista.griglia
                    anchors.verticalCenter: parent.verticalCenter
                    x: 12
                    spacing: 0
                    Text { width: 32; text: d.v ? I.icona(d.v.nome, d.v.cartella) : ""; font.family: Tema.icone; font.pixelSize: 20
                           color: d.v ? I.colore(d.v.nome, d.v.cartella) : Tema.tenue; anchors.verticalCenter: parent.verticalCenter }
                    Text { width: vista.wNome; elide: Text.ElideMiddle; visible: p.rinomina !== (d.v?.percorso ?? "")
                           text: (d.v?.nome ?? "") + (p.profonda || p.ovunque || p.cestino ? "   — " + (d.v?.da ?? "").replace(Quickshell.env("HOME"), "~") : "")
                           color: Tema.testo; font.family: Tema.font; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                    Item { width: vista.wNome; height: 1; visible: p.rinomina === (d.v?.percorso ?? "") }
                    Text { width: vista.wDim; text: d.v && !d.v.cartella ? I.dimensione(d.v.dimensione) : ""; color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
                           anchors.verticalCenter: parent.verticalCenter }
                    Text { width: vista.wData; visible: width > 0; text: d.v?.data ? I.data(d.v.data) : ""; color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
                           anchors.verticalCenter: parent.verticalCenter }
                    Text { width: vista.wTipo; visible: width > 0; text: d.v ? (d.v.cartella ? "cartella" : (I.suffisso(d.v.nome) || "file")) : ""; color: Tema.tenue
                           font.family: Tema.font; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                }
                // il nome mentre lo cambi (F2)
                Rectangle {
                    visible: p.rinomina !== "" && p.rinomina === (d.v?.percorso ?? "")
                    x: vista.griglia ? 4 : 44; y: vista.griglia ? riquadroIcona.y + p.gestore.zoom + 2 : 3
                    width: vista.griglia ? parent.width - 8 : vista.wNome; height: 28; radius: 6
                    color: Tema.fondo; border.color: Tema.oro
                    onVisibleChanged: if (visible) { nuovoNome.text = d.v.nome; nuovoNome.forceActiveFocus();
                                                     const i = d.v.cartella ? -1 : d.v.nome.lastIndexOf(".");
                                                     nuovoNome.select(0, i > 0 ? i : d.v.nome.length); }
                    TextInput {
                        id: nuovoNome
                        anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                        verticalAlignment: TextInput.AlignVCenter
                        color: Tema.testo; font.family: Tema.font; font.pixelSize: 12; clip: true; selectByMouse: true
                        // l'Invio si ferma qui (un TextInput lo lascerebbe passare al riquadro, che aprirebbe il file)
                        function conferma() { const v = d.v; p.rinomina = ""; p.forceActiveFocus(); if (text && text !== v.nome) p.gestore.rinomina(v.percorso, text); }
                        Keys.onReturnPressed: e => { e.accepted = true; conferma(); }
                        Keys.onEnterPressed: e => { e.accepted = true; conferma(); }
                        Keys.onEscapePressed: { p.rinomina = ""; p.forceActiveFocus(); }
                        onActiveFocusChanged: if (!activeFocus && p.rinomina === d.v?.percorso) p.rinomina = ""
                    }
                }

                // si può lasciare dentro una cartella
                DropArea {
                    id: dropCartella
                    anchors.fill: parent
                    enabled: !!d.v && d.v.cartella && !p.cestino
                    keys: ["text/uri-list"]
                    onDropped: e => p.gestore.lascia(e, d.v.percorso)
                }
                MouseArea {
                    id: sopra
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    drag.target: trascina
                    onPressed: m => {
                        p.forceActiveFocus(); p.gestore.attivo = p;
                        if (m.button === Qt.RightButton) { if (!d.scelto) p.scegli(d.index, 0); return; }
                        if (!d.scelto || m.modifiers & (Qt.ControlModifier | Qt.ShiftModifier)) p.scegli(d.index, m.modifiers);
                    }
                    onReleased: m => { if (m.button === Qt.LeftButton && !drag.active && !(m.modifiers & (Qt.ControlModifier | Qt.ShiftModifier)) && p.selezione.length > 1) p.scegli(d.index, 0); }
                    onClicked: m => { if (m.button === Qt.RightButton) p.gestore.menu(p, d.v, mapToItem(null, m.x, m.y)); }
                    onDoubleClicked: m => { if (m.button === Qt.LeftButton) p.apri(d.v); }
                }
                Item {                                   // quello che si trascina (anche fuori, verso altri programmi)
                    id: trascina
                    Drag.active: sopra.drag.active
                    Drag.dragType: Drag.Automatic
                    Drag.supportedActions: Qt.MoveAction | Qt.CopyAction
                    Drag.mimeData: ({ "text/uri-list": p.selezione.map(f => "file://" + encodeURI(f)).join("\r\n") })
                    Drag.keys: ["text/uri-list"]
                }
            }
        }
        Text {
            anchors.centerIn: parent
            visible: p.quanti === 0
            text: p.cestino ? "Il cestino è vuoto." : p.ricerca ? "Niente con «" + p.ricerca + "»." : cartella.status === FolderListModel.Ready ? "Cartella vuota." : ""
            color: Tema.tenue; font.family: Tema.font; font.pixelSize: 14
        }
    }
}
