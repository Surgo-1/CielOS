// La batteria nella barra: il livello si vede dal disegno (battery_0…6, full), il fulmine dice che è in carica.
// UPower manda i cambiamenti da solo: niente timer e nessun processo che gira a vuoto. Su un PC fisso l'icona
// non c'è. La schedina (mouse sopra o clic) dice percentuale, stato, tempo rimanente e profilo energetico.
import QtQuick
import Quickshell.Services.UPower
import qs.servizi

Icona {
    id: b
    property bool attiva: true                 // la scelta «Batteria» in Impostazioni → Barra
    readonly property var pila: UPower.displayDevice
    readonly property bool c_e: !!pila && pila.isPresent && (pila.isLaptopBattery || pila.type === UPowerDeviceType.Battery)
    readonly property int perc: pila ? Math.max(0, Math.min(100, Math.round(pila.percentage))) : 0
    readonly property bool carica: !!pila && (pila.state === UPowerDeviceState.Charging
                                             || pila.state === UPowerDeviceState.PendingCharge)
    readonly property bool piena: !!pila && pila.state === UPowerDeviceState.FullyCharged
    readonly property bool scarica: !!pila && (pila.state === UPowerDeviceState.Discharging
                                              || pila.state === UPowerDeviceState.PendingDischarge)
    readonly property string stato: {
        if (!c_e) return "";
        if (carica) return Lingua.t("in carica");
        if (piena) return Lingua.t("completamente carica");
        if (scarica) return Lingua.t("a batteria");
        if (pila.state === UPowerDeviceState.Empty) return Lingua.t("batteria scarica");
        return UPower.onBattery ? Lingua.t("a batteria") : Lingua.t("alla presa");
    }
    readonly property string profilo: PowerProfiles.profile === PowerProfile.PowerSaver ? Lingua.t("risparmio")
                                  : PowerProfiles.profile === PowerProfile.Performance ? Lingua.t("prestazioni")
                                  : Lingua.t("bilanciato")
    function durata(secondi) {
        if (!secondi || secondi <= 0) return "";
        const minuti = Math.round(secondi / 60);
        return minuti >= 60 ? Math.floor(minuti / 60) + " h " + (minuti % 60) + " min" : minuti + " min";
    }
    readonly property string tempo: !pila ? ""
                                         : carica ? (pila.timeToFull > 0 ? durata(pila.timeToFull) : "")
                                         : scarica ? (pila.timeToEmpty > 0 ? durata(pila.timeToEmpty) : "")
                                         : ""

    visible: c_e && attiva
    nome: {
        if (perc >= 95) return "battery_full";
        if (perc >= 85) return "battery_6_bar";
        if (perc >= 70) return "battery_5_bar";
        if (perc >= 55) return "battery_4_bar";
        if (perc >= 40) return "battery_3_bar";
        if (perc >= 25) return "battery_2_bar";
        if (perc >= 10) return "battery_1_bar";
        return "battery_0_bar";
    }
    colore: perc <= 15 && !carica ? Tema.allarme : (carica || piena) ? Tema.oro : Tema.oroChiaro

    // il fulmine: un cerchietto del colore del fondo lo stacca dal disegno della batteria
    Rectangle {
        visible: b.carica
        anchors { right: parent.right; bottom: parent.bottom; rightMargin: 1; bottomMargin: 1 }
        width: Math.max(13, b.dimensione * 0.62); height: width; radius: width / 2
        color: Tema.fondo
        border.width: 1
        border.color: Tema.alfa(Tema.oro, 0.55)
        Text {
            anchors.centerIn: parent
            text: "bolt"
            color: Tema.oroChiaro
            font.family: Tema.icone
            font.pixelSize: Math.max(10, b.dimensione * 0.5)
        }
    }

    Schedina {
        id: scheda
        icona: b
        titolo: Lingua.t("Batteria")
        Row {
            spacing: 12
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: b.perc + "%"
                color: b.colore; font.family: Tema.font; font.pixelSize: 30; font.weight: Font.Medium
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text {
                    text: b.stato
                    color: Tema.testo; font.family: Tema.font; font.pixelSize: 14
                }
                Text {
                    visible: b.tempo !== ""
                    text: Lingua.t("Ancora %1", b.tempo)
                    color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
                }
            }
        }
        Row {
            spacing: 8
            Text { text: Lingua.t("Profilo"); color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12 }
            Text { text: b.profilo; color: Tema.oroChiaro; font.family: Tema.font; font.pixelSize: 12 }
        }
    }
}
