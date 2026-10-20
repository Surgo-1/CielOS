// Un tasto grande della pagina iniziale del riquadro: icona, nome, una riga che dice a cosa serve.
// Si alza appena sotto il mouse, con un alone d'accento e la freccia che invita a entrare.
import QtQuick
import qs.servizi

Rectangle {
    id: t
    property string icona
    property string nome
    property string spiega
    signal premuto()
    height: 112
    radius: Tema.raggio + 4
    gradient: Gradient {
        GradientStop { position: 0; color: tocco.containsMouse ? Tema.accentoSoft : Tema.vetroAlto }
        GradientStop { position: 1; color: tocco.containsMouse ? Tema.superficie : Tema.vetroBasso }
    }
    border.width: 1
    border.color: tocco.containsMouse ? Tema.alfa(Tema.oro, 0.65) : Tema.bordoTenue
    Behavior on border.color { ColorAnimation { duration: Tema.durata } }
    scale: tocco.pressed ? 0.985 : 1
    Behavior on scale { NumberAnimation { duration: 90 } }

    // l'alone d'accento in alto a sinistra, come una luce che entra
    Rectangle {
        x: 16; y: 14
        width: 56; height: 56; radius: 28
        color: Tema.accentoSoft
        opacity: tocco.containsMouse ? 1 : 0.65
        Behavior on opacity { NumberAnimation { duration: Tema.durata } }
    }

    Row {
        x: 20
        width: parent.width - 36
        anchors.verticalCenter: parent.verticalCenter
        spacing: 16
        Rectangle {
            width: 54; height: 54; radius: 27
            color: Tema.accentoSoft
            border.width: 1
            border.color: Tema.alfa(Tema.oro, tocco.containsMouse ? 0.5 : 0.2)
            Text {
                anchors.centerIn: parent
                text: t.icona; font.family: Tema.icone; font.pixelSize: 28
                color: Tema.oro
            }
        }
        Column {
            width: parent.width - 70
            spacing: 4
            Text {
                text: t.nome; color: Tema.testo; font.family: Tema.font
                font.pixelSize: 17; font.weight: Font.Medium; elide: Text.ElideRight; width: parent.width
            }
            Text {
                width: parent.width; text: t.spiega; color: Tema.tenue
                font.family: Tema.font; font.pixelSize: 13; wrapMode: Text.WordWrap
                maximumLineCount: 2; elide: Text.ElideRight; lineHeight: 1.05
            }
        }
    }
    Text {
        anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
        text: "arrow_forward"; font.family: Tema.icone; font.pixelSize: 18
        color: Tema.oro
        opacity: tocco.containsMouse ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Tema.durata } }
    }
    MouseArea { id: tocco; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: t.premuto() }
}
