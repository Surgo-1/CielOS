"""Le prove di CielFox: il profilo, l'estensione impacchettata, il ponte con Ciel e l'autoverifica del lanciatore.
python3 prove/test_cielfox.py   (lavora in una cartella temporanea: non tocca ~/.librewolf, né il profilo vero)"""
import json, os, re, shutil, subprocess, tempfile, unittest, zipfile
from pathlib import Path

RADICE = Path(__file__).resolve().parent.parent
CIELFOX = RADICE / "cielfox"
EST = CIELFOX / "estensione"


class Estensione(unittest.TestCase):
    def manifest(self):
        return json.loads((EST / "manifest.json").read_text())

    def test_il_manifest_e_valido_e_i_file_ci_sono(self):
        """Un manifest con un file che non esiste (o un JSON rotto) fa partire il browser senza Ciel e senza dire
        perché: il pannello semplicemente non c'è. Meglio saperlo qui."""
        m = self.manifest()
        self.assertEqual(m["manifest_version"], 2)
        self.assertGreaterEqual(tuple(int(x) for x in m["version"].split(".")), (1, 3))
        riferiti = list(m["icons"].values()) + [m["sidebar_action"]["default_panel"],
                                                m["options_ui"]["page"], m["chrome_url_overrides"]["newtab"],
                                                *m["background"]["scripts"]] + list(m["sidebar_action"]["default_icon"].values()) \
            + list(m["browser_action"]["default_icon"].values())
        for f in riferiti:
            self.assertTrue((EST / f).is_file(), f"il manifest nomina {f}, che non c'è")

    def test_ciel_sta_nel_menu_e_ha_la_scorciatoia(self):
        """Le aggiunte di oggi: «Chiedi a Ciel su questo» nel tasto destro («menus») e Alt+Maiusc+C per la pagina."""
        m = self.manifest()
        self.assertIn("menus", m["permissions"])
        self.assertIn("nativeMessaging", m["permissions"])
        self.assertIn("ciel-pagina", m["commands"])
        self.assertEqual(m["commands"]["ciel-pagina"]["suggested_key"]["default"], "Alt+Shift+C")
        sfondo = (EST / "sfondo.js").read_text()
        for pezzo in ("browser.menus.create", "ciel-selezione", "browser.commands.onCommand"):
            self.assertIn(pezzo, sfondo)

    def test_l_estensione_si_impacchetta(self):
        """Il lanciatore la mette in uno .xpi con zip: il manifest deve stare nella radice dell'archivio (dentro una
        cartella, Firefox non la vedrebbe)."""
        with tempfile.TemporaryDirectory() as d:
            xpi = Path(d) / "ciel.xpi"
            subprocess.run(["zip", "-qr", "-X", str(xpi), "."], cwd=EST, check=True)
            with zipfile.ZipFile(xpi) as z:
                nomi = z.namelist()
                self.assertIn("manifest.json", nomi)
                self.assertIn("sfondo.js", nomi)
                self.assertFalse(any(n.startswith("./") for n in nomi), "percorsi con ./ nell'archivio")
                self.assertEqual(json.loads(z.read("manifest.json"))["version"], self.manifest()["version"])


class Profilo(unittest.TestCase):
    def test_user_js_ha_solo_righe_vere(self):
        """Ogni riga di user.js deve essere un user_pref(…): una riga rotta viene ignorata in silenzio e
        l'impostazione che credevi di avere non c'è (è il modo in cui la decodifica video era spenta senza saperlo)."""
        for i, riga in enumerate((CIELFOX / "profilo/user.js").read_text().splitlines(), 1):
            r = riga.strip()
            if not r or r.startswith("//"):
                continue
            # il commento in coda è facoltativo (e può contenere // dentro un indirizzo: si toglie solo dopo);
            # quello che conta è che la riga sia un user_pref completo, chiuso da «);»
            self.assertRegex(r, r'^user_pref\("[^"]+",\s*.+\);\s*(//.*)?$', f"user.js riga {i}: {r}")

    def test_userchrome_chiude_le_graffe_e_prende_i_colori(self):
        css = (CIELFOX / "profilo/userChrome.css").read_text()
        self.assertEqual(css.count("{"), css.count("}"), "graffe non bilanciate in userChrome.css")
        self.assertIn('@import url("ciel.css")', css)
        self.assertIn("--ciel-raggio", css)
        # le aggiunte di oggi
        self.assertIn("#statuspanel-label", css)
        self.assertIn("findbar", css)


class Lanciatore(unittest.TestCase):
    def test_verifica_il_profilo_di_zeo(self):
        """«cielfox --verifica» su un profilo nuovo (HOME e profilo in una cartella temporanea): prepara tutto,
        impacchetta, registra il ponte e ci parla davvero. Se un giorno si rompe, si vede da qui e non dall'utente."""
        with tempfile.TemporaryDirectory() as d:
            env = {**os.environ, "HOME": f"{d}/h", "CIELFOX_PROFILO": f"{d}/profilo",
                   "XDG_CONFIG_HOME": f"{d}/conf", "XDG_STATE_HOME": f"{d}/stato", "CIELOS_DIR": str(RADICE)}
            r = subprocess.run([str(RADICE / "bin/cielfox"), "--verifica"], capture_output=True, text=True,
                               timeout=180, env=env)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            self.assertNotIn("✗", r.stdout, r.stdout)
            self.assertIn("il ponte risponde", r.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
