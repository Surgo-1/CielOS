// Lo sfondo, disegnato da Ciel: di serie «Notte» (grafica/sfondi, disegnato da CielOS); nelle impostazioni Alba,
// Aurora, un'immagine tua o nessuna (solo il colore di fondo). Alla misura dello schermo: solo i pixel che servono
// (misurato il 14/10: ~25 MB per schermo; con «nessuno» zero).
// Fermo: niente si muove. In prova non c'è (lo sfondo è dell'altra shell).
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.servizi

Variants {
    model: Pannelli.prova ? [] : Quickshell.screens

    PanelWindow {
        required property ShellScreen modelData
        screen: modelData
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "ciel-sfondo"
        color: Tema.fondo

        Image {
            id: foto
            anchors.fill: parent
            visible: source != ""
            source: Tema.sfondo ? "file://" + Tema.sfondo : ""
            sourceSize: Qt.size(parent.width, parent.height)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            opacity: status === Image.Ready ? 1 : 0
            // la comparsa segue «animazioni»: spenta, la foto è subito lì (e con «leggerissima» non c'è nulla che si muove)
            Behavior on opacity { NumberAnimation { duration: Tema.animazioni ? 400 : 0; easing.type: Easing.OutCubic } }
        }

        Rectangle {                      // velo scuro scelto nelle Impostazioni: le scritte si leggono meglio
            anchors.fill: parent
            visible: Tema.scurisciSfondo > 0 && foto.status === Image.Ready
            color: "black"
            opacity: Tema.scurisciSfondo
        }
    }
}
