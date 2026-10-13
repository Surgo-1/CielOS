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
    property int larghezza: 300
    property bool aperta: false
    property bool inAlto: false         // per le icone in cima: la schedina scende invece di salire
    default property alias contenuto: colonna.data
    readonly property bool sopra: icona.sopra || dentro.hovered

    function alterna() { aperta = !aperta; }
    // per guardarle tutte insieme in prova: CIELOS_PROVA=1 CIELOS_SCHEDINE=1
    readonly property bool vetrina: Pannelli.prova && Quickshell.env("CIELOS_SCHEDINE") === "1"
    Timer { running: s.vetrina; interval: 1500; onTriggered: s.aperta = true }

    anchor.item: icona
    anchor.rect.x: icona.width + 6
    anchor.rect.y: inAlto ? 0 : icona.height - implicitHeight
    implicitWidth: larghezza + 8
    implicitHeight: colonna.implicitHeight + 28
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
        interval: 200
        onTriggered: s.aperta = false
    }

    Rectangle {
        id: fondo
        width: s.larghezza
        height: parent.height
        x: s.aperta ? 8 : -6
        opacity: s.aperta ? 1 : 0
        scale: s.aperta ? 1 : 0.96
        transformOrigin: s.inAlto ? Item.TopLeft : Item.BottomLeft
        radius: Tema.raggio
        color: Tema.superficie
        border.color: Tema.bordo
        Behavior on x { NumberAnimation { duration: Tema.durata * 1.3; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Tema.durata * 1.3; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
        HoverHandler { id: dentro }

        Column {
            id: colonna
            x: 14; y: 14
            width: parent.width - 28
            spacing: 10
            Text {
                visible: s.titolo !== ""
                text: s.titolo
                color: Tema.oro; font.family: Tema.font; font.pixelSize: 13; font.letterSpacing: 2
                font.capitalization: Font.AllUppercase; font.weight: Font.Medium
            }
        }
    }
}
