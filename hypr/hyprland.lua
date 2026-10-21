-- Hyprland in CielOS: la base. L'installatore la mette in ~/.config/hypr/hyprland.lua (quella di prima resta in
-- hyprland.lua.prima-di-cielos). La grafica di serie è «bilanciata» (hypr/grafica.lua: animazioni brevi, ombre
-- leggere, pannelli di Ciel sfocati); nelle Impostazioni di Ciel si sceglie «leggerissima» o «bella».
-- Le scorciatoie di Ciel (lanciatore, riquadro, impostazioni…) e l'aspetto delle finestre li scrive cieltema in
-- ~/.config/cielos/hypr-ciel.lua dalle tue scelte; le tue aggiunte vanno in ~/.config/cielos/hypr-mio.lua.
-- Le scorciatoie qui sono le stesse di caelestia, così le mani non devono reimparare niente.

local home = os.getenv("HOME")
CIELOS_BASE = true                  -- la configurazione di CielOS: hypr-ciel.lua non ricarica hypr-sistema.lua
local radice = os.getenv("CIELOS_DIR") or (home .. "/cielos")      -- /usr/share/cielos col pacchetto
hl.env("CIELOS_DIR", radice)

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

-- l'ambiente della sessione: i comandi di CielOS (~/.local/bin) e i programmi Wayland (dal login non arrivano)
hl.env("PATH", home .. "/.local/bin:" .. (os.getenv("PATH") or "/usr/local/bin:/usr/bin"))
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("SDL_VIDEODRIVER", "wayland,x11")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("MOZ_ENABLE_WAYLAND", "1")
-- scheda NVIDIA col driver proprietario: le variabili che servono a Wayland (video accelerati, OpenGL giusto)
local nv = io.open("/proc/driver/nvidia/version", "r")
if nv then
    nv:close()
    hl.env("LIBVA_DRIVER_NAME", "nvidia")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    hl.env("NVD_BACKEND", "direct")
end

-- i programmi Flatpak (plugin da Flathub) nel lanciatore, anche prima che ci sia flatpak
hl.env("XDG_DATA_DIRS", os.getenv("HOME") .. "/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:" ..
                        (os.getenv("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"))

-- la cache degli shader dei giochi più grande (di serie 1 GB: si riempie e i giochi tornano a scattare)
hl.env("MESA_SHADER_CACHE_MAX_SIZE", "10G")
hl.env("__GL_SHADER_DISK_CACHE_SIZE", "10737418240")
hl.env("__GL_SHADER_DISK_CACHE_SKIP_CLEANUP", "1")

hl.config({
    general = {
        layout = "dwindle", gaps_in = 4, gaps_out = 8, border_size = 2,
        col = { active_border = "rgb(3fa9e8)", inactive_border = "rgb(2a3a6a)" },
        allow_tearing = true,                    -- solo per le finestre con «immediate» (i giochi, qui sotto)
    },
    decoration = { rounding = 12 },
    dwindle = { preserve_split = true },
    input = {
        kb_layout = "it", repeat_delay = 250, repeat_rate = 35, focus_on_close = 1,
        touchpad = { natural_scroll = true, disable_while_typing = true },
    },
    -- VRR (FreeSync / G-Sync compatibile) nei giochi a schermo intero; per schermo si cambia in Impostazioni → Schermi
    -- disable_autoreload: durante un aggiornamento pacman sostituisce questi file e Hyprland, ricaricandoli a metà,
    -- mostrava «config has errors: cannot open …hyprland.lua». Chi cambia la configurazione (cieltema, cielimposta,
    -- Impostazioni) ricarica da sé; il resto vale dal prossimo accesso
    misc = { disable_hyprland_logo = true, disable_splash_rendering = true, force_default_wallpaper = 0, vrr = 2,
             disable_autoreload = true },
    render = { direct_scanout = 2 },             -- i giochi a schermo intero vanno dritti al monitor
    ecosystem = { no_update_news = true, no_donation_nag = true },
})

-- i giochi: latenza minima (se il gioco ha il vsync spento l'immagine arriva subito, anche a costo di un taglio)
hl.window_rule({ match = { class = "^(steam_app_[0-9]+|gamescope|.*\\.exe)$" }, immediate = true })

-- il ponte per condividere lo schermo con le app X11 (Discord ufficiale): la sua finestra serve solo da tramite, invisibile
hl.window_rule({ match = { class = "^xwaylandvideobridge$" }, opacity = "0.0 override", no_anim = true,
                 no_initial_focus = true, max_size = "1 1", no_blur = true, no_focus = true })

dofile(radice .. "/hypr/grafica.lua")("bilanciata")     -- cieltema la cambia se ne scegli un'altra

-- ── all'accesso: la shell Ciel e il sistema nervoso (i servizi utente non partono da soli con Hyprland) ──────
hl.on("hyprland.start", function()
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP PATH")
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("systemctl --user start ciel-shell cield")
    hl.exec_cmd("sh -c 'command -v cliphist >/dev/null && exec wl-paste --watch cliphist -max-items 200 store'")
    hl.exec_cmd("sh -c 'command -v cliphist >/dev/null && exec wl-paste --type image --watch cliphist -max-items 200 store'")
    hl.exec_cmd("sh -c 'systemctl --user is-enabled -q assistente 2>/dev/null && systemctl --user start assistente'")
    -- dalla chiavetta (sessione live): si apre l'installatore
    local live = io.open("/etc/cielos-live", "r")
    if live then
        live:close()
        hl.exec_cmd("cielos-installatore")
    end
    -- scelta nell'installatore: Ciel si installa al primo accesso (in un terminale: dice cosa scarica e chiede)
    local c = home .. "/.config/cielos/"
    local da = io.open(c .. "ciel-da-installare", "r")
    if da then
        da:close()
        hl.exec_cmd("foot --app-id=cielos-ciel -e sh -c 'cielos-ciel; rm -f " .. c .. "ciel-da-installare; read -rp \"Invio per chiudere \" x'")
    end
end)

-- ── finestre ─────────────────────────────────────────────────────────────────────────────────────────────────
-- tasto(): hl.bind con la descrizione (la mostra l'elenco delle scorciatoie, Super+K)
local function tasto(tasti, descrizione, azione, opzioni)
    local o = {}
    for k, v in pairs(opzioni or {}) do o[k] = v end
    o.description = descrizione
    hl.bind(tasti, azione, o)
end
for i = 1, 10 do
    local k = tostring(i % 10)
    tasto("SUPER + " .. k, "Vai al workspace " .. i, hl.dsp.focus({ workspace = i }))
    tasto("SUPER + ALT + " .. k, "Sposta la finestra nel workspace " .. i, hl.dsp.window.move({ workspace = i }))
end
for _, ws in ipairs({ { "SUPER + mouse_down", "+1" }, { "SUPER + mouse_up", "-1" }, { "SUPER + Page_Down", "+1" },
                      { "SUPER + Page_Up", "-1" }, { "CTRL + SUPER + Right", "+1" }, { "CTRL + SUPER + Left", "-1" } }) do
    tasto(ws[1], ws[2] == "+1" and "Workspace dopo" or "Workspace prima", hl.dsp.focus({ workspace = ws[2] }))
end
for _, dir in ipairs({ "left", "right", "up", "down" }) do
    tasto("SUPER + " .. dir, "Passa alla finestra di lato", hl.dsp.focus({ direction = dir }))
    tasto("SUPER + SHIFT + " .. dir, "Sposta la finestra di lato", hl.dsp.window.move({ direction = dir }))
end
tasto("SUPER + Q", "Chiudi la finestra", hl.dsp.window.close())
tasto("SUPER + F", "Schermo intero", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
tasto("SUPER + ALT + F", "Ingrandisci la finestra", hl.dsp.window.fullscreen({ mode = "maximized" }))
tasto("SUPER + ALT + Space", "Finestra fluttuante o affiancata", hl.dsp.window.float())
tasto("SUPER + P", "Fissa la finestra su tutti i workspace", hl.dsp.window.pin())
tasto("ALT + TAB", "Finestra successiva", hl.dsp.window.cycle_next(), { repeating = true })
tasto("SHIFT + ALT + TAB", "Finestra precedente", hl.dsp.window.cycle_next({ next = false }), { repeating = true })
tasto("SUPER + mouse:272", "Trascina la finestra", hl.dsp.window.drag(), { mouse = true })
tasto("SUPER + mouse:273", "Ridimensiona la finestra", hl.dsp.window.resize(), { mouse = true })
tasto("SUPER + S", "Workspace speciale", hl.dsp.workspace.toggle_special("special"))
tasto("SUPER + ALT + S", "Manda la finestra nel workspace speciale", hl.dsp.window.move({ workspace = "special:special" }))

-- ── programmi ────────────────────────────────────────────────────────────────────────────────────────────────
tasto("SUPER + W", "Browser (CielFox)", hl.dsp.exec_cmd("cielfox"))
tasto("SUPER + E", "CielFile", hl.dsp.exec_cmd("ciel-file"))

-- ── schermate ────────────────────────────────────────────────────────────────────────────────────────────────
-- Stamp: scegli l'area col mouse (un clic prende una finestra, Esc annulla); Shift: tutto lo schermo; Ctrl: la finestra attiva
tasto("Print", "Schermata di un'area", hl.dsp.exec_cmd("cielos-schermata area"))
tasto("SHIFT + Print", "Schermata di tutto lo schermo", hl.dsp.exec_cmd("cielos-schermata schermo"), { locked = true })
tasto("CTRL + Print", "Schermata della finestra", hl.dsp.exec_cmd("cielos-schermata finestra"))
-- gli strumenti (cielstrumenti; la pagina Strumenti del riquadro, Super+A)
tasto("SUPER + SHIFT + R", "Registra lo schermo (di nuovo: ferma)", hl.dsp.exec_cmd("cielstrumenti registra"))
tasto("SUPER + CTRL + R", "Registra lo schermo con l'audio", hl.dsp.exec_cmd("cielstrumenti registra audio"))
tasto("SUPER + SHIFT + T", "Copia il testo da un'area dello schermo", hl.dsp.exec_cmd("cielstrumenti testo"))
tasto("SUPER + SHIFT + C", "Prendi un colore dallo schermo", hl.dsp.exec_cmd("cielstrumenti colore"))
tasto("SUPER + V", "Cronologia degli appunti", hl.dsp.global("ciel:appunti"))
tasto("SUPER + period", "Emoji", hl.dsp.global("ciel:emoji"))
tasto("SUPER + K", "Elenco delle scorciatoie", hl.dsp.global("ciel:scorciatoie"))
tasto("SUPER + O", "Stacca la finestra (sopra le altre, su tutti i workspace)", hl.dsp.exec_cmd("cielstrumenti finestra stacca"))
-- il mirino (slurp) sparisce di colpo: con la dissolvenza finirebbe dentro la schermata, tutta tinta d'oro
hl.layer_rule({ match = { namespace = "^selection$" }, no_anim = true })

-- ── volume, musica, luminosità (anche con lo schermo bloccato) ───────────────────────────────────────────────
local bloccato, ripeti = { locked = true }, { locked = true, repeating = true }
tasto("XF86AudioRaiseVolume", "Alza il volume", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), ripeti)
tasto("XF86AudioLowerVolume", "Abbassa il volume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), ripeti)
tasto("XF86AudioMute", "Muto", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), bloccato)
tasto("SUPER + SHIFT + M", "Muto", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), bloccato)
tasto("XF86AudioMicMute", "Microfono muto", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), bloccato)
for _, m in ipairs({ { "XF86AudioPlay", "play-pause" }, { "XF86AudioPause", "play-pause" }, { "CTRL + SUPER + Space", "play-pause" },
                     { "XF86AudioNext", "next" }, { "CTRL + SUPER + Equal", "next" },
                     { "XF86AudioPrev", "previous" }, { "CTRL + SUPER + Minus", "previous" }, { "XF86AudioStop", "stop" } }) do
    tasto(m[1], "Musica: " .. m[2], hl.dsp.exec_cmd("playerctl " .. m[2]), bloccato)
end
tasto("XF86MonBrightnessUp", "Più luminoso", hl.dsp.exec_cmd("brightnessctl -q set 5%+"), ripeti)
tasto("XF86MonBrightnessDown", "Meno luminoso", hl.dsp.exec_cmd("brightnessctl -q set 5%-"), ripeti)

-- ── le scelte di Ciel (cieltema), le Impostazioni di sistema (cielimposta: schermi, input, avanzate) e le tue ────────────────────────────────────────────────────────────────────
for _, f in ipairs({ home .. "/.config/cielos/hypr-ciel.lua", home .. "/.config/cielos/hypr-sistema.lua",
                    home .. "/.config/cielos/hypr-mio.lua" }) do
    local h = io.open(f, "r")
    if h then
        h:close()
        local ok, err = pcall(dofile, f)
        if not ok then hl.exec_cmd("notify-send -a CielOS 'Errore in " .. f .. "' '" .. tostring(err):gsub("'", "") .. "'") end
    elseif f:find("hypr%-ciel") then                  -- cieltema non ha ancora scritto niente: almeno il lanciatore
        hl.bind("SUPER + Space", hl.dsp.global("ciel:lanciatore"))
        hl.bind("SUPER + J", hl.dsp.global("ciel:casella"))
        hl.bind("SUPER + T", hl.dsp.exec_cmd("foot"))
    end
end
