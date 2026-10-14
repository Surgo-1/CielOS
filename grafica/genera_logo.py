#!/usr/bin/env python3
"""Il logo di CielOS: un anello aperto (la C, un'orbita, il cielo) in celeste, con una stella bianca a quattro punte
nel varco, e un'orbita sottile dentro. Più la scritta CielOS a tratto unico (tracciati, nessun font).
Genera: logo.svg (per fondi scuri), logo-chiaro.svg (per fondi chiari), logo-completo.svg / logo-completo-chiaro.svg
(marchio + scritta), e le anteprime PNG. Uso: python3 genera_logo.py"""
import math, subprocess
from pathlib import Path

QUI = Path(__file__).parent
CELESTE_A, CELESTE_B = "#9FE1FF", "#3FA9E8"        # la sfumatura dell'anello (alto → basso)
CELESTE_SCURO = "#1F86C7"                         # su fondo chiaro
BIANCO, NOTTE = "#FFFFFF", "#0B1029"

def p(cx, cy, r, gradi):
    a = math.radians(gradi)
    return cx + r * math.cos(a), cy + r * math.sin(a)

def stella(cx, cy, R):
    """stella a quattro punte con i lati incurvati (come ✦)"""
    k = R * 0.16                                  # quanto è «gonfia» al centro
    return (f"M{cx:.2f},{cy-R:.2f} Q{cx+k:.2f},{cy-k:.2f} {cx+R:.2f},{cy:.2f} Q{cx+k:.2f},{cy+k:.2f} {cx:.2f},{cy+R:.2f} "
            f"Q{cx-k:.2f},{cy+k:.2f} {cx-R:.2f},{cy:.2f} Q{cx-k:.2f},{cy-k:.2f} {cx:.2f},{cy-R:.2f}Z")

def marchio(chiaro=False):
    """il marchio in un quadrato 256×256"""
    c, r, varco = 128, 84, -32                    # il varco è in alto a destra, dove sta la stella
    a0, a1 = varco + 34, varco - 34 + 360         # l'anello: dal varco, tutto intorno, fino all'altro lato
    x0, y0 = p(c, c, r, a0); x1, y1 = p(c, c, r, a1)
    sx, sy = p(c, c, r, varco)
    ix0, iy0 = p(c, c, 56, 130); ix1, iy1 = p(c, c, 56, 230)
    anello = f"url(#celeste)" if not chiaro else CELESTE_SCURO
    stella_col = BIANCO if not chiaro else CELESTE_SCURO
    return f"""<defs><linearGradient id="celeste" x1="0" y1="0" x2="0.35" y2="1">
      <stop offset="0" stop-color="{CELESTE_A}"/><stop offset="1" stop-color="{CELESTE_B}"/></linearGradient></defs>
    <path d="M{x0:.2f},{y0:.2f} A{r},{r} 0 1 1 {x1:.2f},{y1:.2f}" fill="none" stroke="{anello}" stroke-width="15" stroke-linecap="round"/>
    <path d="M{ix0:.2f},{iy0:.2f} A56,56 0 0 1 {ix1:.2f},{iy1:.2f}" fill="none" stroke="{anello}" stroke-width="5" stroke-linecap="round" opacity="0.55"/>
    <path d="{stella(sx, sy, 30)}" fill="{stella_col}"/>"""

def scritta(chiaro=False):
    """CielOS a tratto unico; altezza maiuscole 62, x 44, linea di base 100. Restituisce (svg, larghezza)."""
    t = 'fill="none" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"'
    col1 = BIANCO if not chiaro else NOTTE
    col2 = CELESTE_A if not chiaro else CELESTE_SCURO
    parti = []
    # C
    a = p(31, 69, 31, 45); b = p(31, 69, 31, 315)
    parti.append(f'<path d="M{a[0]:.2f},{a[1]:.2f} A31,31 0 1 1 {b[0]:.2f},{b[1]:.2f}" stroke="{col1}" {t}/>')
    # i
    parti.append(f'<path d="M76,58 V100" stroke="{col1}" {t}/><circle cx="76" cy="45" r="4.6" fill="{col1}"/>')
    # e
    x0 = 92; e = p(x0 + 22, 78, 22, 42)
    parti.append(f'<path d="M{x0},78 H{x0+44} A22,22 0 1 0 {e[0]:.2f},{e[1]:.2f}" stroke="{col1}" {t}/>')
    # l
    parti.append(f'<path d="M152,38 V100" stroke="{col1}" {t}/>')
    # O
    parti.append(f'<circle cx="205" cy="69" r="31" stroke="{col2}" {t}/>')
    # S
    x0 = 252; s0 = p(x0 + 19, 53.5, 15.5, -35); s1 = p(x0 + 19, 84.5, 15.5, 145)
    parti.append(f'<path d="M{s0[0]:.2f},{s0[1]:.2f} A15.5,15.5 0 1 0 {x0+19},69 A15.5,15.5 0 1 1 {s1[0]:.2f},{s1[1]:.2f}" '
                 f'stroke="{col2}" {t}/>')
    return "\n    ".join(parti), 294

def scrivi(nome, larg, alt, corpo):
    (QUI / nome).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {larg} {alt}" width="{larg}" height="{alt}">\n'
                            f'  <title>CielOS</title>\n    {corpo}\n</svg>\n')

for chiaro, suff in ((False, ""), (True, "-chiaro")):
    scrivi(f"logo{suff}.svg", 256, 256, marchio(chiaro))
    w, larg = scritta(chiaro)
    # marchio (256 → 140 alto) a sinistra, scritta centrata in verticale
    corpo = (f'<g transform="translate(0,0) scale({140/256:.4f})">{marchio(chiaro)}</g>\n'
             f'    <g transform="translate(162,1)">{w}</g>')
    scrivi(f"logo-completo{suff}.svg", 162 + larg + 6, 140, corpo)

# anteprime
for f in ("logo", "logo-chiaro"):
    subprocess.run(["resvg", "-w", "512", f"{f}.svg", f"{f}.png"], cwd=QUI, check=True)
for f in ("logo-completo", "logo-completo-chiaro"):
    subprocess.run(["resvg", "-w", "1100", f"{f}.svg", f"{f}.png"], cwd=QUI, check=True)
print("fatto")
