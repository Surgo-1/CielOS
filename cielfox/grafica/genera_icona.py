#!/usr/bin/env python3
"""L'icona di CielFox: l'anello della C di CielOS (celeste) con una volpe bianca che ci corre intorno, in orbita:
la testa in alto a destra (dove nel logo di CielOS c'è la stella) e la coda lunga che segue l'anello, sfumando
dal bianco al celeste. Volpe nostra, geometrica (non è quella di Firefox: il suo logo è un marchio di Mozilla).
Genera icona.svg e le PNG a 16..512 px. Uso: python3 genera_icona.py"""
import math, subprocess
from pathlib import Path

QUI = Path(__file__).parent
CELESTE_A, CELESTE_B, BIANCO = "#9FE1FF", "#3FA9E8", "#FFFFFF"

def p(cx, cy, r, g):
    a = math.radians(g)
    return cx + r * math.cos(a), cy + r * math.sin(a)

def icona():
    c, r = 124, 70
    # l'anello: aperto in alto a destra (lì c'è la volpe)
    a0, a1 = -10, -70 + 360
    x0, y0 = p(c, c, r, a0); x1, y1 = p(c, c, r, a1)
    # la coda: una falce che segue l'anello all'esterno, da sotto la testa fino in basso a sinistra, sempre più sottile
    est, punte = r + 26, []
    passi = list(range(-36, 160, 5))
    fuori = [p(c, c, est + 14 * (1 - i / len(passi)) ** 1.3, g) for i, g in enumerate(passi)]
    dentro = [p(c, c, est - 14 * (1 - i / len(passi)) ** 1.0, g) for i, g in enumerate(passi)]
    coda = "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in fuori) + " L" + \
           " L".join(f"{x:.1f},{y:.1f}" for x, y in reversed(dentro)) + "Z"
    # la testa: in alto a destra sull'orbita, muso verso la direzione del moto (in senso orario: verso destra-basso)
    hx, hy = p(c, c, est + 2, -52)
    ang = -58 + 90                              # tangente all'orbita
    def ruota(px, py):
        a = math.radians(ang)
        return hx + px * math.cos(a) - py * math.sin(a), hy + px * math.sin(a) + py * math.cos(a)
    # forma della testa nel suo sistema (x avanti = muso, y giù): orecchie dietro, muso a punta davanti
    testa_pt = [(-28, 4), (-34, -40), (-14, -18), (-2, -42), (8, -16), (44, 4), (12, 20), (-18, 20)]
    testa_pt = [(x * 1.0, y * 1.0) for x, y in testa_pt]
    testa = "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in (ruota(*q) for q in testa_pt)) + "Z"
    occhio = ruota(6, -2)
    naso = ruota(42, 4)
    return f"""<defs>
    <linearGradient id="anello" x1="0" y1="0" x2="0.4" y2="1"><stop offset="0" stop-color="{CELESTE_A}"/><stop offset="1" stop-color="{CELESTE_B}"/></linearGradient>
    <linearGradient id="coda" x1="1" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{BIANCO}"/><stop offset="0.55" stop-color="{CELESTE_A}"/><stop offset="1" stop-color="{CELESTE_B}" stop-opacity="0.15"/></linearGradient>
  </defs>
  <path d="M{x0:.1f},{y0:.1f} A{r},{r} 0 1 1 {x1:.1f},{y1:.1f}" fill="none" stroke="url(#anello)" stroke-width="16" stroke-linecap="round"/>
  <path d="{coda}" fill="url(#coda)"/>
  <path d="{testa}" fill="{BIANCO}" stroke="{BIANCO}" stroke-width="3" stroke-linejoin="round"/>
  <circle cx="{occhio[0]:.1f}" cy="{occhio[1]:.1f}" r="4" fill="#0B1029"/>
  <circle cx="{naso[0]:.1f}" cy="{naso[1]:.1f}" r="3.6" fill="#0B1029"/>"""

(QUI / "icona.svg").write_text('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256">\n'
                               '  <title>CielFox</title>\n  <g transform="translate(14,22) scale(0.89)">' + icona() + "</g>\n</svg>\n")
for n in (16, 32, 48, 64, 128, 256, 512):
    subprocess.run(["resvg", "-w", str(n), "icona.svg", f"icona-{n}.png"], cwd=QUI, check=True)
print("fatto")
