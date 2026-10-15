# Aggiornamenti

## Le ondate

Arch aggiorna tutto subito; CielOS aggiorna **a ondate**: i pacchetti restano fermi a una data già provata e avanzano quando approvi un aggiornamento. Prima ti mostra l'elenco, i pacchetti delicati (kernel, driver) e le **notizie di Arch** che chiedono di fare qualcosa a mano.

- `cielos aggiorna` (o Super+A → Install → Aggiorna tutto, o «aggiorna» a Ciel). La password la chiede la finestra del guardiano.
- Prima di ogni aggiornamento c'è un'**istantanea** (snapper, btrfs).
- Se dopo l'aggiornamento il PC **non parte bene**, al riavvio CielOS **torna indietro da solo**.
- `cielos ritorna`: rimette il sistema com'era prima dell'ultimo aggiornamento (dal prossimo avvio).

## Le istantanee

Si fanno da sole prima di ogni aggiornamento e installazione; le vecchie si cancellano da sole. `snapper list` le elenca.

## Pulizia automatica

Ogni settimana i pacchetti scaricati vecchi si cancellano (restano le ultime 3 versioni); i resoconti dei crash dopo 3 giorni. Il Medico avvisa se la cache supera 5 GB o ci sono pacchetti che non servono più.

## Firmware

Con il plugin **Aggiornamenti del firmware** (fwupd), «Aggiorna tutto» aggiorna anche BIOS, SSD, dock, tastiere e mouse supportati (LVFS).
