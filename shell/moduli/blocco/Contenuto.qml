// Il pannello del blocco di CielOS (Blocco.qml), dalla schermata di blocco di Ciel per caelestia
// (assistente-vocale/avatar/lock/CielContenuto.qml): stessa notte, stesso cerchio, la Pam di Pam.qml.
// Notte blu con le stelle, il cerchio magico al centro (la Guardiana: i suoi commenti stanno sotto), ora e data in
// italiano, la giornata di Ciel (modelli/blocco.json), cosa sta suonando, e il campo della password.
// La password: i tasti vanno a pam.handleKey come nel campo originale di caelestia; qui si vedono solo i pallini.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.servizi

Item {
    id: root

    required property var lock                  // .pam, .unlocking (Blocco.qml)
    property var guardiana: null                // CielGuardiana (le frasi); se manca, una frase fissa
    readonly property var pam: lock.pam

    readonly property color oro: Tema.oro
    readonly property color oroChiaro: Tema.oroChiaro
    readonly property color testo: Tema.testo
    readonly property color tenue: Tema.tenue
    readonly property color allarme: Tema.allarme
    readonly property real k: Math.max(0.7, Math.min(1.25, height / 900))      // scala con lo schermo

    // stato della password (gli stati sono quelli di Pam.qml)
    readonly property bool controlla: !!(pam && pam.passwd && pam.passwd.active)
    readonly property bool scrive: !!(pam && pam.buffer && pam.buffer.length > 0)
    readonly property bool sbagliata: !!pam && (pam.state === "sbagliata" || pam.state === "errore")
    readonly property bool troppi: !!pam && pam.state === "troppi"
    readonly property bool sospetto: guardiana ? guardiana.sospetto : sbagliata

    // ---------------------------------------------------------------- dati
    property var giornata: ({})
    FileView {
        path: Quickshell.env("HOME") + "/assistente-vocale/modelli/blocco.json"
        printErrors: false
        onLoaded: { try { root.giornata = JSON.parse(text()) || {}; } catch (e) { root.giornata = {}; } }
    }
    property date ora: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.ora = new Date() }
    readonly property var giorni: Lingua.inglese ? ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"] : ["domenica", "lunedì", "martedì", "mercoledì", "giovedì", "venerdì", "sabato"]
    readonly property var mesi: Lingua.inglese ? ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"] : ["gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno", "luglio", "agosto",
                                 "settembre", "ottobre", "novembre", "dicembre"]
    readonly property var lettore: {
        const v = Mpris.players.values;
        return v.find(p => p.isPlaying) ?? v[0] ?? null;
    }

    // ---------------------------------------------------------------- il cielo dentro il pannello
    Item {
        id: cielo
        anchors.fill: parent
        anchors.margins: -24 * root.k                // fino ai bordi del pannello
        clip: true
        Rectangle {
            anchors.fill: parent
            radius: 36
            gradient: Gradient {
                GradientStop { position: 0; color: Tema.fondoAlto }
                GradientStop { position: 0.6; color: Tema.fondo }
                GradientStop { position: 1; color: Tema.scurisci(Tema.fondo, 0.28) }
            }
        }
        Repeater {                                   // stelle che brillano piano (poche: costano niente)
            model: 70
            Rectangle {
                required property int index
                readonly property real r: ((index * 7919) % 1000) / 1000
                readonly property real q: ((index * 104729) % 1000) / 1000
                x: r * cielo.width; y: q * cielo.height
                width: 1.5 + (index % 3); height: width; radius: width / 2
                color: index % 9 === 0 ? root.oroChiaro : "#dfe6ff"
                // le stelle brillano piano solo se le animazioni sono accese (Impostazioni → Aspetto): con le
                // animazioni spente il blocco è un cielo fermo — niente che ridisegna lo schermo mentre sei via
                // (era l'unica animazione infinita che non guardava «animazioni», e «leggerissima» la prometteva spenta)
                SequentialAnimation on opacity {
                    running: Tema.animazioni
                    loops: Animation.Infinite
                    PauseAnimation { duration: (index * 397) % 3000 }
                    NumberAnimation { to: 0.85; duration: 1600 + (index * 131) % 1800; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.2; duration: 1600 + (index * 173) % 1800; easing.type: Easing.InOutSine }
                }
            }
        }
    }

    // ---------------------------------------------------------------- le tre colonne
    RowLayout {
        anchors.fill: parent
        spacing: 28 * root.k

        // a sinistra: la giornata
        Scheda {
            Layout.preferredWidth: root.width * 0.26
            Layout.alignment: Qt.AlignVCenter
            titolo: Lingua.t("Oggi")
            ColumnLayout {
                width: parent.width
                spacing: 10 * root.k
                Text {
                    text: root.giorni[root.ora.getDay()].charAt(0).toUpperCase() + root.giorni[root.ora.getDay()].slice(1)
                          + " " + root.ora.getDate() + " " + root.mesi[root.ora.getMonth()]
                    color: root.oroChiaro; font.family: Tema.font; font.pixelSize: 22 * root.k; font.weight: Font.Medium
                }
                Text {
                    Layout.fillWidth: true
                    visible: !!root.giornata.meteo
                    text: root.giornata.meteo || ""
                    color: root.testo; font.family: Tema.font; font.pixelSize: 15 * root.k; wrapMode: Text.WordWrap
                    lineHeight: 1.15
                }
                Rectangle { Layout.fillWidth: true; Layout.topMargin: 6 * root.k; implicitHeight: 1; color: Tema.alfa(Tema.oro, 0.25) }
                Text {
                    text: Lingua.t("Impegni")
                    color: root.tenue; font.family: Tema.font; font.pixelSize: 13 * root.k; font.letterSpacing: 2
                    font.capitalization: Font.AllUppercase
                }
                Repeater {
                    model: root.giornata.impegni || []
                    Text {
                        required property var modelData
                        Layout.fillWidth: true
                        text: "✦  " + modelData
                        color: root.testo; font.family: Tema.font; font.pixelSize: 15 * root.k; wrapMode: Text.WordWrap
                    }
                }
                Text {
                    visible: !(root.giornata.impegni && root.giornata.impegni.length)
                    text: Lingua.t("Niente in programma.")
                    color: root.tenue; font.family: Tema.font; font.pixelSize: 15 * root.k; font.italic: true
                }
            }
        }

        // al centro: ora, data, la Guardiana, la password
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6 * root.k

            Item { Layout.fillHeight: true }
            Row {
                Layout.alignment: Qt.AlignHCenter
                Text {
                    text: Qt.formatTime(root.ora, "HH")
                    color: root.testo; font.family: Tema.font; font.weight: Font.Light; font.pixelSize: 112 * root.k
                }
                Text {
                    text: ":"
                    color: root.oro; font.family: Tema.font; font.weight: Font.Light; font.pixelSize: 112 * root.k
                    opacity: root.ora.getSeconds() % 2 ? 0.35 : 1
                    Behavior on opacity { NumberAnimation { duration: 400 } }
                }
                Text {
                    text: Qt.formatTime(root.ora, "mm")
                    color: root.testo; font.family: Tema.font; font.weight: Font.Light; font.pixelSize: 112 * root.k
                }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Lingua.inglese ? root.giorni[root.ora.getDay()] + ", " + root.mesi[root.ora.getMonth()] + " " + root.ora.getDate() : root.giorni[root.ora.getDay()] + " " + root.ora.getDate() + " " + root.mesi[root.ora.getMonth()]
                color: root.tenue; font.family: Tema.font; font.pixelSize: 18 * root.k; font.letterSpacing: 3
                font.capitalization: Font.AllUppercase
            }

            Cerchio {
                id: cerchio
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 8 * root.k
                Layout.preferredWidth: 260 * root.k
                Layout.preferredHeight: 260 * root.k
                colore: root.sospetto || root.troppi ? root.allarme : root.oro
                umore: root.sospetto ? "irritata" : "sereno"
                stato: root.controlla ? "pensa" : root.scrive ? "ascolto" : "idle"
                Behavior on colore { ColorAnimation { duration: 500 } }
            }
            Text {                                   // quello che dice la Guardiana
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: root.width * 0.42
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: root.guardiana && root.guardiana.frase ? root.guardiana.frase : Lingua.t("Postazione sigillata.")
                color: root.sospetto ? "#ffb3b3" : root.oroChiaro
                font.family: Tema.font; font.italic: true; font.pixelSize: 16 * root.k
            }

            // il campo della password
            Rectangle {
                id: campo
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 14 * root.k
                implicitWidth: 380 * root.k
                implicitHeight: 54 * root.k
                radius: height / 2
                color: Tema.conAlfa(Tema.fondo, 0.92)
                border.width: 1.5
                border.color: root.sbagliata || root.troppi ? root.allarme
                            : root.scrive || root.controlla ? root.oro : Tema.alfa(Tema.oro, 0.4)
                Behavior on border.color { ColorAnimation { duration: 250 } }

                focus: true
                Component.onCompleted: forceActiveFocus()
                onActiveFocusChanged: if (!activeFocus) forceActiveFocus()
                Keys.onPressed: event => {
                    if (root.lock.unlocking) return;
                    root.pam.handleKey(event);
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onClicked: campo.forceActiveFocus() }

                // scossa quando la password è sbagliata
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
                Connections {
                    target: root.pam
                    function onFlashMsg() { scossa.restart(); }
                }

                Text {                               // lucchetto (o rotellina mentre controlla)
                    id: icona
                    anchors.left: parent.left; anchors.leftMargin: 20 * root.k
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.controlla ? "progress_activity" : root.troppi ? "lock_clock" : "lock"
                    font.family: Tema.icone; font.pixelSize: 22 * root.k
                    color: root.sbagliata || root.troppi ? root.allarme : root.oro
                    RotationAnimation on rotation { running: root.controlla; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
                    onTextChanged: if (!root.controlla) rotation = 0
                }
                Text {
                    anchors.left: icona.right; anchors.leftMargin: 14 * root.k
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !root.scrive
                    text: root.troppi ? Lingua.t("Troppi tentativi") : root.controlla ? Lingua.t("Controllo…") : Lingua.t("Parola d'ordine")
                    color: root.tenue; font.family: Tema.font; font.pixelSize: 17 * root.k
                }
                Row {                                // un pallino per carattere: mai i caratteri
                    anchors.left: icona.right; anchors.leftMargin: 16 * root.k
                    anchors.right: parent.right; anchors.rightMargin: 52 * root.k
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7 * root.k
                    clip: true
                    Repeater {
                        model: root.pam && root.pam.buffer ? Math.min(root.pam.buffer.length, 22) : 0
                        Rectangle {
                            width: 9 * root.k; height: width; radius: width / 2
                            color: root.oro
                            opacity: 0
                            scale: 0.4
                            Component.onCompleted: { opacity = 1; scale = 1; }
                            Behavior on opacity { NumberAnimation { duration: 140 } }
                            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                        }
                    }
                }
                Text {                               // invio
                    anchors.right: parent.right; anchors.rightMargin: 18 * root.k
                    anchors.verticalCenter: parent.verticalCenter
                    text: "arrow_forward"
                    font.family: Tema.icone; font.pixelSize: 22 * root.k
                    color: root.scrive ? root.oro : Qt.rgba(1, 1, 1, 0.25)
                }
            }
            Text {                                   // messaggi del sistema (account bloccato, errori)
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: root.width * 0.42
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: text !== ""
                text: root.troppi ? (root.pam.lockMessage || Lingua.t("Troppi tentativi: aspetta un po' e riprova."))
                    : root.pam && root.pam.state === "errore" ? Lingua.t("Errore: ") + (root.pam.passwd.message || Lingua.t("riprova"))
                    : root.sbagliata ? Lingua.t("Parola d'ordine sbagliata.") : ""
                color: "#ffb3b3"; font.family: Tema.font; font.pixelSize: 14 * root.k
            }
            Item { Layout.fillHeight: true }
        }

        // a destra: Ciel e la musica
        Scheda {
            Layout.preferredWidth: root.width * 0.26
            Layout.alignment: Qt.AlignVCenter
            titolo: "Ciel"
            ColumnLayout {
                width: parent.width
                spacing: 10 * root.k
                Text {
                    Layout.fillWidth: true
                    text: "«" + (root.giornata.frase || Lingua.t("Faccio la guardia io.")) + "»"
                    color: root.testo; font.family: Tema.font; font.italic: true; font.pixelSize: 18 * root.k
                    wrapMode: Text.WordWrap; lineHeight: 1.2
                }
                Rectangle { Layout.fillWidth: true; Layout.topMargin: 6 * root.k; implicitHeight: 1; color: Tema.alfa(Tema.oro, 0.25) }
                Text {
                    text: Lingua.t("In riproduzione")
                    color: root.tenue; font.family: Tema.font; font.pixelSize: 13 * root.k; font.letterSpacing: 2
                    font.capitalization: Font.AllUppercase
                }
                Text {
                    Layout.fillWidth: true
                    text: root.lettore ? (root.lettore.trackTitle || Lingua.t("Senza titolo")) : Lingua.t("Niente")
                    color: root.testo; font.family: Tema.font; font.pixelSize: 16 * root.k; font.weight: Font.Medium
                    elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.WordWrap
                }
                Text {
                    Layout.fillWidth: true
                    visible: !!(root.lettore && root.lettore.trackArtist)
                    text: root.lettore ? (root.lettore.trackArtist || "") : ""
                    color: root.tenue; font.family: Tema.font; font.pixelSize: 14 * root.k; elide: Text.ElideRight
                }
                Row {
                    visible: !!root.lettore
                    spacing: 14 * root.k
                    Repeater {
                        model: [["skip_previous", "previous", "canGoPrevious"], ["", "togglePlaying", "canTogglePlaying"],
                                ["skip_next", "next", "canGoNext"]]
                        Rectangle {
                            required property var modelData
                            readonly property bool attivo: !!(root.lettore && root.lettore[modelData[2]])
                            width: 44 * root.k; height: width; radius: width / 2
                            color: modelData[0] === "" ? root.oro : Tema.conAlfa(Tema.testo, 0.06)
                            border.width: 1; border.color: Tema.alfa(Tema.oro, 0.35)
                            opacity: attivo ? 1 : 0.35
                            Text {
                                anchors.centerIn: parent
                                text: parent.modelData[0] || (root.lettore && root.lettore.isPlaying ? "pause" : "play_arrow")
                                font.family: Tema.icone; font.pixelSize: 22 * root.k
                                color: parent.modelData[0] === "" ? "#0b1029" : root.testo
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: parent.attivo
                                onClicked: root.lettore[parent.modelData[1]]()
                            }
                        }
                    }
                }
            }
        }
    }

    component Scheda: Rectangle {
        id: s
        property string titolo: ""
        default property alias contenuto: dentro.data
        radius: 26 * root.k
        implicitHeight: intestazione.height + dentro.height + 54 * root.k
        Layout.preferredHeight: implicitHeight
        color: Tema.biancoTenue
        border.width: 1
        border.color: Tema.alfa(Tema.oro, 0.22)
        Text {
            id: intestazione
            x: 24 * root.k; y: 20 * root.k
            text: s.titolo
            color: root.oro; font.family: Tema.font; font.pixelSize: 14 * root.k; font.letterSpacing: 3
            font.capitalization: Font.AllUppercase; font.weight: Font.Medium
        }
        Item {
            id: dentro
            x: 24 * root.k
            anchors.top: intestazione.bottom; anchors.topMargin: 14 * root.k
            width: s.width - 48 * root.k
            height: childrenRect.height
        }
    }
}
