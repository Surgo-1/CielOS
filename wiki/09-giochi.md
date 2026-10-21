# Giochi

## ProtonDB e l'anti-cheat, dentro CielOS

**CielGiochi** (dal lanciatore, o `ciel-giochi`): i giochi che hai su Steam con il giudizio di **ProtonDB** (platino, oro, argento, bronzo, rotto, con quante prove), l'**anti-cheat su Linux** (da [Are We Anti-Cheat Yet?](https://areweanticheatyet.com): se non funziona, il gioco online non parte qualunque sia la tua scheda video) e i requisiti di Steam confrontati con questo PC. RAM, VRAM e disco sono i numeri veri del tuo computer; CPU e scheda video restano «da confrontare», perché un confronto tra nomi sarebbe una bugia.

Al posto di «Can You RUN It» — che misura un PC Windows e vuole il suo componente nel browser — c'è la domanda che conta su Linux. «Anti-cheat» apre la pagina del gioco su areweanticheatyet.com in CielFox.

Dal terminale: `cielgiochi elenco`, `cielgiochi proton APPID`, `cielgiochi anticheat APPID`, `cielgiochi requisiti APPID`, `cielgiochi apri APPID` (la guida con `cielgiochi --aiuto`). I giudizi restano in cache un giorno, la tabella degli anti-cheat un giorno, i requisiti un mese: la seconda volta è istantaneo, e senza rete si vedono gli ultimi che c'erano.

## Steam e Proton

Super+A → Install → Consigliati → Giochi: Steam, Heroic, Lutris, Bottles, ProtonUp-Qt, «Prestazioni nei giochi» (GameMode, MangoHud, gamescope)… I pacchetti a 32 bit (multilib) si accendono da soli quando servono. Per i driver giusti: `sudo cielos-hardware installa`.

## La modalità gioco

Parte da sola quando giochi: profilo prestazioni, niente notifiche, grafica del desktop leggera; quando smetti torna tutto com'era. In più CielOS ha di serie: VRR, latenza minima per i giochi a schermo intero, ntsync per Wine/Proton, cache degli shader grande, le regolazioni del kernel di CachyOS.

## Controller

Xbox, PlayStation, Nintendo, Steam, 8BitDo e altri funzionano subito, con il filo e senza (bluetooth), anche con Steam Input.

## Discord

- **Discord (web)** (consigliato): chiamate e condivisione dello schermo funzionano su Wayland.
- **Discord ufficiale**: se lo schermo condiviso è nero installa «Ponte per condividere lo schermo» e condividi la sua finestra; se si chiude, spegni l'accelerazione hardware nelle sue impostazioni.
- Il microfono non si sente? Vedi [Errori](12-errori.md#microfono).
