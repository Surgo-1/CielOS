// Il pannello di Ciel in CielFox: «Chiedi» (a Ciel, anche sulla pagina aperta) e «Fai per me» (l'agente del browser).
// Parla con sfondo.js, che parla con il ponte (e lui con Ciel e i modelli).
const porta = browser.runtime.connect({ name: "pannello" });
const $ = s => document.querySelector(s);
const ICONE = "../comune/icone.svg#";
let finestra = null;
const nuovoId = () => Math.random().toString(36).slice(2, 10);

// ── le due schede ───────────────────────────────────────────────────────────────────────────────────────────
function mostraScheda(nome) {
  document.querySelectorAll(".segmenti button").forEach(x => x.classList.toggle("attiva", x.dataset.scheda === nome));
  document.querySelectorAll(".scheda").forEach(x => x.classList.toggle("attiva", x.id === nome));
  if (nome === "compiti") porta.postMessage({ tipo: "modelli" });
  (nome === "compiti" ? $("#compito") : $("#domanda")).focus();
}
for (const b of document.querySelectorAll(".segmenti button")) b.onclick = () => mostraScheda(b.dataset.scheda);

// ── pezzi comuni ────────────────────────────────────────────────────────────────────────────────────────────
const VUOTI = { conversazione: $("#conversazione .vuoto"), registro: $("#registro .vuoto") };
function aggiungi(dove, classe, testo) {
  const el = document.createElement("div");
  el.className = classe; el.textContent = testo;
  dove.querySelector(".vuoto")?.remove();
  dove.appendChild(el); dove.scrollTop = dove.scrollHeight;
  return el;
}
// le risposte di Ciel: un markdown piccolo (paragrafi, elenchi, grassetto, codice, link), sempre a partire da testo puro
function scappa(t) { return t.replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]); }
function inline(t) {
  return scappa(t).replace(/`([^`]+)`/g, "<code>$1</code>").replace(/\*\*([^*]+)\*\*/g, "<b>$1</b>")
    .replace(/(^|[\s(])\*([^*\s][^*]*)\*/g, "$1<i>$2</i>")
    .replace(/\bhttps?:\/\/[^\s<)]+/g, u => `<a href="${u}" target="_blank" rel="noopener">${u}</a>`);
}
function markdown(testo) {
  const out = []; let lista = null;
  for (const riga of testo.split("\n")) {
    const m = riga.match(/^\s*(?:[-*•]|(\d+)[.)])\s+(.*)/);
    if (m) {
      const tipo = m[1] ? "ol" : "ul";
      if (lista !== tipo) { if (lista) out.push(`</${lista}>`); out.push(`<${tipo}>`); lista = tipo; }
      out.push(`<li>${inline(m[2])}</li>`);
      continue;
    }
    if (lista) { out.push(`</${lista}>`); lista = null; }
    if (riga.trim()) out.push(`<p>${inline(riga.replace(/^#+\s*/, ""))}</p>`);
  }
  if (lista) out.push(`</${lista}>`);
  return out.join("");
}
function risposta(dove, testo) {
  const el = aggiungi(dove, "ciel", "");
  el.innerHTML = markdown(testo);
  const c = document.createElement("button");
  c.className = "icona copia"; c.title = "Copia";
  c.innerHTML = `<svg class="ic piccola"><use href="${ICONE}copia"/></svg>`;
  c.onclick = () => { navigator.clipboard.writeText(testo); c.innerHTML = `<svg class="ic piccola"><use href="${ICONE}ok"/></svg>`; };
  el.appendChild(c);
  dove.scrollTop = dove.scrollHeight;
  return el;
}
function conferma(dove, testo, risposta) {
  const el = document.createElement("div");
  el.className = "conferma";
  el.innerHTML = "<b>Posso procedere?</b><span></span><div class='scelta'><button class='bottone primario'>Sì, vai</button><button class='bottone'>No</button></div>";
  el.querySelector("span").textContent = testo;
  const [si, no] = el.querySelectorAll("button");
  const fine = ok => { el.querySelector(".scelta").remove(); aggiungi(el, "stato", ok ? "Hai detto di sì." : "Hai detto di no."); risposta(ok); };
  si.onclick = () => fine(true); no.onclick = () => fine(false);
  dove.querySelector(".vuoto")?.remove();
  dove.appendChild(el); dove.scrollTop = dove.scrollHeight;
  si.focus();
}
function scrittura(area, form, bottone) {
  const misura = () => { area.style.height = "auto"; area.style.height = Math.min(area.scrollHeight, 160) + "px";
                         if (!bottone.classList.contains("ferma")) bottone.disabled = !area.value.trim(); };
  area.addEventListener("input", misura);
  area.addEventListener("keydown", e => { if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); form.requestSubmit(); } });
  misura();
  return misura;
}
for (const g of document.querySelectorAll(".esempi")) for (const b of g.querySelectorAll("button"))
  b.onclick = () => {
    const area = $("#" + g.dataset.per);
    area.value = b.textContent; area.dispatchEvent(new Event("input"));
    area.closest("form").requestSubmit();
  };

// ── che pagina vede Ciel ───────────────────────────────────────────────────────────────────────────────────────
let vedi = true, foto = false, paginaLeggibile = true;
async function aggiornaPagina() {
  if (finestra === null) return;
  const [t] = await browser.tabs.query({ active: true, windowId: finestra });
  paginaLeggibile = !!t && /^(https?|file):/.test(t.url || "") && !t.incognito;
  const titolo = t?.title || "";
  $("#vediTesto").textContent = !vedi ? "Non vede la pagina" : !paginaLeggibile ? "Questa pagina non si legge"
                                : "Vede: " + (titolo.length > 40 ? titolo.slice(0, 40) + "…" : titolo);
  $("#vedi").classList.toggle("accesa", vedi && paginaLeggibile);
  $("#vedi use").setAttribute("href", ICONE + (vedi ? "occhio" : "occhio-no"));
  $("#foto").hidden = !vedi || !paginaLeggibile;
  $("#foto").classList.toggle("accesa", foto);
}
$("#vedi").onclick = () => { vedi = !vedi; aggiornaPagina(); };
$("#foto").onclick = () => { foto = !foto; aggiornaPagina(); };
browser.tabs.onActivated.addListener(i => i.windowId === finestra && aggiornaPagina());
browser.tabs.onUpdated.addListener((id, info, t) => t.windowId === finestra && t.active && (info.title || info.url) && aggiornaPagina());
browser.windows.getCurrent().then(w => { finestra = w.id; aggiornaPagina(); });

// ── Chiedi ───────────────────────────────────────────────────────────────────────────────────────────────────
const conv = $("#conversazione");
const stati = {};
const misuraDomanda = scrittura($("#domanda"), $("#formChiedi"), $("#formChiedi .manda"));
$("#formChiedi").onsubmit = e => {
  e.preventDefault();
  const t = $("#domanda").value.trim();
  if (!t) return;
  $("#domanda").value = ""; misuraDomanda();
  aggiungi(conv, "tu", t);
  const id = nuovoId();
  const guarda = vedi && paginaLeggibile;
  stati[id] = aggiungi(conv, "stato pensa", guarda ? "Leggo la pagina…" : "Ci penso…");
  porta.postMessage({ tipo: "ciel", id, testo: t, finestra, vedi: guarda, foto: guarda && foto });
};
$("#pulisciChat").onclick = () => {
  const attiva = $(".scheda.attiva");
  const flusso = attiva.querySelector(".flusso");
  if (attiva.id === "compiti" && compito) return;          // non mentre lavora
  flusso.innerHTML = ""; flusso.appendChild(VUOTI[flusso.id]);
  (attiva.id === "compiti" ? $("#compito") : $("#domanda")).focus();
};

// ── Fai per me ───────────────────────────────────────────────────────────────────────────────────────────────
const reg = $("#registro");
let compito = null, corrente = null, passi = null, ultimoPasso = null;
const misuraCompito = scrittura($("#compito"), $("#formCompito"), $("#via"));
$("#formCompito").onsubmit = async e => {
  e.preventDefault();
  if (compito) return;
  const t = $("#compito").value.trim();
  if (!t) return;
  $("#compito").value = ""; misuraCompito();
  aggiungi(reg, "tu", t);
  compito = nuovoId();
  const [tab] = await browser.tabs.query({ active: true, windowId: finestra });
  $("#lavoroTesto").textContent = "Sto lavorando" + (tab?.title ? " in «" + tab.title.slice(0, 50) + "»" : "") + "…";
  $("#lavoro").hidden = false;
  $("#via").classList.add("ferma"); $("#via").disabled = true; $("#via").title = "Ci sto lavorando";
  porta.postMessage({ tipo: "compito", id: compito, testo: t, finestra });
};
function ferma() { if (compito) porta.postMessage({ tipo: "ferma", id: compito }); aggiungi(reg, "avviso", "Fermato."); finito(); }
$("#ferma").onclick = ferma;
function finito() {
  compito = null; corrente = null; passi = null;
  $("#lavoro").hidden = true;
  $("#via").classList.remove("ferma"); $("#via").title = "Comincia (Invio)"; misuraCompito();
}
const NOMI = { read_page: "Leggo la pagina", click: "Clicco", type_text: "Scrivo", select_option: "Scelgo", press_key: "Premo",
               scroll: "Scorro", go_to: "Apro", go_back: "Torno indietro", new_tab: "Apro una scheda", list_tabs: "Guardo le schede",
               switch_tab: "Cambio scheda", wait: "Aspetto", look: "Guardo la pagina" };
const SCORRI = { up: "su", down: "giù", top: "in cima", bottom: "in fondo" };

$("#modello").onchange = () => {
  const [fornitore, ...m] = $("#modello").value.split("|");
  $("#iconaModello use").setAttribute("href", ICONE + (fornitore === "ollama" ? "pc" : "nuvola"));
  porta.postMessage({ tipo: "usa", fornitore, modello: m.join("|") });
};

// ── Anonimo (Tor) ────────────────────────────────────────────────────────────────────────────────────────────
let tor = false;
function mostraTor() {
  $("#anonimo").classList.remove("attende");
  $("#anonimo").classList.toggle("accesa", tor);
  $("#anonimo span").textContent = tor ? "Anonimo attivo" : "Anonimo";
}
$("#anonimo").onclick = () => {
  $("#anonimo").classList.add("attende");
  $("#anonimo span").textContent = tor ? "Spengo…" : "Collego…";
  porta.postMessage({ tipo: "tor", acceso: !tor });
};

// ── dal ponte ────────────────────────────────────────────────────────────────────────────────────────────────
function spia(accesa, titolo) { $("#spia").className = "spia " + (accesa ? "accesa" : "spenta"); $("#spia").title = titolo; }
porta.onMessage.addListener(m => {
  switch (m.tipo) {
    case "ciao":
      tor = m.tor; mostraTor();
      spia(m.ciel, m.ciel ? "Ciel è accesa" : "Ciel è spenta");
      if (!m.ciel) aggiungi(conv, "avviso", "Ciel è spenta: accendila con «ciel accendi» nel terminale. «Fai per me» funziona lo stesso.");
      break;
    case "ciel_stato": if (stati[m.id]) stati[m.id].textContent = m.stato; break;
    case "ciel_domanda":
      conferma(conv, m.testo, si => porta.postMessage({ tipo: "conferma", conferma: m.id, si }));
      break;
    case "ciel_risposta":
      stati[m.id]?.remove(); delete stati[m.id];
      if (m.errore) aggiungi(conv, "errore", m.testo); else risposta(conv, m.testo);
      break;
    case "agente":
      if (m.id !== compito) break;
      if (m.ev === "inizio") aggiungi(reg, "stato", "Uso " + (m.modello || "").replace(/^hf\.co\//, ""));
      else if (m.ev === "testo") {
        passi = null;
        corrente ??= aggiungi(reg, "ciel", "");
        corrente.dataset.testo = (corrente.dataset.testo || "") + m.delta;
        corrente.innerHTML = markdown(corrente.dataset.testo);
        reg.scrollTop = reg.scrollHeight;
      }
      else if (m.ev === "passo") {
        corrente = null;
        passi ??= aggiungi(reg, "passi", "");
        const a = m.argomenti || {};
        const det = a.url || (a.text ? "«" + a.text + "»" : "") || (a.option ? "«" + a.option + "»" : "") ||
                    SCORRI[a.direction] || a.key || "";
        ultimoPasso = document.createElement("div");
        ultimoPasso.className = "passo";
        ultimoPasso.innerHTML = "<span></span>";
        ultimoPasso.querySelector("span").textContent = (NOMI[m.nome] || m.nome) + (det ? " " + det : "");
        ultimoPasso.title = ultimoPasso.textContent;
        passi.appendChild(ultimoPasso); reg.scrollTop = reg.scrollHeight;
      }
      else if (m.ev === "esito" && ultimoPasso) { ultimoPasso.classList.add(m.ok ? "ok" : "no"); if (!m.ok) ultimoPasso.title = m.testo; }
      else if (m.ev === "conferma") { passi = null; conferma(reg, m.testo, si => porta.postMessage({ tipo: "conferma", conferma: m.conferma, si })); }
      else if (m.ev === "avviso") { passi = null; aggiungi(reg, "avviso", m.testo); }
      else if (m.ev === "fatto") { if (corrente === null && m.testo) risposta(reg, m.testo); finito(); }
      else if (m.ev === "errore") { aggiungi(reg, "errore", m.testo); finito(); }
      break;
    case "modelli": {
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
      $("#iconaModello use").setAttribute("href", ICONE + (m.scelto.fornitore === "ollama" ? "pc" : "nuvola"));
      break;
    }
    case "rete":
      tor = m.tor; mostraTor();
      if (m.errore) aggiungi(conv, "errore", m.errore); else if (m.nota) aggiungi(conv, "avviso", m.nota);
      break;
    case "ponte_spento":
      spia(false, "Il ponte con Ciel non risponde");
      aggiungi($(".scheda.attiva .flusso"), "errore", "Il ponte con Ciel non risponde: " + m.testo);
      finito();
      break;
  }
});

// ── impostazioni e domande arrivate dalla nuova scheda ─────────────────────────────────────────────────────────
$("#ingranaggio").onclick = () => browser.runtime.openOptionsPage();
browser.storage.local.get("impostazioni").then(d => {
  const i = d.impostazioni || {};
  vedi = i.vediPagina !== false; foto = !!i.fotoPagina;
  aggiornaPagina();
});
function domandaInSospeso(d) {
  if (!d || Date.now() - d.t > 60000) return;
  browser.storage.local.remove("domandaPerCiel");
  mostraScheda("chiedi");
  const prima = vedi;
  vedi = false;                                   // dalla nuova scheda non c'è una pagina da guardare
  $("#domanda").value = d.testo;
  $("#formChiedi").requestSubmit();
  vedi = prima; aggiornaPagina();
}
browser.storage.local.get("domandaPerCiel").then(d => domandaInSospeso(d.domandaPerCiel));
browser.storage.onChanged.addListener(ch => ch.domandaPerCiel?.newValue && domandaInSospeso(ch.domandaPerCiel.newValue));
$("#domanda").focus();
