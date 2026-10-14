// Lo sfondo dell'estensione: tiene il collegamento con il ponte (cielfox_ponte.py), passa i messaggi al pannello,
// esegue nelle schede le azioni dell'agente, mette il tema di CielFox (e la variante azzurra mentre l'IA lavora),
// e manda il traffico attraverso Tor quando «Anonimo» è acceso.

// ── l'aspetto: i colori di CielOS (di serie, li manda il ponte), quelli celesti di CielFox, o un accento tuo ───────
const CIELFOX = { fondo: "#0b1029", fondoAlto: "#16204a", superficie: "#0e1533", oro: "#3fa9e8", oroChiaro: "#9fe1ff",
                  testo: "#e6f3ff", tenue: "#9aaacb", allarme: "#ff6b6b", bordo: "#2a3a6a", font: "Rubik" };
const SERIE = { aspetto: "cielos", accento: "#3fa9e8", motore: "duckduckgo", orologio: true, saluto: true,
                collegamenti: [], vediPagina: true, fotoPagina: false,
                tracciatori: true, soloHttps: true, webrtc: true, gpc: true, cookieSeparati: true, pulisciAvvio: false,
                dormi: 30 };
let coloriCielos = null;
let impostazioni = { ...SERIE };

function mescola(a, b, t) {
  const n = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16));
  const [x, y] = [n(a), n(b)];
  return "#" + x.map((v, i) => Math.round(v + (y[i] - v) * t).toString(16).padStart(2, "0")).join("");
}
function colori() {
  let c = impostazioni.aspetto === "cielos" && coloriCielos ? { ...CIELFOX, ...coloriCielos } : { ...CIELFOX };
  if (impostazioni.aspetto === "personale") c = { ...c, oro: impostazioni.accento, oroChiaro: mescola(impostazioni.accento, "#ffffff", 0.45) };
  return c;
}
function tema(c, lavoro = false) {
  const acc = lavoro ? "#9fe1ff" : c.oro;
  return { colors: {
    frame: lavoro ? "#123a5e" : c.fondo, frame_inactive: lavoro ? "#123a5e" : c.fondo,
    tab_background_text: c.tenue, tab_selected: lavoro ? "#1d4a75" : c.fondoAlto, tab_text: c.testo,
    tab_line: acc, tab_loading: c.oroChiaro, toolbar: lavoro ? "#183a63" : c.fondoAlto, toolbar_text: c.testo,
    toolbar_field: c.fondo, toolbar_field_text: c.testo, toolbar_field_border: c.bordo,
    toolbar_field_focus: c.fondo, toolbar_field_border_focus: acc, toolbar_field_highlight: acc,
    toolbar_field_highlight_text: c.fondo, toolbar_top_separator: lavoro ? "#9fe1ff" : c.fondo,
    toolbar_bottom_separator: c.fondo, popup: c.fondoAlto, popup_text: c.testo, popup_border: c.bordo,
    popup_highlight: acc, popup_highlight_text: c.fondo, sidebar: c.superficie || c.fondo, sidebar_text: c.testo,
    sidebar_border: c.fondoAlto, sidebar_highlight: acc, sidebar_highlight_text: c.fondo,
    ntp_background: c.fondo, ntp_text: c.testo, icons: c.oroChiaro, icons_attention: c.oroChiaro,
    button_background_hover: mescola(c.fondoAlto, c.oroChiaro, 0.14), button_background_active: mescola(c.fondoAlto, c.oroChiaro, 0.26),
  } };
}
async function applicaAspetto() {
  const c = colori();
  await browser.storage.local.set({ colori: c });          // per la nuova scheda, il pannello, le impostazioni
  browser.theme.update(tema(c));
  for (const a of agenti.values()) if (a.attivo) browser.theme.update(a.finestra, tema(c, true));
}
// ── privacy e sicurezza: con le API ufficiali del browser (le impostazioni si vedono anche in about:preferences) ──
async function applicaPrivacy() {
  const i = impostazioni, p = browser.privacy;
  const metti = (x, v) => x.set({ value: v }).catch(e => console.warn("CielFox privacy:", e));
  metti(p.websites.trackingProtectionMode, i.tracciatori ? "always" : "private_browsing");
  metti(p.network.httpsOnlyMode, i.soloHttps ? "always" : "never");
  metti(p.network.webRTCIPHandlingPolicy, i.webrtc ? "default_public_interface_only" : "default");
  if (p.network.globalPrivacyControl) metti(p.network.globalPrivacyControl, !!i.gpc);
  metti(p.websites.cookieConfig, { behavior: i.cookieSeparati ? "reject_trackers_and_partition_foreign" : "reject_trackers" });
}

browser.storage.local.get(["impostazioni", "coloriCielos"]).then(d => {
  impostazioni = { ...SERIE, ...(d.impostazioni || {}) };
  coloriCielos = d.coloriCielos || null;
  applicaAspetto();
  applicaPrivacy();
  if (impostazioni.pulisciAvvio)        // la sessione di prima: cronologia, cookie, cache (le password restano)
    browser.browsingData.remove({}, { history: true, cookies: true, cache: true, localStorage: true, formData: true, downloads: true });
});
browser.storage.onChanged.addListener(ch => {
  if (ch.impostazioni) { impostazioni = { ...SERIE, ...ch.impostazioni.newValue }; applicaAspetto(); applicaPrivacy(); }
});
browser.runtime.onMessage.addListener(m => { if (m?.tipo === "impostazioni_di_serie") return Promise.resolve(SERIE); });

// ── leggerezza: le schede che non guardi da un po' si addormentano (restano lì, ma senza usare memoria) ──────────
setInterval(async () => {
  const min = Number(impostazioni.dormi) || 0;
  if (!min) return;
  const limite = Date.now() - min * 60000;
  const occupate = new Set([...agenti.values()].map(a => a.tab));
  for (const t of await browser.tabs.query({ active: false, discarded: false, audible: false, pinned: false }))
    if (t.lastAccessed < limite && !occupate.has(t.id) && /^https?:/.test(t.url)) browser.tabs.discard(t.id);
}, 60000);

let ponte = null;
const pannelli = new Set();
const agenti = new Map();            // id del compito -> { tab, finestra }
let anonimo = false;


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
      browser.theme.update(a.finestra, tema(colori(), !!g.si));
      return await allaPagina(a.tab, { fai: "evidenzia", si: !!g.si });
  }
  return { errore: "unknown action " + m.nome };
}
function fineAgente(id) {
  const a = agenti.get(id);
  if (!a) return;
  browser.theme.update(a.finestra, tema(colori()));
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
  if (m.tipo === "tema" || (m.tipo === "ciao" && m.tema)) {
    coloriCielos = m.tipo === "tema" ? m.colori : m.tema;
    browser.storage.local.set({ coloriCielos });
    applicaAspetto();
  }
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

collega();
browser.browserAction.onClicked.addListener(() => browser.sidebarAction.toggle());
