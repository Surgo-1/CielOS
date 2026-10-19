#!/usr/bin/env python3
"""Gli sfondi di CielOS (2560×1440, si adattano a ogni schermo): disegnati qui, niente foto da scaricare.
  notte.jpg    il cielo di notte di CielOS (lo stesso del menu di avvio, senza logo): quello di serie
  alba.jpg     la notte che schiarisce: viola e un bagliore caldo all'orizzonte
  aurora.jpg   un'aurora azzurra e verde sopra il cielo di notte
  pixel.png    lo stesso cielo a pixel (griglia 256×144 ingrandita di 10 volte, ogni pixel un blocco): è lo sfondo
               del preset «pixel» (Impostazioni → Aspetto → Preset grafico)
Uso: python3 genera.py   (serve python-pillow e numpy)"""
import random
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

QUI = Path(__file__).resolve().parent
L, A = 2560, 1440


def sfumatura(colori):
    """colori: [(posizione 0-1, (r, g, b)), …] dall'alto in basso; con un filo di rumore contro le bande"""
    y = np.linspace(0, 1, A)[:, None]
    img = np.zeros((A, 1, 3))
    for (p0, c0), (p1, c1) in zip(colori, colori[1:]):
        t = np.clip((y - p0) / (p1 - p0), 0, 1)
        dentro = (y >= p0) & (y <= p1)
        img = np.where(dentro[..., None], np.array(c0) + (np.array(c1) - np.array(c0)) * t[..., None], img)
    img = np.repeat(img, L, axis=1)
    img += np.random.default_rng(3).normal(0, 1.2, img.shape)
    return img


def stelle(img, quante, alto=0.7, seme=7):
    caso = random.Random(seme)
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(im)
    for _ in range(quante):
        x, y = caso.randrange(L), int(caso.random() ** 1.5 * A * alto)
        r = 2.2 if caso.random() < 0.06 else 1.4 if caso.random() < 0.25 else 0.9
        v = caso.randrange(120, 235)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(v, v + 8 if v < 247 else 255, 255))
    return im


def bagliore(im, cx, cy, rx, ry, colore, forza):
    """un alone morbido (ellisse sfocata) sommato all'immagine"""
    m = Image.new("L", (L, A), 0)
    ImageDraw.Draw(m).ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=int(255 * forza))
    m = m.filter(ImageFilter.GaussianBlur(max(rx, ry) / 2.2))
    strato = Image.new("RGB", (L, A), colore)
    return Image.composite(strato, im, m)


def notte():
    img = sfumatura([(0, (9, 13, 34)), (0.6, (16, 22, 56)), (1, (24, 32, 78))])
    im = stelle(img, 420)
    im = bagliore(im, L // 2, A + 260, 1500, 420, (63, 120, 210), 0.35)       # la luce della città, lontana
    return im


def alba():
    img = sfumatura([(0, (12, 14, 40)), (0.45, (46, 30, 86)), (0.78, (120, 62, 110)), (1, (232, 140, 110))])
    im = stelle(img, 260, alto=0.45, seme=11)
    im = bagliore(im, int(L * 0.62), A + 120, 1100, 360, (255, 190, 130), 0.55)
    return im


def aurora():
    """tende di luce: bordo in basso netto e verde, coda verso l'alto che sfuma nel viola, righe verticali sottili"""
    img = sfumatura([(0, (6, 12, 30)), (0.7, (10, 22, 52)), (1, (14, 30, 66))])
    caso = np.random.default_rng(9)
    x = np.linspace(0, 1, L)
    luce = np.zeros((A, L))
    tinta = np.zeros((A, L))
    for base, ampiezza, forza, fase in ((0.46, 0.07, 1.0, 0.0), (0.36, 0.05, 0.6, 2.1)):
        bordo = A * (base + ampiezza * np.sin(x * 4.2 + fase) + 0.025 * np.sin(x * 13 + fase * 2))
        righe = 0.55 + 0.45 * np.convolve(caso.random(L), np.ones(9) / 9, mode="same")       # le pieghe della tenda
        righe *= 0.6 + 0.4 * np.clip(np.sin(x * 3.1 + fase) + 0.4, 0, 1)                   # più viva in alcuni tratti
        y = np.arange(A)[:, None]
        su = np.clip((bordo[None, :] - y) / (A * 0.28), 0, None)                          # 0 al bordo, 1 in alto
        profilo = np.where(y <= bordo[None, :], np.exp(-su * 2.6), np.exp(-((y - bordo[None, :]) / 14) ** 2))
        luce += profilo * righe[None, :] * forza
        tinta = np.maximum(tinta, np.clip(su, 0, 1) * (profilo > 0.02))
    luce = np.clip(luce, 0, 1)[..., None]
    verde, viola = np.array((90, 240, 180)), np.array((140, 110, 255))
    colore = verde + (viola - verde) * np.clip(tinta * 1.4, 0, 1)[..., None]
    img = img * (1 - luce * 0.75) + colore * luce * 0.75
    im = stelle(img, 380, seme=5)
    return im.filter(ImageFilter.GaussianBlur(1.2))


# ── la versione a pixel ───────────────────────────────────────────────────────────────────────────────────────
# Il cielo di notte disegnato su una griglia di 256×144 e ingrandito di 10 volte senza ammorbidire niente (NEAREST):
# ogni pixel è un blocco, e le sfumature si fanno a scacchiera (dithering), come sui PC a 16 colori. Deterministico:
# lo stesso file a ogni esecuzione (seme fisso), così si vede subito se qualcosa è cambiato.
PIX_L, PIX_A, PIX_SCALA = 256, 144, 10
PIX = {
    "cielo": [(9, 13, 34), (13, 19, 46), (17, 24, 58), (22, 31, 72), (28, 39, 88)],
    "stella": (207, 227, 255),
    "stella_oro": (255, 191, 63),
    "luna": (255, 226, 158),
    "luna_bordo": (255, 191, 63),
    "luna_ombra": (226, 190, 130),
    "monti_lontani": (26, 33, 74),
    "monti_vicini": (14, 19, 45),
    "acqua": [(17, 24, 58), (11, 15, 38)],
    "riflesso": (255, 205, 110),
}


def _cielo(im, d):
    """le fasce del cielo, con una riga a scacchiera tra una e l'altra (il dithering dell'epoca)"""
    fasce = PIX["cielo"]
    alto_fascia = 84                                        # il cielo finisce dove iniziano i monti
    passo = alto_fascia / len(fasce)
    for i in range(alto_fascia):
        colore = fasce[min(int(i / passo), len(fasce) - 1)]
        d.line([(0, i), (PIX_L, i)], fill=colore)
    for i in range(1, len(fasce)):                          # una fascia di scacchiera al confine
        y = int(i * passo) - 1
        chiaro, scuro = fasce[i], fasce[i - 1]
        for x in range(PIX_L):
            d.point((x, y), fill=chiaro if (x + y) % 2 else scuro)
    # il chiarore dell'orizzonte (dove il cielo tocca i monti): tre righe a scacchiera, sempre più larghe
    for i, chiaro in enumerate(((46, 60, 120), (38, 50, 104), (32, 42, 88))):
        y = alto_fascia - 3 + i
        for x in range(PIX_L):
            d.point((x, y), fill=chiaro if (x + y) % 2 else fasce[-1])


def _stelle(im, d):
    caso = random.Random(31)
    for _ in range(240):
        x, y = caso.randrange(PIX_L), caso.randrange(0, 78)
        if caso.random() < 0.10:
            d.point((x, y), fill=PIX["stella_oro"])         # una stella d'oro ogni tanto
        elif caso.random() < 0.35:
            d.point((x, y), fill=PIX["stella"])
            d.point((x + 1, y), fill=PIX["stella"])


def _luna(d):
    """la luna: un cerchio di blocchi con quattro crateri, in alto a destra"""
    cx, cy, r = 186, 34, 15
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            q = (x - cx) ** 2 + (y - cy) ** 2
            if q <= r * r:
                bordo = q > (r - 1.6) ** 2
                d.point((x, y), fill=PIX["luna_bordo"] if bordo else PIX["luna"])
    for dx, dy in ((-6, -4), (2, -7), (5, 6), (-3, 7)):
        d.point((cx + dx, cy + dy), fill=PIX["luna_ombra"])
        d.point((cx + dx + 1, cy + dy), fill=PIX["luna_ombra"])


def _anello(d):
    """il segno di CielOS in piccolo: l'anello aperto con la stella nel varco (a sinistra, 19×19)"""
    cx, cy, r = 52, 36, 9
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            q = (x - cx) ** 2 + (y - cy) ** 2
            if (r - 1.6) ** 2 < q <= r * r and not (x > cx + 3 and abs(y - cy) < 3):   # il varco a destra
                d.point((x, y), fill=PIX["luna_bordo"])
    for dy in range(-2, 3):                                  # la stella a quattro punte
        for dx in range(-2, 3):
            if abs(dx) + abs(dy) <= 2:
                d.point((cx + 6 + dx, cy + dy), fill=PIX["stella_oro"])


def _monti(d):
    """due catene di monti: una lontana più chiara, una vicina quasi nera; disegnate con una camminata a caso
    ma con passo piccolo, così i pendii sono corti e «a blocchi»"""
    caso = random.Random(5)
    for colore, base, ampiezza, passo in ((PIX["monti_lontani"], 84, 16, 0.42), (PIX["monti_vicini"], 100, 12, 0.3)):
        y = base
        for x in range(PIX_L):
            y += caso.choice((-1, 0, 0, 1)) * passo
            y = min(base + ampiezza, max(base - ampiezza, y))
            d.line([(x, int(y)), (x, PIX_A)], fill=colore)


def _acqua(d):
    """il lago: bande più scure e, sotto la luna, trattini d'oro che si allargano scendendo"""
    chiaro, scuro = PIX["acqua"]
    for y in range(112, PIX_A):
        d.line([(0, y), (PIX_L, y)], fill=scuro if (y // 3) % 2 else chiaro)
    caso = random.Random(77)
    for y in range(113, PIX_A):
        larghezza = 2 + (y - 113) // 3                              # il riflesso si allarga andando giù
        for _ in range(max(1, 5 - (y - 113) // 6)):
            x = 186 + caso.randint(-larghezza, larghezza)
            d.point((x, y), fill=PIX["riflesso"])
        if (y - 113) % 4 == 0:                                      # qualche pagliuzza di luce sparsa
            for _ in range(3):
                d.point((caso.randrange(PIX_L), y), fill=chiaro)


def pixel():
    im = Image.new("RGB", (PIX_L, PIX_A), PIX["cielo"][0])
    d = ImageDraw.Draw(im)
    _cielo(im, d)
    _stelle(im, d)
    _luna(d)
    _anello(d)
    _monti(d)
    _acqua(d)
    return im.resize((PIX_L * PIX_SCALA, PIX_A * PIX_SCALA), Image.NEAREST)


if __name__ == "__main__":
    for nome, f in (("notte", notte), ("alba", alba), ("aurora", aurora)):
        f().save(QUI / f"{nome}.jpg", quality=92, optimize=True)
    pixel().save(QUI / "pixel.png", optimize=True)
    print("fatto:", ", ".join(f"{p.name} ({p.stat().st_size // 1024} KB)"
                              for p in sorted(list(QUI.glob("*.jpg")) + list(QUI.glob("*.png")))))
