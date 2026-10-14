// Dentro la pagina: leggere (elementi numerati e testo visibile), cliccare, scrivere, scorrere, e il bordo azzurro
// mentre Ciel lavora qui. Lo inietta sfondo.js quando serve (una volta per pagina).
(() => {
if (window.__cielfox) return;
window.__cielfox = true;

let mappa = [];                                  // n -> elemento, dall'ultima lettura

const INTERATTIVI = "a[href], button, input:not([type=hidden]), textarea, select, summary, [contenteditable=''], " +
  "[contenteditable=true], [role=button], [role=link], [role=tab], [role=checkbox], [role=radio], [role=menuitem], " +
  "[role=option], [role=switch], [role=combobox], [role=textbox], [role=searchbox], [onclick], [tabindex]:not([tabindex='-1'])";

function visibile(el) {
  const r = el.getBoundingClientRect();
  if (r.width < 2 || r.height < 2) return false;
  const s = getComputedStyle(el);
  if (s.visibility === "hidden" || s.display === "none" || Number(s.opacity) === 0) return false;
  return r.bottom > -window.innerHeight * 0.5 && r.top < window.innerHeight * 2.5;   // dentro o vicino allo schermo
}

function etichetta(el) {
  const t = (el.getAttribute("aria-label") || el.innerText || el.value || el.getAttribute("title") ||
             el.getAttribute("alt") || el.getAttribute("placeholder") || el.getAttribute("name") || "").trim();
  return t.replace(/\s+/g, " ").slice(0, 90);
}

function tipo(el) {
  const tag = el.tagName.toLowerCase();
  if (tag === "input") return "input " + (el.type || "text");
  if (tag === "a") return "link";
  return el.getAttribute("role") || tag;
}

function leggi() {
  mappa = [];
  const righe = [];
  for (const el of document.querySelectorAll(INTERATTIVI)) {
    if (!visibile(el) || el.closest("#__cielfox_bordo")) continue;
    if (mappa.length >= 250) break;
    const n = mappa.length + 1;
    mappa.push(el);
    let r = `[${n}] ${tipo(el)} «${etichetta(el)}»`;
    if (el.tagName === "INPUT" || el.tagName === "TEXTAREA") {
      if (el.type === "password") r += " (password)";
      else if (el.value) r += ` value="${String(el.value).slice(0, 60)}"`;
      if (el.placeholder) r += ` placeholder="${el.placeholder.slice(0, 50)}"`;
    }
    if (el.tagName === "SELECT") r += " options: " + [...el.options].slice(0, 15).map(o => o.text.trim()).join(" | ");
    if (el.tagName === "A" && el.href && !el.href.startsWith("javascript")) r += " → " + el.href.slice(0, 100);
    if (el.disabled) r += " (disabled)";
    if (el.checked) r += " (checked)";
    righe.push(r);
  }
  const radice = document.querySelector("main, [role=main], article") || document.body;
  const testo = (radice.innerText || "").replace(/\n{3,}/g, "\n\n").slice(0, 5000);
  const scorrimento = Math.round(100 * window.scrollY / Math.max(1, document.documentElement.scrollHeight - innerHeight));
  return `URL: ${location.href}\nTitle: ${document.title}\nScrolled: ${isFinite(scorrimento) ? scorrimento : 0}%\n\n` +
         `Interactive elements:\n${righe.join("\n") || "(none)"}\n\nVisible text:\n${testo}`;
}

function elemento(n) {
  const el = mappa[Number(n) - 1];
  if (!el || !el.isConnected) throw new Error(`element ${n} not found: call read_page again`);
  return el;
}

function impostaValore(el, testo) {
  if (el.isContentEditable) {
    el.focus();
    el.textContent = testo;
    el.dispatchEvent(new InputEvent("input", { bubbles: true }));
    return;
  }
  const proto = el.tagName === "TEXTAREA" ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
  Object.getOwnPropertyDescriptor(proto, "value").set.call(el, testo);      // anche con React & co.
  el.dispatchEvent(new Event("input", { bubbles: true }));
  el.dispatchEvent(new Event("change", { bubbles: true }));
}

function tasto(el, key) {
  const o = { key, code: key, bubbles: true, cancelable: true, keyCode: key === "Enter" ? 13 : 0 };
  const giu = el.dispatchEvent(new KeyboardEvent("keydown", o));
  el.dispatchEvent(new KeyboardEvent("keypress", o));
  el.dispatchEvent(new KeyboardEvent("keyup", o));
  if (key === "Enter" && giu && el.form && el.tagName === "INPUT") el.form.requestSubmit?.();
}

const PAGAMENTO = /card|carta|cvv|cvc|iban|cc-|expir|scadenza|security.?code/i;

function descrivi(n) {
  const el = elemento(n);
  const ac = (el.getAttribute("autocomplete") || "") + " " + (el.name || "") + " " + (el.id || "");
  const form = el.form || el.closest("form");
  const campiForm = form ? [...form.querySelectorAll("input")] : [];
  return {
    testo: etichetta(el), sito: location.hostname,
    password: el.type === "password" || /current-password|new-password/.test(ac),
    pagamento: el.tagName === "INPUT" && (PAGAMENTO.test(ac) || /^cc-/.test(el.getAttribute("autocomplete") || "")),
    invia_modulo: !!form && (el.type === "submit" || (el.tagName === "BUTTON" && (el.type || "submit") === "submit")),
    modulo_delicato: campiForm.some(i => i.type === "password" || PAGAMENTO.test((i.getAttribute("autocomplete") || "") + i.name)),
  };
}

function bordo(si) {
  let b = document.getElementById("__cielfox_bordo");
  if (!si) { b?.remove(); return; }
  if (b) return;
  b = document.createElement("div");
  b.id = "__cielfox_bordo";
  b.innerHTML = "<span>✦ Ciel sta lavorando qui</span>";
  const s = document.createElement("style");
  s.textContent = `#__cielfox_bordo{position:fixed;inset:0;pointer-events:none;z-index:2147483647;
    box-shadow:inset 0 0 0 3px #7fd0ff, inset 0 0 28px rgba(127,208,255,.55);border-radius:6px;
    animation:__cielfox_respiro 2.4s ease-in-out infinite}
    #__cielfox_bordo span{position:absolute;right:14px;bottom:12px;padding:6px 12px;border-radius:14px;
    background:rgba(11,16,41,.88);color:#cfefff;font:500 13px system-ui,sans-serif;box-shadow:0 0 0 1px #7fd0ff}
    @keyframes __cielfox_respiro{50%{box-shadow:inset 0 0 0 3px #9fe1ff, inset 0 0 40px rgba(127,208,255,.75)}}
    @media (prefers-reduced-motion:reduce){#__cielfox_bordo{animation:none}}`;
  b.appendChild(s);
  document.documentElement.appendChild(b);
}

function contesto() {
  const radice = document.querySelector("main, [role=main], article") || document.body;
  return { titolo: document.title, url: location.href, selezione: String(getSelection() || "").slice(0, 4000),
           testo: (radice.innerText || "").replace(/\n{3,}/g, "\n\n").slice(0, 8000) };
}

browser.runtime.onMessage.addListener(async m => {
  try {
    switch (m.fai) {
      case "leggi": return { testo: leggi() };
      case "contesto": return contesto();
      case "descrivi_elemento": return descrivi(m.n);
      case "clicca": {
        const el = elemento(m.n);
        el.scrollIntoView({ block: "center", behavior: "instant" });
        el.focus?.();
        el.click();
        return { testo: `Clicked [${m.n}] «${etichetta(el)}». Call read_page to see the result.` };
      }
      case "scrivi": {
        const el = elemento(m.n);
        if (el.type === "password") throw new Error("password field: the user must type it");
        el.scrollIntoView({ block: "center", behavior: "instant" });
        el.focus();
        impostaValore(el, m.text ?? "");
        if (m.enter) tasto(el, "Enter");
        return { testo: `Typed into [${m.n}]${m.enter ? " and pressed Enter" : ""}.` };
      }
      case "scegli": {
        const el = elemento(m.n);
        const o = [...el.options].find(o => o.text.trim().toLowerCase() === String(m.option).trim().toLowerCase())
               || [...el.options].find(o => o.text.toLowerCase().includes(String(m.option).toLowerCase()));
        if (!o) throw new Error("option not found");
        el.value = o.value;
        el.dispatchEvent(new Event("change", { bubbles: true }));
        return { testo: `Selected «${o.text.trim()}».` };
      }
      case "premi": tasto(document.activeElement || document.body, m.key); return { testo: `Pressed ${m.key}.` };
      case "scorri": {
        const d = m.direction;
        if (d === "top") scrollTo(0, 0);
        else if (d === "bottom") scrollTo(0, document.documentElement.scrollHeight);
        else scrollBy(0, (d === "up" ? -0.85 : 0.85) * innerHeight);
        return { testo: `Scrolled ${d}.` };
      }
      case "evidenzia": bordo(m.si); return { testo: "ok" };
    }
    return { errore: "unknown action " + m.fai };
  } catch (e) {
    return { errore: String(e.message || e) };
  }
});
})();
