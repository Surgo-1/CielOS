// Strumenti (Super+A → Strumenti), come il menu «Trigger» di Omarchy: catture, interruttori, finestre, rete, e le viste
// Appunti (Super+V), Emoji (Super+.), Scorciatoie (Super+K), QR del Wi-Fi, Velocità. Il motore è bin/cielstrumenti;
// lo stato (registrazione, luce notturna, resta sveglio) è in servizi/Strumenti.qml.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.servizi

Item {
    id: st
    property string vista: ""                     // "" | appunti | emoji | scorciatoie | wifi | velocita
    property var voci: []                         // appunti
    property var emoji: ({ recenti: [], tutte: [] })
    property var tasti: []
    property var wifi: null
    property var rete: null
    property var disco: null
    property string dns: ""
    property bool sicuro: false                   // «chiudi tutte»: secondo clic per confermare
    readonly property string motore: Strumenti.motore
    readonly property var titoli: ({ appunti: Lingua.t("Appunti"), emoji: Lingua.t("Emoji"), scorciatoie: Lingua.t("Scorciatoie"),
                                     wifi: Lingua.t("QR del Wi-Fi"), velocita: Lingua.t("Velocità") })

    function apri(v) {
        vista = v ?? "";
        filtro.text = "";
        Strumenti.aggiorna();
        if (vista === "appunti") appuntiP.running = true;
        if (vista === "emoji" && !emoji.tutte.length) emojiP.running = true;
        if (vista === "scorciatoie") tastiP.running = true;
        if (vista === "wifi") { wifi = null; wifiP.running = true; }
        if (vista === "") dnsP.running = true;
        Qt.callLater(() => vista ? filtro.forceActiveFocus() : st.forceActiveFocus());
    }
    function indietro() { if (vista) { apri(""); return true; } return false; }
    function chiudiE(f) { f(); Pannelli.chiudi(); }
    function copiaEmoji(e) { Quickshell.execDetached([motore, "emoji", "copia", e]); Pannelli.chiudi(); }
    function copiaAppunto(v) { Quickshell.execDetached([motore, "appunti", "copia", v.id]); Pannelli.chiudi(); }
    readonly property string q: filtro.text.trim().toLowerCase()

    Process { id: appuntiP; command: [st.motore, "appunti", "--json"]
              stdout: StdioCollector { onStreamFinished: { try { st.voci = JSON.parse(text).voci; } catch (e) { st.voci = []; } } } }
    Process { id: emojiP; command: [st.motore, "emoji", "--json"]
              stdout: StdioCollector { onStreamFinished: { try { st.emoji = JSON.parse(text); } catch (e) {} } } }
    Process { id: tastiP; command: [st.motore, "scorciatoie", "--json"]
              stdout: StdioCollector { onStreamFinished: { try { st.tasti = JSON.parse(text); } catch (e) { st.tasti = []; } } } }
    Process { id: wifiP; command: [st.motore, "wifi-qr", "--json"]
              stdout: StdioCollector { onStreamFinished: { try { st.wifi = JSON.parse(text); } catch (e) { st.wifi = { ok: false, messaggio: text.trim() }; } } } }
    Process { id: reteP; command: [st.motore, "velocita-rete", "--json"]
              stdout: StdioCollector { onStreamFinished: { try { st.rete = JSON.parse(text); } catch (e) { st.rete = { errore: text.trim() }; } } } }
    Process { id: discoP; command: [st.motore, "velocita-disco", "--json"]
              stdout: StdioCollector { onStreamFinished: { try { st.disco = JSON.parse(text); } catch (e) { st.disco = null; } } } }
    Process { id: dnsP; command: [st.motore, "dns"]
              stdout: StdioCollector { onStreamFinished: { const m = text.match(/DNS: (\w+)/); st.dns = m ? m[1] : ""; } } }
    Process { id: comandoP; onExited: { appuntiP.running = true; dnsP.running = true; } }
    Timer { interval: 4000; running: st.sicuro; onTriggered: st.sicuro = false }

    // ── la pagina: sezioni di pulsanti ──
    Flickable {
        id: casa
        visible: st.vista === ""
        anchors.fill: parent
        contentHeight: sezioni.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: sezioni
            width: parent.width
            spacing: 14

            component Titolo: Text {
                color: Tema.oro; font.family: Tema.font; font.pixelSize: 12; font.letterSpacing: 1.5
                font.capitalization: Font.AllUppercase; font.weight: Font.Medium
            }
            component Interruttore: Pulsante { property bool acceso: false; pieno: acceso }

            Titolo { text: Lingua.t("Cattura") }
            Flow {
                width: parent.width; spacing: 8
                Pulsante { icona: "screenshot_region"; testo: Lingua.t("Schermata di un'area"); onPremuto: { Pannelli.chiudi(); Avvia.comando("schermata", ["sh", "-c", "sleep 0.35; exec cielos-schermata area"]); } }
                Pulsante { icona: "fullscreen"; testo: Lingua.t("Tutto lo schermo"); onPremuto: { Pannelli.chiudi(); Avvia.comando("schermata", ["sh", "-c", "sleep 0.35; exec cielos-schermata schermo"]); } }
                Pulsante { visible: !Strumenti.registra; icona: "videocam"; testo: Lingua.t("Registra"); onPremuto: Strumenti.dopoArea(["registra"]) }
                Pulsante { visible: !Strumenti.registra; icona: "volume_up"; testo: Lingua.t("Registra con l'audio"); onPremuto: Strumenti.dopoArea(["registra", "audio"]) }
                Pulsante { visible: !Strumenti.registra; icona: "mic"; testo: Lingua.t("Con audio e microfono"); onPremuto: Strumenti.dopoArea(["registra", "audio", "microfono"]) }
                Pulsante { visible: !Strumenti.registra; icona: "crop"; testo: Lingua.t("Registra un'area"); onPremuto: Strumenti.dopoArea(["registra", "area"]) }
                Pulsante { visible: Strumenti.registra; pieno: true; pericolo: true; icona: "stop_circle"; testo: Lingua.t("Ferma la registrazione"); onPremuto: Strumenti.fai(["registra", "ferma"]) }
                Pulsante { icona: "text_fields"; testo: Lingua.t("Testo dallo schermo"); onPremuto: Strumenti.dopoArea(["testo"]) }
                Pulsante { icona: "qr_code_scanner"; testo: Lingua.t("Leggi un QR"); onPremuto: Strumenti.dopoArea(["qr"]) }
                Pulsante { icona: "colorize"; testo: Lingua.t("Colore"); onPremuto: Strumenti.dopoArea(["colore"]) }
            }

            Titolo { text: Lingua.t("Interruttori") }
            Flow {
                width: parent.width; spacing: 8
                Interruttore { acceso: Strumenti.luce; icona: "nightlight"; testo: Lingua.t("Luce notturna"); onPremuto: Strumenti.fai(["luce"]) }
                Interruttore { acceso: Strumenti.sveglio; icona: "coffee"; testo: Lingua.t("Resta sveglio"); onPremuto: Strumenti.fai(["sveglio"]) }
                Interruttore { acceso: Pannelli.nonDisturbare; icona: "notifications_off"; testo: Lingua.t("Non disturbare"); onPremuto: Pannelli.nonDisturbare = !Pannelli.nonDisturbare }
                Interruttore { acceso: Tema.animazioni; icona: "animation"; testo: Lingua.t("Animazioni")
                               onPremuto: Quickshell.execDetached([Percorsi.bin("cieltema"), "imposta", "animazioni=" + (Tema.animazioni ? "no" : "si")]) }
                Interruttore { acceso: Tema.v("spazi", true); icona: "grid_view"; testo: Lingua.t("Spazio tra le finestre")
                               onPremuto: Quickshell.execDetached(acceso ? [Percorsi.bin("cieltema"), "imposta", "spazio_dentro=0", "spazio_fuori=0"]
                                                                         : [Percorsi.bin("cieltema"), "togli", "spazio_dentro", "spazio_fuori"]) }
            }

            Titolo { text: Lingua.t("Finestre") }
            Flow {
                width: parent.width; spacing: 8
                Pulsante { icona: "picture_in_picture"; testo: Lingua.t("Stacca la finestra (Super+O)"); onPremuto: st.chiudiE(() => Quickshell.execDetached([st.motore, "finestra", "stacca"])) }
                Pulsante { icona: "close"; pericolo: true; pieno: st.sicuro
                           testo: st.sicuro ? Lingua.t("Sicuro? Chiude tutto") : Lingua.t("Chiudi tutte le finestre")
                           onPremuto: { if (!st.sicuro) { st.sicuro = true; return; } st.sicuro = false; st.chiudiE(() => Quickshell.execDetached([st.motore, "finestre", "chiudi-tutte"])); } }
            }

            Titolo { text: Lingua.t("Rete e disco") }
            Flow {
                width: parent.width; spacing: 8
                Pulsante { icona: "qr_code_2"; testo: Lingua.t("QR del Wi-Fi"); onPremuto: st.apri("wifi") }
                Pulsante { icona: "speed"; testo: Lingua.t("Velocità di internet e del disco"); onPremuto: st.apri("velocita") }
            }
            Row {
                spacing: 8
                Text { anchors.verticalCenter: parent.verticalCenter; text: Lingua.t("DNS:"); color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13 }
                Repeater {
                    model: [["automatico", Lingua.t("Automatico")], ["cloudflare", "Cloudflare"], ["google", "Google"], ["quad9", "Quad9"]]
                    Interruttore {
                        required property var modelData
                        acceso: st.dns === modelData[0]; testo: modelData[1]
                        onPremuto: if (!acceso) { comandoP.command = [st.motore, "dns", modelData[0]]; comandoP.running = true; }
                    }
                }
            }

            Titolo { text: Lingua.t("Altro") }
            Flow {
                width: parent.width; spacing: 8
                Pulsante { icona: "content_paste"; testo: Lingua.t("Appunti (Super+V)"); onPremuto: st.apri("appunti") }
                Pulsante { icona: "mood"; testo: Lingua.t("Emoji (Super+.)"); onPremuto: st.apri("emoji") }
                Pulsante { icona: "keyboard"; testo: Lingua.t("Scorciatoie (Super+K)"); onPremuto: st.apri("scorciatoie") }
                Pulsante { icona: "menu_book"; testo: "Arch Wiki"; onPremuto: st.chiudiE(() => Quickshell.execDetached(["xdg-open", "https://wiki.archlinux.org"])) }
                Pulsante { icona: "menu_book"; testo: "Hyprland Wiki"; onPremuto: st.chiudiE(() => Quickshell.execDetached(["xdg-open", "https://wiki.hypr.land"])) }
            }
        }
    }

    // ── le viste: in cima il titolo e (dove serve) il filtro ──
    Column {
        visible: st.vista !== ""
        anchors.fill: parent
        spacing: 12
        Row {
            width: parent.width
            spacing: 10
            Text { anchors.verticalCenter: parent.verticalCenter; text: st.titoli[st.vista] ?? ""; color: Tema.testo; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.Medium }
            Rectangle {
                visible: ["appunti", "emoji", "scorciatoie"].includes(st.vista)
                width: parent.width - 260; height: 38; radius: Tema.raggio
                color: Qt.rgba(0.02, 0.03, 0.1, 0.9)
                border.color: filtro.activeFocus ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.7) : Qt.rgba(1, 1, 1, 0.12)
                TextInput {
                    id: filtro
                    anchors { left: parent.left; leftMargin: 12; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; clip: true
                    onAccepted: {
                        if (st.vista === "emoji" && griglia.count) st.copiaEmoji(griglia.model[0].e);
                        if (st.vista === "appunti" && listaAppunti.count) st.copiaAppunto(listaAppunti.model[0]);
                    }
                    Text { anchors.verticalCenter: parent.verticalCenter; visible: !filtro.text; color: Tema.tenue; font: filtro.font
                           text: st.vista === "emoji" ? Lingua.t("Cerca (in inglese: heart, smile, fire…)") : Lingua.t("Cerca…") }
                }
            }
            Pulsante { visible: st.vista === "appunti"; anchors.verticalCenter: parent.verticalCenter; pericolo: true; testo: Lingua.t("Svuota")
                       onPremuto: { comandoP.command = [st.motore, "appunti", "svuota"]; comandoP.running = true; } }
        }

        // appunti
        ListView {
            id: listaAppunti
            visible: st.vista === "appunti"
            width: parent.width; height: parent.height - y
            clip: true; spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            model: st.voci.filter(v => !st.q || v.testo.toLowerCase().includes(st.q))
            delegate: Rectangle {
                required property var modelData
                width: listaAppunti.width; height: 40; radius: Tema.raggio
                color: ta.containsMouse ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.12) : Qt.rgba(1, 1, 1, 0.03)
                Text {
                    anchors { left: parent.left; leftMargin: 12; right: via.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    text: (modelData.immagine ? "🖼  " : "") + modelData.testo.replace(/\s+/g, " ")
                    elide: Text.ElideRight; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13
                }
                MouseArea { id: ta; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: st.copiaAppunto(modelData) }
                Text {
                    id: via
                    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    text: "close"; font.family: Tema.icone; font.pixelSize: 18; color: tv.containsMouse ? Tema.allarme : Tema.tenue
                    MouseArea { id: tv; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { comandoP.command = [st.motore, "appunti", "togli", modelData.id]; comandoP.running = true; } }
                }
            }
            Text { visible: !listaAppunti.count && !appuntiP.running; width: parent.width; wrapMode: Text.WordWrap
                   text: Lingua.t("Ancora niente: quello che copi d'ora in poi resta qui (gli ultimi 200, testo e immagini).")
                   color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13 }
        }

        // emoji
        Column {
            visible: st.vista === "emoji"
            width: parent.width; height: parent.height - y
            spacing: 8
            Row {
                visible: !st.q && st.emoji.recenti.length > 0
                spacing: 4
                Repeater {
                    model: st.emoji.recenti
                    Text {
                        required property string modelData
                        text: modelData; font.pixelSize: 26; font.family: "Noto Color Emoji"
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: st.copiaEmoji(modelData) }
                    }
                }
            }
            GridView {
                id: griglia
                width: parent.width; height: parent.height - y
                cellWidth: 46; cellHeight: 46
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: st.q ? st.emoji.tutte.filter(x => x.n.includes(st.q)) : st.emoji.tutte
                delegate: Rectangle {
                    required property var modelData
                    width: 42; height: 42; radius: 8
                    color: te.containsMouse ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.18) : "transparent"
                    Text { anchors.centerIn: parent; text: modelData.e; font.pixelSize: 26; font.family: "Noto Color Emoji" }
                    MouseArea { id: te; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: st.copiaEmoji(modelData.e) }
                }
            }
        }

        // scorciatoie
        ListView {
            id: listaTasti
            visible: st.vista === "scorciatoie"
            width: parent.width; height: parent.height - y
            clip: true; spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: st.tasti.filter(t => !st.q || (t.tasti + " " + t.cosa).toLowerCase().includes(st.q))
            delegate: Row {
                required property var modelData
                width: listaTasti.width; height: 30
                spacing: 12
                Text { width: 230; anchors.verticalCenter: parent.verticalCenter; text: modelData.tasti; elide: Text.ElideRight
                       color: Tema.oroChiaro; font.family: Tema.font; font.pixelSize: 13; font.weight: Font.Medium }
                Text { width: parent.width - 242; anchors.verticalCenter: parent.verticalCenter; text: Lingua.t(modelData.cosa); elide: Text.ElideRight
                       color: Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
            }
        }

        // QR del Wi-Fi
        Column {
            visible: st.vista === "wifi"
            width: parent.width
            spacing: 10
            Text { visible: !st.wifi; text: Lingua.t("Preparo il codice…"); color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13 }
            Text { visible: !!st.wifi && !st.wifi.ok; width: parent.width; wrapMode: Text.WordWrap; text: st.wifi?.messaggio ?? ""
                   color: Tema.allarme; font.family: Tema.font; font.pixelSize: 13 }
            Image {
                visible: !!st.wifi?.ok
                anchors.horizontalCenter: parent.horizontalCenter
                width: 300; height: 300; smooth: false; cache: false
                source: st.wifi?.ok ? "file://" + st.wifi.immagine + "?" + Date.now() : ""
            }
            Text { visible: !!st.wifi?.ok; anchors.horizontalCenter: parent.horizontalCenter
                   text: Lingua.t("Inquadralo col telefono per entrare in «%1». Chi vede questo codice ha la password.", st.wifi?.rete ?? "")
                   color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13 }
        }

        // velocità
        Column {
            visible: st.vista === "velocita"
            width: parent.width
            spacing: 14
            Row {
                spacing: 10
                Pulsante { pieno: true; icona: "wifi"; testo: reteP.running ? Lingua.t("Provo internet…") : Lingua.t("Prova internet"); attivo: !reteP.running
                           onPremuto: { st.rete = null; reteP.running = true; } }
                Text { anchors.verticalCenter: parent.verticalCenter; color: st.rete?.errore ? Tema.allarme : Tema.testo; font.family: Tema.font; font.pixelSize: 15
                       text: !st.rete ? "" : st.rete.errore ? st.rete.errore
                             : Lingua.t("↓ %1 Mbit/s   ↑ %2 Mbit/s   risposta %3 ms", st.rete.giu_mbit, st.rete.su_mbit, st.rete.ping_ms) }
            }
            Row {
                spacing: 10
                Pulsante { pieno: true; icona: "hard_drive"; testo: discoP.running ? Lingua.t("Provo il disco…") : Lingua.t("Prova il disco"); attivo: !discoP.running
                           onPremuto: { st.disco = null; discoP.running = true; } }
                Text { anchors.verticalCenter: parent.verticalCenter; color: Tema.testo; font.family: Tema.font; font.pixelSize: 15
                       text: st.disco ? Lingua.t("scrive %1 MB/s   legge %2 MB/s", st.disco.scrive_mb, st.disco.legge_mb) : "" }
            }
            Text { width: parent.width; wrapMode: Text.WordWrap; color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
                   text: Lingua.t("Internet: scarica ~25 MB e ne manda ~10 ai server di Cloudflare. Disco: scrive e rilegge 512 MB nella tua home, poi li cancella.") }
        }
    }
}
