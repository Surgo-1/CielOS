#!/usr/bin/env python3
"""Le immagini dell'avvio di CielOS, dal logo (grafica/): si rigenerano solo se cambia il logo.
  avvio.png             lo sfondo del menu di avvio (Limine e GRUB): il cielo di notte, il logo in basso
  plymouth/logo.png     il marchio per la schermata d'avvio (Plymouth)
  plymouth/punto.png    la stellina che pulsa sotto il marchio
Uso: python3 genera.py   (servono resvg e python-pillow)"""
import random, subprocess, tempfile
from pathlib import Path
from PIL import Image, ImageDraw

QUI = Path(__file__).resolve().parent
GRAFICA = QUI.parent.parent / "grafica"
NOTTE_ALTO, NOTTE_BASSO = (11, 16, 41), (20, 28, 66)          # #0B1029 → #141C42


def svg(nome, larghezza):
    with tempfile.NamedTemporaryFile(suffix=".png") as f:
        subprocess.run(["resvg", "-w", str(larghezza), str(GRAFICA / nome), f.name], check=True)
        return Image.open(f.name).convert("RGBA")


def cielo(l, a):
    """sfumatura verticale con qualche stella, più fitte in alto"""
    im = Image.new("RGB", (l, a))
    d = ImageDraw.Draw(im)
    for y in range(a):
        t = y / (a - 1)
        d.line([(0, y), (l, y)], fill=tuple(round(x + (z - x) * t) for x, z in zip(NOTTE_ALTO, NOTTE_BASSO)))
    caso = random.Random(7)                       # seme fisso: le stesse stelle a ogni rigenerazione
    for i in range(80):
        x, y = caso.randrange(l), int(caso.random() ** 1.6 * a * 0.66)
        r = 2 if caso.random() < 0.15 else 1
        v = caso.randrange(70, 200)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(v, v + 10, min(255, v + 40)))
    return im


def avvio():
    im = cielo(1920, 1080).convert("RGBA")
    logo = svg("logo-completo.svg", 420)
    im.alpha_composite(logo, ((1920 - logo.width) // 2, int(1080 * 0.80) - logo.height // 2))
    im.convert("RGB").save(QUI / "avvio.png", optimize=True)     # GRUB vuole PNG RGB a 8 bit, non interlacciato


def plymouth():
    svg("logo.svg", 150).save(QUI / "plymouth/logo.png", optimize=True)
    p = Image.new("RGBA", (14, 14))
    ImageDraw.Draw(p).ellipse([1, 1, 12, 12], fill=(127, 208, 255, 255))
    p.save(QUI / "plymouth/punto.png")


if __name__ == "__main__":
    avvio()
    plymouth()
    print("fatto:", ", ".join(str(f.relative_to(QUI)) for f in sorted(QUI.rglob("*.png"))))
