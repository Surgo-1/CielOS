// Un'icona della barra (Material Symbols) che si accende sotto il mouse.
// La pastiglia è appena più chiara del fondo, con un filo d'accento: niente si muove se non la tocchi.
import QtQuick
import qs.servizi

Item {
    id: icona
    property string nome
    property color colore: Tema.oroChiaro
    property int dimensione: Tema.iconaBarra
    readonly property bool sopra: tocco.containsMouse
    signal premuto(var mouse)
    signal rotella(var ruota)

    implicitWidth: Tema.barra - 14
    implicitHeight: implicitWidth

    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: Tema.raggioPiccolo + 2
        color: tocco.containsMouse ? Tema.accentoSoft : "transparent"
        border.width: tocco.containsMouse ? 1 : 0
        border.color: Tema.alfa(Tema.oro, 0.22)
        Behavior on color { ColorAnimation { duration: Tema.durata } }
        Behavior on border.color { ColorAnimation { duration: Tema.durata } }
    }
    // un filo d'accento alla base: si vede solo mentre ci passi sopra
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        width: tocco.containsMouse ? 12 : 0
        height: 2
        radius: 1
        color: Tema.oro
        opacity: tocco.containsMouse ? 0.9 : 0
        Behavior on width { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Tema.durata } }
    }
    Text {
        anchors.centerIn: parent
        text: icona.nome
        font.family: Tema.icone
        font.pixelSize: icona.dimensione
        color: icona.colore
        Behavior on color { ColorAnimation { duration: Tema.durata } }
    }
    MouseArea {
        id: tocco
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => icona.premuto(mouse)
        onWheel: ruota => icona.rotella(ruota)
    }
}
