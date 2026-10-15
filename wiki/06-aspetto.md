# Aspetto

## Dalle Impostazioni (Super+I → Aspetto)

- **Temi pronti**: notte (di serie), alba, bosco, ghiaccio, carta, e quelli in stile Archcraft: catppuccin, latte (chiaro), dracula, gruvbox, nord, tokyonight, everforest, kanagawa, nightfox, rosepine, cyberpunk.
- **Colori dallo sfondo**: CielOS prende i colori dall'immagine (o video) di sfondo.
- Accento, raggio degli angoli, larghezza e lato della barra, bordi e spazi delle finestre, animazioni, avatar di Ciel, suono delle notifiche, modo chiaro/scuro delle app.
- **Grafica**: leggera, bilanciata (di serie) o piena (sfocature, ombre).

Ogni modifica si può **annullare** (`cieltema annulla`); `cieltema ripristina` torna tutto di serie.

## Dal terminale

```
cieltema                       com'è adesso
cieltema tema nord             un tema pronto
cieltema imposta accento=#7fd0ff raggio=20
cieltema sfondo ~/Immagini/foto.jpg
cieltema schema                tutte le chiavi
```

## A mano

- Le tue scelte: `~/.config/cielos/cielos.json` (cieltema genera il resto).
- Le tue righe per Hyprland: `~/.config/cielos/hypr-mio.lua` (si carica per ultimo: vince su tutto). Se sbagli una riga, una notifica e il Medico ti dicono quale.
- Non modificare `hypr-ciel.lua` e `hypr-sistema.lua`: li riscrivono le Impostazioni.
