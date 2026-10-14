#!/usr/bin/env python3
"""Gli sfondi di CielOS (2560×1440, si adattano a ogni schermo): disegnati qui, niente foto da scaricare.
  notte.jpg    il cielo di notte di CielOS (lo stesso del menu di avvio, senza logo): quello di serie
  alba.jpg     la notte che schiarisce: viola e un bagliore caldo all'orizzonte
  aurora.jpg   un'aurora azzurra e verde sopra il cielo di notte
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


if __name__ == "__main__":
    for nome, f in (("notte", notte), ("alba", alba), ("aurora", aurora)):
        f().save(QUI / f"{nome}.jpg", quality=92, optimize=True)
    print("fatto:", ", ".join(f"{p.name} ({p.stat().st_size // 1024} KB)" for p in sorted(QUI.glob("*.jpg"))))
