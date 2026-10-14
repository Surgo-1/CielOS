// Lo sfondo dell'estensione: tiene il collegamento con il ponte (cielfox_ponte.py), passa i messaggi al pannello,
// esegue nelle schede le azioni dell'agente, mette il tema di CielFox (e la variante azzurra mentre l'IA lavora),
// e manda il traffico attraverso Tor quando «Anonimo» è acceso.

const TEMA = {
  colors: {
    frame: "#0b1029", frame_inactive: "#0b1029", tab_background_text: "#b9c7e6", tab_selected: "#16204a",
    tab_text: "#ffffff", tab_line: "#3fa9e8", tab_loading: "#9fe1ff", toolbar: "#16204a", toolbar_text: "#e6f3ff",
    toolbar_field: "#0b1029", toolbar_field_text: "#e6f3ff", toolbar_field_border: "#2a3a6a",
    toolbar_field_focus: "#0b1029", toolbar_field_border_focus: "#3fa9e8", toolbar_top_separator: "#0b1029",
    toolbar_bottom_separator: "#0b1029", popup: "#16204a", popup_text: "#e6f3ff", popup_border: "#2a3a6a",
    popup_highlight: "#3fa9e8", popup_highlight_text: "#0b1029", sidebar: "#0e1533", sidebar_text: "#e6f3ff",
    sidebar_border: "#16204a", sidebar_highlight: "#3fa9e8", sidebar_highlight_text: "#0b1029",
    ntp_background: "#0b1029", ntp_text: "#e6f3ff", icons: "#9fe1ff", icons_attention: "#9fe1ff",
    button_background_hover: "rgba(159,225,255,0.12)", button_background_active: "rgba(159,225,255,0.22)",
  },
};
// mentre Ciel lavora: la cornice della finestra e il bordo della scheda diventano azzurrini
const TEMA_LAVORO = { colors: { ...TEMA.colors, frame: "#123a5e", frame_inactive: "#123a5e", tab_line: "#9fe1ff",
                                tab_selected: "#1d4a75", toolbar: "#183a63", toolbar_top_separator: "#9fe1ff" } };

let ponte = null;
const pannelli = new Set();
const agenti = new Map();            // id del compito -> { tab, finestra }
let anonimo = false;

browser.theme.update(TEMA);

function collega() {
  ponte = browser.runtime.connectNative("cielfox");
  ponte.onMessage.addListener(dalPonte);
  ponte.onDisconnect.addListener(() => {
    const e = ponte?.error?.message;
    ponte = null;
    a_pannelli({ tipo: "ponte_spento", testo: e || "il ponte si è chiuso" });
    for (const [id, a] of agenti) fineAgente(id);
  });
  ponte.postMessage({ tipo: "ciao" });
}
function alPonte(m) {
  if (!ponte) collega();
  ponte.postMessage(m);
}
function a_pannelli(m) { for (const p of pannelli) p.postMessage(m); }

// ── le schede ──────────────────────────────────────────────────────────────────────────────────────────────────
async function inietta(tab) {
  try {
    await browser.tabs.executeScript(tab, { file: "/contenuto.js", runAt: "document_idle" });
    return true;
  } catch (e) {
    return false;                    // pagine speciali (about:, addons.mozilla.org): lì le estensioni non entrano
  }
}
async function allaPagina(tab, m) {
  if (!(await inietta(tab))) return { errore: "this page cannot be read or controlled (browser page)" };
  try {
    return (await browser.tabs.sendMessage(tab, m)) ?? { errore: "no answer from the page" };
  } catch (e) {
    return { errore: String(e.message || e) };
  }
}
function caricata(tab, max = 20000) {
  return new Promise(ok => {
    const fine = setTimeout(() => { browser.tabs.onUpdated.removeListener(l); ok(); }, max);
    const l = (id, info) => {
      if (id === tab && info.status === "complete") {
        clearTimeout(fine); browser.tabs.onUpdated.removeListener(l); setTimeout(ok, 400);
      }
    };
    browser.tabs.onUpdated.addListener(l);
  });
}

// ── l'agente ───────────────────────────────────────────────────────────────────────────────────────────────────
async function eseguiAzione(m) {
  const a = agenti.get(m.id);
  if (!a) return { errore: "no task" };
  const g = m.argomenti || {};
  switch (m.nome) {
    case "leggi": case "clicca": case "scrivi": case "scegli": case "premi": case "scorri": case "descrivi_elemento": {
      const r = await allaPagina(a.tab, { fai: m.nome, ...g });
      if (m.nome === "clicca" || (m.nome === "scrivi" && g.enter) || (m.nome === "premi" && g.key === "Enter")) {
        await new Promise(ok => setTimeout(ok, 900));          // se il clic apre un'altra pagina, aspetta che carichi
        const t = await browser.tabs.get(a.tab);
        if (t.status === "loading") await caricata(a.tab, 15000);
        if (a.attivo) allaPagina(a.tab, { fai: "evidenzia", si: true });
      }
      return r;
    }
    case "vai": {
      let url = String(g.url || "").trim();
      if (!/^[a-z]+:/i.test(url)) url = "https://" + url;
      await browser.tabs.update(a.tab, { url });
      await caricata(a.tab);
      if (a.attivo) await allaPagina(a.tab, { fai: "evidenzia", si: true });
      return { testo: `Opened ${url}. Call read_page.` };
    }
    case "indietro":
      await browser.tabs.goBack(a.tab);
      await caricata(a.tab, 10000);
      return { testo: "Went back." };
    case "nuova_scheda": {
      const t = await browser.tabs.create({ url: g.url ? (/^[a-z]+:/i.test(g.url) ? g.url : "https://" + g.url) : undefined,
                                            windowId: a.finestra, active: true });
      await allaPagina(a.tab, { fai: "evidenzia", si: false });
      a.tab = t.id;
      if (g.url) await caricata(t.id);
      await allaPagina(t.id, { fai: "evidenzia", si: true });
      return { testo: "New tab opened." };
    }
    case "schede": {
      const ts = await browser.tabs.query({ windowId: a.finestra });
      return { testo: ts.map((t, i) => `[${i + 1}] ${t.id === a.tab ? "(current) " : ""}${t.title} — ${t.url}`).join("\n") };
    }
    case "scheda": {
      const ts = await browser.tabs.query({ windowId: a.finestra });
      const t = ts[Number(g.n) - 1];
      if (!t) return { errore: "no tab with that number" };
      await allaPagina(a.tab, { fai: "evidenzia", si: false });
      a.tab = t.id;
      await browser.tabs.update(t.id, { active: true });
      await allaPagina(t.id, { fai: "evidenzia", si: true });
      return { testo: `Now on tab [${g.n}] ${t.title}.` };
    }
    case "screenshot": {
      await browser.tabs.update(a.tab, { active: true });
      const url = await browser.tabs.captureTab(a.tab, { format: "jpeg", quality: 80 });
      return { png: url.split(",")[1] };
    }
    case "evidenzia":
      a.attivo = !!g.si;
      browser.theme.update(a.finestra, g.si ? TEMA_LAVORO : TEMA);
      return await allaPagina(a.tab, { fai: "evidenzia", si: !!g.si });
  }
  return { errore: "unknown action " + m.nome };
}
function fineAgente(id) {
  const a = agenti.get(id);
  if (!a) return;
  browser.theme.update(a.finestra, TEMA);
  allaPagina(a.tab, { fai: "evidenzia", si: false });
  agenti.delete(id);
}

function dalPonte(m) {
  if (m.tipo === "azione") {
    eseguiAzione(m).then(r => ponte?.postMessage({ tipo: "esito_azione", id: m.id, azione: m.azione, risultato: r }));
    return;
  }
  if (m.tipo === "agente" && (m.ev === "fatto" || m.ev === "errore")) fineAgente(m.id);
  if (m.tipo === "rete") anonimo = !!m.tor;
  a_pannelli(m);
}

// ── dal pannello ───────────────────────────────────────────────────────────────────────────────────────────────
async function dalPannello(m) {
  if (m.tipo === "ciel") {
    const [tab] = await browser.tabs.query({ active: true, windowId: m.finestra });
    if (m.vedi && tab) {
      const c = await allaPagina(tab.id, { fai: "contesto" });
      if (!c.errore) m.contesto = c;
      else m.contesto = { titolo: tab.title, url: tab.url };
      if (m.foto) {
        try { m.immagine = (await browser.tabs.captureTab(tab.id, { format: "jpeg", quality: 80 })).split(",")[1]; }
        catch (e) { /* pagine speciali */ }
      }
    }
    delete m.vedi; delete m.foto;
    return alPonte(m);
  }
  if (m.tipo === "compito") {
    const [tab] = await browser.tabs.query({ active: true, windowId: m.finestra });
    agenti.set(m.id, { tab: tab.id, finestra: m.finestra, attivo: false });
    return alPonte(m);
  }
  if (m.tipo === "ferma") for (const id of agenti.keys()) if (!m.id || id === m.id) fineAgente(id);
  alPonte(m);
}

browser.runtime.onConnect.addListener(p => {
  if (p.name !== "pannello") return;
  pannelli.add(p);
  p.onMessage.addListener(dalPannello);
  p.onDisconnect.addListener(() => pannelli.delete(p));
  if (!ponte) collega(); else ponte.postMessage({ tipo: "ciao" });
});

// se una pagina dell'agente si ricarica da sola, il bordo torna
browser.tabs.onUpdated.addListener((id, info) => {
  if (info.status !== "complete") return;
  for (const a of agenti.values()) if (a.tab === id && a.attivo) allaPagina(id, { fai: "evidenzia", si: true });
});

// «Anonimo»: tutto il traffico del browser passa da Tor (acceso dal ponte, solo quando serve)
browser.proxy.onRequest.addListener(() => anonimo ? { type: "socks", host: "127.0.0.1", port: 9150, proxyDNS: true }
                                                  : { type: "direct" }, { urls: ["<all_urls>"] });

browser.browserAction.onClicked.addListener(() => browser.sidebarAction.toggle());
