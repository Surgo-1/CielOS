#!/usr/bin/env python3
"""Le immagini dell'avvio di CielOS, dal logo (grafica/): si rigenerano solo se cambia il logo.
  avvio.png             lo sfondo del menu di avvio (Limine e GRUB): il cielo di notte, il logo in basso
  plymouth/marchio.png  il marchio con la scritta, per la schermata d'avvio (Plymouth)
  plymouth/alone.png    l'alone celeste dietro il marchio
  plymouth/stella-*.png le stelle del cielo (tre misure)
  plymouth/barra*.png   la barra di avanzamento (fondo e riempimento)
  plymouth/segmento.png il pezzo che scorre quando l'avanzamento non si sa ancora
  plymouth/pannello.png la scheda della password del disco
  plymouth/campo.png    il campo dove si scrive la password
  plymouth/caret.png    la barretta che lampeggia nel campo vuoto
  plymouth/lucchetto.png il lucchetto della scheda
Uso: python3 genera.py   (servono resvg e python-pillow)"""
import math, random, subprocess, tempfile
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

QUI = Path(__file__).resolve().parent
GRAFICA = QUI.parent.parent / "grafica"
NOTTE_ALTO, NOTTE_BASSO = (11, 16, 41), (20, 28, 66)          # #0B1029 → #141C42
CELESTE, CELESTE_CHIARO = (63, 169, 232), (159, 225, 255)      # #3FA9E8, #9FE1FF


def svg(nome, larghezza):
    with tempfile.NamedTemporaryFile(suffix=".png") as f:
        subprocess.run(["resvg", "-w", str(larghezza), str(GRAFICA / nome), f.name], check=True)
        return Image.open(f.name).convert("RGBA")


def salva(im, nome):
    im.save(QUI / "plymouth" / nome, optimize=True)


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


def radiale(dim, colore, massimo):
    """un alone morbido: pieno al centro, trasparente ai bordi"""
    grad = Image.radial_gradient("L").resize((dim, dim), Image.Resampling.LANCZOS)
    alpha = grad.point(lambda v: int((1 - v / 255) ** 2 * massimo))
    im = Image.new("RGBA", (dim, dim), (*colore, 0))
    im.putalpha(alpha)
    return im


def stella(dim):
    """una stella a quattro punte con un alone celeste"""
    scala = 4
    n = dim * scala
    c, R, k = n / 2, n * 0.38, n * 0.06
    punti = [(c, c - R), (c + k, c - k), (c + R, c), (c + k, c + k),
             (c, c + R), (c - k, c + k), (c - R, c), (c - k, c - k)]
    alone = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    ImageDraw.Draw(alone).polygon(punti, fill=(*CELESTE_CHIARO, 170))
    alone = alone.filter(ImageFilter.GaussianBlur(n * 0.07))
    nucleo = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    ImageDraw.Draw(nucleo).polygon(punti, fill=(255, 255, 255, 255))
    im = Image.alpha_composite(alone, nucleo)
    return im.resize((dim, dim), Image.Resampling.LANCZOS)


def sfumatura(l, a, da, a_):
    im = Image.new("RGBA", (l, a), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for x in range(l):
        t = x / max(1, l - 1)
        d.line([(x, 0), (x, a)], fill=tuple(round(p + (q - p) * t) for p, q in zip(da, a_)))
    maschera = Image.new("L", (l, a), 0)
    ImageDraw.Draw(maschera).rounded_rectangle([0, 0, l - 1, a - 1], radius=a / 2, fill=255)
    im.putalpha(maschera)
    return im


def barre():
    l, a = 800, 12
    salva(sfumatura(l, a, CELESTE, CELESTE_CHIARO), "barra.png")
    fondo = Image.new("RGBA", (l, a), (0, 0, 0, 0))
    d = ImageDraw.Draw(fondo)
    d.rounded_rectangle([0, 0, l - 1, a - 1], radius=a / 2, fill=(255, 255, 255, 22),
                        outline=(255, 255, 255, 30), width=1)
    salva(fondo, "barra-fondo.png")
    # il pezzo che scorre quando il sistema non sa ancora a che punto è: acceso al centro, spento ai lati
    seg = Image.new("RGBA", (160, a), (0, 0, 0, 0))
    d = ImageDraw.Draw(seg)
    for x in range(160):
        t = x / 159
        f = math.sin(math.pi * t) ** 0.7
        al = int(255 * f)
        col = tuple(round(p + (q - p) * t) for p, q in zip(CELESTE, CELESTE_CHIARO))
        d.line([(x, 0), (x, a)], fill=(*col, al))
    maschera = Image.new("L", (160, a), 0)
    ImageDraw.Draw(maschera).rounded_rectangle([0, 0, 159, a - 1], radius=a / 2, fill=255)
    seg.putalpha(maschera)
    salva(seg, "segmento.png")


def pannello():
    l, a = 760, 320
    im = Image.new("RGBA", (l, a), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([1, 1, l - 2, a - 2], radius=34, fill=(10, 15, 38, 235),
                        outline=(*CELESTE, 110), width=2)
    # una riga di luce in cima: la scheda non è un rettangolo piatto
    velo = Image.new("RGBA", (l, a), (0, 0, 0, 0))
    v = ImageDraw.Draw(velo)
    v.rounded_rectangle([34, 2, l - 34, 3], radius=1, fill=(*CELESTE_CHIARO, 70))
    im = Image.alpha_composite(im, velo)
    salva(im, "pannello.png")


def campo():
    l, a = 560, 52
    im = Image.new("RGBA", (l, a), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([1, 1, l - 2, a - 2], radius=26, fill=(6, 10, 26, 205),
                        outline=(*CELESTE, 90), width=2)
    d.rounded_rectangle([18, 3, l - 19, 4], radius=1, fill=(255, 255, 255, 18))
    salva(im, "campo.png")
    caret = Image.new("RGBA", (3, 30), (0, 0, 0, 0))
    ImageDraw.Draw(caret).rounded_rectangle([0, 0, 2, 29], radius=1, fill=(*CELESTE_CHIARO, 255))
    salva(caret, "caret.png")


def lucchetto():
    scala = 4
    l, a = 72, 80
    n = (l * scala, a * scala)
    im = Image.new("RGBA", n, (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    col = (*CELESTE_CHIARO, 255)
    d.arc([84, 12, 204, 170], 180, 360, fill=col, width=16)
    d.line([(84, 91), (84, 150)], fill=col, width=16)
    d.line([(204, 91), (204, 150)], fill=col, width=16)
    d.rounded_rectangle([40, 132, 248, 300], radius=28, fill=(*CELESTE, 38), outline=col, width=14)
    d.ellipse([128, 184, 160, 216], fill=col)
    d.line([(144, 208), (144, 252)], fill=col, width=12)
    im = im.resize((l, a), Image.Resampling.LANCZOS)
    salva(im, "lucchetto.png")


def avvio():
    im = cielo(1920, 1080).convert("RGBA")
    alone = radiale(1600, CELESTE, 40)
    alone = alone.resize((1600, 900), Image.Resampling.LANCZOS)
    im.alpha_composite(alone, ((1920 - 1600) // 2, 1080 - 900 + 140))
    logo = svg("logo-completo.svg", 420)
    im.alpha_composite(logo, ((1920 - logo.width) // 2, int(1080 * 0.80) - logo.height // 2))
    im.convert("RGB").save(QUI / "avvio.png", optimize=True)     # GRUB vuole PNG RGB a 8 bit, non interlacciato


def plymouth():
    (QUI / "plymouth").mkdir(exist_ok=True)
    salva(svg("logo-completo.svg", 1600), "marchio.png")
    salva(radiale(1024, CELESTE, 96), "alone.png")
    for misura in (10, 18, 30):
        salva(stella(misura), f"stella-{misura}.png")
    barre()
    pannello()
    campo()
    lucchetto()


if __name__ == "__main__":
    avvio()
    plymouth()
    print("fatto:", ", ".join(str(f.relative_to(QUI)) for f in sorted(QUI.rglob("*.png"))))
