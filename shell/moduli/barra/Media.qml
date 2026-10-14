// La musica o il video che sta suonando (MPRIS: Spotify, browser, mpv…). L'icona c'è solo se c'è un lettore.
// Clic: pausa/riprendi; rotella: brano dopo/prima; mouse sopra: copertina, titolo, avanzamento e comandi.
import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.servizi

Icona {
    id: me
    readonly property var lettori: Mpris.players.values
    readonly property MprisPlayer lettore: lettori.find(p => p.isPlaying) ?? lettori[0] ?? null
    visible: lettore !== null
    nome: lettore?.isPlaying ? "graphic_eq" : "music_note"
    onPremuto: if (lettore?.canTogglePlaying) lettore.togglePlaying()
    onRotella: r => {
        if (!lettore) return;
        if (r.angleDelta.y < 0 && lettore.canGoNext) lettore.next();
        else if (r.angleDelta.y > 0 && lettore.canGoPrevious) lettore.previous();
    }

    function tempo(s) {
        s = Math.max(0, Math.floor(s));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    Timer {                              // l'avanzamento si aggiorna solo a schedina aperta
        running: scheda.aperta && (me.lettore?.isPlaying ?? false)
        interval: 1000; repeat: true
        onTriggered: me.lettore.positionChanged()
    }

    Schedina {
        id: scheda
        icona: me
        titolo: me.lettore?.identity ?? ""
        larghezza: 300
        Row {
            spacing: 12
            Rectangle {
                width: 64; height: 64; radius: Tema.raggio / 1.5
                color: Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.08)
                clip: true
                Image {
                    anchors.fill: parent
                    source: me.lettore?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(128, 128)
                }
                Text {
                    anchors.centerIn: parent
                    visible: !(me.lettore?.trackArtUrl)
                    text: "music_note"; font.family: Tema.icone; font.pixelSize: 28; color: Tema.tenue
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: 300 - 28 - 76
                spacing: 3
                Text {
                    width: parent.width
                    text: me.lettore?.trackTitle || "Niente in riproduzione"
                    color: Tema.testo; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.Medium
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    visible: text !== ""
                    text: me.lettore?.trackArtist ?? ""
                    color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }
        }
        Column {                             // l'avanzamento (clic per saltare, se il lettore lo permette)
            visible: (me.lettore?.lengthSupported ?? false) && me.lettore.length > 0
            width: parent.width
            spacing: 4
            Rectangle {
                width: parent.width; height: 4; radius: 2
                color: Qt.rgba(1, 1, 1, 0.1)
                Rectangle {
                    width: parent.width * Math.min(1, (me.lettore?.position ?? 0) / Math.max(1, me.lettore?.length ?? 1))
                    height: parent.height; radius: 2; color: Tema.oro
                }
                MouseArea {
                    anchors.fill: parent; anchors.margins: -6
                    enabled: me.lettore?.canSeek ?? false
                    cursorShape: Qt.PointingHandCursor
                    onClicked: m => me.lettore.position = (m.x - 6) / (width - 12) * me.lettore.length
                }
            }
            Item {
                width: parent.width; height: 14
                Text { text: me.tempo(me.lettore?.position ?? 0); color: Tema.tenue; font.family: Tema.font; font.pixelSize: 11 }
                Text { anchors.right: parent.right; text: me.tempo(me.lettore?.length ?? 0); color: Tema.tenue; font.family: Tema.font; font.pixelSize: 11 }
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 18
            Repeater {
                model: [["skip_previous", "prima"], [me.lettore?.isPlaying ? "pause" : "play_arrow", "pausa"], ["skip_next", "dopo"]]
                Rectangle {
                    required property var modelData
                    readonly property bool grande: modelData[1] === "pausa"
                    width: grande ? 44 : 36; height: width; radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: grande ? Tema.oro : t.containsMouse ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.18) : "transparent"
                    Behavior on color { ColorAnimation { duration: Tema.durata } }
                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData[0]; font.family: Tema.icone; font.pixelSize: parent.grande ? 26 : 22
                        color: parent.grande ? Tema.fondo : Tema.oroChiaro
                    }
                    MouseArea {
                        id: t
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const l = me.lettore, c = parent.modelData[1];
                            if (!l) return;
                            if (c === "prima" && l.canGoPrevious) l.previous();
                            else if (c === "dopo" && l.canGoNext) l.next();
                            else if (c === "pausa" && l.canTogglePlaying) l.togglePlaying();
                        }
                    }
                }
            }
        }
        Row {                                // più lettori: scegli quale
            visible: me.lettori.length > 1
            spacing: 6
            Repeater {
                model: me.lettori
                Rectangle {
                    required property MprisPlayer modelData
                    height: 24; width: nomeL.implicitWidth + 18; radius: 12
                    color: modelData === me.lettore ? Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.22) : Qt.rgba(Tema.oro.r, Tema.oro.g, Tema.oro.b, 0.06)
                    border.color: Tema.bordo
                    Text { id: nomeL; anchors.centerIn: parent; text: parent.modelData.identity; color: Tema.testo; font.family: Tema.font; font.pixelSize: 11 }
                }
            }
        }
    }
}
