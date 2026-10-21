"""Le prove di cieltema: i preset (base, pixel, compatto, morbido) e le chiavi che restano tue.
python3 prove/test_cieltema.py   (lavora in una cartella temporanea: non tocca ~/.config, né ricarica Hyprland)"""
import importlib.machinery, importlib.util, json, os, sys, tempfile, unittest
from pathlib import Path

RADICE = Path(__file__).resolve().parent.parent


def carica(cartella):
    """cieltema con le sue cartelle puntate sulla cartella di prova: env prima, poi il modulo."""
    os.environ.update(XDG_CONFIG_HOME=f"{cartella}/conf", XDG_STATE_HOME=f"{cartella}/stato",
                      HOME=f"{cartella}/home", CIELOS_DIR=str(RADICE))
    Path(cartella, "home").mkdir(parents=True, exist_ok=True)
    for nome in ("cieltema",):
        sys.modules.pop(nome, None)
    loader = importlib.machinery.SourceFileLoader("cieltema", str(RADICE / "bin/cieltema"))
    spec = importlib.util.spec_from_loader("cieltema", loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    # niente comandi veri: la prova non deve ricaricare la Hyprland di chi la lancia, né avvisare la shell
    import types
    comandi = []
    mod.subprocess = types.SimpleNamespace(DEVNULL=-3, run=lambda c, **k: comandi.append(c),
                                           Popen=lambda c, **k: comandi.append(c))
    return mod, comandi


class Preset(unittest.TestCase):
    def setUp(self):
        self.t = tempfile.TemporaryDirectory()
        self.ct, self.comandi = carica(self.t.name)
        self.conf = Path(self.t.name, "conf/cielos")

    def tearDown(self):
        self.t.cleanup()
        for k in ("XDG_CONFIG_HOME", "XDG_STATE_HOME", "HOME", "CIELOS_DIR"):
            os.environ.pop(k, None)

    def scelte(self):
        return self.ct.leggi()

    def tema(self):
        return json.loads((self.conf / "tema.json").read_text())

    def test_pixel_mette_tutto_squadrato(self):
        ok, msg, dati = self.ct.esegui(["preset", "pixel"])
        self.assertTrue(ok, msg)
        s, t = self.scelte(), self.tema()
        self.assertEqual((s["preset"], s["raggio"], s["finestre_raggio"]), ("pixel", 0, 0))
        self.assertEqual((s["grafica"], s["animazioni"], s["opacita_pannelli"]), ("leggerissima", False, 1.0))
        self.assertTrue(s["sfondo"].endswith("grafica/sfondi/pixel.png"))
        # la shell lo vede subito: il tema generato è squadrato, opaco e senza animazioni
        self.assertEqual((t["raggio"], t["animazioni"], t["barra"]), (0, False, 42))
        self.assertTrue(t["sfondo"].endswith("pixel.png"))
        # e la base di Hyprland: niente angoli tondi, bordi spessi, sfocatura spenta
        lua = (self.conf / "hypr-ciel.lua").read_text()
        self.assertIn('dofile("' + str(RADICE / "hypr/grafica.lua") + '")("leggerissima")', lua)
        self.assertIn("rounding = 0", lua)
        self.assertIn("border_size = 3", lua)

    def test_imposta_senza_preset_nel_file(self):
        """Il caso che faceva esplodere tutto: cielos.json senza «preset», e una modifica qualsiasi."""
        (self.conf).mkdir(parents=True, exist_ok=True)
        (self.conf / "cielos.json").write_text('{"accento": "#7fd0ff"}\n')
        ok, msg, dati = self.ct.esegui(["imposta", "raggio=20"])
        self.assertTrue(ok, msg)
        self.assertEqual(self.scelte()["raggio"], 20)
        self.assertNotIn("preset", self.scelte())          # non se lo inventa
        self.assertEqual(self.scelte()["accento"], "#7fd0ff")

    def test_le_chiavi_dette_a_mano_vincono(self):
        ok, msg, _ = self.ct.esegui(["imposta", "preset=pixel", "raggio=9"])
        self.assertTrue(ok, msg)
        self.assertEqual((self.scelte()["preset"], self.scelte()["raggio"]), ("pixel", 9))

    def test_base_rimette_di_serie(self):
        self.ct.esegui(["preset", "pixel"])
        self.ct.esegui(["imposta", "accento=#6fd08c"])     # una scelta che il preset non tocca
        ok, msg, _ = self.ct.esegui(["preset", "base"])
        self.assertTrue(ok, msg)
        s = self.scelte()
        for k in self.ct._CHIAVI_PRESET:
            self.assertNotIn(k, s, f"«{k}» doveva tornare di serie")
        self.assertEqual((s["preset"], s["accento"]), ("base", "#6fd08c"))
        t = self.tema()
        self.assertEqual((t["raggio"], t["animazioni"]), (14, True))

    def test_togli_il_preset_toglie_il_pacchetto(self):
        self.ct.esegui(["preset", "morbido"])
        ok, msg, _ = self.ct.esegui(["togli", "preset"])
        self.assertTrue(ok, msg)
        s = self.scelte()
        for k in self.ct._CHIAVI_PRESET:
            self.assertNotIn(k, s)

    def test_preset_sconosciuto(self):
        ok, msg, _ = self.ct.esegui(["preset", "fluo"])
        self.assertFalse(ok)
        self.assertIn("pixel", msg)                        # dice quali ci sono

    def test_elenco_dice_quale_e_acceso(self):
        self.ct.esegui(["preset", "compatto"])
        ok, msg, dati = self.ct.esegui(["preset"])
        self.assertTrue(ok, msg)
        self.assertEqual(dati["attivo"], "compatto")
        self.assertIn("compatto  ←", msg)

    def test_pixel_squadra_anche_le_app(self):
        """Il preset non si ferma alla shell: GTK e CielFox prendono gli stessi angoli (0 = squadrati)."""
        self.ct.esegui(["preset", "pixel"])
        fox = (self.conf / "cielfox.css").read_text()
        self.assertIn("--ciel-raggio: 0px", fox)
        gtk = Path(self.t.name, "home/.config/gtk-3.0/gtk.css").read_text()
        self.assertIn("border-radius: 0px", gtk)
        self.ct.esegui(["preset", "base"])
        self.assertIn("--ciel-raggio: 14px", (self.conf / "cielfox.css").read_text())
        self.assertIn("border-radius: 14px", Path(self.t.name, "home/.config/gtk-3.0/gtk.css").read_text())

    def test_ogni_preset_dice_cosa_cambia(self):
        ok, _, dati = self.ct.esegui(["schema"])
        self.assertTrue(ok)
        det = dati["chiavi"]["preset"]["dettagli"]
        self.assertEqual(set(det), set(self.ct.PRESET))
        self.assertIn("pixel", det["pixel"])

    def test_schema_ha_il_titolo_dei_preset(self):
        ok, _, dati = self.ct.esegui(["schema"])
        self.assertTrue(ok)
        p = dati["chiavi"]["preset"]
        self.assertEqual((p["tipo"], p["di_serie"], tuple(p["limiti"])), ("scelta", "base", ("base", "pixel", "compatto", "morbido")))
        self.assertEqual(p["titolo"], "Preset grafico")

    def test_il_login_segue_le_animazioni(self):
        """sddm.conf porta le animazioni fino al login (Main.qml legge «Animazioni»): accese di serie, spente con
        «pixel». Prima la chiave non c'era e le 140 stelle del login si muovevano anche con le animazioni spente."""
        self.ct.esegui(["imposta", "accento=#7fd0ff"])
        conf = (self.conf / "sddm.conf").read_text()
        self.assertIn("Animazioni=true", conf)                 # minuscolo: è così che il login lo rilegge
        self.assertIn("Font=Rubik", conf)
        self.assertIn("Oro=#7fd0ff", conf)
        self.ct.esegui(["preset", "pixel"])
        self.assertIn("Animazioni=false", (self.conf / "sddm.conf").read_text())

    def test_ricarica_hyprland_solo_quando_serve(self):
        self.ct.esegui(["preset", "pixel"])
        self.assertIn(["hyprctl", "reload"], self.comandi)


if __name__ == "__main__":
    unittest.main(verbosity=2)
