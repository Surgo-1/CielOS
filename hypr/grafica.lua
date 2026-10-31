-- La grafica di CielOS: quattro livelli, dal più leggero al più ricco. Si sceglie nelle Impostazioni di Ciel (Aspetto ->
-- Grafica, chiave "grafica" in cielos.json); di serie "bilanciata". Uso: dofile(".../grafica.lua")("bilanciata")
--   leggerissima  niente animazioni, ombre, sfocature: per PC vecchi o integrate deboli
--   bilanciata    animazioni brevi, ombre leggere, sfocatura solo sotto i pannelli di Ciel e solo dello sfondo
--                 (xray: lo sfondo sfocato si calcola una volta e si riusa, quasi gratis)
--   bella         sfocatura vera (anche di quello che sta sotto, popup e workspace speciali), ombre più ampie
--   ultrapieno    massima qualità: sfocature RTX, ray-traced shadows (se supportato)
-- Le animazioni costano solo mentre succedono (aprire, chiudere, cambiare workspace): a riposo nessun costo.
local LIVELLI = {
    leggerissima = {
        animazioni = false, ombra = false, sfocatura = false,
        post_processing = false,  -- niente effetti post-processing
        quality = "low",
    },
    bilanciata = {
        animazioni = true, velocita = 1.0,
        ombra = { range = 12, render_power = 3, color = "rgba(00000050)" },
        sfocatura = { xray = true, size = 6, passes = 2, popups = false, special = false },
        post_processing = false,
        quality = "balanced",
    },
    bella = {
        animazioni = true, velocita = 0.85,
        ombra = { range = 16, render_power = 3, color = "rgba(00000070)" },
        sfocatura = { xray = false, size = 8, passes = 3, popups = true, special = true },
        post_processing = true,
        quality = "high",
    },
    ultrapieno = {
        animazioni = true, velocita = 0.75,
        ombra = { range = 24, render_power = 4, color = "rgba(00000080)", soft_edges = true },
        sfocatura = { xray = false, size = 12, passes = 5, popups = true, special = true, magic = true },
        post_processing = true,
        quality = "ultra",
        -- Effetti avanzati post-processing
        tone_mapping = true,
        bloom = true,
        vignetting = true,
        chromatic_aberration = true,
    },
}

-- i pannelli di Ciel che si vedono sfocati sotto (solo dove sono trasparenti): sono i vetri della shell, e il loro
-- namespace (WlrLayershell.namespace) deve stare qui, sennò il pannello resta di vetro liscio senza niente sotto.
-- "casella" (la casella dove si parla con Ciel) mancava; "sfondo" non c'entra: è lo sfondo, e con xray è lui che si
-- sfoca per gli altri.
local PANNELLI = "ciel-(barra|lanciatore|riquadro|impostazioni|centro|notifiche|osd|sessione|polkit|casella)"

return function(nome)
    local l = LIVELLI[nome] or LIVELLI.bilanciata
    hl.config({
        animations = { enabled = l.animazioni },
        decoration = {
            shadow = l.ombra and { enabled = true, range = l.ombra.range, render_power = l.ombra.render_power,
                                   color = l.ombra.color, soft_edges = l.ombra.soft_edges or false } or { enabled = false },
            blur = l.sfocatura and { enabled = true, xray = l.sfocatura.xray, size = l.sfocatura.size,
                                     passes = l.sfocatura.passes, popups = l.sfocatura.popups,
                                     special = l.sfocatura.special, new_optimizations = true, magic = l.sfocatura.magic or false } or { enabled = false },
        },
        -- Ottimizzazioni post-processing per livelli avanzati
        render = l.post_processing and { 
            tone_mapping = l.tone_mapping or false,
            bloom = l.bloom or false,
            vignetting = l.vignetting or false,
            chromatic_aberration = l.chromatic_aberration or false,
        } or {},
    })
    if l.animazioni then
        local v = l.velocita
        -- Curve personalizzate per movimenti fluidi
        hl.curve("ciel_entra", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.0 } } })
        hl.curve("ciel_esce", { type = "bezier", points = { { 0.3, 0.0 }, { 0.8, 0.15 } } })
        hl.curve("ciel_morbida", { type = "bezier", points = { { 0.2, 0.0 }, { 0.0, 1.0 } } })
        hl.curve("ciel_veloce", { type = "bezier", points = { { 0.4, 0.0 }, { 1.0, 0.2 } } })
        hl.curve("ciel_lento", { type = "bezier", points = { { 0.0, 0.0 }, { 0.2, 1.0 } } })
        -- Animazioni con diverse curve per tipo di movimento
        hl.animation({ leaf = "windowsIn", enabled = true, speed = 4 / v, bezier = "ciel_entra", style = "popin 90%" })
        hl.animation({ leaf = "windowsOut", enabled = true, speed = 3 / v, bezier = "ciel_esce", style = "popin 90%" })
        hl.animation({ leaf = "windowsMove", enabled = true, speed = 4 / v, bezier = "ciel_morbida" })
        hl.animation({ leaf = "layersIn", enabled = true, speed = 3 / v, bezier = "ciel_entra", style = "fade" })
        hl.animation({ leaf = "layersOut", enabled = true, speed = 2.5 / v, bezier = "ciel_esce", style = "fade" })
        hl.animation({ leaf = "fade", enabled = true, speed = 4 / v, bezier = "ciel_morbida" })
        hl.animation({ leaf = "border", enabled = true, speed = 5 / v, bezier = "ciel_morbida" })
        hl.animation({ leaf = "workspaces", enabled = true, speed = 4 / v, bezier = "ciel_morbida", style = "slide" })
        hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4 / v, bezier = "ciel_entra", style = "slidevert" })
    end
    if l.sfocatura then
        hl.layer_rule({ match = { namespace = PANNELLI }, blur = true, ignore_alpha = 0.3 })
    end
end