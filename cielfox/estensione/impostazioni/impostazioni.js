// Le impostazioni di CielFox: si salvano subito in storage.local («impostazioni»); sfondo.js le applica
// (aspetto, privacy, schede addormentate) e la nuova scheda le legge.
const $ = s => document.querySelector(s);
let imp = {}, serie = {};
const porta = browser.runtime.connect({ name: "pannello" });       // per i modelli (li chiede al ponte)

// i motori, come scelte
for (const [id, m] of Object.entries(MOTORI)) {
  const b = document.createElement("button");
  b.value = id;
  b.innerHTML = "<b></b><small></small>";
  b.querySelector("b").textContent = m.nome;
  b.querySelector("small").textContent = m.nota;
  $("#motori").appendChild(b);
}

function mostra() {
  for (const el of document.querySelectorAll("[data-chiave]")) {
    const v = imp[el.dataset.chiave];
    if (el.tagName === "DIV") el.querySelectorAll("button").forEach(b => b.classList.toggle("scelto", b.value === v));
    else if (el.type === "checkbox") el.checked = !!v;
    else if (v !== undefined) el.value = String(v);
  }
  $("#rigaAccento").hidden = imp.aspetto !== "personale";
}
let spegni;
function salva(cambi) {
  imp = { ...imp, ...cambi };
  browser.storage.local.set({ impostazioni: imp });
  mostra();
  $("#salvato").classList.add("ora"); $("#salvato span").textContent = "Salvato";
  clearTimeout(spegni);
  spegni = setTimeout(() => { $("#salvato").classList.remove("ora"); $("#salvato span").textContent = "Le modifiche si salvano da sole"; }, 1800);
}
for (const el of document.querySelectorAll("[data-chiave]")) {
  const k = el.dataset.chiave;
  if (el.tagName === "DIV") el.querySelectorAll("button").forEach(b => b.onclick = () => salva({ [k]: b.value }));
  else if (el.type === "checkbox") el.onchange = () => salva({ [k]: el.checked });
  else if (el.type === "color") el.oninput = () => salva({ [k]: el.value });
  else el.onchange = () => salva({ [k]: el.tagName === "SELECT" && /^\d+$/.test(el.value) ? Number(el.value) : el.value });
}

// l'indice a sinistra segue la sezione che stai guardando
const voci = [...document.querySelectorAll("nav a")];
const osserva = new IntersectionObserver(es => {
  for (const e of es) if (e.isIntersecting)
    voci.forEach(a => a.classList.toggle("attiva", a.getAttribute("href") === "#" + e.target.id));
}, { rootMargin: "-15% 0px -75% 0px" });
document.querySelectorAll("section").forEach(s => osserva.observe(s));
voci[0].classList.add("attiva");
for (const a of voci) a.onclick = e => {
  e.preventDefault();
  document.querySelector(a.getAttribute("href")).scrollIntoView({ behavior: "smooth", block: "start" });
};

$("#ublock").onclick = async () => {
  try {
    const u = await browser.management.get("uBlock0@raymondhill.net");
    if (u.optionsUrl) browser.tabs.create({ url: u.optionsUrl });
  } catch (e) { $("#ublock").textContent = "uBlock Origin non c'è"; $("#ublock").disabled = true; }
};
let pulisciSicuro = false;
$("#pulisci").onclick = async () => {
  const s = $("#pulisci span");
  if (!pulisciSicuro) {                            // due clic: il primo chiede, il secondo pulisce
    pulisciSicuro = true; s.textContent = "Sicuro? Clicca ancora";
    setTimeout(() => { if (pulisciSicuro) { pulisciSicuro = false; s.textContent = "Pulisci"; } }, 4000);
    return;
  }
  pulisciSicuro = false;
  await browser.browsingData.remove({}, { history: true, cookies: true, cache: true, localStorage: true, formData: true, downloads: true });
  s.textContent = "Fatto";
  setTimeout(() => s.textContent = "Pulisci", 2500);
};
let ripristinaSicuro = false;
$("#ripristina").onclick = () => {
  if (!ripristinaSicuro) {
    ripristinaSicuro = true; $("#ripristina").textContent = "Sicuro? I tuoi siti restano. Clicca ancora";
    setTimeout(() => { ripristinaSicuro = false; $("#ripristina").textContent = "Rimetti le impostazioni di serie"; }, 4000);
    return;
  }
  ripristinaSicuro = false;
  salva({ ...serie, collegamenti: imp.collegamenti || [] });
  $("#ripristina").textContent = "Rimetti le impostazioni di serie";
};

$("#modello").onchange = () => {
  const [fornitore, ...m] = $("#modello").value.split("|");
  porta.postMessage({ tipo: "usa", fornitore, modello: m.join("|") });
  salva({});
};
porta.onMessage.addListener(m => {
  if (m.tipo === "ponte_spento") { $("#modello").innerHTML = "<option>Ciel non risponde</option>"; return; }
  if (m.tipo !== "modelli") return;
  const s = $("#modello"); s.innerHTML = "";
  const gruppi = {};
  for (const x of m.modelli) {
    const g = x.fornitore === "ollama" ? "Sul PC" : "In cloud · " + x.nome_fornitore;
    if (!gruppi[g]) { gruppi[g] = document.createElement("optgroup"); gruppi[g].label = g; s.appendChild(gruppi[g]); }
    const o = document.createElement("option");
    o.value = x.fornitore + "|" + x.id;
    o.textContent = x.nome.replace(/^hf\.co\//, "") + (x.fornitore !== "ollama" && x.gratis ? " (gratis)" : "");
    o.selected = x.id === m.scelto.modello;
    gruppi[g].appendChild(o);
  }
});
porta.postMessage({ tipo: "modelli" });

browser.runtime.sendMessage({ tipo: "impostazioni_di_serie" }).then(s => {
  serie = s;
  browser.storage.local.get("impostazioni").then(d => { imp = { ...serie, ...(d.impostazioni || {}) }; mostra(); });
});
