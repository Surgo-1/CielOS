# Giochi

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
