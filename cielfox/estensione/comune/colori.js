// I colori di CielFox nelle pagine dell'estensione (nuova scheda, pannello, impostazioni): variabili CSS che seguono
// l'aspetto scelto (CielOS, CielFox o il tuo accento), anche quando cambia.
(() => {
  const applica = c => {
    if (!c) return;
    const s = document.documentElement.style;
    const mappa = { fondo: "--fondo", fondoAlto: "--alto", superficie: "--superficie", oro: "--accento",
                    oroChiaro: "--chiaro", testo: "--testo", tenue: "--tenue", allarme: "--allarme", bordo: "--bordo" };
    for (const [k, v] of Object.entries(mappa)) if (c[k]) s.setProperty(v, c[k]);
    if (c.font) s.setProperty("--font", `"${c.font}", system-ui, sans-serif`);
  };
  browser.storage.local.get("colori").then(d => applica(d.colori));
  browser.storage.onChanged.addListener(ch => ch.colori && applica(ch.colori.newValue));
})();
