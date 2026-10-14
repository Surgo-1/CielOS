// I motori di ricerca della nuova scheda (gli stessi nelle impostazioni). Google è anche nella barra degli
// indirizzi: l'aggiunge il manifest (LibreWolf di suo non ce l'ha).
const MOTORI = {
  duckduckgo: { nome: "DuckDuckGo", url: "https://duckduckgo.com/?q=", nota: "privato" },
  google:     { nome: "Google", url: "https://www.google.com/search?q=", nota: "i risultati migliori, ma ti traccia" },
  startpage:  { nome: "Startpage", url: "https://www.startpage.com/sp/search?query=", nota: "privato, con i risultati di Google" },
  brave:      { nome: "Brave Search", url: "https://search.brave.com/search?q=", nota: "privato, indice suo" },
  qwant:      { nome: "Qwant", url: "https://www.qwant.com/?q=", nota: "europeo" },
  ecosia:     { nome: "Ecosia", url: "https://www.ecosia.org/search?q=", nota: "pianta alberi" },
  bing:       { nome: "Bing", url: "https://www.bing.com/search?q=", nota: "di Microsoft" },
};
const motore = id => MOTORI[id] || MOTORI.duckduckgo;
