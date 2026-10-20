// Un pulsantino delle impostazioni: testo, icona facoltativa, acceso se è la scelta attuale.
import QtQuick
import qs.servizi

Rectangle {
    id: c
    property string testo
    property string icona
    property bool acceso: false
    signal premuto()
    width: riga.implicitWidth + 26
    height: 32; radius: 16
    color: acceso ? Tema.accentoMedio
         : tocco.containsMouse ? Tema.accentoSoft : Tema.conAlfa(Tema.oro, 0.045)
    border.width: 1
    border.color: acceso ? Tema.alfa(Tema.oro, 0.72) : tocco.containsMouse ? Tema.alfa(Tema.oro, 0.24) : Tema.bordoTenue
    Behavior on color { ColorAnimation { duration: Tema.durata } }
    Behavior on border.color { ColorAnimation { duration: Tema.durata } }
    scale: tocco.pressed ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: 90 } }
    Row {
        id: riga
        anchors.centerIn: parent
        spacing: 6
        Text {
            visible: c.icona !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: c.icona; font.family: Tema.icone; font.pixelSize: 16; color: Tema.oroChiaro
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            // solo la prima lettera maiuscola («A destra di HDMI-A-1», non «A Destra Di»)
            text: c.testo.charAt(0).toUpperCase() + c.testo.slice(1)
            color: Tema.testo; font.family: Tema.font; font.pixelSize: 13
            font.weight: c.acceso ? Font.Medium : Font.Normal
        }
    }
    MouseArea { id: tocco; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: c.premuto() }
}
