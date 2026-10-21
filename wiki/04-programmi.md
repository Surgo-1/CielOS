# Programmi

## Install (Super+A → Install)

Un posto solo per tutti i programmi, come Shelly:

- **Cerca**: repository di Arch, **AUR** (anche le varianti `-git` e `-bin`) e **Flathub** insieme. Apri un risultato e scegli la variante e la **versione** (per Arch anche le vecchie, dall'archivio).
- **Aggiornamenti**: cosa aspetta un aggiornamento, da Arch, AUR e Flatpak insieme, con quanti sono per fonte; da qui **Aggiorna tutto** (sistema con le ondate e l'istantanea prima, AUR, Flatpak e firmware).
- **Consigliati**: il catalogo di CielOS (giochi, comunicazione, grafica, ufficio, sviluppo, web app…), ognuno dalla fonte più sicura che lo ha.
- **Rimuovi**: scrivi delle lettere, trova tutto quello che è installato e le contiene, scegli e togli (o «Tutti gli installati» per vederli tutti). I pacchetti vitali sono bloccati.
- La **scheda del programma**: cosa scarichi, quanto occupa, le dipendenze, la licenza, quando è stato aggiornato (per l'AUR anche voti e manutentore).

Le installazioni girano in un terminale davanti a tutto: vedi cosa succede e la password la scrivi tu.

## Codice (Super+A → Codice)

Gli agenti che scrivono codice nel terminale, da scaricare e aprire da lì: **FreeBuff** (gratis, senza chiavi), **OpenCode** (open source, qualunque modello), **Aider** (modifica i file di un progetto git) e **Crush** (leggero, di Charm).

- **Installa** esegue il comando vero in un terminale davanti a te: vedi cosa fa e la password la scrivi tu. FreeBuff passa da npm (Node.js viene messo prima se manca), OpenCode dal pacchetto di Arch (o dall'AUR), Aider dal suo installer, Crush dall'AUR.
- Quando è installato, **Apri** lo lancia nella tua home: da lì entri nel progetto e gli parli.

## I miei modelli (Super+A → I miei modelli)

I modelli scaricati, con quello che è in memoria adesso e la stima per questo PC. Ognuno si accende, si spegne, si libera dalla memoria o si elimina (prima esce dalla RAM, poi i file).

Le **rotelle** aprono le impostazioni di esecuzione, come le impostazioni di un programma:

- **Memoria stimata** (scheda video e totale) e **contesto**, fino al massimo che il modello dichiara.
- **Campionamento**: temperatura, top P, top K, min P, ripetizione, presenza, max token, seme.
- **Memoria**: sempre (resta caricato), 5 minuti (Ollama), no (esce subito e non si ricarica da solo).
- **Avanzate**: strati sulla scheda video, batch, mmap/mlock, ragionamento (se il modello lo sa fare).

Ci sono solo le impostazioni che Ollama sa usare davvero: KV cache, speculative decoding, parallel slots, checkpoint e argomenti extra non esistono nel suo motore, quindi non vengono mostrati per finta. «Ricarica modello» le applica a quello in memoria; «Ripristina» torna ai valori di serie. Se il modello è la mente di Ciel, le stesse impostazioni finiscono nel suo `config.yaml` e Ciel si riavvia.

## Le fonti

| Fonte | Cos'è | Sicurezza |
|---|---|---|
| Arch | i pacchetti ufficiali | controllati da Arch |
| Flathub | programmi isolati dal sistema | buona |
| AUR | ricette della comunità, compilate sul tuo PC | **nessun controllo**: installa solo quello che conosci |

## Web app

Alcuni consigliati sono **web app** (es. «Discord (web)»): un sito in una finestra sua, con la sua icona, come un programma. Funzionano bene su Wayland (anche la condivisione dello schermo).

Dal terminale: `cielos plugin elenco`, `cielos plugin installa NOME`, `cielos plugin togli NOME`.
