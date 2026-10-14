// Il pannello di Ciel in CielFox: «Chiedi» (a Ciel, anche sulla pagina aperta) e «Compiti» (l'agente del browser).
// Parla con sfondo.js, che parla con il ponte (e lui con Ciel e i modelli).
const porta = browser.runtime.connect({ name: "pannello" });
const $ = s => document.querySelector(s);
let finestra = null;
browser.windows.getCurrent().then(w => finestra = w.id);
const nuovoId = () => Math.random().toString(36).slice(2, 10);

for (const b of document.querySelectorAll("nav button"))
  b.onclick = () => {
    document.querySelectorAll("nav button, .scheda").forEach(x => x.classList.remove("attiva"));
    b.classList.add("attiva"); $("#" + b.dataset.scheda).classList.add("attiva");
    if (b.dataset.scheda === "compiti") porta.postMessage({ tipo: "modelli" });
  };

function aggiungi(dove, classe, testo) {
  const el = document.createElement("div");
  el.className = classe; el.textContent = testo;
  dove.querySelector(".vuoto")?.remove();
  dove.appendChild(el); dove.scrollTop = dove.scrollHeight;
  return el;
}
function conferma(dove, testo, risposta) {
  const el = document.createElement("div");
  el.className = "conferma";
  el.innerHTML = "<span></span><div><button class='si'>Sì</button><button class='no'>No</button></div>";
  el.querySelector("span").textContent = testo;
  const fine = si => { el.querySelector("div").remove(); aggiungi(el, "stato", si ? "Confermato." : "Non confermato."); risposta(si); };
  el.querySelector(".si").onclick = () => fine(true);
  el.querySelector(".no").onclick = () => fine(false);
  dove.appendChild(el); dove.scrollTop = dove.scrollHeight;
}
function invioConTasto(area, form) {
  area.addEventListener("keydown", e => { if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); form.requestSubmit(); } });
}

// ── Chiedi ───────────────────────────────────────────────────────────────────────────────────────────────────
const conv = $("#conversazione");
const stati = {};
invioConTasto($("#domanda"), $("#formChiedi"));
$("#formChiedi").onsubmit = e => {
  e.preventDefault();
  const t = $("#domanda").value.trim();
  if (!t) return;
  $("#domanda").value = "";
  aggiungi(conv, "tu", t);
  const id = nuovoId();
  stati[id] = aggiungi(conv, "stato", "…");
  porta.postMessage({ tipo: "ciel", id, testo: t, finestra, vedi: $("#vedi").checked, foto: $("#foto").checked });
};

// ── Compiti ──────────────────────────────────────────────────────────────────────────────────────────────────
const reg = $("#registro");
let compito = null, corrente = null;
invioConTasto($("#compito"), $("#formCompito"));
$("#formCompito").onsubmit = e => {
  e.preventDefault();
  if (compito) { porta.postMessage({ tipo: "ferma", id: compito }); return; }
  const t = $("#compito").value.trim();
  if (!t) return;
  $("#compito").value = "";
  aggiungi(reg, "tu", t);
  compito = nuovoId();
  $("#via").textContent = "■"; $("#via").classList.add("ferma");
  porta.postMessage({ tipo: "compito", id: compito, testo: t, finestra });
};
function finito() { compito = null; corrente = null; $("#via").textContent = "↑"; $("#via").classList.remove("ferma"); }
const NOMI = { read_page: "Legge la pagina", click: "Clicca", type_text: "Scrive", select_option: "Sceglie", press_key: "Preme",
               scroll: "Scorre", go_to: "Apre", go_back: "Torna indietro", new_tab: "Nuova scheda", list_tabs: "Guarda le schede",
               switch_tab: "Cambia scheda", wait: "Aspetta", look: "Guarda la pagina" };
let ultimoPasso = null;

$("#modello").onchange = () => {
  const [fornitore, ...m] = $("#modello").value.split("|");
  porta.postMessage({ tipo: "usa", fornitore, modello: m.join("|") });
};

// ── Anonimo (Tor) ────────────────────────────────────────────────────────────────────────────────────────────
let tor = false;
$("#anonimo").onclick = () => {
  $("#anonimo").classList.add("attende");
  $("#anonimo").textContent = tor ? "Anonimo" : "Collego…";
  porta.postMessage({ tipo: "tor", acceso: !tor });
};

// ── dal ponte ────────────────────────────────────────────────────────────────────────────────────────────────
porta.onMessage.addListener(m => {
  switch (m.tipo) {
    case "ciao":
      tor = m.tor; $("#anonimo").classList.toggle("acceso", tor);
      if (!m.ciel) aggiungi(conv, "stato", "Ciel è spenta: accendila con «ciel accendi» (i compiti funzionano lo stesso).");
      break;
    case "ciel_stato": if (stati[m.id]) stati[m.id].textContent = m.stato; break;
    case "ciel_domanda":
      conferma(conv, m.testo, si => porta.postMessage({ tipo: "conferma", conferma: m.id, si }));
      break;
    case "ciel_risposta":
      stati[m.id]?.remove(); delete stati[m.id];
      aggiungi(conv, "ciel" + (m.errore ? " errore" : ""), m.testo);
      break;
    case "agente":
      if (m.id !== compito) break;
      if (m.ev === "inizio") aggiungi(reg, "stato", "Lavoro con " + (m.modello || "").replace(/^hf\.co\//, "") + "…");
      else if (m.ev === "testo") { corrente ??= aggiungi(reg, "ciel", ""); corrente.textContent += m.delta; reg.scrollTop = reg.scrollHeight; }
      else if (m.ev === "passo") {
        corrente = null;
        const a = m.argomenti || {};
        ultimoPasso = aggiungi(reg, "passo", (NOMI[m.nome] || m.nome) + " " + (a.url || (a.text ? "«" + a.text + "»" : "") || (a.n ? "[" + a.n + "]" : "") || a.direction || a.key || ""));
      }
      else if (m.ev === "esito" && ultimoPasso) { ultimoPasso.classList.add(m.ok ? "ok" : "no"); if (!m.ok) ultimoPasso.title = m.testo; }
      else if (m.ev === "conferma") conferma(reg, m.testo, si => porta.postMessage({ tipo: "conferma", conferma: m.conferma, si }));
      else if (m.ev === "avviso") aggiungi(reg, "stato", m.testo);
      else if (m.ev === "fatto") { if (corrente === null && m.testo) aggiungi(reg, "ciel", m.testo); finito(); }
      else if (m.ev === "errore") { aggiungi(reg, "err", m.testo); finito(); }
      break;
    case "modelli": {
      const s = $("#modello"); s.innerHTML = "";
      for (const x of m.modelli) {
        const o = document.createElement("option");
        o.value = x.fornitore + "|" + x.id;
        o.textContent = (x.fornitore === "ollama" ? "💻 " : "☁ ") + x.nome + (x.fornitore !== "ollama" && x.gratis ? " (gratis)" : "");
        o.selected = x.id === m.scelto.modello;
        s.appendChild(o);
      }
      break;
    }
    case "rete":
      tor = m.tor; $("#anonimo").classList.remove("attende"); $("#anonimo").classList.toggle("acceso", tor);
      $("#anonimo").textContent = "Anonimo";
      if (m.errore) aggiungi(conv, "err", m.errore); else if (m.nota) aggiungi(conv, "stato", m.nota);
      break;
    case "ponte_spento": aggiungi(conv, "err", "Il ponte con Ciel non risponde: " + m.testo); finito(); break;
  }
});
