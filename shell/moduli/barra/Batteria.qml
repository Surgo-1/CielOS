// La batteria nella barra: il livello si vede dal disegno (battery_0…6, full), il fulmine dice che è in carica.
// UPower manda i cambiamenti da solo: niente timer e nessun processo che gira a vuoto. Su un PC fisso l'icona
// non c'è. La schedina (mouse sopra o clic) dice percentuale, stato, tempo rimanente e profilo energetico.
// Il livello si legge dalle batterie vere del portatile, non dal DisplayDevice di UPower: quello è una media di
// tutto quello che UPower vede (schede USB-C «fantasma», batterie di mouse e tastiera…) e all'avvio può non essere
// ancora pronto (0%). Con due batterie il livello è pesato sull'energia, non la media dei due numeri.
import QtQuick
import Quickshell.Services.UPower
import qs.servizi

Icona {
    id: b
    property bool attiva: true                 // la scelta «Batteria» in Impostazioni → Barra
    readonly property var pile: UPower.devices.values.filter(d => d.isLaptopBattery && d.isPresent !== false)
    readonly property var pila: UPower.displayDevice     // il ripiego, se il firmware non espone una batteria vera
    readonly property bool c_e: pile.length > 0 ||
        (!!pila && pila.isPresent && (pila.isLaptopBattery || pila.type === UPowerDeviceType.Battery))
    readonly property bool pronta: pile.length > 0 || (!!pila && pila.ready)

    function somma(campo) {
        let s = 0;
        for (const d of pile) s += (d[campo] || 0);
        return s;
    }
    // la percentuale: energia residua / energia piena di tutte le batterie (UPower la definisce così)
    readonly property real percentuale: {
        if (pile.length > 0 && pile.every(d => d.ready)) {
            const capacita = somma("energyCapacity");
            if (capacita > 0) return 100 * somma("energy") / capacita;
        }
        const pronte = pile.filter(d => d.ready);
        if (pronte.length > 0) return pronte.reduce((s, d) => s + d.percentage, 0) / pronte.length;
        return pila && pila.ready ? pila.percentage : 0;
    }
    readonly property int perc: Math.max(0, Math.min(100, Math.round(percentuale)))
    readonly property bool carica: pile.length > 0
        ? pile.some(d => d.state === UPowerDeviceState.Charging || d.state === UPowerDeviceState.PendingCharge)
        : !!pila && (pila.state === UPowerDeviceState.Charging || pila.state === UPowerDeviceState.PendingCharge)
    readonly property bool piena: pile.length > 0
        ? pile.every(d => d.state === UPowerDeviceState.FullyCharged)
        : !!pila && pila.state === UPowerDeviceState.FullyCharged
    readonly property bool scarica: pile.length > 0
        ? pile.some(d => d.state === UPowerDeviceState.Discharging || d.state === UPowerDeviceState.PendingDischarge)
        : !!pila && (pila.state === UPowerDeviceState.Discharging || pila.state === UPowerDeviceState.PendingDischarge)
    readonly property string stato: {
        if (!c_e || !pronta) return "";
        if (carica) return Lingua.t("in carica");
        if (piena) return Lingua.t("completamente carica");
        if (scarica) return Lingua.t("a batteria");
        if (pile.some(d => d.state === UPowerDeviceState.Empty) ||
            (pile.length === 0 && pila.state === UPowerDeviceState.Empty)) return Lingua.t("batteria scarica");
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
    // il tempo che manca: energia da riempire (o da consumare) diviso la velocità di adesso; se il driver non la
    // dà, la stima della batteria che finisce per ultima (in carica) o per prima (a batteria)
    readonly property real tempoSecondi: {
        if (!c_e || !pronta) return 0;
        const velocita = pile.reduce((s, d) => s + (d.changeRate || 0), 0);
        if (carica && velocita > 0.05) {
            const manca = somma("energyCapacity") - somma("energy");
            if (manca > 0) return manca / velocita * 3600;
        }
        if (scarica && velocita < -0.05) {
            const energia = somma("energy");
            if (energia > 0) return energia / -velocita * 3600;
        }
        const stime = pile.map(d => carica ? d.timeToFull : d.timeToEmpty).filter(t => t > 0);
        if (stime.length > 0) return carica ? Math.max(...stime) : Math.min(...stime);
        if (pile.length === 0 && pila) return carica ? (pila.timeToFull || 0) : (pila.timeToEmpty || 0);
        return 0;
    }
    readonly property string tempo: tempoSecondi > 0 ? durata(tempoSecondi) : ""

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
