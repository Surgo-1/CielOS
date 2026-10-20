// La musica o il video che sta suonando (MPRIS: Spotify, browser, mpv…). L'icona c'è solo se c'è un lettore.
// Clic: pausa/riprendi; rotella: brano dopo/prima; mouse sopra: copertina, titolo, avanzamento e comandi.
import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.servizi

Icona {
    id: me
    readonly property var lettori: Mpris.players.values
    property MprisPlayer scelto: null            // se ne hai più di uno, quello che stai guardando
    readonly property MprisPlayer lettore: (scelto && lettori.includes(scelto)) ? scelto
                                          : (lettori.find(p => p.isPlaying) ?? lettori[0] ?? null)
    visible: lettore !== null
    nome: lettore?.isPlaying ? "graphic_eq" : "music_note"
    onPremuto: if (lettore?.canTogglePlaying) lettore.togglePlaying()
    onRotella: r => {
        if (!lettore) return;
        if (r.angleDelta.y < 0 && lettore.canGoNext) lettore.next();
        else if (r.angleDelta.y > 0 && lettore.canGoPrevious) lettore.previous();
    }

    // l'avanzamento: lo teniamo noi, secondo per secondo, e lo riallineiamo al lettore quando cambia brano
    // (chiamare positionChanged() ogni secondo era un ciclo inutile e il cursore saltava)
    property real posizione: 0
    function sincronizza() { posizione = Math.max(0, me.lettore?.position ?? 0) }
    onLettoreChanged: sincronizza()
    Connections {
        target: me.lettore
        ignoreUnknownSignals: true
        function onTrackTitleChanged() { me.sincronizza() }
        function onPlaybackStateChanged() { me.sincronizza() }
    }
    Timer {
        running: scheda.aperta && (me.lettore?.isPlaying ?? false)
        interval: 1000; repeat: true
        onTriggered: {
            const p = me.lettore?.position ?? 0;
            if (Math.abs(p - me.posizione) > 2) me.posizione = p;
            else me.posizione = Math.min(me.lettore?.length || 1e9, me.posizione + 1);
        }
    }

    function tempo(s) {
        s = Math.max(0, Math.floor(s));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    Schedina {
        id: scheda
        icona: me
        titolo: me.lettore?.identity ?? ""
        larghezza: 310
        onApertaChanged: if (aperta) me.sincronizza()
        Row {
            spacing: 12
            Rectangle {
                width: 68; height: 68; radius: Tema.raggio
                color: Tema.accentoSoft
                border.width: 1; border.color: Tema.alfa(Tema.oro, 0.2)
                clip: true
                Image {
                    id: copertina
                    anchors.fill: parent
                    source: me.lettore?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(136, 136)
                }
                Text {
                    anchors.centerIn: parent
                    visible: copertina.status !== Image.Ready     // anche se la copertina è sparita (file in /tmp)
                    text: "music_note"; font.family: Tema.icone; font.pixelSize: 30; color: Tema.tenue
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: 310 - 32 - 80
                spacing: 4
                Text {
                    width: parent.width
                    text: me.lettore?.trackTitle || Lingua.t("Niente in riproduzione")
                    color: Tema.testo; font.family: Tema.font; font.pixelSize: 15; font.weight: Font.Medium
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    visible: text !== ""
                    text: me.lettore?.trackArtist ?? ""
                    color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    visible: text !== ""
                    text: me.lettore?.trackAlbum ?? ""
                    color: Tema.tenue; font.family: Tema.font; font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
        }
        Column {                             // l'avanzamento (clic per saltare, se il lettore lo permette)
            visible: (me.lettore?.lengthSupported ?? false) && me.lettore.length > 0
            width: parent.width
            spacing: 5
            Rectangle {
                width: parent.width; height: 5; radius: 2.5
                color: Tema.conAlfa(Tema.testo, 0.10)
                border.width: 1; border.color: Tema.bordoTenue
                Rectangle {
                    width: parent.width * Math.min(1, me.posizione / Math.max(1, me.lettore?.length ?? 1))
                    height: parent.height; radius: 2.5
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Tema.oro }
                        GradientStop { position: 1; color: Tema.oroChiaro }
                    }
                }
                MouseArea {
                    anchors.fill: parent; anchors.margins: -7
                    enabled: me.lettore?.canSeek ?? false
                    cursorShape: Qt.PointingHandCursor
                    onClicked: m => {
                        const v = (m.x - 7) / (width - 14) * me.lettore.length;
                        me.lettore.position = v; me.posizione = v;
                    }
                }
            }
            Item {
                width: parent.width; height: 14
                Text { text: me.tempo(me.posizione); color: Tema.tenue; font.family: Tema.font; font.pixelSize: 11 }
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
                    width: grande ? 46 : 38; height: width; radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: grande ? Tema.oro : t.containsMouse ? Tema.accentoSoft : "transparent"
                    border.width: grande ? 0 : 1
                    border.color: Tema.bordoTenue
                    Behavior on color { ColorAnimation { duration: Tema.durata } }
                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData[0]; font.family: Tema.icone; font.pixelSize: parent.grande ? 27 : 23
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
                    height: 26; width: nomeL.implicitWidth + 20; radius: 13
                    color: modelData === me.lettore ? Tema.accentoMedio : sT.containsMouse ? Tema.accentoSoft : "transparent"
                    border.width: 1
                    border.color: modelData === me.lettore ? Tema.alfa(Tema.oro, 0.55) : Tema.bordoTenue
                    Text {
                        id: nomeL
                        anchors.centerIn: parent
                        text: parent.modelData.identity
                        color: Tema.testo; font.family: Tema.font; font.pixelSize: 11
                    }
                    MouseArea {
                        id: sT
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { me.scelto = parent.modelData; me.sincronizza(); }
                    }
                }
            }
        }
    }
}
