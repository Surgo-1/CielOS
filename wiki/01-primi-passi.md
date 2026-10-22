# Primi passi

## All'accensione

Prima del desktop c'è il cielo di CielOS: il marchio, qualche stella che respira e una riga sottile che dice a che
punto è l'avvio. Se il disco è cifrato, il marchio sale e compare una scheda con il lucchetto: scrivi la frase segreta
e premi Invio; se il Bloc Maiusc è acceso, CielOS te lo dice. Spegnimento, riavvio e sospensione hanno la loro frase
(«a presto», «torno subito», «a tra poco»).

La schermata sta anche nell'initramfs: quando arriva un aggiornamento di CielOS viene rifatta da sola, senza dover
ritoccare l'avvio a mano.

## Il desktop

- **La barra** (a sinistra di serie; si sposta e si monta in Impostazioni → Barra): in alto Ciel e i workspace, in basso layout delle finestre, vassoio, musica, sensori, luminosità, volume, rete, orologio e spegnimento. Ogni elemento si può spegnere, e si scelgono misura delle icone e spazio. L'icona del layout passa tra affiancate, una grande e colonne, con l'anteprima animata. Quando registri lo schermo, o sono accesi *resta sveglio*, *luce notturna* o *non disturbare*, compare la loro icona: un clic li spegne.
- **Il lanciatore** (Super o Super+Spazio): scrivi il nome di un programma, di uno strumento («registra», «emoji», «luce») o una domanda per Ciel. Con **?** davanti la domanda va direttamente a Ciel.
- **La casella** (Super+J): dove Ciel ti risponde e dove le scrivi.
- **Le notifiche** (Super+N): il centro notifiche, con *non disturbare*.

## Rete

- **Impostazioni → Rete** (o l'icona della rete nella barra → «Impostazioni di rete»): accendi o spegni il Wi-Fi,
  scegli la rete dall'elenco (la password la scrivi solo la prima volta), vedi cavo e indirizzi, e scegli il **DNS
  di tutto il PC**: automatico (quello del router), Cloudflare, Google o Quad9. Il DNS resta anche cambiando Wi-Fi.
- Dalla riga di comando: `cielrete` (stato, reti, connetti, scollega, wifi, dns), per esempio `cielrete reti`.

## Finestre e workspace

CielOS usa **Hyprland**: le finestre si affiancano da sole, senza sovrapporsi.

- **Super+1…0**: vai al workspace 1…10; **Super+Alt+1…0**: ci mandi la finestra.
- **Super+frecce**: passa alla finestra di lato; **Super+Maiusc+frecce**: spostala.
- **Super+Q** chiude, **Super+F** schermo intero, **Super+Alt+F** ingrandisci, **Super+Alt+Spazio** fluttuante.
- **Super+trascina** col mouse sposta, **Super+clic destro** ridimensiona.
- **Super+O** stacca la finestra: sopra le altre, su tutti i workspace.
- **Super+S** il workspace speciale (un cassetto che appare sopra); **Super+Alt+S** ci manda la finestra.
- Nella barra, passa sopra un workspace per vedere le sue finestre; **trascina un file sopra un workspace** e dopo un attimo ci vai, per lasciarlo nell'app che c'è.

## File e browser

- **CielFile** (Super+E, o dal lanciatore): schede, vista divisa (F3), anteprime, chiavette, cestino, ricerca anche nelle sottocartelle.
- **CielFox** (Super+W): il browser di CielOS (LibreWolf, senza telemetria, uBlock dentro) con Ciel nella barra laterale.
