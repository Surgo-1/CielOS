# Report

CielOS scrive da solo un report ogni volta che ha qualcosa da raccontare, e lo mette subito nella repo dei report:
**github.com/Surgo-1/cielos-report**. Non serve fare niente: non c'è un pulsante «invia».

| Report | Quando | Cosa contiene |
|---|---|---|
| **Collaudo** | ogni notte, dopo il giro della VM (`cielos-collaudo.timer`) | fasi e prove, problemi nuovi e già visti, crash, servizi falliti, kernel |
| **Visita** | ogni giorno, con il timer del Medico (`cielmedico avvisa`) | l'esito della visita e ogni controllo con il suo rimedio |
| **Segnalazione** | quando lanci `cielos segnala` | il tuo racconto, l'hardware, gli errori, l'avvio prima — già senza nome, nome del PC e indirizzi MAC |

## Com'è fatto

Un file Markdown per report, in `rapporti/AAAA/MM/GG-HHMM-TIPO-MACCHINA.md`, con una scheda in testa:

```markdown
---
tipo: visita
macchina: pc
data: 2026-10-21T23:34+02:00
titolo: Visita del PC del 21/10/2026 23:34
esito: 2 consigli
---
```

`indice.json` è l'elenco per i programmi; `README.md` è la pagina da leggere, con gli ultimi report. Si rigenerano
da soli a ogni pubblicazione: non si modificano a mano. I report vecchi restano lì, in `rapporti/AAAA/MM/`.

## I comandi

- `cielreport stato` — se e dove pubblica, se GitHub è collegato, gli ultimi tentativi.
- `cielreport elenco` — gli ultimi report già nella repo.
- `cielreport configura --macchina NOME` — l'etichetta della macchina (non il nome vero del PC).
- `cielreport configura --spegni` / `--accendi` — la pubblicazione automatica.
- `cielmedico pubblica` — la visita di adesso, pubblicata subito.
- `cielreport pubblica FILE --tipo collaudo|segnalazione|visita` — un report qualsiasi (per i programmi: `--json`).

## Se non può pubblicare

La macchina che pubblica deve poter scrivere nella repo: serve `gh` collegato a GitHub (`gh auth login`). Se manca
la rete, GitHub non è collegato o la pubblicazione è spenta, il report **non si perde**: resta dove l'ha scritto il
suo produttore (il rapporto del collaudo nel giro, la visita in `~/.local/state/cielos/ultima-visita.md`, la
segnalazione nella tua cartella home) e `cielreport` esce con 3 senza fermare niente. Dentro CielOS non c'è nessuna
chiave: il permesso è quello del tuo account GitHub, quindi un PC senza quel permesso non pubblica.

## Privacy

I report sono pubblici. Prima di uscire, nome utente, nome del PC e indirizzi MAC diventano `UTENTE`, `PC` e
`xx:xx:xx:xx:xx:xx` (lo fa già chi li produce, e `cielreport` lo ricontrolla). La macchina è un'etichetta scelta da
te (`pc` di serie), non il nome vero. Le segnalazioni non contengono password né il contenuto dei tuoi file.
