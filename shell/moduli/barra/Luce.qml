// La luminosità dello schermo di questa barra: rotella per cambiarla, mouse sopra per la barra da trascinare.
// Sparisce se il monitor non risponde a DDC/CI.
import QtQuick
import qs.servizi

Icona {
    id: lu
    required property string schermo
    readonly property var dati: Luminosita.schermi[schermo]
    readonly property int valore: dati?.valore ?? 0
    visible: Tema.mostraLuce && (!Luminosita.pronta || dati !== undefined)
    nome: valore < 35 ? "brightness_low" : valore < 70 ? "brightness_medium" : "brightness_high"
    Component.onCompleted: Luminosita.cerca()
    onRotella: r => Luminosita.imposta(schermo, valore + (r.angleDelta.y > 0 ? 5 : -5))
    onPremuto: scheda.alterna()

    Schedina {
        id: scheda
        icona: lu
        titolo: Lingua.t("Luminosità")
        larghezza: 280
        Text {
            visible: !Luminosita.pronta
            text: Lingua.t("Cerco i monitor…")
            color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13
        }
        Cursore {
            visible: lu.dati !== undefined
            icona: lu.nome
            valore: lu.valore / 100
            onCambiato: x => Luminosita.imposta(lu.schermo, x * 100)
        }
    }
}
