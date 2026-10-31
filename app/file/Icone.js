// L'icona (Material Symbols) e il colore di un file dal suo tipo: niente temi di icone da installare.
.pragma library

const IMMAGINI = ["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg", "avif", "heic", "tiff", "tif", "ico", "jxl"];
const VIDEO = ["mp4", "mkv", "webm", "avi", "mov", "m4v", "flv", "wmv", "mpg", "mpeg", "ts"];
const AUDIO = ["mp3", "flac", "ogg", "opus", "wav", "m4a", "aac", "wma", "mid", "midi"];
const ARCHIVI = ["zip", "tar", "gz", "xz", "zst", "bz2", "7z", "rar", "tgz", "txz", "iso", "deb", "rpm", "jar"];
const CODICE = ["py", "js", "ts", "qml", "c", "h", "cpp", "hpp", "rs", "go", "java", "kt", "lua", "rb", "php", "cs",
                "html", "css", "json", "yaml", "yml", "toml", "xml", "sql", "sh", "fish", "zsh", "bash", "ini", "conf"];
const TESTI = ["txt", "md", "log", "csv", "rst", "org", "tex"];
const DOCUMENTI = ["odt", "doc", "docx", "rtf", "pages"];
const FOGLI = ["ods", "xls", "xlsx"];
const PRESENTAZIONI = ["odp", "ppt", "pptx", "key"];

const COLORE_SISTEMA = {
    // Temi grafici CielOS - colori coordinati con Tema.qml
    fondo: "#0b1029",
    oro: "#3fa9e8",
    oroChiaro: "#9fe1ff",
    tenue: "#9aaacb",
    testo: "#e6f3ff",
    alto: "#16204a",
    bordo: "#2a3a6a",
    allarme: "#ff6b6b",
    accento: "#3fa9e8",
    velo: "rgba(51, 168, 255, 0.15)",
};

function suffisso(nome) {
    const i = nome.lastIndexOf(".");
    return i > 0 ? nome.slice(i + 1).toLowerCase() : "";
}
function immagine(nome) { return IMMAGINI.includes(suffisso(nome)) && suffisso(nome) !== "svg"; }
function archivio(nome) { return ARCHIVI.includes(suffisso(nome)) && !["iso", "deb", "rpm", "jar"].includes(suffisso(nome)); }

function icona(nome, cartella) {
    if (cartella) return "folder";
    const s = suffisso(nome);
    if (IMMAGINI.includes(s)) return "image";
    if (VIDEO.includes(s)) return "movie";
    if (AUDIO.includes(s)) return "music_note";
    if (ARCHIVI.includes(s)) return "folder_zip";
    if (s === "pdf") return "picture_as_pdf";
    if (["sh", "fish", "zsh", "bash", "appimage", "run"].includes(s)) return "terminal";
    if (CODICE.includes(s)) return "code";
    if (TESTI.includes(s)) return "description";
    if (DOCUMENTI.includes(s)) return "article";
    if (FOGLI.includes(s)) return "table_chart";
    if (PRESENTAZIONI.includes(s)) return "slideshow";
    if (["ttf", "otf", "woff", "woff2"].includes(s)) return "font_download";
    if (["desktop"].includes(s)) return "apps";
    if (["exe", "msi"].includes(s)) return "window";
    return "draft";
}

// Colori coordinati con il tema CielOS - questi possono essere sovrascritti dai file QML
// che importano questa library e accedono a I.coloreSistema
let coloriSistema = { ...COLORE_SISTEMA };

function colore(nome, cartella) {
    if (cartella) return coloriSistema.oroChiaro;
    const s = suffisso(nome);
    if (IMMAGINI.includes(s)) return coloriSistema.oro;
    if (VIDEO.includes(s)) return coloriSistema.allarme;
    if (AUDIO.includes(s)) return "#ffb347";
    if (ARCHIVI.includes(s)) return coloriSistema.tenue;
    if (s === "pdf") return coloriSistema.allarme;
    if (CODICE.includes(s)) return coloriSistema.oroChiaro;
    return coloriSistema.tenue;
}

function dimensione(b) {
    if (b < 1024) return b + " B";
    const u = ["KB", "MB", "GB", "TB"];
    let i = -1;
    do { b /= 1024; i++; } while (b >= 1024 && i < u.length - 1);
    return b.toFixed(b < 10 ? 1 : 0).replace(".", virgola) + " " + u[i];
}

// Rende i colori di sistema disponibili ai file QML che importano questa library
I = { ...I, coloreSistema: coloriSistema, setColoreSistema: function(c) { Object.assign(coloriSistema, c); } };

// la lingua la imposta shell.qml con lingua(Lingua.inglese): questa libreria non vede i singleton
var inglese = false;
var virgola = ",";
function lingua(en) { inglese = en; virgola = en ? "." : ","; }
function data(d, en) {
    if (en !== undefined) inglese = en;
    if (!d) return "";
    const oggi = new Date();
    const stesso = d.toDateString() === oggi.toDateString();
    const p = n => (n < 10 ? "0" : "") + n;
    const ora = p(d.getHours()) + ":" + p(d.getMinutes());
    if (stesso) return (inglese ? "today " : "oggi ") + ora;
    return (inglese ? p(d.getMonth() + 1) + "/" + p(d.getDate()) : p(d.getDate()) + "/" + p(d.getMonth() + 1)) + "/" + d.getFullYear() + " " + ora;
}