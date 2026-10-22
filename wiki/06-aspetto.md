# Aspetto

## Dalle Impostazioni (Super+I → Aspetto)

- **Preset grafico**: **classico** (com'è di serie), **bare-bones** (il più leggero: nessuno sfondo se non il colore, niente effetti né animazioni, angoli e spazi a zero, barra minima e app non ritinte; tutte le funzioni di CielOS restano), **pixellato** (retro: squadrato, bordi netti, niente sfocature né animazioni, sfondo a pixel: più leggero del classico, più ricco del bare-bones), **compatto** (barra e spazi stretti, pochi effetti: per schermi piccoli), **morbido** (angoli tondi e sfocature). Un preset cambia in un colpo raggio, bordi, spazi, effetti, animazioni, barra e sfondo; poi le singole voci restano tue. I nomi di prima (`base`, `pixel`) restano accettati.
- **Temi pronti**: notte (di serie), alba, bosco, ghiaccio, carta, giorno, sabbia, oceano, orchidea, menta, e quelli in stile Archcraft: catppuccin, latte (chiaro), dracula, gruvbox, nord, tokyonight, everforest, kanagawa, nightfox, rosepine, cyberpunk.
- **Colori dallo sfondo**: CielOS prende i colori dall'immagine (o video) di sfondo.
- Accento, raggio degli angoli, bordi e spazi delle finestre, animazioni, avatar di Ciel, suono delle notifiche.
- **Modo chiaro/scuro**: vale per le app (browser, Discord, GTK) e, se non hai scelto colori tuoi, anche per la shell intera. I temi chiari (carta, giorno, sabbia, latte) portano con sé il modo giusto.
- **Grafica**: leggerissima (niente effetti), bilanciata (di serie) o bella (sfocature e ombre piene).

## La barra

In **Impostazioni → Barra** scegli lato, larghezza, misura delle icone e spazio tra gli elementi; accendi o spegni nucleo, workspace, layout delle finestre, vassoio, musica, sistema, sensori, batteria, luminosità, volume, rete, orologio e spegnimento. Niente è obbligatorio: la barra resta quella che vuoi.

L'**icona del layout delle finestre** (di serie accesa) passa tra *affiancate* (dwindle), *una grande* (master) e *colonne* (scrolling). La schedina mostra le tre possibilità con un disegno che si anima, la scelta si applica subito e resta dopo il riavvio. Si spegne come tutto il resto dalla pagina Barra. La stessa scelta è `cieltema imposta finestre_layout=master`.

Le scelte arrivano fino in fondo: colori, carattere e animazioni valgono anche per la **schermata di login** (cieltema le scrive in `sddm.conf`) e per il **blocco**, che con le animazioni spente resta un cielo fermo.

Ogni modifica si può **annullare** (`cieltema annulla`); `cieltema ripristina` torna tutto di serie.

## Dal terminale

```
cieltema                       com'è adesso
cieltema tema nord             un tema pronto
cieltema preset bare-bones    un preset grafico (classico, bare-bones, pixellato, compatto, morbido)
cieltema imposta accento=#7fd0ff raggio=20
cieltema sfondo ~/Immagini/foto.jpg
cieltema schema                tutte le chiavi
```

## A mano

- Le tue scelte: `~/.config/cielos/cielos.json` (cieltema genera il resto).
- Le tue righe per Hyprland: `~/.config/cielos/hypr-mio.lua` (si carica per ultimo: vince su tutto). Se sbagli una riga, una notifica e il Medico ti dicono quale.
- Non modificare `hypr-ciel.lua` e `hypr-sistema.lua`: li riscrivono le Impostazioni.
