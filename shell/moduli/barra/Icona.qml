// Un'icona della barra (Material Symbols) che si accende sotto il mouse.
import QtQuick
import qs.servizi

Item {
    id: icona
    property string nome
    property color colore: Tema.oroChiaro
    property int dimensione: 20
    readonly property bool sopra: tocco.containsMouse
    signal premuto(var mouse)
    signal rotella(var ruota)

    implicitWidth: Tema.barra - 14
    implicitHeight: implicitWidth

    Rectangle {
        anchors.fill: parent
        radius: Tema.raggio / 1.5
        color: tocco.containsMouse ? Qt.rgba(1, 0.75, 0.25, 0.14) : "transparent"
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
