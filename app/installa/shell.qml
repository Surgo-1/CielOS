// L'installatore di CielOS (dalla ISO). Sette pagine: benvenuto, disco, tu, lingua e tastiera, Ciel, riepilogo
// (con la conferma esplicita: il disco viene cancellato), installazione (le fasi e il registro), fine.
// Il lavoro lo fa cielos-installa-sistema (da root, con sudo: sulla ISO l'utente live non ha password).
// La password non passa mai sulla riga di comando: va in un file 0600 che il motore legge e cancella.
//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import qs.servizi

ShellRoot {
    id: app
    property int pagina: 0
    property var dischi: []
    property string disco: ""
    property string nome: ""
    property string utente: ""
    property string password: ""
    property string password2: ""
    property string host: "cielos"
    property string fuso: "Europe/Rome"
    property string tastiera: Lingua.sistema === "en" ? "us" : "it"
    property string lingua: Lingua.sistema === "en" ? "en_US.UTF-8" : "it_IT.UTF-8"
    // la lingua scelta vale subito anche per l'installatore; con l'inglese la tastiera passa all'americana, se non l'hai già scelta tu
    property bool tastieraToccata: false
    onLinguaChanged: { Lingua.forzata = lingua.startsWith("it") ? "it" : "en"; if (!tastieraToccata) tastiera = lingua.startsWith("it") ? "it" : "us"; }
    property bool ciel: true
    property bool capito: false
    property bool internet: false
    property bool uefi: false
    property int fase: 0
    property int fasi: 10
    property string testoFase: ""
    property var registro: []
    property string esito: ""                    // "", "fatto", "errore"
    property string errore: ""
    property var fusi: []
    readonly property var d: dischi.find(x => x.path === disco) ?? null
    readonly property bool utenteOk: /^[a-z_][a-z0-9_-]{0,31}$/.test(utente)
    readonly property bool passwordOk: password.length >= 4 && password === password2
    readonly property var pagine: ["Benvenuto", "Disco", "Tu", "Lingua", "Ciel", "Riepilogo", "Installazione", "Fatto"]
    readonly property bool puoiAvanti: [internet, disco !== "", nome.trim() !== "" && utenteOk && passwordOk && host !== "",
                                        true, true, capito, false, false][pagina]

    function gb(b) { return (b / 1e9).toFixed(0) + " GB"; }
    // il nome utente nasce dal nome (minuscolo, senza accenti e spazi), finché non lo cambi tu
    property bool utenteToccato: false
    onNomeChanged: if (!utenteToccato) utente = nome.toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/[^a-z0-9]/g, "").slice(0, 20)

    // ── cosa c'è: dischi, Internet, UEFI, fusi ───────────────────────────────────────────────────────────────
    Process {
        id: leggiDischi
        running: true
        command: ["sh", "-c", "lsblk -J -b -d -o NAME,PATH,SIZE,MODEL,TRAN,RM,TYPE,RO; echo; findmnt -no SOURCE /run/archiso/bootmnt 2>/dev/null; " +
                  "[ -d /sys/firmware/efi ] && echo UEFI"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parti = text.split("\n}\n");
                let l = [];
                try { l = JSON.parse(parti[0] + "\n}").blockdevices; } catch (e) {}
                const resto = (parti[1] ?? "").trim().split("\n");
                const live = (resto[0] ?? "").replace(/p?\d+$/, "");
                app.uefi = resto.includes("UEFI");
                app.dischi = l.filter(x => x.type === "disk" && !x.ro && x.path !== live && x.size > 16e9);
                if (app.dischi.length === 1) app.disco = app.dischi[0].path;
            }
        }
    }
    Process {
        id: rete
        running: true
        command: ["sh", "-c", "ping -c1 -W3 archlinux.org >/dev/null 2>&1 && echo si"]
        stdout: StdioCollector { onStreamFinished: app.internet = text.trim() === "si" }
    }
    Timer { running: !app.internet && app.pagina === 0; interval: 4000; repeat: true; onTriggered: if (!rete.running) rete.running = true }
    Process {
        running: true
        command: ["timedatectl", "list-timezones"]
        stdout: StdioCollector { onStreamFinished: app.fusi = text.trim().split("\n") }
    }

    // ── l'installazione ──────────────────────────────────────────────────────────────────────────────────────
    Process {
        id: scriviPassword
        command: ["sh", "-c", "umask 077; cat > /tmp/cielos-installa.pw"]
        stdinEnabled: true
        onStarted: { write(app.daScrivere); app.daScrivere = ""; stdinEnabled = false; }
        onExited: avvia.running = true
    }
    Process {
        id: scriviConfig
        command: ["sh", "-c", "umask 077; cat > /tmp/cielos-installa.json"]
        stdinEnabled: true
        onStarted: {
            write(JSON.stringify({ disco: app.disco, utente: app.utente, nome: app.nome.trim(), password_file: "/tmp/cielos-installa.pw",
                                   host: app.host, fuso: app.fuso, tastiera: app.tastiera, lingua: app.lingua, ciel: app.ciel }));
            stdinEnabled = false;
        }
        onExited: scriviPassword.running = true
    }
    Process {
        id: avvia
        command: ["sudo", "-n", Percorsi.bin("cielos-installa-sistema"), "/tmp/cielos-installa.json"]
        stdout: SplitParser {
            onRead: riga => {
                app.registro = app.registro.concat([riga]).slice(-300);
                const m = riga.match(/^PASSO (\d+)\/(\d+) (.*)$/);
                if (m) { app.fase = Number(m[1]); app.fasi = Number(m[2]); app.testoFase = m[3]; }
                else if (riga === "FATTO") { app.esito = "fatto"; app.pagina = 7; }
                else if (riga.startsWith("ERRORE")) { app.esito = "errore"; app.errore = riga.slice(7); }
            }
        }
        onExited: (codice) => { if (app.esito === "" ) { app.esito = codice === 0 ? "fatto" : "errore"; if (codice === 0) app.pagina = 7; else app.errore = app.errore || Lingua.t("uscito con errore %1", codice); } }
    }
    property string daScrivere: ""               // la password, solo finché non è nel file (poi vuota)
    function installa() {
        app.daScrivere = app.password;
        app.password = ""; app.password2 = "";
        app.pagina = 6;
        scriviConfig.running = true;                 // → scriviPassword → avvia
    }

    FloatingWindow {
        title: Lingua.t("Installa CielOS")
        implicitWidth: 980
        implicitHeight: 680
        color: Tema.fondo
        visible: true
        onVisibleChanged: if (!visible && app.pagina !== 6) Qt.quit()

        // a sinistra: le pagine
        Rectangle {
            id: lato
            width: 230; height: parent.height
            color: Qt.rgba(0, 0, 0, 0.18)
            Image { x: 24; y: 28; width: 150; height: 46; fillMode: Image.PreserveAspectFit; sourceSize.width: 300
                    source: "file://" + Percorsi.radice + "/grafica/logo-completo.png" }
            Column {
                x: 16; y: 110; width: parent.width - 32; spacing: 4
                Repeater {
                    model: app.pagine
                    Rectangle {
                        required property string modelData
                        required property int index
                        width: parent.width; height: 36; radius: 10
                        color: app.pagina === index ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.18) : "transparent"
                        Row {
                            x: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                            Text { text: index < app.pagina ? "check_circle" : index === app.pagina ? "radio_button_checked" : "radio_button_unchecked"
                                   font.family: Tema.icone; font.pixelSize: 18; color: index <= app.pagina ? Tema.oro : Tema.tenue }
                            Text { text: Lingua.t(modelData); color: index === app.pagina ? Tema.testo : Tema.tenue; font.family: Tema.font; font.pixelSize: 14
                                   anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }
        }

        Item {
            id: corpo
            anchors { left: lato.right; right: parent.right; top: parent.top; bottom: piede.top; margins: 32 }

            component Titolo: Text { color: Tema.testo; font.family: Tema.font; font.pixelSize: 26; font.weight: Font.Medium; width: corpo.width; wrapMode: Text.Wrap }
            component Spiega: Text { color: Tema.tenue; font.family: Tema.font; font.pixelSize: 14; width: corpo.width; wrapMode: Text.Wrap; lineHeight: 1.2 }
            component Campo: Column {
                property alias testo: inp.text
                property string etichetta
                property bool segreto: false
                property bool errato: false
                property string suggerimento
                signal modificato()
                spacing: 6
                width: 380
                Text { text: parent.etichetta; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
                Rectangle {
                    width: parent.width; height: 40; radius: 12
                    color: Qt.rgba(1, 1, 1, 0.05); border.color: parent.errato ? Tema.allarme : inp.activeFocus ? Tema.oro : Tema.bordo
                    TextInput {
                        id: inp
                        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: parent.parent.segreto ? TextInput.Password : TextInput.Normal
                        color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; clip: true; selectByMouse: true
                        onTextEdited: parent.parent.modificato()
                        Text { visible: !parent.text; anchors.verticalCenter: parent.verticalCenter; text: parent.parent.parent.suggerimento; color: Tema.tenue; font: parent.font }
                    }
                }
            }
            component Scelta: Rectangle {
                property string testo
                property string sotto
                property string icona
                property bool acceso
                signal premuto()
                width: corpo.width; height: sotto ? 62 : 46; radius: 14
                color: acceso ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.15) : ms.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(1, 1, 1, 0.025)
                border.color: acceso ? Tema.oro : Tema.bordo
                Text { x: 16; anchors.verticalCenter: parent.verticalCenter; text: parent.icona; font.family: Tema.icone; font.pixelSize: 24; color: Tema.oroChiaro }
                Column {
                    x: 54; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 70
                    Text { text: parent.parent.testo; color: Tema.testo; font.family: Tema.font; font.pixelSize: 15 }
                    Text { visible: parent.parent.sotto !== ""; width: parent.width; elide: Text.ElideRight; text: parent.parent.sotto; color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12 }
                }
                MouseArea { id: ms; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.premuto() }
            }

            // 0 · benvenuto
            Column {
                visible: app.pagina === 0; spacing: 16; width: parent.width
                Titolo { text: Lingua.t("Benvenuto in CielOS") }
                Row { spacing: 8
                    Repeater { model: [["it_IT.UTF-8", "Italiano"], ["en_US.UTF-8", "English"]]
                        Scelta { required property var modelData; width: 200; icona: "translate"; testo: modelData[1]; acceso: app.lingua === modelData[0]; onPremuto: app.lingua = modelData[0] } } }
                Spiega { text: Lingua.t("CielOS è Arch Linux costruito intorno a Ciel: leggero, che si aggiorna a ondate e torna indietro da solo se un aggiornamento lo rompe, con i driver giusti per il tuo PC e niente di superfluo.\n\nL'installazione richiede pochi minuti. Puoi anche continuare a provarlo dalla chiavetta: chiudi questa finestra (la ritrovi nel lanciatore, «Installa CielOS»).") }
                Row {
                    spacing: 10
                    Text { text: app.internet ? "wifi" : "wifi_off"; font.family: Tema.icone; font.pixelSize: 22; color: app.internet ? "#7fe0a8" : Tema.allarme }
                    Spiega { width: corpo.width - 40; text: app.internet ? Lingua.t("Connesso a Internet: i pacchetti arrivano aggiornati.") : Lingua.t("Serve Internet: collega il cavo, o scegli il Wi-Fi dall'icona della rete nella barra. Riprovo da solo.") }
                }
                Spiega { text: Lingua.t("Avvio: %1. Il disco resterà avviabile in entrambi i modi.", app.uefi ? "UEFI" : "BIOS (legacy)") }
            }
            // 1 · disco
            Column {
                visible: app.pagina === 1; spacing: 12; width: parent.width
                Titolo { text: Lingua.t("Su quale disco?") }
                Spiega { text: Lingua.t("CielOS usa il disco intero: tutto quello che c'è sopra verrà cancellato. La chiavetta da cui stai provando CielOS non compare.") }
                Repeater {
                    model: app.dischi
                    Scelta {
                        required property var modelData
                        icona: modelData.tran === "usb" ? "usb" : modelData.tran === "nvme" ? "memory" : "hard_drive"
                        testo: (modelData.model || modelData.name) + " — " + app.gb(modelData.size)
                        sotto: modelData.path + (modelData.tran ? " · " + modelData.tran.toUpperCase() : "")
                        acceso: app.disco === modelData.path
                        onPremuto: app.disco = modelData.path
                    }
                }
                Spiega { visible: app.dischi.length === 0; text: Lingua.t("Nessun disco adatto (servono almeno 16 GB).") }
            }
            // 2 · tu
            Column {
                visible: app.pagina === 2; spacing: 14; width: parent.width
                Titolo { text: Lingua.t("Chi sei?") }
                Campo { etichetta: Lingua.t("Il tuo nome"); suggerimento: Lingua.t("Mario Rossi"); testo: app.nome; onModificato: app.nome = testo }
                Campo { etichetta: Lingua.t("Il nome per entrare (minuscolo, senza spazi)"); suggerimento: "mario"; testo: app.utente
                        errato: app.utente !== "" && !app.utenteOk; onModificato: { app.utenteToccato = true; app.utente = testo; } }
                Campo { etichetta: Lingua.t("Password"); segreto: true; testo: app.password; onModificato: app.password = testo }
                Campo { etichetta: Lingua.t("Ancora la password"); segreto: true; testo: app.password2; errato: app.password2 !== "" && app.password !== app.password2
                        onModificato: app.password2 = testo }
                Spiega { visible: app.password !== "" && app.password.length < 4; text: Lingua.t("Almeno 4 caratteri (meglio di più).") }
                Campo { etichetta: Lingua.t("Il nome di questo PC"); suggerimento: "cielos"; testo: app.host; onModificato: app.host = testo.replace(/[^A-Za-z0-9-]/g, "") }
            }
            // 3 · lingua
            Column {
                visible: app.pagina === 3; spacing: 12; width: parent.width
                Titolo { text: Lingua.t("Lingua, tastiera e ora") }
                Spiega { text: Lingua.t("Lingua del sistema") }
                Row { spacing: 8
                    Repeater { model: [["it_IT.UTF-8", "Italiano"], ["en_US.UTF-8", "English"]]
                        Scelta { required property var modelData; width: 200; icona: "translate"; testo: modelData[1]; acceso: app.lingua === modelData[0]; onPremuto: app.lingua = modelData[0] } } }
                Spiega { text: Lingua.t("Tastiera") }
                Flow { width: parent.width; spacing: 8
                    Repeater { model: [["it", Lingua.t("Italiana")], ["us", Lingua.t("Americana")], ["gb", Lingua.t("Inglese")], ["de", Lingua.t("Tedesca")], ["fr", Lingua.t("Francese")], ["es", Lingua.t("Spagnola")], ["ch", Lingua.t("Svizzera")]]
                        Scelta { required property var modelData; width: 150; icona: "keyboard"; testo: modelData[1]; acceso: app.tastiera === modelData[0]; onPremuto: { app.tastieraToccata = true; app.tastiera = modelData[0]; } } } }
                Spiega { text: Lingua.t("Fuso orario: ") + app.fuso }
                Rectangle {
                    width: parent.width; height: 180; radius: 12; color: Qt.rgba(1, 1, 1, 0.03); border.color: Tema.bordo
                    ListView {
                        anchors { fill: parent; margins: 4 }
                        clip: true; model: app.fusi
                        onCountChanged: positionViewAtIndex(Math.max(0, app.fusi.indexOf(app.fuso)), ListView.Center)
                        delegate: Rectangle {
                            required property string modelData
                            width: ListView.view.width; height: 30; radius: 8
                            color: app.fuso === modelData ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.2) : "transparent"
                            Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: modelData.replace(/_/g, " "); color: Tema.testo; font.family: Tema.font; font.pixelSize: 13 }
                            MouseArea { anchors.fill: parent; onClicked: app.fuso = modelData }
                        }
                    }
                }
            }
            // 4 · Ciel
            Column {
                visible: app.pagina === 4; spacing: 14; width: parent.width
                Titolo { text: Lingua.t("Ciel, l'assistente") }
                Spiega { text: Lingua.t("Ciel risponde in una casella sullo schermo (Super+J) e fa le cose sul PC per te. Non ha modelli di serie: la «mente» la scegli dopo, adatta al tuo hardware, se e quando vuoi. La voce è un'opzione che si accende dopo.") }
                Scelta { icona: "auto_awesome"; testo: Lingua.t("Sì, installa Ciel"); sotto: Lingua.t("Al primo accesso si prepara (circa 340 MB di librerie; ti dice tutto prima)"); acceso: app.ciel; onPremuto: app.ciel = true }
                Scelta { icona: "block"; testo: Lingua.t("No, solo CielOS"); sotto: Lingua.t("Puoi installarla quando vuoi: cielos-ciel"); acceso: !app.ciel; onPremuto: app.ciel = false }
            }
            // 5 · riepilogo
            Column {
                visible: app.pagina === 5; spacing: 10; width: parent.width
                Titolo { text: Lingua.t("Pronto a installare") }
                Repeater {
                    model: [["hard_drive", Lingua.t("Disco"), app.d ? (app.d.model || app.d.name) + " (" + app.disco + ", " + app.gb(app.d.size) + ")" + Lingua.t(" — sarà cancellato") : ""],
                            ["person", Lingua.t("Utente"), app.nome + " (" + app.utente + ")"], ["computer", Lingua.t("Nome del PC"), app.host],
                            ["translate", Lingua.t("Lingua e tastiera"), (app.lingua.startsWith("it") ? "Italiano" : "English") + Lingua.t(", tastiera ") + app.tastiera],
                            ["schedule", Lingua.t("Fuso orario"), app.fuso], ["auto_awesome", "Ciel", app.ciel ? Lingua.t("sì") : Lingua.t("no")],
                            ["memory", "Driver", Lingua.t("solo quelli di questo PC (li sceglie CielOS guardando l'hardware)")]]
                    Row {
                        required property var modelData
                        spacing: 12
                        Text { text: modelData[0]; font.family: Tema.icone; font.pixelSize: 20; color: Tema.oroChiaro }
                        Text { width: 150; text: modelData[1]; color: Tema.tenue; font.family: Tema.font; font.pixelSize: 14 }
                        Text { width: corpo.width - 200; wrapMode: Text.Wrap; text: modelData[2]; color: Tema.testo; font.family: Tema.font; font.pixelSize: 14 }
                    }
                }
                Item { width: 1; height: 8 }
                Scelta { icona: app.capito ? "check_box" : "check_box_outline_blank"; testo: Lingua.t("Ho capito: tutto quello che c'è su %1 sarà cancellato", app.disco)
                         acceso: app.capito; onPremuto: app.capito = !app.capito }
            }
            // 6 · installazione
            Column {
                visible: app.pagina === 6; spacing: 14; width: parent.width
                Titolo { text: app.esito === "errore" ? Lingua.t("Qualcosa non è andato") : Lingua.t("Installo CielOS…") }
                Spiega { text: app.esito === "errore" ? app.errore : app.testoFase }
                Rectangle {
                    width: parent.width; height: 10; radius: 5; color: Qt.rgba(1, 1, 1, 0.08)
                    Rectangle { width: parent.width * app.fase / Math.max(1, app.fasi); height: parent.height; radius: 5
                                color: app.esito === "errore" ? Tema.allarme : Tema.oro
                                Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } } }
                }
                Rectangle {
                    width: parent.width; height: 320; radius: 12; color: Qt.rgba(0, 0, 0, 0.3); border.color: Tema.bordo
                    ListView {
                        id: log
                        anchors { fill: parent; margins: 10 }
                        clip: true; model: app.registro
                        onCountChanged: positionViewAtEnd()
                        delegate: Text { required property string modelData; width: log.width; wrapMode: Text.WrapAnywhere; text: modelData
                                         color: modelData.startsWith("PASSO") ? Tema.oroChiaro : modelData.startsWith("ERRORE") ? Tema.allarme : Tema.tenue
                                         font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11 }
                    }
                }
                Spiega { visible: app.esito === "errore"; text: Lingua.t("Il registro completo è in /var/log/cielos-installa.log. Puoi tornare indietro e riprovare.") }
            }
            // 7 · fatto
            Column {
                visible: app.pagina === 7; spacing: 16; width: parent.width
                Titolo { text: Lingua.t("CielOS è installato") }
                Spiega { text: Lingua.t(app.ciel ? "Togli la chiavetta e riavvia. Al primo accesso CielOS prepara il tuo desktop e ti propone di installare Ciel."
                                                 : "Togli la chiavetta e riavvia. Al primo accesso CielOS prepara il tuo desktop.") + "\n\n" +
                               Lingua.t("Scorciatoie da ricordare: Super+Spazio il lanciatore, Super+J la casella di Ciel, Super+A il riquadro (modelli), Super+I le impostazioni, Super+E i file.") }
            }
        }

        // in fondo: indietro / avanti / installa / riavvia
        Item {
            id: piede
            anchors { left: lato.right; right: parent.right; bottom: parent.bottom }
            height: 72
            component Bottone: Rectangle {
                property string testo
                property bool primario: false
                property bool attivo: true
                signal premuto()
                width: tb.implicitWidth + 44; height: 42; radius: 21
                color: !attivo ? Qt.rgba(1, 1, 1, 0.04) : primario ? Tema.oro : mb.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.06)
                Text { id: tb; anchors.centerIn: parent; text: parent.testo; color: parent.primario && parent.attivo ? Tema.fondo : parent.attivo ? Tema.testo : Tema.tenue
                       font.family: Tema.font; font.pixelSize: 15; font.weight: Font.Medium }
                MouseArea { id: mb; anchors.fill: parent; hoverEnabled: true; enabled: parent.attivo; cursorShape: Qt.PointingHandCursor; onClicked: parent.premuto() }
            }
            Row {
                anchors { right: parent.right; rightMargin: 32; verticalCenter: parent.verticalCenter }
                spacing: 10
                Bottone { visible: app.pagina > 0 && app.pagina < 6 || app.esito === "errore"; testo: Lingua.t("Indietro")
                          onPremuto: { if (app.esito === "errore") { app.esito = ""; app.registro = []; app.fase = 0; app.pagina = 5; } else app.pagina-- } }
                Bottone { visible: app.pagina < 5; testo: Lingua.t("Avanti"); primario: true; attivo: app.puoiAvanti; onPremuto: app.pagina++ }
                Bottone { visible: app.pagina === 5; testo: Lingua.t("Installa"); primario: true; attivo: app.capito; onPremuto: app.installa() }
                Bottone { visible: app.pagina === 7; testo: Lingua.t("Riavvia"); primario: true; onPremuto: Quickshell.execDetached(["systemctl", "reboot"]) }
            }
        }
    }
}
