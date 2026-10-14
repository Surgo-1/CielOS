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
for i = 1, 10 do
    local k = tostring(i % 10)
    hl.bind("SUPER + " .. k, hl.dsp.focus({ workspace = i }))
    hl.bind("SUPER + ALT + " .. k, hl.dsp.window.move({ workspace = i }))
end
for _, ws in ipairs({ { "SUPER + mouse_down", "+1" }, { "SUPER + mouse_up", "-1" }, { "SUPER + Page_Down", "+1" },
                      { "SUPER + Page_Up", "-1" }, { "CTRL + SUPER + Right", "+1" }, { "CTRL + SUPER + Left", "-1" } }) do
    hl.bind(ws[1], hl.dsp.focus({ workspace = ws[2] }))
end
for _, dir in ipairs({ "left", "right", "up", "down" }) do
    hl.bind("SUPER + " .. dir, hl.dsp.focus({ direction = dir }))
    hl.bind("SUPER + SHIFT + " .. dir, hl.dsp.window.move({ direction = dir }))
end
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind("SUPER + ALT + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind("SUPER + ALT + Space", hl.dsp.window.float())
hl.bind("SUPER + P", hl.dsp.window.pin())
hl.bind("ALT + TAB", hl.dsp.window.cycle_next(), { repeating = true })
hl.bind("SHIFT + ALT + TAB", hl.dsp.window.cycle_next({ next = false }), { repeating = true })
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind("SUPER + S", hl.dsp.workspace.toggle_special("special"))
hl.bind("SUPER + ALT + S", hl.dsp.window.move({ workspace = "special:special" }))

-- ── programmi ────────────────────────────────────────────────────────────────────────────────────────────────
hl.bind("SUPER + W", hl.dsp.exec_cmd("cielfox"))
hl.bind("SUPER + E", hl.dsp.exec_cmd("ciel-file"))

-- ── schermate ────────────────────────────────────────────────────────────────────────────────────────────────
-- Stamp: scegli l'area col mouse (un clic prende una finestra, Esc annulla); Shift: tutto lo schermo; Ctrl: la finestra attiva
hl.bind("Print", hl.dsp.exec_cmd("cielos-schermata area"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("cielos-schermata schermo"), { locked = true })
hl.bind("CTRL + Print", hl.dsp.exec_cmd("cielos-schermata finestra"))

-- ── volume, musica, luminosità (anche con lo schermo bloccato) ───────────────────────────────────────────────
local bloccato, ripeti = { locked = true }, { locked = true, repeating = true }
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), ripeti)
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), ripeti)
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), bloccato)
hl.bind("SUPER + SHIFT + M", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), bloccato)
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), bloccato)
for _, m in ipairs({ { "XF86AudioPlay", "play-pause" }, { "XF86AudioPause", "play-pause" }, { "CTRL + SUPER + Space", "play-pause" },
                     { "XF86AudioNext", "next" }, { "CTRL + SUPER + Equal", "next" },
                     { "XF86AudioPrev", "previous" }, { "CTRL + SUPER + Minus", "previous" }, { "XF86AudioStop", "stop" } }) do
    hl.bind(m[1], hl.dsp.exec_cmd("playerctl " .. m[2]), bloccato)
end
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -q set 5%+"), ripeti)
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -q set 5%-"), ripeti)

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
