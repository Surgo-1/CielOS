// La nuova scheda di CielFox: ora e saluto, ricerca (il motore si cambia dal bottone a sinistra; «Chiedi a Ciel»,
// Maiusc+Invio o «?» davanti la mandano a Ciel), i tuoi siti (iniziali: nessuna icona scaricata dai siti, niente tracce).
const $ = s => document.querySelector(s);
let imp = {};
const ICONE = "../comune/icone.svg#";

function orologio() {
  const d = new Date();
  $("#ora").textContent = d.toLocaleTimeString("it-IT", { hour: "2-digit", minute: "2-digit" });
  const h = d.getHours();
  const saluto = h < 5 ? "Buonanotte" : h < 13 ? "Buongiorno" : h < 18 ? "Buon pomeriggio" : "Buonasera";
  $("#saluto").textContent = (imp.saluto === false ? "" : saluto + " · ") +
    d.toLocaleDateString("it-IT", { weekday: "long", day: "numeric", month: "long" });
}

function icona(nome, piccola) {
  return `<svg class="ic${piccola ? " piccola" : ""}"><use href="${ICONE}${nome}"/></svg>`;
}

function disegna() {
  $("#ora").hidden = imp.orologio === false;
  const m = motore(imp.motore);
  $("#nomeMotore").textContent = m.nome;
  $("#q").placeholder = `Cerca con ${m.nome} o scrivi un indirizzo`;

  const siti = imp.collegamenti || [];
  const c = $("#collegamenti");
  c.innerHTML = "";
  for (const [i, l] of siti.entries()) {
    const a = document.createElement("a");
    a.className = "tile"; a.href = l.url; a.title = l.url;
    a.innerHTML = `<div class="iniziale"></div><span></span><button class="via" title="Togli dai tuoi siti">${icona("x", true)}</button>`;
    a.querySelector(".iniziale").textContent = (l.titolo || l.url).replace(/^https?:\/\/(www\.)?/, "")[0]?.toUpperCase() || "?";
    a.querySelector("span").textContent = l.titolo;
    a.querySelector(".via").onclick = e => {
      e.preventDefault(); e.stopPropagation();
      const n = [...siti]; n.splice(i, 1);
      salva({ collegamenti: n });
    };
    c.appendChild(a);
  }
  const piu = document.createElement("a");
  piu.className = "tile aggiungi"; piu.href = "#";
  piu.innerHTML = `<div class="iniziale">${icona("piu")}</div><span>${siti.length ? "Aggiungi" : "Aggiungi un sito"}</span>`;
  piu.onclick = e => { e.preventDefault(); $("#formNuovo").reset(); $("#nuovo").showModal(); };
  c.appendChild(piu);
  $("#modifica").hidden = !siti.length;
  if (!siti.length) c.parentElement.classList.remove("modifica");
}

function salva(cambi) {
  imp = { ...imp, ...cambi };
  browser.storage.local.set({ impostazioni: imp });
}

// ── il menu dei motori ──────────────────────────────────────────────────────────────────────────────────────────
function menuMotori(apri) {
  const menu = $("#menuMotori"), b = $("#sceltaMotore");
  if (!apri) { menu.hidden = true; b.setAttribute("aria-expanded", "false"); return; }
  menu.innerHTML = "";
  for (const [id, m] of Object.entries(MOTORI)) {
    const x = document.createElement("button");
    x.type = "button"; x.setAttribute("role", "option");
    const scelto = id === (MOTORI[imp.motore] ? imp.motore : "duckduckgo");
    x.innerHTML = `<span class="spunta">${scelto ? icona("ok", true) : ""}</span><span class="nome"></span><small></small>`;
    x.querySelector(".nome").textContent = m.nome;
    x.querySelector("small").textContent = m.nota;
    x.onclick = () => { salva({ motore: id }); disegna(); menuMotori(false); $("#q").focus(); };
    menu.appendChild(x);
  }
  menu.hidden = false; b.setAttribute("aria-expanded", "true");
  menu.querySelector("button")?.focus();
}
$("#sceltaMotore").onclick = () => menuMotori($("#menuMotori").hidden);
document.addEventListener("click", e => { if (!e.target.closest(".cercatore")) menuMotori(false); });
document.addEventListener("keydown", e => { if (e.key === "Escape" && !$("#menuMotori").hidden) { menuMotori(false); $("#q").focus(); } });

// ── cercare, aprire, chiedere a Ciel ───────────────────────────────────────────────────────────────────────────
async function aCiel(testo) {                     // si apre la barra laterale e la domanda arriva lì
  browser.sidebarAction.open();                   // subito, dentro il gesto dell'utente (se no il browser lo blocca)
  await browser.storage.local.set({ domandaPerCiel: { testo, t: Date.now() } });
  $("#q").value = ""; aggiornaCiel();
}
function aggiornaCiel() { $("#chiediCiel").classList.toggle("pronto", $("#q").value.trim().startsWith("?")); }
$("#q").addEventListener("input", aggiornaCiel);
$("#q").addEventListener("keydown", e => {
  if (e.key === "Enter" && e.shiftKey) { e.preventDefault(); const t = $("#q").value.trim().replace(/^\?\s*/, ""); if (t) aCiel(t); }
});
$("#chiediCiel").onclick = () => {
  const t = $("#q").value.trim().replace(/^\?\s*/, "");
  if (t) aCiel(t); else { browser.sidebarAction.open(); }
};
$("#cerca").onsubmit = e => {
  e.preventDefault();
  const q = $("#q").value.trim();
  if (!q) return;
  if (q.startsWith("?")) return aCiel(q.slice(1).trim());
  const sembraIndirizzo = /^[^\s]+\.[a-z]{2,}(:\d+)?(\/\S*)?$/i.test(q) || /^[a-z]+:\/\//i.test(q) || /^localhost(:\d+)?/.test(q);
  location.href = sembraIndirizzo ? (/^[a-z]+:\/\//i.test(q) ? q : "https://" + q)
                                  : motore(imp.motore).url + encodeURIComponent(q);
};

// ── i tuoi siti ────────────────────────────────────────────────────────────────────────────────────────────────
$("#modifica").onclick = () => {
  const s = $(".siti");
  s.classList.toggle("modifica");
  $("#modifica").textContent = s.classList.contains("modifica") ? "Fatto" : "Modifica";
};
$("#annulla").onclick = () => $("#nuovo").close();
$("#formNuovo").onsubmit = () => {
  let url = $("#nUrl").value.trim();
  if (!url) return;
  if (!/^[a-z]+:/i.test(url)) url = "https://" + url;
  let titolo = $("#nTitolo").value.trim();
  if (!titolo) {
    try { titolo = new URL(url).hostname.replace(/^www\./, "").replace(/\.[a-z]+$/i, ""); titolo = titolo[0].toUpperCase() + titolo.slice(1); }
    catch { titolo = url; }
  }
  salva({ collegamenti: [...(imp.collegamenti || []), { titolo, url }] });
};

$("#impostazioni").onclick = () => browser.runtime.openOptionsPage();

browser.storage.local.get("impostazioni").then(d => { imp = d.impostazioni || {}; disegna(); orologio(); });
browser.storage.onChanged.addListener(ch => { if (ch.impostazioni) { imp = ch.impostazioni.newValue || {}; disegna(); orologio(); } });
setInterval(orologio, 10000);
