// Impostazioni → Bluetooth: acceso o spento, i dispositivi collegati, quelli conosciuti e la ricerca di quelli
// vicini. Lo stato arriva da Quickshell.Bluetooth (il D-Bus di BlueZ): non serve un comando esterno e si aggiorna
// da solo quando qualcosa cambia. Se il PC non ha il bluetooth la pagina lo dice (bluez lo mette cielos-hardware,
// Impostazioni → Hardware).
import QtQuick
import Quickshell
import Quickshell.Bluetooth as Bt
import qs.servizi

Column {
    id: p
    width: parent ? parent.width : 500
    spacing: 10

    readonly property var adattatore: Bt.Bluetooth.defaultAdapter
    readonly property bool presente: !!adattatore
    readonly property bool acceso: !!adattatore && adattatore.enabled
    // i collegati per primi, poi i conosciuti, e in fondo quelli visti con una ricerca
    readonly property var dispositivi: {
        const d = adattatore ? (adattatore.devices?.values ?? []) : [];
        return [...d].sort((x, y) => (y.connected ? 1 : 0) - (x.connected ? 1 : 0) || (y.paired ? 1 : 0) - (x.paired ? 1 : 0));
    }
    readonly property int collegati: dispositivi.filter(d => d.connected).length

    // la ricerca non resta accesa per sempre: BlueZ continua a scandagliare finché qualcuno glielo dice, e la
    // radio resta accesa per niente
    function cerca() {
        if (!adattatore || adattatore.discovering) return;
        adattatore.discovering = true;
        fineCerca.restart();
    }
    Timer { id: fineCerca; interval: 15000; onTriggered: if (p.adattatore) p.adattatore.discovering = false }
    onVisibleChanged: if (!visible && p.adattatore) p.adattatore.discovering = false

    function icona(d) {
        const i = d?.icon ?? "";
        if (i.startsWith("audio-headset")) return "headset";
        if (i.startsWith("audio-headphones")) return "headphones";
        if (i.startsWith("audio")) return "speaker";
        if (i.startsWith("input-keyboard")) return "keyboard";
        if (i.startsWith("input-mouse")) return "mouse";
        if (i.startsWith("input-gaming")) return "sports_esports";
        if (i.startsWith("input-tablet")) return "tablet";
        if (i.startsWith("phone")) return "smartphone";
        if (i.startsWith("computer")) return "laptop";
        if (i.startsWith("printer")) return "print";
        return "bluetooth";
    }
    function stato(d) {
        if (d.pairing) return Lingua.t("accoppiamento in corso…");
        if (d.batteryAvailable) return (d.connected ? Lingua.t("collegato") : Lingua.t("conosciuto")) +
                                       " · " + Lingua.t("batteria %1%", Math.round(d.battery * 100));
        return d.connected ? Lingua.t("collegato") : d.paired ? Lingua.t("conosciuto") : Lingua.t("non accoppiato");
    }

    // ── acceso o spento ──
    Titoletto { testo: Lingua.t("Bluetooth")
                spiega: Lingua.t("Cuffie, controller, tastiere. Un clic per collegare, e la batteria dei dispositivi che la dicono.") }
    Interruttore {
        width: parent.width
        testo: Lingua.t("Bluetooth")
        spiega: !p.presente ? Lingua.t("Questo PC non ha il bluetooth.")
              : p.acceso ? Lingua.t("acceso") + (p.collegati > 0 ? " · " + Lingua.t("%1 collegati", p.collegati) : "")
              : Lingua.t("spento")
        acceso: p.acceso
        attivo: p.presente
        onCambiato: v => { if (p.adattatore) p.adattatore.enabled = v; }
    }
    Text {
        visible: !p.presente
        width: parent.width; wrapMode: Text.WordWrap
        text: Lingua.t("Se il PC ha il bluetooth ma CielOS non lo vede, manca bluez: si installa da Impostazioni → Hardware.")
        color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
    }

    // ── i dispositivi ──
    Row {
        visible: p.presente && p.dispositivi.length > 0
        width: parent.width
        spacing: 8
        Titoletto { width: parent.width - 130; testo: Lingua.t("Dispositivi")
                    spiega: p.acceso ? Lingua.t("I collegati per primi; un clic per collegare o staccare. «Dimentica» lo toglie dai conosciuti.")
                                      : Lingua.t("Il bluetooth è spento.") }
        Chip { anchors.verticalCenter: parent.verticalCenter
               testo: p.adattatore?.discovering ? Lingua.t("Cerco…") : Lingua.t("Cerca")
               icona: "bluetooth_searching"
               onPremuto: p.cerca() }
    }
    Text {
        visible: p.presente && p.acceso && p.dispositivi.length === 0
        width: parent.width; wrapMode: Text.WordWrap
        text: Lingua.t("Nessun dispositivo conosciuto. «Cerca» trova quelli vicini: accendili e mettili in accoppiamento.")
        color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
    }
    Repeater {
        model: p.dispositivi
        Rectangle {
            required property var modelData
            width: p.width; height: 58; radius: Tema.raggio
            color: modelData.connected ? Tema.accentoMedio : Tema.conAlfa(Tema.oro, 0.06)
            border.width: 1
            border.color: modelData.connected ? Tema.alfa(Tema.oro, 0.55) : Tema.bordoTenue
            Row {
                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                spacing: 10
                Text { anchors.verticalCenter: parent.verticalCenter; text: p.icona(modelData)
                       font.family: Tema.icone; font.pixelSize: 21
                       color: modelData.connected ? Tema.oro : Tema.oroChiaro }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text { width: p.width - 300; elide: Text.ElideRight
                           text: modelData.name || modelData.address
                           color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.Medium }
                    Text { text: modelData.address + "  ·  " + p.stato(modelData)
                           color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12 }
                }
            }
            Row {
                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 6
                Chip {
                    visible: modelData.connected || modelData.paired
                    testo: modelData.connected ? Lingua.t("Stacca") : Lingua.t("Collega")
                    icona: modelData.connected ? "link_off" : "link"
                    acceso: modelData.connected
                    onPremuto: modelData.connected ? modelData.disconnect() : modelData.connect()
                }
                Chip {
                    visible: !modelData.connected && !modelData.paired
                    testo: modelData.pairing ? Lingua.t("Accoppio…") : Lingua.t("Accoppia")
                    icona: "add_link"
                    onPremuto: modelData.pair()
                }
                Chip {
                    visible: modelData.paired
                    testo: Lingua.t("Dimentica"); icona: "delete"
                    onPremuto: modelData.forget()
                }
            }
        }
    }

    // ── come si usa ──
    Text {
        visible: p.presente && p.dispositivi.length > 0
        width: parent.width; wrapMode: Text.WordWrap
        text: Lingua.t("La prima volta un dispositivo va accoppiato (qualcuno chiede di confermare sul dispositivo stesso); dopo si collega da solo quando è acceso.")
        color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
    }
}
