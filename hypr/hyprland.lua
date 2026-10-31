-- Hyprland in CielOS: la base. L'installatore la mette in ~/.config/hypr/hyprland.lua (quella di prima resta in
-- hyprland.lua.prima-di-cielos). La grafica di serie è "bilanciata" (hypr/grafica.lua: animazioni brevi, ombre
-- leggere, pannelli di Ciel sfocati); nelle Impostazioni di Ciel si sceglie "leggerissima" o "bella".
-- Le scorciatoie di Ciel (lanciatore, riquadro, impostazioni…) e l'aspetto delle finestre li scrive cieltema in
-- ~/.config/cielos/hypr-ciel.lua dalle tue scelte; le tue aggiunte vanno in ~/.config/cielos/hypr-mio.lua.
-- Le scorciatoie qui sono le stesse di caelestia, così le mani non devono reimparare niente.

local home = os.getenv("HOME")
CIELOS_BASE = true                  -- la configurazione di CielOS: hypr-ciel.lua non ricarica hypr-sistema.lua
local radice = os.getenv("CIELOS_DIR") or (home .. "/cielos")      -- /usr/share/cielos col pacchetto
hl.env("CIELOS_DIR", radice)

-- ==================== MONITOR & DISPLAY ====================
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

-- ==================== AMBIENTE SESSIONE ====================
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

-- ==================== NVIDIA DRIVER ====================
local nv = io.open("/proc/driver/nvidia/version", "r")
if nv then
    nv:close()
    hl.env("LIBVA_DRIVER_NAME", "nvidia")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    hl.env("NVD_BACKEND", "direct")
    -- Ottimizzazioni RTX complete
    hl.env("NVD_CUC", "1")            -- Compute Unified Cache
    hl.env("NVD_DECOMPRESS", "1")     -- Decompress Textures
    hl.env("NVD_LOG", "1")            -- Logging per debug
    hl.env("CUDA_VISIBLE_DEVICES", "all")
    hl.env("__GL_SHADER_DISK_CACHE", "1")  -- Abilita cache
    hl.env("__GL_SHADER_DISK_CACHE_SIZE", "34359738368") -- 32GB
end

-- ==================== FLATPAK ====================
hl.env("XDG_DATA_DIRS", os.getenv("HOME") .. "/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:" ..
                        (os.getenv("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"))

-- ==================== GPU SHADER CACHE (Massima) ====================
-- Cache shader 20GB per giochi (raddoppiata da 10GB per prestazioni RTX)
hl.env("MESA_SHADER_CACHE_MAX_SIZE", "20G")
hl.env("__GL_SHADER_DISK_CACHE_SIZE", "21474836480")
hl.env("__GL_SHADER_DISK_CACHE_SKIP_CLEANUP", "1")

-- ==================== INTEL ARC ====================
local intel = io.open("/sys/class/drm/intel_dri0/power_dpm_force_performance_level", "r")
if not intel then intel = io.open("/sys/class/drm/card0gt/force_performance_level", "r") end
if intel then
    intel:close()
    hl.env("INTEL_DEBUG", "perf")
    hl.env("i965_DISABLE_HPS", "1")
end

-- ==================== AMD RDNA3 ====================
local f = io.open("/sys/class/drm/card0/device/vendor", "r")
if f then
    local v = f:read("*l")
    f:close()
    if v == "0x1002" then
        hl.env("RADV_PERFTEST", "aco")
        hl.env("R600_DEBUG", "perf")
    end
end

-- ==================== CONFIG ====================
hl.config({
    general = {
        layout = "dwindle", gaps_in = 4, gaps_out = 8, border_size = 2,
        col = { active_border = "rgb(3fa9e8)", inactive_border = "rgb(2a3a6a)" },
        allow_tearing = true,
    },
    decoration = { rounding = 12 },
    dwindle = { preserve_split = true },
    input = {
        kb_layout = "it", repeat_delay = 250, repeat_rate = 35, focus_on_close = 1,
        touchpad = { natural_scroll = true, disable_while_typing = true },
    },
    misc = { 
        disable_hyprland_logo = true, 
        disable_splash_rendering = true, 
        force_default_wallpaper = 0, 
        vrr = 2,
        disable_autoreload = true 
    },
    render = { direct_scanout = 2 },
    ecosystem = { no_update_news = true, no_donation_nag = true },
})

-- ==================== GIOCHI ====================
hl.window_rule({ match = { class = "^(steam_app_[0-9]+|gamescope|.*\\.exe)$" }, immediate = true })

-- ==================== XWAYLAND ====================
hl.window_rule({ match = { class = "^xwaylandvideobridge$" }, opacity = "0.0 override", no_anim = true,
                 no_initial_focus = true, max_size = "1 1", no_blur = true, no_focus = true })

-- ==================== all'accesso ====================
hl.on("hyprland.start", function()
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_ID XDG_SESSION_TYPE PATH")
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    
    local nightly = os.getenv("CIELOS_NIGHTLY")
    hl.exec_cmd("systemctl --user stop " .. (nightly and "ciel-shell" or "ciel-nightly"))
    hl.exec_cmd("systemctl --user start " .. (nightly and "ciel-nightly" or "ciel-shell") .. " cield")
    
    hl.exec_cmd("sh -c 'command -v cliphist >/dev/null && exec wl-paste --watch cliphist -max-items 200 store'")
    hl.exec_cmd("sh -c 'command -v cliphist >/dev/null && exec wl-paste --type image --watch cliphist -max-items 200 store'")
    hl.exec_cmd("sh -c 'systemctl --user is-enabled -q assistente 2>/dev/null && systemctl --user start assistente'")
    
    local live = io.open("/etc/cielos-live", "r")
    if live then
        live:close()
        hl.exec_cmd("cielos-installatore")
    end
    
    local c = home .. "/.config/cielos/"
    local da = io.open(c .. "ciel-da-installare", "r")
    if da then
        da:close()
        hl.exec_cmd("foot --app-id=cielos-ciel -e sh -c 'cielos-ciel; rm -f " .. c .. "ciel-da-installare; read -rp \"Invio per chiudere \" x'")
    end
end)

-- ==================== TASTI ====================
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

-- ==================== PROGRAMMI ====================
tasto("SUPER + W", "Browser (CielFox)", hl.dsp.exec_cmd("cielfox"))
tasto("SUPER + E", "CielFile", hl.dsp.exec_cmd("ciel-file"))

-- ==================== SCHERMAZE ====================
tasto("Print", "Schermata di un'area", hl.dsp.exec_cmd("cielos-schermata area"))
tasto("SHIFT + Print", "Schermata di tutto lo schermo", hl.dsp.exec_cmd("cielos-schermata schermo"), { locked = true })
tasto("CTRL + Print", "Schermata della finestra", hl.dsp.exec_cmd("cielos-schermata finestra"))
tasto("SUPER + SHIFT + R", "Registra lo schermo", hl.dsp.exec_cmd("cielstrumenti registra"))
tasto("SUPER + CTRL + R", "Registra con audio", hl.dsp.exec_cmd("cielstrumenti registra audio"))
tasto("SUPER + SHIFT + T", "Copia testo da area", hl.dsp.exec_cmd("cielstrumenti testo"))
tasto("SUPER + SHIFT + C", "Prendi colore", hl.dsp.exec_cmd("cielstrumenti colore"))
tasto("SUPER + V", "Cronologia appunti", hl.dsp.global("ciel:appunti"))
tasto("SUPER + period", "Emoji", hl.dsp.global("ciel:emoji"))
tasto("SUPER + K", "Elenco scorciatoie", hl.dsp.global("ciel:scorciatoie"))
tasto("SUPER + O", "Stacca finestra", hl.dsp.exec_cmd("cielstrumenti finestra stacca"))

-- ==================== AUDIO ====================
local bloccato, ripeti = { locked = true }, { locked = true, repeating = true }
tasto("XF86AudioRaiseVolume", "Alza volume", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), ripeti)
tasto("XF86AudioLowerVolume", "Abbassa volume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), ripeti)
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

-- ==================== FILE DI CONFIGURAZIONE ====================
for _, f in ipairs({ home .. "/.config/cielos/hypr-ciel.lua", home .. "/.config/cielos/hypr-sistema.lua",
                    home .. "/.config/cielos/hypr-mio.lua" }) do
    local h = io.open(f, "r")
    if h then
        h:close()
        local ok, err = pcall(dofile, f)
        if not ok then hl.exec_cmd("notify-send -a CielOS 'Errore in " .. f .. "' '" .. tostring(err):gsub("'", "") .. "'") end
    elseif f:find("hypr%-ciel") then
        hl.bind("SUPER + Space", hl.dsp.global("ciel:lanciatore"))
        hl.bind("SUPER + J", hl.dsp.global("ciel:casella"))
        hl.bind("SUPER + T", hl.dsp.exec_cmd("foot"))
    end
end

-- ==================== SLURP (selezionatore) ====================
hl.layer_rule({ match = { namespace = "^selection$" }, no_anim = true })