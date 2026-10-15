# Installazione

## La chiavetta

Copia la ISO di CielOS su una chiavetta **Ventoy** (basta copiare il file) oppure scrivila con un programma come Impression o Fedora Media Writer. Avvia il PC dalla chiavetta: parte CielOS «live» con l'installatore.

## L'installatore

1. Benvenuto (serve internet: cavo o Wi-Fi dalla barra).
2. **Disco**: CielOS usa il disco intero (tutto quello che c'è viene cancellato). Puoi **cifrare il disco** (LUKS2): a ogni accensione chiede una frase segreta. Se la dimentichi, i dati sono persi.
3. Tu: nome, nome per entrare, password, nome del PC.
4. Lingua e tastiera, fuso orario.
5. Ciel (sì/no).
6. Riepilogo e conferma.

Installa solo i driver che servono a quel PC. Si avvia sia con UEFI sia con BIOS. Il disco: btrfs con istantanee, compressione zstd.

Il registro dell'installazione: `/var/log/cielos-installa.log` (anche sul sistema installato).

## Dopo

Al primo accesso Ciel si prepara da sola (se l'hai scelta). Aggiorna con `cielos aggiorna`.
