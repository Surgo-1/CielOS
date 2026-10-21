// Il login di SDDM a tema Ciel: la stessa notte della schermata di blocco (avatar/lock/CielContenuto.qml).
// Stelle, ora e data in italiano, il cerchio magico di Ciel (CielAvatar.qml = avatar/Avatar.qml) che ti saluta,
// e sotto il campo della password. Sullo schermo secondario solo cielo, ora e cerchio.
// SDDM gira come utente «sddm»: non vede niente della tua home (niente meteo, niente agenda), solo questi file.
// Si installa con sistema/sddm-ciel/installa.sh (sudo); si torna al tema di prima togliendo /etc/sddm.conf.d/30-ciel.conf
import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: Qt.darker(fondo, 1.5)

    readonly property real k: Math.max(0.7, Math.min(1.4, height / 1000))
    // i colori: quelli scelti in Ciel (cieltema scrive ~/.config/cielos/sddm.conf, installa.sh lo copia qui come
    // theme.conf.user), altrimenti la notte di Ciel
    readonly property color oro: config.Oro || "#ffbf3f"
    readonly property color oroChiaro: config.OroChiaro || "#ffd98a"
    readonly property color testo: config.Testo || "#eef2ff"
    readonly property color tenue: config.Tenue || "#9aa6c8"
    readonly property color allarme: config.Allarme || "#ff5a5a"
    readonly property color fondo: config.Fondo || "#0b1029"
    readonly property color fondoAlto: config.FondoAlto || "#141b3d"
    readonly property string carattere: config.Font || "Rubik"
    readonly property string icone: config.IconFont || "Material Symbols Rounded"
    // le stelle si muovono solo se le animazioni sono accese in Ciel (cieltema scrive Animazioni in
    // ~/.config/cielos/sddm.conf → theme.conf.user): fermi al login non c'è niente che ridisegna lo schermo mentre
    // aspetti di entrare. Senza la chiave (installazioni vecchie) restano come prima, accese.
    readonly property bool animazioni: String(config.Animazioni === undefined ? "true" : config.Animazioni).toLowerCase() !== "false"
    readonly property bool principale: typeof primaryScreen === "undefined" ? true : primaryScreen

    property date ora: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.ora = new Date() }
    // l'inglese se il sistema non è in italiano (SDDM parte con la lingua di /etc/locale.conf)
    readonly property bool en: !Qt.locale().name.startsWith("it")
    readonly property var giorni: en ? ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"] : ["domenica", "lunedì", "martedì", "mercoledì", "giovedì", "venerdì", "sabato"]
    readonly property var mesi: en ? ["January", "February", "March", "April", "May", "June", "July", "August", "September",
                                      "October", "November", "December"] : ["gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno", "luglio", "agosto",
                                 "settembre", "ottobre", "novembre", "dicembre"]
    readonly property string saluto: {
        const h = ora.getHours();
        if (en)
            return h < 5 ? "Still up? Come in, I'll keep you company."
                 : h < 12 ? "Good morning. I was waiting for you."
                 : h < 18 ? "Good afternoon. Welcome back."
                 : "Good evening. Welcome home.";
        return h < 5 ? "Ancora sveglio? Entra, ti tengo compagnia."
             : h < 12 ? "Buongiorno. Ti stavo aspettando."
             : h < 18 ? "Buon pomeriggio. Bentornato."
             : "Buonasera. Bentornato a casa.";
    }

    // ---------------------------------------------------------------- utenti e sessioni
    property var utenti: []
    property var sessioni: []
    property int utente: 0
    property int sessione: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    readonly property var chi: utenti[utente] || ({ name: userModel.lastUser, realName: "" })
    Repeater {
        model: userModel
        delegate: Item {
            Component.onCompleted: {
                const l = root.utenti.slice();
                l[index] = { name: model.name, realName: model.realName };
                root.utenti = l;
                if (model.name === userModel.lastUser) root.utente = index;
            }
        }
    }
    Repeater {
        model: sessionModel
        delegate: Item {
            Component.onCompleted: {
                const l = root.sessioni.slice();
                l[index] = model.name;
                root.sessioni = l;
            }
        }
    }

    property bool controlla: false
    property bool sbagliata: false
    function entra() {
        if (controlla || !password.text) return;
        controlla = true; sbagliata = false;
        sddm.login(chi.name, password.text, sessione);
    }
    Connections {
        target: sddm
        function onLoginFailed() {
            root.controlla = false; root.sbagliata = true;
            password.text = "";
            scossa.restart();
            password.forceActiveFocus();
        }
        function onLoginSucceeded() { root.controlla = false; }
    }

    // ---------------------------------------------------------------- il cielo
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: root.fondoAlto }
            GradientStop { position: 0.6; color: root.fondo }
            GradientStop { position: 1; color: Qt.darker(root.fondo, 1.5) }
        }
    }
    Repeater {                          // stelle che brillano piano
        model: 140
        Rectangle {
            required property int index
            x: (((index * 7919) % 1000) / 1000) * root.width
            y: (((index * 104729) % 1000) / 1000) * root.height
            width: (1.5 + (index % 3)) * root.k; height: width; radius: width / 2
            color: index % 9 === 0 ? root.oroChiaro : "#dfe6ff"
            opacity: 0.3
            SequentialAnimation on opacity {
                running: root.animazioni
                loops: Animation.Infinite
                PauseAnimation { duration: (index * 397) % 3000 }
                NumberAnimation { to: 0.9; duration: 1600 + (index * 131) % 1800; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.2; duration: 1600 + (index * 173) % 1800; easing.type: Easing.InOutSine }
            }
        }
    }

    // ---------------------------------------------------------------- centro
    Column {
        id: centro
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -30 * root.k
        spacing: 8 * root.k

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            Text {
                text: Qt.formatTime(root.ora, "HH")
                color: root.testo; font.family: root.carattere; font.weight: Font.Light; font.pixelSize: 120 * root.k
            }
            Text {
                text: ":"
                color: root.oro; font.family: root.carattere; font.weight: Font.Light; font.pixelSize: 120 * root.k
                opacity: root.ora.getSeconds() % 2 ? 0.35 : 1
                Behavior on opacity { NumberAnimation { duration: 400 } }
            }
            Text {
                text: Qt.formatTime(root.ora, "mm")
                color: root.testo; font.family: root.carattere; font.weight: Font.Light; font.pixelSize: 120 * root.k
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.en ? root.giorni[root.ora.getDay()] + ", " + root.mesi[root.ora.getMonth()] + " " + root.ora.getDate()
                          : root.giorni[root.ora.getDay()] + " " + root.ora.getDate() + " " + root.mesi[root.ora.getMonth()]
            color: root.tenue; font.family: root.carattere; font.pixelSize: 19 * root.k; font.letterSpacing: 3
            font.capitalization: Font.AllUppercase
        }

        CielAvatar {
            anchors.horizontalCenter: parent.horizontalCenter
            width: (root.principale ? 280 : 360) * root.k
            height: width
            colore: root.sbagliata ? root.allarme : root.oro
            umore: root.sbagliata ? "irritata" : "sereno"
            stato: root.controlla ? "pensa" : password.text.length ? "ascolto" : "idle"
            Behavior on colore { ColorAnimation { duration: 500 } }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.principale
            text: root.sbagliata ? (root.en ? "That's not the right word. Try again." : "Non è la parola giusta. Riprova.") : root.saluto
            color: root.sbagliata ? "#ffb3b3" : root.oroChiaro
            font.family: root.carattere; font.italic: true; font.pixelSize: 18 * root.k
        }

        Item { width: 1; height: 10 * root.k; visible: root.principale }

        // nome (clic per cambiare utente, se ce n'è più di uno)
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.principale
            text: root.chi.realName || root.chi.name || ""
            color: root.testo; font.family: root.carattere; font.pixelSize: 20 * root.k; font.weight: Font.Medium
            MouseArea {
                anchors.fill: parent
                enabled: root.utenti.length > 1
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.utente = (root.utente + 1) % root.utenti.length
            }
        }

        // il campo della password: solo pallini
        Rectangle {
            id: campo
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.principale
            width: 400 * root.k
            height: 56 * root.k
            radius: height / 2
            color: Qt.rgba(root.fondo.r * 0.6, root.fondo.g * 0.6, root.fondo.b * 0.6, 0.92)
            border.width: 1.5
            border.color: root.sbagliata ? root.allarme
                        : password.text.length || root.controlla ? root.oro : Qt.rgba(root.oro.r, root.oro.g, root.oro.b, 0.4)
            Behavior on border.color { ColorAnimation { duration: 250 } }

            property real spinta: 0
            transform: Translate { x: campo.spinta }
            SequentialAnimation {
                id: scossa
                NumberAnimation { target: campo; property: "spinta"; to: -14; duration: 50 }
                NumberAnimation { target: campo; property: "spinta"; to: 12; duration: 70 }
                NumberAnimation { target: campo; property: "spinta"; to: -8; duration: 70 }
                NumberAnimation { target: campo; property: "spinta"; to: 5; duration: 60 }
                NumberAnimation { target: campo; property: "spinta"; to: 0; duration: 60 }
            }

            Text {
                id: icona
                anchors.left: parent.left; anchors.leftMargin: 20 * root.k
                anchors.verticalCenter: parent.verticalCenter
                text: root.controlla ? "progress_activity" : "lock"
                font.family: root.icone; font.pixelSize: 22 * root.k
                color: root.sbagliata ? root.allarme : root.oro
                RotationAnimation on rotation { running: root.controlla; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
                onTextChanged: if (!root.controlla) rotation = 0
            }
            TextInput {                     // invisibile: tiene la password; si vedono solo i pallini
                id: password
                anchors.fill: parent
                anchors.leftMargin: 56 * root.k; anchors.rightMargin: 56 * root.k
                echoMode: TextInput.Password
                color: "transparent"; selectionColor: "transparent"; selectedTextColor: "transparent"
                cursorVisible: false
                cursorDelegate: Item {}
                font.pixelSize: 18 * root.k
                verticalAlignment: TextInput.AlignVCenter
                enabled: !root.controlla
                focus: root.principale
                Component.onCompleted: if (root.principale) forceActiveFocus()
                onTextChanged: if (text.length) root.sbagliata = false
                Keys.onReturnPressed: root.entra()
                Keys.onEnterPressed: root.entra()
            }
            Text {
                anchors.left: icona.right; anchors.leftMargin: 14 * root.k
                anchors.verticalCenter: parent.verticalCenter
                visible: !password.text.length
                text: root.controlla ? (root.en ? "Checking…" : "Controllo…") : keyboard.capsLock ? (root.en ? "Caps Lock is on" : "Bloc Maiusc attivo")
                    : (root.en ? "Password" : "Parola d'ordine")
                color: keyboard.capsLock && !root.controlla ? root.oroChiaro : root.tenue
                font.family: root.carattere; font.pixelSize: 17 * root.k
            }
            Row {
                anchors.left: icona.right; anchors.leftMargin: 16 * root.k
                anchors.right: parent.right; anchors.rightMargin: 52 * root.k
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7 * root.k
                clip: true
                Repeater {
                    model: Math.min(password.text.length, 22)
                    Rectangle {
                        width: 9 * root.k; height: width; radius: width / 2
                        color: root.oro
                        opacity: 0; scale: 0.4
                        Component.onCompleted: { opacity = 1; scale = 1; }
                        Behavior on opacity { NumberAnimation { duration: 140 } }
                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                    }
                }
            }
            Text {
                anchors.right: parent.right; anchors.rightMargin: 18 * root.k
                anchors.verticalCenter: parent.verticalCenter
                text: "arrow_forward"
                font.family: root.icone; font.pixelSize: 24 * root.k
                color: password.text.length ? root.oro : Qt.rgba(root.oro.r, root.oro.g, root.oro.b, 0.35)
                MouseArea { anchors.fill: parent; anchors.margins: -10; cursorShape: Qt.PointingHandCursor; onClicked: root.entra() }
            }
            MouseArea {
                anchors.fill: parent; z: -1
                cursorShape: Qt.IBeamCursor
                onClicked: password.forceActiveFocus()
            }
        }
    }

    // ---------------------------------------------------------------- in basso: sessione e alimentazione
    component Pillola: Rectangle {
        default property alias contenuto: fila.data
        height: 48 * root.k
        width: fila.width + 14 * root.k
        radius: height / 2
        color: Qt.rgba(root.fondo.r * 0.6, root.fondo.g * 0.6, root.fondo.b * 0.6, 0.85)
        border.color: Qt.rgba(root.oro.r, root.oro.g, root.oro.b, 0.3)
        border.width: 1
        Row { id: fila; anchors.centerIn: parent; spacing: 2 * root.k }
    }
    component Bottone: Rectangle {
        property string icona
        property string etichetta: ""
        signal premuto
        height: 38 * root.k
        width: etichetta ? riga.width + 28 * root.k : height
        radius: height / 2
        color: ma.containsMouse ? Qt.rgba(root.oro.r, root.oro.g, root.oro.b, 0.15) : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
        Row {
            id: riga
            anchors.centerIn: parent
            spacing: 8 * root.k
            Text {
                text: icona; font.family: root.icone; font.pixelSize: 21 * root.k; color: root.oroChiaro
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                visible: etichetta.length > 0
                text: etichetta; font.family: root.carattere; font.pixelSize: 15 * root.k; color: root.testo
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.premuto() }
    }

    Pillola {
        visible: root.principale && root.sessioni.length > 0
        anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 32 * root.k
        Bottone {
            icona: "desktop_windows"
            etichetta: root.sessioni[root.sessione] || ""
            onPremuto: root.sessione = (root.sessione + 1) % root.sessioni.length
        }
    }
    Pillola {
        visible: root.principale
        anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 32 * root.k
        Bottone { icona: "bedtime"; visible: sddm.canSuspend; onPremuto: sddm.suspend() }
        Bottone { icona: "restart_alt"; onPremuto: sddm.reboot() }
        Bottone { icona: "power_settings_new"; onPremuto: sddm.powerOff() }
    }
}
