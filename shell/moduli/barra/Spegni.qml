// Il pulsante di spegnimento. Clic: il menu completo. Mouse sopra: una schedina con le scelte più comuni.
import QtQuick
import Quickshell
import qs.servizi

Icona {
    id: sp
    nome: "power_settings_new"
    onPremuto: { scheda.aperta = false; Pannelli.apri("sessione"); }

    function fai(cmd) {
        scheda.aperta = false;
        if (Pannelli.prova) { console.log("prova: avrei fatto", cmd.join(" ")); return; }
        Quickshell.execDetached(cmd);
    }

    Schedina {
        id: scheda
        icona: sp
        titolo: "Sessione"
        larghezza: 220
        Bottone { icona: "lock"; testo: "Blocca"; onPremuto: sp.fai(["loginctl", "lock-session"]) }
        Bottone { icona: "bedtime"; testo: "Sospendi"; onPremuto: sp.fai(["systemctl", "suspend"]) }
        Bottone { icona: "more_horiz"; testo: "Esci, riavvia, spegni…"; onPremuto: { scheda.aperta = false; Pannelli.apri("sessione"); } }
    }
}
