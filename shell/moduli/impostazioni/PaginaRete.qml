// Impostazioni → Rete: il Wi-Fi (acceso/spento, reti vicine, password), il cavo, gli indirizzi e il DNS di tutto
// il PC. Il motore è cielrete (NetworkManager); il DNS passa dal guardiano, che chiede la password.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.servizi

Column {
    id: p
    width: parent ? parent.width : 500
    spacing: 10

    property var stato: null
    property var reti: []
    property string scelta: ""                 // la rete di cui si sta scrivendo la password
    property string password: ""
    property string avviso: ""
    property bool errore: false
    readonly property var w: stato?.wifi ?? ({})
    readonly property var c: stato?.cavo ?? ({})
    readonly property var connessioni: stato?.connessioni ?? []
    readonly property var salvate: stato?.salvate ?? []
    readonly property string dns: stato?.dns ?? "automatico"

    function aggiorna() { if (!statoP.running) statoP.running = true; }
    function cerca(rescan) {
        if (retiP.running) return;
        retiP.command = [Percorsi.bin("cielrete"), "reti", "--json"].concat(rescan ? ["--rescan"] : []);
        retiP.running = true;
    }
    function comando(...a) { cmd.args = a; cmd.running = true; }
    function icona(s) {
        return s >= 75 ? "signal_wifi_4_bar" : s >= 50 ? "network_wifi_3_bar"
             : s >= 25 ? "wifi_2_bar" : s > 0 ? "wifi_1_bar" : "signal_wifi_0_bar";
    }
    function collega(rete) {
        if (rete.collegata || collegamento.running) return;
        p.avviso = ""; p.errore = false;
        if (rete.sicurezza === "" || p.salvate.indexOf(rete.ssid) >= 0) {
            p.scelta = "";
            collegamento.command = [Percorsi.bin("cielrete"), "connetti", rete.ssid, "--json"];
            collegamento.running = true;
        } else {
            p.scelta = rete.ssid;
            p.password = "";
            Qt.callLater(() => campo.forceActiveFocus());
        }
    }
    function conPassword() {
        const pw = p.password;
        if (!p.scelta || !pw || collegamento.running) return;
        p.avviso = ""; p.errore = false;
        p.password = "";
        collegamento.connettiConPassword(p.scelta, pw);
    }

    Component.onCompleted: aggiorna()
    Timer { running: p.visible; interval: 20000; repeat: true; onTriggered: { p.aggiorna(); if (p.w.acceso) p.cerca(false); } }

    Process {
        id: statoP
        command: [Percorsi.bin("cielrete"), "stato", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    p.stato = r;
                    if (!r.wifi?.acceso) p.reti = [];
                    else if (p.reti.length === 0 && !retiP.running) p.cerca(false);
                } catch (e) { /* nmcli non risponde: resta com'era */ }
            }
        }
    }
    Process {
        id: retiP
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    p.reti = r.reti ?? [];
                    if (r.ok === false) { p.avviso = r.messaggio ?? ""; p.errore = true; }
                } catch (e) { p.reti = []; }
            }
        }
    }
    Process {
        id: cmd
        property var args: []
        command: [Percorsi.bin("cielrete"), ...args, "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    p.errore = r.ok === false;
                    p.avviso = r.messaggio ?? "";
                } catch (e) { p.errore = true; p.avviso = text.trim(); }
            }
        }
        onExited: {
            p.aggiorna();
            if (cmd.args[0] === "wifi" && cmd.args[1] === "on") p.cerca(false);
        }
    }
    Process {
        id: collegamento
        command: []
        stdinEnabled: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    p.errore = r.ok === false;
                    p.avviso = r.messaggio ?? "";
                } catch (e) { p.errore = true; p.avviso = text.trim(); }
            }
        }
        function connettiConPassword(ssid, pw) {
            p.passwordDaScrivere = pw;
            command = [Percorsi.bin("cielrete"), "connetti", ssid, "--password-stdin", "--json"];
            stdinEnabled = true;
            running = true;
        }
        onStarted: {
            if (p.passwordDaScrivere) { write(p.passwordDaScrivere + "\n"); p.passwordDaScrivere = ""; }
            stdinEnabled = false;
        }
        onExited: {
            if (!p.errore) p.scelta = "";
            p.aggiorna();
            p.cerca(false);
            if (p.scelta) Qt.callLater(() => campo.forceActiveFocus());
        }
    }
    property string passwordDaScrivere: ""

    // ── Wi-Fi ──
    Titoletto { testo: Lingua.t("Wi-Fi"); spiega: Lingua.t("Scegli la rete dall'elenco: se è la prima volta e serve una password, la scrivi qui. Le reti già conosciute si aprono da sole.") }
    Interruttore {
        width: parent.width
        testo: Lingua.t("Wi-Fi")
        spiega: p.w.presente ? (p.w.acceso ? Lingua.t("acceso") : Lingua.t("spento")) : Lingua.t("Questo PC non ha il Wi-Fi.")
        acceso: p.w.acceso ?? false
        attivo: (p.w.presente ?? false) && !cmd.running
        onCambiato: v => p.comando("wifi", v ? "on" : "off")
    }

    // le connessioni attive: nome, indirizzo, e «Scollega»
    Repeater {
        model: p.connessioni
        Rectangle {
            required property var modelData
            width: p.width; height: 58; radius: Tema.raggio
            color: Tema.conAlfa(Tema.oro, 0.06)
            border.width: 1; border.color: Tema.bordoTenue
            Row {
                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                spacing: 10
                Text { anchors.verticalCenter: parent.verticalCenter
                       text: modelData.tipo === "wifi" ? "wifi" : modelData.tipo === "ethernet" ? "lan" : "hub"
                       font.family: Tema.icone; font.pixelSize: 21; color: Tema.oroChiaro }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text { width: p.width - 190; elide: Text.ElideRight; text: modelData.nome
                           color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.Medium }
                    Text { text: (modelData.indirizzo || "—").replace(/\/\d+$/, "") + (modelData.gateway ? "  →  " + modelData.gateway : "")
                           color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12 }
                }
            }
            Chip {
                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                testo: Lingua.t("Scollega"); icona: "link_off"
                onPremuto: p.comando("scollega", modelData.nome)
            }
        }
    }

    // ── le reti vicine ──
    Row {
        width: parent.width
        spacing: 8
        Titoletto { width: parent.width - 120; testo: Lingua.t("Reti vicine")
                    spiega: p.w.acceso ? Lingua.t("Un clic per entrare; la password la chiedi solo la prima volta.") : Lingua.t("Il Wi-Fi è spento.") }
        Chip { anchors.verticalCenter: parent.verticalCenter; testo: retiP.running ? Lingua.t("Cerco…") : Lingua.t("Cerca")
               icona: "refresh"; onPremuto: p.cerca(true) }
    }
    Text {
        visible: (p.w.acceso ?? false) && !retiP.running && p.reti.length === 0
        width: parent.width; wrapMode: Text.WordWrap
        text: Lingua.t("Nessuna rete trovata. Riprova tra poco.")
        color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
    }
    Repeater {
        model: p.reti
        Rectangle {
            required property var modelData
            width: p.width; height: 52; radius: Tema.raggio
            color: modelData.collegata ? Tema.accentoMedio
                 : tocco.containsMouse ? Tema.biancoTenue : Tema.conAlfa(Tema.testo, 0.03)
            border.width: 1
            border.color: modelData.collegata ? Tema.alfa(Tema.oro, 0.55) : Tema.bordoTenue
            Behavior on color { ColorAnimation { duration: Tema.durata } }
            Row {
                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                spacing: 10
                Text { anchors.verticalCenter: parent.verticalCenter; text: p.icona(modelData.segnale)
                       font.family: Tema.icone; font.pixelSize: 21
                       color: modelData.collegata ? Tema.oro : Tema.oroChiaro }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text { width: p.width - 190; elide: Text.ElideRight; text: modelData.ssid
                           color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.Medium }
                    Row {
                        spacing: 5
                        Text { visible: modelData.sicurezza !== ""; text: modelData.sicurezza !== "" ? "lock" : "lock_open"
                               font.family: Tema.icone; font.pixelSize: 12; color: Tema.tenue }
                        Text { text: modelData.sicurezza !== "" ? modelData.sicurezza : Lingua.t("aperta")
                               color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12 }
                    }
                }
            }
            Text {
                anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                text: modelData.collegata ? Lingua.t("in uso") : Lingua.t("collega")
                color: modelData.collegata ? Tema.oro : Tema.tenue; font.family: Tema.font; font.pixelSize: 12
            }
            MouseArea { id: tocco; anchors.fill: parent; hoverEnabled: true
                        cursorShape: modelData.collegata ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: p.collega(modelData) }
        }
    }

    // la password, solo quando serve
    Rectangle {
        visible: p.scelta !== ""
        width: parent.width; height: 46; radius: Tema.raggio
        color: Tema.conAlfa(Tema.oro, 0.06); border.width: 1; border.color: Tema.alfa(Tema.oro, 0.4)
        Row {
            anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
            spacing: 8
            Text { anchors.verticalCenter: parent.verticalCenter; text: "key"; font.family: Tema.icone
                   font.pixelSize: 18; color: Tema.oro }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 250; height: 32; radius: 16
                color: Tema.conAlfa(Tema.testo, 0.06); border.width: 1
                border.color: campo.activeFocus ? Tema.alfa(Tema.oro, 0.7) : Tema.bordoTenue
                TextInput {
                    id: campo
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password; passwordCharacter: "●"
                    color: Tema.testo; font.family: Tema.font; font.pixelSize: 13; clip: true
                    selectionColor: Tema.accentoForte
                    onAccepted: p.conPassword()
                    Text { visible: !parent.text; anchors.verticalCenter: parent.verticalCenter
                           text: Lingua.t("Password di «%1»", p.scelta); color: Tema.tenue; font: parent.font }
                }
            }
            Chip { anchors.verticalCenter: parent.verticalCenter; testo: Lingua.t("Collega"); icona: "login"
                   onPremuto: p.conPassword() }
            Chip { anchors.verticalCenter: parent.verticalCenter; testo: Lingua.t("Annulla")
                   onPremuto: { p.scelta = ""; p.password = ""; } }
        }
    }

    // ── il DNS di tutto il PC ──
    Titoletto { testo: Lingua.t("DNS di tutto il PC")
                spiega: Lingua.t("Vale per ogni rete, anche cambiando Wi-Fi. «Automatico» usa quello che dà il router; Cloudflare, Google e Quad9 sono più veloci e non vendono le tue ricerche.") }
    Row {
        spacing: 8
        Repeater {
            model: [["automatico", Lingua.t("Automatico")], ["cloudflare", "Cloudflare"], ["google", "Google"], ["quad9", "Quad9"]]
            Chip {
                required property var modelData
                testo: modelData[1]
                acceso: p.dns === modelData[0]
                onPremuto: if (p.dns !== modelData[0]) p.comando("dns", modelData[0])
            }
        }
    }
    Text {
        width: parent.width; wrapMode: Text.WordWrap
        text: (p.stato?.dns_attuali ?? []).length ? Lingua.t("Server DNS in uso: %1", (p.stato?.dns_attuali ?? []).join(", "))
                                                   : Lingua.t("Nessun server DNS in uso.")
        color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
    }

    Text {
        visible: p.avviso !== ""
        width: parent.width; wrapMode: Text.WordWrap
        text: p.avviso
        color: p.errore ? Tema.allarme : Tema.tenue
        font.family: Tema.font; font.pixelSize: 12
    }
}
