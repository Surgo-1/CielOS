// La nuova scheda di CielFox: ora e saluto, ricerca (motore scelto nelle impostazioni; «?» la chiede a Ciel),
// collegamenti rapidi (iniziali colorate: nessuna icona scaricata dai siti, niente tracce).
const MOTORI = {
  duckduckgo: ["DuckDuckGo", "https://duckduckgo.com/?q="], startpage: ["Startpage", "https://www.startpage.com/sp/search?query="],
  brave: ["Brave Search", "https://search.brave.com/search?q="], qwant: ["Qwant", "https://www.qwant.com/?q="],
  ecosia: ["Ecosia", "https://www.ecosia.org/search?q="], google: ["Google", "https://www.google.com/search?q="],
  bing: ["Bing", "https://www.bing.com/search?q="],
};
const $ = s => document.querySelector(s);
let imp = {};

function orologio() {
  const d = new Date();
  $("#ora").textContent = d.toLocaleTimeString("it-IT", { hour: "2-digit", minute: "2-digit" });
  const h = d.getHours();
  const saluto = h < 5 ? "Buonanotte" : h < 13 ? "Buongiorno" : h < 18 ? "Buon pomeriggio" : "Buonasera";
  $("#saluto").textContent = (imp.saluto === false ? "" : saluto + " · ") +
    d.toLocaleDateString("it-IT", { weekday: "long", day: "numeric", month: "long" });
}

function disegna() {
  $("#ora").hidden = imp.orologio === false;
  $("#motore").textContent = (MOTORI[imp.motore] || MOTORI.duckduckgo)[0];
  const c = $("#collegamenti");
  c.innerHTML = "";
  for (const [i, l] of (imp.collegamenti || []).entries()) {
    const a = document.createElement("a");
    a.className = "tile"; a.href = l.url;
    a.innerHTML = `<div class="iniziale"></div><span></span><button class="via" title="Togli">×</button>`;
    a.querySelector(".iniziale").textContent = (l.titolo || l.url).replace(/^https?:\/\/(www\.)?/, "")[0]?.toUpperCase() || "?";
    a.querySelector("span").textContent = l.titolo;
    a.querySelector(".via").onclick = e => {
      e.preventDefault();
      const n = [...imp.collegamenti]; n.splice(i, 1);
      salva({ collegamenti: n });
    };
    c.appendChild(a);
  }
  const piu = document.createElement("a");
  piu.className = "tile aggiungi"; piu.href = "#";
  piu.innerHTML = `<div class="iniziale">+</div><span>Aggiungi</span>`;
  piu.onclick = e => { e.preventDefault(); $("#nuovo").hidden = false; $("#nTitolo").focus(); };
  c.appendChild(piu);
}

function salva(cambi) {
  imp = { ...imp, ...cambi };
  browser.storage.local.set({ impostazioni: imp });
}

$("#nuovo").onsubmit = e => {
  e.preventDefault();
  let url = $("#nUrl").value.trim();
  if (!url) return;
  if (!/^[a-z]+:/i.test(url)) url = "https://" + url;
  const titolo = $("#nTitolo").value.trim() || new URL(url).hostname.replace(/^www\./, "");
  salva({ collegamenti: [...(imp.collegamenti || []), { titolo, url }] });
  $("#nuovo").reset(); $("#nuovo").hidden = true;
};
$("#annulla").onclick = () => { $("#nuovo").reset(); $("#nuovo").hidden = true; };

$("#cerca").onsubmit = async e => {
  e.preventDefault();
  const q = $("#q").value.trim();
  if (!q) return;
  if (q.startsWith("?")) {                       // a Ciel: si apre la barra laterale e la domanda arriva lì
    await browser.storage.local.set({ domandaPerCiel: { testo: q.slice(1).trim(), t: Date.now() } });
    browser.sidebarAction.open();
    $("#q").value = "";
    return;
  }
  const sembraIndirizzo = /^[^\s]+\.[a-z]{2,}(\/\S*)?$/i.test(q) || /^[a-z]+:\/\//i.test(q) || /^localhost(:\d+)?/.test(q);
  location.href = sembraIndirizzo ? (/^[a-z]+:\/\//i.test(q) ? q : "https://" + q)
                                  : (MOTORI[imp.motore] || MOTORI.duckduckgo)[1] + encodeURIComponent(q);
};
$("#impostazioni").onclick = e => { e.preventDefault(); browser.runtime.openOptionsPage(); };

browser.storage.local.get("impostazioni").then(d => { imp = d.impostazioni || {}; disegna(); orologio(); });
browser.storage.onChanged.addListener(ch => { if (ch.impostazioni) { imp = ch.impostazioni.newValue; disegna(); orologio(); } });
setInterval(orologio, 10000);
