// La luminosità dello schermo di questa barra: rotella per cambiarla, mouse sopra per la barra da trascinare.
// Sparisce se il monitor non risponde a DDC/CI.
import QtQuick
import qs.servizi

Icona {
    id: lu
    required property string schermo
    readonly property var dati: Luminosita.schermi[schermo]
    readonly property int valore: dati?.valore ?? 0
    visible: Tema.mostraLuce && !Luminosita.saltati[schermo] && (!Luminosita.pronta || dati !== undefined)
    nome: valore < 35 ? "brightness_low" : valore < 70 ? "brightness_medium" : "brightness_high"
    // la ricerca DDC/CI costa un paio di secondi e parla con l'I2C di ogni monitor: si fa solo se il controllo è
    // nella barra e solo per gli schermi esterni (il pannello interno di un portatile non risponde a DDC/CI)
    Component.onCompleted: {
        if (!Tema.mostraLuce) return;
        if (/^(eDP|LVDS)/i.test(schermo)) Luminosita.salta(schermo); else Luminosita.cerca();
    }
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
