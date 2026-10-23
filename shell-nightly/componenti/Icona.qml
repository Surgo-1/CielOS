// Un'icona della Nightly: simbolo Material, si accende sotto il mouse con un anello sottile. Clic e rotella.
import QtQuick
import qs.servizi

Item {
    id: icona
    property string nome
    property color colore: Tema.ciano
    property int dimensione: Tema.icona
    readonly property bool sopra: tocco.containsMouse
    signal premuto(var mouse)
    signal rotella(var ruota)
    signal entrato()
    signal uscito()

    implicitWidth: 34
    implicitHeight: 34

    Rectangle {
        anchors.fill: parent
        radius: Tema.raggioPiccolo
        color: icona.sopra ? Tema.cianoFondo : "transparent"
        border.width: icona.sopra ? 1 : 0
        border.color: Tema.alfa(Tema.ciano, 0.35)
        Behavior on color { ColorAnimation { duration: Tema.durata } }
    }
    Text {
        anchors.centerIn: parent
        text: icona.nome
        color: icona.sopra ? Tema.testo : icona.colore
        font.family: Tema.icone
        font.pixelSize: icona.dimensione
    }
    MouseArea {
        id: tocco
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: m => icona.premuto(m)
        onWheel: r => icona.rotella(r)
        onEntered: icona.entrato()
        onExited: icona.uscito()
    }
}
