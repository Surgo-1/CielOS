// La schedina accanto a un'icona della barra: si apre da sola quando il mouse ci si ferma sopra (un attimo,
// così passarci sopra di corsa non apre niente), scivola fuori dalla barra e si chiude poco dopo che il mouse
// è andato via, sia dall'icona sia dalla schedina. Il clic sull'icona la apre o la chiude subito.
// Uso: Schedina { icona: r; titolo: "Rete"; …contenuto… } (l'icona deve avere «sopra»: il mouse è su di lei)
import QtQuick
import Quickshell
import qs.servizi

PopupWindow {
    id: s
    required property Item icona
    property string titolo
    property int larghezza: 310
    property bool aperta: false
    property int spaziatura: 10
    property int attesa: 200            // quanto resta aperta dopo che il mouse è andato via (ms)
    property bool inAlto: false         // per le icone all'inizio della barra (in cima o a sinistra): si allinea lì
    default property alias contenuto: colonna.data
    readonly property bool sopra: icona.sopra || dentro.hovered

    function alterna() { aperta = !aperta; }
    // per guardarle tutte insieme in prova: CIELOS_PROVA=1 CIELOS_SCHEDINE=1
    readonly property string _v: Quickshell.env("CIELOS_SCHEDINE") ?? ""      // "1": tutte; oppure un titolo
    readonly property bool vetrina: Pannelli.prova && (_v === "1" || (_v !== "" && _v === titolo))
    Timer { running: s.vetrina; interval: 1500; onTriggered: s.aperta = true }

    // dove si apre dipende da dove sta la barra: sempre verso il centro dello schermo
    readonly property string lato: Tema.lato
    anchor.item: icona
    anchor.rect.x: lato === "sinistra" ? icona.width + 6 : lato === "destra" ? -implicitWidth - 6
                 : inAlto ? 0 : icona.width - implicitWidth
    anchor.rect.y: lato === "alto" ? icona.height + 6 : lato === "basso" ? -implicitHeight - 6
                 : inAlto ? 0 : icona.height - implicitHeight
    implicitWidth: larghezza + (Tema.orizzontale ? 0 : 8)
    implicitHeight: colonna.implicitHeight + 36 + (Tema.orizzontale ? 8 : 0)
    color: "transparent"
    visible: aperta || fondo.opacity > 0

    // una alla volta: quando se ne apre un'altra questa si chiude subito; e se un'altra è già aperta, passando
    // a quest'icona si apre senza aspettare (come i menu di un'applicazione)
    onApertaChanged: if (aperta && !vetrina) Pannelli.schedina = s
    Connections {
        target: Pannelli
        function onSchedinaChanged() { if (Pannelli.schedina !== s && !s.vetrina) s.aperta = false; }
    }
    Timer {                              // ci si ferma sopra: si apre
        running: s.icona.sopra && !s.aperta
        interval: Pannelli.schedina && Pannelli.schedina !== s && Pannelli.schedina.aperta ? 0 : 220
        onTriggered: s.aperta = true
    }
    Timer {                              // il mouse è andato via: si chiude
        running: s.aperta && !s.sopra && !s.vetrina
        interval: s.attesa
        onTriggered: s.aperta = false
    }

    // l'ombra morbida: due rettangoli larghi e bassi, senza sfocature vere (la GPU resta libera)
    Rectangle {
        x: fondo.x - 5; y: fondo.y + 7
        width: fondo.width + 10; height: fondo.height
        radius: fondo.radius + 6
        color: Tema.ombra
        opacity: fondo.opacity * 0.55
        visible: fondo.opacity > 0
    }
    Rectangle {
        x: fondo.x - 2; y: fondo.y + 3
        width: fondo.width + 4; height: fondo.height
        radius: fondo.radius + 3
        color: Tema.ombra
        opacity: fondo.opacity * 0.5
        visible: fondo.opacity > 0
    }

    Rectangle {
        id: fondo
        width: s.larghezza
        height: colonna.implicitHeight + 36
        // scivola fuori dalla barra: 8 px di corsa verso il centro dello schermo
        x: s.lato === "sinistra" ? (s.aperta ? 8 : -6) : s.lato === "destra" ? (s.aperta ? 0 : 14) : 0
        y: s.lato === "alto" ? (s.aperta ? 8 : -6) : s.lato === "basso" ? (s.aperta ? 0 : 14) : 0
        Behavior on y { NumberAnimation { duration: Tema.durata * 1.3; easing.type: Easing.OutCubic } }
        opacity: s.aperta ? 1 : 0
        scale: s.aperta ? 1 : 0.96
        transformOrigin: s.lato === "sinistra" ? (s.inAlto ? Item.TopLeft : Item.BottomLeft)
                       : s.lato === "destra" ? (s.inAlto ? Item.TopRight : Item.BottomRight)
                       : s.lato === "alto" ? (s.inAlto ? Item.TopLeft : Item.TopRight)
                       : (s.inAlto ? Item.BottomLeft : Item.BottomRight)
        radius: Tema.raggio + 2
        gradient: Gradient {
            GradientStop { position: 0; color: Tema.vetroAlto }
            GradientStop { position: 1; color: Tema.vetroBasso }
        }
        border.color: Tema.alfa(Tema.oro, 0.28)
        Behavior on x { NumberAnimation { duration: Tema.durata * 1.3; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Tema.durata * 1.3; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
        HoverHandler { id: dentro }

        // il filo d'accento in cima e la luce sul bordo: due dettagli che fanno sembrare la schedina di vetro
        Rectangle {
            x: 18; y: 1; width: 34; height: 2; radius: 1
            color: Tema.oro; opacity: 0.9
        }
        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 1; radius: parent.radius
            color: Tema.alfa(Tema.testo, 0.10)
        }

        Column {
            id: colonna
            x: 16; y: 17
            width: parent.width - 32
            spacing: s.spaziatura + 1

            Row {
                visible: s.titolo !== ""
                spacing: 8
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6; height: 6; radius: 3
                    color: Tema.oro
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: s.titolo
                    color: Tema.oro; font.family: Tema.font; font.pixelSize: 13; font.letterSpacing: 1.6
                    font.capitalization: Font.AllUppercase; font.weight: Font.Medium
                }
            }
            Rectangle {
                visible: s.titolo !== ""
                width: parent.width; height: 1
                color: Tema.bordoTenue
            }
        }
    }
}
