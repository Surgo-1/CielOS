"""Le prove della schermata d'avvio di CielOS: il tema Plymouth, le immagini, il generatore e l'installazione.
python3 prove/test_avvio.py   (ridisegna il tema in una cartella temporanea: non tocca quello installato, né /boot)"""
import re, shutil, subprocess, sys, tempfile, unittest
from pathlib import Path
from PIL import Image

RADICE = Path(__file__).resolve().parent.parent
IDENTITA = RADICE / "sistema/identita"
PLYMOUTH = IDENTITA / "plymouth"
SCRIPT = PLYMOUTH / "cielos.script"

IMMAGINI = {
    "marchio.png": (1600, 485), "alone.png": (1024, 1024),
    "stella-10.png": (10, 10), "stella-18.png": (18, 18), "stella-30.png": (30, 30),
    "barra.png": (800, 12), "barra-fondo.png": (800, 12), "segmento.png": (160, 12),
    "pannello.png": (760, 320), "campo.png": (560, 52), "caret.png": (3, 30),
    "lucchetto.png": (72, 80),
}
RIFERITE = {
    "marchio.png", "alone.png", "stella-10.png", "stella-18.png", "stella-30.png",
    "barra.png", "barra-fondo.png", "segmento.png", "pannello.png", "campo.png",
    "caret.png", "lucchetto.png",
}


class Tema(unittest.TestCase):
    def test_il_tema_si_chiama_cielos_e_usa_lo_script(self):
        conf = dict(re.findall(r"^([A-Za-z]+)=(.*)$", (PLYMOUTH / "cielos.plymouth").read_text(), re.M))
        self.assertEqual(conf["Name"], "CielOS")
        self.assertEqual(conf["ModuleName"], "script")
        self.assertTrue(conf["Description"].startswith("CielOS:"), "la descrizione deve dire cosa si vede")
        self.assertEqual(conf["ImageDir"], "/usr/share/plymouth/themes/cielos")
        self.assertEqual(conf["ScriptFile"], "/usr/share/plymouth/themes/cielos/cielos.script")

    def test_ogni_immagine_e_al_suo_posto_e_leggera(self):
        """Il tema finisce nell'initramfs: poche immagini giuste, non un video di fotogrammi. Il marchio e l'alone
        sono i più pesanti e devono restare sotto i 50 KB ciascuno (il totale sotto i 200 KB)."""
        for nome, misura in IMMAGINI.items():
            f = PLYMOUTH / nome
            self.assertTrue(f.is_file(), f"manca {nome}")
            with Image.open(f) as im:
                self.assertEqual(im.size, misura, nome)
                self.assertEqual(im.mode, "RGBA", nome)
            self.assertLess(f.stat().st_size, 50_000, f"{nome} è troppo pesante per l'initramfs")
        self.assertLess(sum((PLYMOUTH / n).stat().st_size for n in IMMAGINI), 200_000)
        with Image.open(PLYMOUTH / "marchio.png") as im:
            self.assertEqual(im.getpixel((0, 0))[3], 0, "il marchio deve avere lo sfondo trasparente")
        with Image.open(PLYMOUTH / "alone.png") as im:
            self.assertEqual(im.getpixel((0, 0))[3], 0, "l'alone deve spegnersi ai bordi")
            self.assertGreater(im.getpixel((512, 512))[3], 60, "l'alone deve accendersi al centro")
        with Image.open(PLYMOUTH / "pannello.png") as im:
            self.assertGreater(im.getpixel((380, 160))[3], 200, "la scheda deve essere leggibile")
            self.assertEqual(im.getpixel((0, 0))[3], 0, "la scheda ha gli angoli tondi")

    def test_lo_script_referenzia_solo_immagini_che_esistono(self):
        testo = SCRIPT.read_text()
        riferite = set(re.findall(r'Image\("([^"]+)"\)', testo))
        self.assertEqual(riferite, RIFERITE)
        for nome in riferite:
            self.assertTrue((PLYMOUTH / nome).is_file(), f"lo script cerca {nome}, che non c'è")

    def test_lo_script_e_collegato_a_tutti_i_momenti_dell_avvio(self):
        testo = SCRIPT.read_text()
        for funzione in ("SetRefreshFunction", "SetBootProgressFunction", "SetDisplayPasswordFunction",
                         "SetDisplayQuestionFunction", "SetDisplayNormalFunction", "SetDisplayMessageFunction",
                         "SetHideMessageFunction", "SetDisplayPromptFunction", "SetDisplayHotplugFunction",
                         "SetQuitFunction"):
            self.assertIn(f"Plymouth.{funzione}(", testo, f"manca {funzione}")
        self.assertIn("Plymouth.GetMode()", testo)
        self.assertIn("Plymouth.GetCapslockState()", testo)
        self.assertIn("Bloc Maiusc", testo)
        # niente rotazioni di immagini grandi a ogni fotogramma: il tema deve restare leggero
        self.assertNotIn("Rotate(", testo)
        self.assertLess(len(testo.splitlines()), 600)

    def test_la_password_ha_la_scheda_e_il_campo(self):
        testo = SCRIPT.read_text()
        for pezzo in ("sprite_pannello", "sprite_lucchetto", "sprite_campo", "sprite_caret",
                      "sprite_maschera", "sprite_maiusc", "Sblocca il disco", "premi Invio"):
            self.assertIn(pezzo, testo)

    def test_il_menu_di_avvio_ha_lo_stesso_marchio(self):
        with Image.open(IDENTITA / "avvio.png") as im:
            self.assertEqual(im.size, (1920, 1080))
            self.assertEqual(im.mode, "RGB")
        self.assertLess((IDENTITA / "avvio.png").stat().st_size, 300_000)


class Generatore(unittest.TestCase):
    def test_rigirandolo_non_cambia_niente(self):
        """Il generatore è deterministico (stelle a seme fisso): rigirarlo deve dare gli stessi pixel, altrimenti
        ogni esecuzione sporcherebbe il repository e non si vedrebbe più cosa è cambiato davvero."""
        if not shutil.which("resvg"):
            self.skipTest("serve resvg per ridisegnare le immagini dal logo")
        with tempfile.TemporaryDirectory() as d:
            radice = Path(d)
            (radice / "grafica").mkdir()
            (radice / "sistema/identita/plymouth").mkdir(parents=True)
            for nome in ("logo.svg", "logo-completo.svg"):
                shutil.copy(RADICE / "grafica" / nome, radice / "grafica" / nome)
            shutil.copy(IDENTITA / "genera.py", radice / "sistema/identita/genera.py")
            subprocess.run([sys.executable, "genera.py"], cwd=radice / "sistema/identita",
                           check=True, capture_output=True, timeout=180)
            for nome in IMMAGINI:
                with Image.open(radice / "sistema/identita/plymouth" / nome) as nuovo, \
                        Image.open(PLYMOUTH / nome) as vecchio:
                    self.assertEqual(nuovo.tobytes(), vecchio.tobytes(), f"{nome} è cambiato ridisegnandolo")
            with Image.open(radice / "sistema/identita/avvio.png") as nuovo, \
                    Image.open(IDENTITA / "avvio.png") as vecchio:
                self.assertEqual(nuovo.tobytes(), vecchio.tobytes(), "avvio.png è cambiato ridisegnandolo")


class Installazione(unittest.TestCase):
    def test_identita_mette_il_tema_e_lo_sceglie(self):
        testo = (IDENTITA / "identita.sh").read_text()
        self.assertIn('install -m644 "$D"/plymouth/* /usr/share/plymouth/themes/cielos/', testo)
        self.assertIn("plymouth-set-default-theme cielos", testo)
        self.assertIn("cielos-plymouth.conf", testo)
        self.assertIn("mkinitcpio -P", testo)

    def test_aggiornamento_rifa_l_initramfs_solo_se_il_tema_e_attivo(self):
        script = IDENTITA / "aggiorna-avvio"
        self.assertTrue(script.is_file())
        self.assertTrue(script.stat().st_mode & 0o111, "aggiorna-avvio deve essere eseguibile")
        testo = script.read_text()
        self.assertIn("/etc/mkinitcpio.conf.d/cielos-plymouth.conf", testo)
        self.assertIn('plymouth-set-default-theme', testo)
        self.assertIn('"cielos"', testo)
        self.assertIn("mkinitcpio -P", testo)
        self.assertIn("pacman -Q cielos", testo)
        hook = (IDENTITA / "cielos-avvio.hook").read_text()
        self.assertIn("Target = cielos", hook)
        self.assertIn("When = PostTransaction", hook)
        self.assertIn("Exec = /usr/lib/cielos/aggiorna-avvio", hook)
        pkg = (RADICE / "pacchetti/cielos/PKGBUILD").read_text()
        self.assertIn('sistema/identita/aggiorna-avvio', pkg)
        self.assertIn('sistema/identita/cielos-avvio.hook', pkg)
        self.assertIn('sistema/identita/plymouth/*', pkg)
        install = (RADICE / "pacchetti/cielos/cielos.install").read_text()
        self.assertIn("/usr/lib/cielos/aggiorna-avvio", install)
        manuale = (RADICE / "installa.sh").read_text()
        self.assertIn('sistema/identita/aggiorna-avvio', manuale)
        self.assertIn('sistema/identita/cielos-avvio.hook', manuale)
        self.assertIn('cmp -s "$C/sistema/identita/plymouth/cielos.script"', manuale)


if __name__ == "__main__":
    unittest.main(verbosity=2)
