// CielFox: le impostazioni del profilo (le rimette il lanciatore a ogni avvio; le tue modifiche in about:config
// restano per la sessione). Base: LibreWolf, che è già senza telemetria e ha uBlock Origin dentro.

// ── la nostra estensione (Ciel nel browser): non è firmata da Mozilla, LibreWolf lo permette
user_pref("xpinstall.signatures.required", false);
user_pref("extensions.autoDisableScopes", 0);
user_pref("extensions.enabledScopes", 15);
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

// ── leggerezza
user_pref("dom.ipc.processCount", 4);                       // meno processi per i contenuti (di serie 8)
user_pref("dom.ipc.processPrelaunch.enabled", false);       // niente processi pronti «per sicurezza»
user_pref("browser.tabs.unloadOnLowMemory", true);          // con poca RAM scarica le schede che non guardi
user_pref("browser.sessionstore.interval", 60000);          // salva la sessione ogni minuto, non ogni 15 s
user_pref("browser.cache.disk.capacity", 262144);           // 256 MB di cache su disco al massimo
user_pref("browser.startup.preXulSkeletonUI", false);
user_pref("network.prefetch-next", false);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.predictor.enabled", false);
user_pref("browser.urlbar.speculativeConnect.enabled", false);
user_pref("browser.newtabpage.activity-stream.feeds.topsites", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("extensions.pocket.enabled", false);
user_pref("browser.ml.enable", false);                       // l'IA del browser è Ciel: quella di Mozilla resta spenta
user_pref("browser.ml.chat.enabled", false);
user_pref("browser.ml.linkPreview.enabled", false);
user_pref("browser.tabs.groups.smart.enabled", false);
user_pref("media.autoplay.default", 5);                      // niente video che partono da soli
user_pref("gfx.webrender.all", true);
user_pref("media.ffmpeg.vaapi.enabled", true);               // video decodificati dalla scheda video, se si può

// ── comodità (LibreWolf di serie è molto severo: qui si resta collegati ai siti e i siti non si rompono)
user_pref("privacy.resistFingerprinting", false);
user_pref("privacy.fingerprintingProtection", true);
user_pref("privacy.clearOnShutdown_v2.cookiesAndStorage", false);
user_pref("privacy.clearOnShutdown_v2.historyFormDataAndDownloads", false);
user_pref("privacy.sanitize.sanitizeOnShutdown", false);
user_pref("browser.startup.page", 3);                        // riapre le schede di prima
user_pref("webgl.disabled", false);
user_pref("identity.fxaccounts.enabled", false);

// ── aspetto: scuro, in italiano, barra laterale moderna (lì vive Ciel)
user_pref("layout.css.prefers-color-scheme.content-override", 0);
user_pref("ui.systemUsesDarkTheme", 1);
user_pref("intl.locale.requested", "it,en-US");
user_pref("intl.accept_languages", "it-IT, it, en-US, en");
user_pref("sidebar.revamp", true);
user_pref("browser.toolbars.bookmarks.visibility", "never");
user_pref("browser.uidensity", 1);                           // compatto
user_pref("browser.aboutwelcome.enabled", false);
user_pref("browser.shell.checkDefaultBrowser", false);
