"""Le prove del compartimento grafico di CielOS: gli sfondi, il logo, il carattere.
python3 prove/test_grafica.py   (ridisegna gli sfondi in una cartella temporanea: non tocca grafica/, né ~)"""
import re, shutil, subprocess, sys, tempfile, unittest
import xml.etree.ElementTree as ET
from pathlib import Path
from PIL import Image

RADICE = Path(__file__).resolve().parent.parent
GRAFICA = RADICE / "grafica"
SFONDI = GRAFICA / "sfondi"
SFONDI_FILE = ("notte.jpg", "alba.jpg", "aurora.jpg", "pixel.png")
SVG = "http://www.w3.org/2000/svg"


class Sfondi(unittest.TestCase):
    def test_alla_misura_dello_schermo_e_leggeri(self):
        """2560×1440 (poi si adattano a ogni schermo) e sotto i 300 KB: sono nel computer, non un download da
        25 MB — gli sfondi entrano nel budget di leggerezza come tutto il resto."""
        for nome in SFONDI_FILE:
            with Image.open(SFONDI / nome) as im:
                self.assertEqual(im.size, (2560, 1440), nome)
                self.assertEqual(im.mode, "RGB", nome)
            self.assertLess((SFONDI / nome).stat().st_size, 300_000, f"{nome} è troppo pesante")

    def test_pixel_e_davvero_una_griglia_di_blocchi(self):
        """«pixel» (preset e sfondo) è 256×144 ingrandito di 10 volte senza ammorbidire niente: ogni blocco è
        uniforme e il disegno ha pochi colori. Se un giorno finisse salvato sfocato o ridimensionato, il preset
        smetterebbe di essere a pixel e non se ne accorgerebbe nessuno."""
        with Image.open(SFONDI / "pixel.png") as im:
            piccola = im.resize((256, 144), Image.NEAREST)
            self.assertEqual(im.tobytes(), piccola.resize(im.size, Image.NEAREST).tobytes(),
                             "pixel.png non è un ingrandimento esatto (NEAREST) di 256×144")
            self.assertIsNotNone(im.getcolors(256), "pixel.png ha troppi colori per essere un disegno a blocchi")

    def test_rigirando_il_generatore_non_cambia_niente(self):
        """Il generatore è deterministico (seme fisso) e lo dice nel suo commento: rigirarlo deve dare gli stessi
        pixel. Se no, ogni esecuzione sporcherebbe il repository e non si vedrebbe più cosa è cambiato davvero."""
        try:
            import numpy  # noqa: F401  (il generatore disegna con numpy: non è una dipendenza di CielOS)
        except ImportError:
            self.skipTest("serve python-numpy per ridisegnare gli sfondi")
        with tempfile.TemporaryDirectory() as d:
            shutil.copy(SFONDI / "genera.py", Path(d) / "genera.py")
            subprocess.run([sys.executable, "genera.py"], cwd=d, check=True, capture_output=True, timeout=180)
            for nome in SFONDI_FILE:
                with Image.open(Path(d, nome)) as nuovo, Image.open(SFONDI / nome) as vecchio:
                    self.assertEqual(nuovo.tobytes(), vecchio.tobytes(), f"{nome} è cambiato ridisegnandolo")


class Logo(unittest.TestCase):
    def test_svg_validi_e_firmati_cielos(self):
        for nome in ("logo.svg", "logo-chiaro.svg", "logo-completo.svg", "logo-completo-chiaro.svg"):
            radice = ET.parse(GRAFICA / nome).getroot()
            self.assertEqual(radice.tag, f"{{{SVG}}}svg", nome)
            self.assertEqual(radice.find(f"{{{SVG}}}title").text, "CielOS", nome)
            self.assertEqual(len(radice.get("viewBox").split()), 4, nome)

    def test_le_anteprime_hanno_la_forma_del_logo(self):
        """Le PNG (menu di avvio, login, avvio grafico) vengono dagli SVG con resvg: se il logo cambia e le
        anteprime no, CielOS avrebbe due marchi diversi in due posti diversi."""
        for svg, png in (("logo.svg", "logo.png"), ("logo-chiaro.svg", "logo-chiaro.png"),
                         ("logo-completo.svg", "logo-completo.png"),
                         ("logo-completo-chiaro.svg", "logo-completo-chiaro.png")):
            x, y, larg, alt = (float(v) for v in ET.parse(GRAFICA / svg).getroot().get("viewBox").split())
            with Image.open(GRAFICA / png) as im:
                self.assertAlmostEqual(im.size[0] / im.size[1], larg / alt, delta=0.02,
                                       msg=f"{png} non ha la forma di {svg}")


class Pannelli(unittest.TestCase):
    def test_ogni_pannello_di_vetro_e_nel_giro_della_sfocatura(self):
        """I pannelli della shell sono vetro (vetroAlto → superficie → vetroBasso) e Hyprland li sfoca solo se il loro
        namespace è in PANNELLI di hypr/grafica.lua. «ciel-casella» mancava: era l'unico pannello di vetro senza
        niente sotto. Se nasce un pannello nuovo e nessuno lo aggiunge, questa prova se ne accorge."""
        lua = (RADICE / "hypr/grafica.lua").read_text()
        giro = re.search(r'local PANNELLI = "(.*?)"', lua).group(1)
        nomi = set()
        for f in (RADICE / "shell").rglob("*.qml"):
            nomi |= set(re.findall(r'namespace:\s*"(ciel-[a-z]+)"', f.read_text()))
        self.assertIn("ciel-casella", nomi)            # se cambia nome, va cambiato anche qui
        fuori = {n for n in nomi if not re.fullmatch(giro, n)}
        self.assertEqual(fuori, {"ciel-sfondo"},
                         f"pannelli di vetro che restano senza sfocatura: {sorted(fuori - {'ciel-sfondo'})}")


class Carattere(unittest.TestCase):
    def test_il_carattere_di_ciel_c_e(self):
        """Rubik è il carattere di CielOS (shell, app, login): sta in grafica/font e viaggia col pacchetto, e
        installa.sh lo mette di sistema (il login gira come utente «sddm» e la tua ~ non la vede)."""
        ttf = GRAFICA / "font/Rubik-VF.ttf"
        self.assertTrue(ttf.is_file())
        self.assertGreater(ttf.stat().st_size, 100_000)
        self.assertIn("SIL OPEN FONT LICENSE", (GRAFICA / "font/OFL.txt").read_text(), "manca la licenza")


if __name__ == "__main__":
    unittest.main(verbosity=2)
