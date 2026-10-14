// Le impostazioni di CielFox: si salvano subito in storage.local («impostazioni»); sfondo.js le applica
// (aspetto, privacy, schede addormentate) e la nuova scheda le legge.
const $ = s => document.querySelector(s);
let imp = {};
const porta = browser.runtime.connect({ name: "pannello" });       // per i modelli (li chiede al ponte)

function mostra() {
  for (const el of document.querySelectorAll("[data-chiave]")) {
    const v = imp[el.dataset.chiave];
    if (el.classList.contains("scelte")) el.querySelectorAll("button").forEach(b => b.classList.toggle("scelto", b.value === v));
    else if (el.type === "checkbox") el.checked = !!v;
    else if (v !== undefined) el.value = String(v);
  }
  $("#rigaAccento").hidden = imp.aspetto !== "personale";
}
function salva(k, v) {
  imp = { ...imp, [k]: v };
  browser.storage.local.set({ impostazioni: imp });
  mostra();
  $("#salvato").textContent = "Salvato.";
  setTimeout(() => $("#salvato").textContent = "Le modifiche si salvano da sole.", 1500);
}
for (const el of document.querySelectorAll("[data-chiave]")) {
  const k = el.dataset.chiave;
  if (el.classList.contains("scelte")) el.querySelectorAll("button").forEach(b => b.onclick = () => salva(k, b.value));
  else if (el.type === "checkbox") el.onchange = () => salva(k, el.checked);
  else el.onchange = () => salva(k, el.tagName === "SELECT" && /^\d+$/.test(el.value) ? Number(el.value) : el.value);
}

$("#ublock").onclick = async () => {
  try {
    const u = await browser.management.get("uBlock0@raymondhill.net");
    if (u.optionsUrl) browser.tabs.create({ url: u.optionsUrl });
  } catch (e) { $("#ublock").textContent = "uBlock Origin non c'è"; }
};
$("#pulisci").onclick = async () => {
  await browser.browsingData.remove({}, { history: true, cookies: true, cache: true, localStorage: true, formData: true, downloads: true });
  $("#pulisci").textContent = "Fatto ✓";
};

$("#modello").onchange = () => {
  const [fornitore, ...m] = $("#modello").value.split("|");
  porta.postMessage({ tipo: "usa", fornitore, modello: m.join("|") });
};
porta.onMessage.addListener(m => {
  if (m.tipo !== "modelli") return;
  const s = $("#modello"); s.innerHTML = "";
  for (const x of m.modelli) {
    const o = document.createElement("option");
    o.value = x.fornitore + "|" + x.id;
    o.textContent = (x.fornitore === "ollama" ? "Sul PC · " : x.nome_fornitore + " · ") + x.nome.replace(/^hf\.co\//, "") + (x.fornitore !== "ollama" && x.gratis ? " (gratis)" : "");
    o.selected = x.id === m.scelto.modello;
    s.appendChild(o);
  }
});
porta.postMessage({ tipo: "modelli" });

browser.runtime.sendMessage({ tipo: "impostazioni_di_serie" }).then(serie => {
  browser.storage.local.get("impostazioni").then(d => { imp = { ...serie, ...(d.impostazioni || {}) }; mostra(); });
});
