// Uno scaricamento in corso: barra, quanto manca, velocità, «Annulla» (riprende da lì se lo riscarichi).
import QtQuick
import Quickshell
import qs.servizi

Item {
    id: a
    property var d: null                          // la riga di «cielmodelli scaricamenti»
    property bool conNome: false
    readonly property real quota: d && d.totale ? d.fatti / d.totale : 0
    implicitHeight: conNome ? 52 : 38

    Text {
        id: nome
        visible: a.conNome
        width: parent.width - annulla.width - 10; elide: Text.ElideMiddle
        text: (a.d?.nome ?? "").replace(/^hf\.co\//, "")
        color: Tema.testo; font.family: Tema.font; font.pixelSize: 13
    }
    Rectangle {
        id: fondo
        anchors { left: parent.left; right: annulla.left; rightMargin: 12; top: a.conNome ? nome.bottom : undefined; topMargin: 6
                  verticalCenter: a.conNome ? undefined : parent.verticalCenter; verticalCenterOffset: a.conNome ? 0 : -7 }
        height: 6; radius: 3
        color: Qt.rgba(1, 1, 1, 0.1)
        Rectangle {
            width: parent.width * a.quota; height: parent.height; radius: 3
            color: Tema.oro
            Behavior on width { NumberAnimation { duration: 900; easing.type: Easing.Linear } }
        }
    }
    Text {
        anchors { left: fondo.left; top: fondo.bottom; topMargin: 5 }
        text: a.d ? (a.d.totale ? Math.round(a.quota * 100) + "% · " + (a.d.fatti / 1e9).toFixed(1) + Lingua.t(" di ") + (a.d.totale / 1e9).toFixed(1) + " GB"
                                 + (a.d.velocita_mbs > 0 ? " · " + a.d.velocita_mbs + " MB/s" + (a.d.velocita_mbs > 0.1 ? Lingua.t(" · mancano ~") + a.manca() : "") : "")
                               : a.d.messaggio) : ""
        color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
    }
    function manca() {
        const s = (d.totale - d.fatti) / 1e6 / d.velocita_mbs;
        return s > 3600 ? Math.round(s / 3600) + " h" : s > 60 ? Math.round(s / 60) + " min" : Math.round(s) + " s";
    }
    Pulsante {
        id: annulla
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        testo: Lingua.t("Annulla"); icona: "close"
        onPremuto: Quickshell.execDetached([Percorsi.bin("cielmodelli"), "annulla", a.d.nome])
    }
}
