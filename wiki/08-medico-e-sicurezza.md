# Medico e sicurezza

## Il Medico

Controlla il PC ogni giorno e quando glielo chiedi: kernel da riavviare, servizi che non partono, spazio, driver, scheda video, memoria, temperature, audio, rete, ora, firewall, istantanee, aggiornamenti, pacman bloccato, cache e pacchetti inutili, file .pacnew, errori di Hyprland.

- Impostazioni → Medico, oppure `cielos medico`, oppure «come sta il PC?» a Ciel.
- **Ripara**: `cielos medico ripara` (tutto) o `cielos medico ripara ID`. Dopo ogni riparazione ricontrolla. I pacchetti inutili li toglie solo se lo chiedi tu.
- **Ogni giorno**: il timer scrive la visita nella [repo dei report](13-report.md) (e ti avvisa solo se c'è qualcosa di nuovo).

## Il guardiano

Il servizio che fa le cose da **amministratore**: aggiornare, installare, togliere, servizi di sistema, firewall, istantanee, DNS, sbloccare pacman. Ha un elenco chiuso di azioni, controlla ogni richiesta e **chiede sempre la tua password** in una finestra che Ciel non può cliccare. Ciel non è mai amministratrice.

## Firewall

Acceso di serie (ufw). Le porte si aprono solo verso la rete di casa, mai verso internet.

## Segnalare un problema

`cielos segnala` ti chiede prima di **raccontare il problema** (una riga, poi cosa è successo: cosa stavi facendo, cosa ti aspettavi, da quando succede), poi raccoglie in un file tutto quello che serve (hardware, audio, errori, crash, l'avvio prima), **senza** il tuo nome, il nome del PC e gli indirizzi MAC, e ti dice subito cosa riconosce la guida agli errori. Puoi anche scriverlo direttamente: `cielos segnala "il microfono non va dopo il riavvio"`. La copia finisce da sola nella [repo dei report](13-report.md); poi, se vuoi, apre una segnalazione già compilata su GitHub (serve un account gratuito), o la mandi tu (es. su Discord).

Anche la **visita giornaliera** del Medico diventa un report nella stessa repo: l'esito e ogni controllo con il suo rimedio, pubblicato dal timer di ogni giorno. `cielmedico pubblica` fa la stessa cosa subito. Se il PC non è collegato a GitHub il report resta sul PC; per spegnere la pubblicazione: `cielreport configura --spegni`.
