// Un'icona della barra (Material Symbols) che si accende sotto il mouse.
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
        radius: Tema.raggio / 1.5
        color: tocco.containsMouse ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.14) : "transparent"
        Behavior on color { ColorAnimation { duration: Tema.durata } }
    }
    Text {
        anchors.centerIn: parent
        text: icona.nome
        font.family: Tema.icone
        font.pixelSize: icona.dimensione
        color: icona.colore
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
