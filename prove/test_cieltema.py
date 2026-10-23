"""Le prove di cieltema: i preset (classico, bare-bones, pixellato, compatto, morbido), i vecchi nomi che restano
validi e le chiavi che restano tue.
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

    def test_pixellato_mette_tutto_squadrato(self):
        ok, msg, dati = self.ct.esegui(["preset", "pixellato"])
        self.assertTrue(ok, msg)
        s, t = self.scelte(), self.tema()
        self.assertEqual((s["preset"], s["raggio"], s["finestre_raggio"]), ("pixellato", 0, 0))
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

    def test_bare_bones_e_il_piu_leggero(self):
        """Il preset di chi vuole un sistema nudo: niente immagine, niente effetti, barra ai minimi, app non ritinte.
        Le funzioni di CielOS restano tutte (vedi test_bare_bones_non_spegne_le_funzioni)."""
        ok, msg, _ = self.ct.esegui(["preset", "bare-bones"])
        self.assertTrue(ok, msg)
        s, t = self.scelte(), self.tema()
        self.assertEqual((s["preset"], s["raggio"], s["finestre_raggio"], s["finestre_bordo"]),
                         ("bare-bones", 0, 0, 1))
        self.assertEqual((s["spazio_dentro"], s["spazio_fuori"]), (0, 0))
        self.assertEqual((s["grafica"], s["animazioni"], s["opacita_pannelli"]),
                         ("leggerissima", False, 1.0))
        self.assertEqual((s["barra_larghezza"], s["icona_barra"], s["barra_spazio"], s["margine"]),
                         (36, 14, 2, 4))
        self.assertEqual(s["sfondo"], "")                     # nessuna immagine: solo il colore
        self.assertFalse(s["tema_app"])                      # le app restano come sono
        self.assertEqual((t["sfondo"], t["animazioni"], t["barra"]), ("", False, 36))
        # le app non vengono ritinte: niente css di Ciel per GTK e CielFox
        self.assertFalse((self.conf / "cielfox.css").exists())
        self.assertFalse(Path(self.t.name, "home/.config/gtk-3.0/gtk.css").exists())
        lua = (self.conf / "hypr-ciel.lua").read_text()
        self.assertIn('dofile("' + str(RADICE / "hypr/grafica.lua") + '")("leggerissima")', lua)
        self.assertIn("rounding = 0", lua)
        self.assertIn("border_size = 1", lua)
        self.assertIn("gaps_in = 0", lua)
        self.assertIn("gaps_out = 0", lua)

    def test_bare_bones_lascia_le_app_come_sono(self):
        """Bare-bones non impone colori alle app: toglie il css di Ciel e rimette quello che c'era prima."""
        gtk = Path(self.t.name, "home/.config/gtk-3.0/gtk.css")
        self.ct.esegui(["preset", "pixellato"])
        self.assertIn("border-radius: 0px", gtk.read_text())
        self.ct.esegui(["preset", "bare-bones"])
        self.assertFalse(gtk.exists())                          # era nostro: va via
        self.assertFalse((self.conf / "cielfox.css").exists())
        gtk.write_text("# il tema mio\n")                     # uno tuo, invece, resta tuo
        self.ct.esegui(["preset", "pixellato"])
        self.ct.esegui(["preset", "bare-bones"])
        self.assertEqual(gtk.read_text(), "# il tema mio\n")

    def test_bare_bones_non_spegne_le_funzioni(self):
        """Bare-bones spegne la shell grafica, non CielOS: IA, avatar e barra componibile restano come li hai scelti;
        le scorciatoie restano, ma aprono i menu nel terminale (cielos-tui) invece dei pannelli."""
        self.ct.esegui(["imposta", "avatar=true", "barra_mostra_media=false", "tasto_lanciatore=SUPER + K"])
        ok, msg, _ = self.ct.esegui(["preset", "bare-bones"])
        self.assertTrue(ok, msg)
        s, t = self.scelte(), self.tema()
        self.assertEqual((s["avatar"], s["barra_mostra_media"], s["tasto_lanciatore"]),
                         (True, False, "SUPER + K"))
        self.assertEqual((t["ia"], t["barra_mostra_nucleo"], t["barra_mostra_orologio"], t["barra_mostra_spegni"]),
                         ("accesa", True, True, True))
        self.assertEqual((s["modalita"], t["modalita"]), ("tui", "tui"))
        lua = (self.conf / "hypr-ciel.lua").read_text()
        for sezione in ("programmi", "impostazioni", "sessione", "sistema"):
            self.assertIn(f"cielos-tui {sezione}", lua)
        self.assertNotIn("ciel:lanciatore", lua)
        self.assertIn('hl.bind("SUPER + K", hl.dsp.exec_cmd("foot -e cielos-tui programmi")', lua)
        # tornare alla grafica riporta i tasti ai pannelli della shell
        self.ct.esegui(["preset", "classico"])
        self.assertEqual(self.scelte()["modalita"], "shell")
        self.assertIn("ciel:lanciatore", (self.conf / "hypr-ciel.lua").read_text())

    def test_il_passaggio_tra_preset_non_lascia_resti(self):
        """Il preset nuovo decide tutto il suo pacchetto: niente sfondo a pixel o barra minima ereditati da prima."""
        self.ct.esegui(["preset", "pixellato"])
        self.ct.esegui(["preset", "bare-bones"])
        s = self.scelte()
        self.assertEqual((s["sfondo"], s["tema_app"], s["barra_larghezza"], s["icona_barra"]),
                         ("", False, 36, 14))
        self.ct.esegui(["preset", "classico"])
        s, t = self.scelte(), self.tema()
        for k in self.ct._CHIAVI_PRESET:
            self.assertNotIn(k, s)
        self.assertEqual((t["sfondo"], t["barra"], t["animazioni"]),
                         (str(RADICE / "grafica/sfondi/notte.jpg"), 52, True))
        # anche andando a morbido lo sfondo a pixel non resta attaccato
        self.ct.esegui(["preset", "pixellato"])
        self.ct.esegui(["preset", "morbido"])
        self.assertTrue(self.tema()["sfondo"].endswith("notte.jpg"))

    def test_i_nomi_vecchi_restano_accettati(self):
        ok, msg, dati = self.ct.esegui(["preset", "base"])
        self.assertTrue(ok, msg)
        self.assertEqual((self.scelte()["preset"], dati["preset"]), ("classico", "classico"))
        ok, msg, dati = self.ct.esegui(["preset", "pixel"])
        self.assertTrue(ok, msg)
        self.assertEqual((self.scelte()["preset"], dati["preset"]), ("pixellato", "pixellato"))
        self.ct.esegui(["imposta", "preset=base"])
        self.assertEqual(self.scelte()["preset"], "classico")
        (self.conf / "cielos.json").write_text('{"preset": "pixel"}\n')
        self.assertEqual(self.ct.leggi()["preset"], "pixellato")

    def test_genera_non_riscrive_i_file_identici(self):
        """Rigenerare le stesse cose non deve toccare i file: niente scritture, niente ricariche della shell a vuoto."""
        self.ct.esegui(["preset", "pixellato"])
        casa = Path(self.t.name, "home/.config")
        file = [self.conf / "tema.json", self.conf / "hypr-ciel.lua", self.conf / "sddm.conf",
                self.conf / "cielfox.css", casa / "gtk-3.0/gtk.css", casa / "foot/foot.ini",
                casa / "foot/ciel-colori.ini"]
        prima = {f: f.stat().st_ino for f in file}
        self.ct.esegui(["genera"])
        self.assertEqual({f: f.stat().st_ino for f in file}, prima)

    def test_hook_solo_quando_i_colori_cambiano(self):
        """Il raggio o la barra non riguardano gli hook «tema»; un colore nuovo sì."""
        self.ct.esegui(["preset", "classico"])
        conta = lambda: len([c for c in self.comandi if c and "cielos-hook" in str(c[0])])
        prima = conta()
        self.ct.esegui(["imposta", "raggio=20"])
        self.assertEqual(conta(), prima)
        self.ct.esegui(["imposta", "accento=#7fd0ff"])
        self.assertGreater(conta(), prima)

    def test_i_preset_leggeri_non_installano_la_sfocatura(self):
        """Se la grafica è «leggerissima» la sfocatura è spenta: la regola sui pannelli non serve e non si mette."""
        for nome in ("bare-bones", "pixellato"):
            self.ct.esegui(["preset", nome])
            self.assertNotIn("blur = true", (self.conf / "hypr-ciel.lua").read_text(), nome)
        self.ct.esegui(["preset", "classico"])
        self.assertIn("blur = true", (self.conf / "hypr-ciel.lua").read_text())

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
        ok, msg, _ = self.ct.esegui(["imposta", "preset=pixellato", "raggio=9"])
        self.assertTrue(ok, msg)
        self.assertEqual((self.scelte()["preset"], self.scelte()["raggio"]), ("pixellato", 9))

    def test_classico_rimette_di_serie(self):
        self.ct.esegui(["preset", "pixellato"])
        self.ct.esegui(["imposta", "accento=#6fd08c"])     # una scelta che il preset non tocca
        ok, msg, _ = self.ct.esegui(["preset", "classico"])
        self.assertTrue(ok, msg)
        s = self.scelte()
        for k in self.ct._CHIAVI_PRESET:
            self.assertNotIn(k, s, f"«{k}» doveva tornare di serie")
        self.assertEqual((s["preset"], s["accento"]), ("classico", "#6fd08c"))
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
        for nome in ("classico", "bare-bones", "pixellato"):
            self.assertIn(nome, msg)                       # dice quali ci sono

    def test_elenco_dice_quale_e_acceso(self):
        self.ct.esegui(["preset", "compatto"])
        ok, msg, dati = self.ct.esegui(["preset"])
        self.assertTrue(ok, msg)
        self.assertEqual(dati["attivo"], "compatto")
        self.assertIn("compatto  ←", msg)

    def test_pixellato_squadra_anche_le_app(self):
        """Il preset non si ferma alla shell: GTK e CielFox prendono gli stessi angoli (0 = squadrati)."""
        self.ct.esegui(["preset", "pixellato"])
        fox = (self.conf / "cielfox.css").read_text()
        self.assertIn("--ciel-raggio: 0px", fox)
        gtk = Path(self.t.name, "home/.config/gtk-3.0/gtk.css").read_text()
        self.assertIn("border-radius: 0px", gtk)
        self.ct.esegui(["preset", "classico"])
        self.assertIn("--ciel-raggio: 14px", (self.conf / "cielfox.css").read_text())
        self.assertIn("border-radius: 14px", Path(self.t.name, "home/.config/gtk-3.0/gtk.css").read_text())

    def test_ogni_preset_dice_cosa_cambia(self):
        ok, _, dati = self.ct.esegui(["schema"])
        self.assertTrue(ok)
        det = dati["chiavi"]["preset"]["dettagli"]
        self.assertEqual(set(det), set(self.ct.PRESET))
        self.assertIn("leggerissimo", det["bare-bones"])
        self.assertIn("retro", det["pixellato"])

    def test_schema_ha_il_titolo_dei_preset(self):
        ok, _, dati = self.ct.esegui(["schema"])
        self.assertTrue(ok)
        p = dati["chiavi"]["preset"]
        self.assertEqual((p["tipo"], p["di_serie"], tuple(p["limiti"])),
                         ("scelta", "classico", ("classico", "bare-bones", "pixellato", "compatto", "morbido")))
        self.assertEqual(p["titolo"], "Preset grafico")

    def test_l_ia_si_puo_spegnere_tutta(self):
        """«ia» spenta: la shell non carica avatar e riquadro di Ciel e il ponte di CielFox non risponde. Di serie è
        accesa (e chi ha un cielos.json vecchio, senza la chiave, non si trova l'IA spenta per caso)."""
        self.ct.esegui(["imposta", "accento=#7fd0ff"])
        t = self.tema()
        self.assertEqual((t["ia"], t["ia_cielfox"]), ("accesa", True))
        ok, msg, _ = self.ct.esegui(["imposta", "ia=spenta"])
        self.assertTrue(ok, msg)
        t = self.tema()
        self.assertEqual((t["ia"], t["ia_cielfox"]), ("spenta", False))   # il browser segue la scelta principale
        self.ct.esegui(["imposta", "ia=accesa", "ia_cielfox=false"])
        t = self.tema()
        self.assertEqual((t["ia"], t["ia_cielfox"]), ("accesa", False))   # e si può spegnere solo nel browser

    def test_il_login_segue_le_animazioni(self):
        """sddm.conf porta le animazioni fino al login (Main.qml legge «Animazioni»): accese di serie, spente con
        «pixellato». Prima la chiave non c'era e le 140 stelle del login si muovevano anche con le animazioni spente."""
        self.ct.esegui(["imposta", "accento=#7fd0ff"])
        conf = (self.conf / "sddm.conf").read_text()
        self.assertIn("Animazioni=true", conf)                 # minuscolo: è così che il login lo rilegge
        self.assertIn("Font=Rubik", conf)
        self.assertIn("Oro=#7fd0ff", conf)
        self.ct.esegui(["preset", "pixellato"])
        self.assertIn("Animazioni=false", (self.conf / "sddm.conf").read_text())

    def test_ricarica_hyprland_solo_quando_serve(self):
        self.ct.esegui(["preset", "pixellato"])
        self.assertIn(["hyprctl", "reload"], self.comandi)

    def test_modo_chiaro_cambia_anche_la_shell(self):
        """Prima «chiaro» cambiava solo le app: la barra restava notte. Senza colori scelti a mano, la shell segue
        il modo; un tema o un colore esplicito vincono sempre."""
        ok, msg, _ = self.ct.esegui(["imposta", "modo=chiaro"])
        self.assertTrue(ok, msg)
        t = self.tema()
        self.assertEqual((t["modo"], t["fondo"], t["testo"]), ("chiaro", "#f4efe6", "#2a2420"))
        self.assertNotEqual(t["superficie"], "#0a0f29")       # la superficie non resta blu notte
        self.assertNotEqual(t["fondoAlto"], "#141b3d")         # nemmeno la parte alta della barra
        self.ct.esegui(["imposta", "modo=scuro"])
        self.assertEqual((self.tema()["modo"], self.tema()["fondo"]), ("scuro", "#0b1029"))
        # un tema chiaro porta con sé il modo; e i colori detti a mano restano tuoi
        self.ct.esegui(["tema", "giorno"])
        t = self.tema()
        self.assertEqual((t["modo"], t["fondo"]), ("chiaro", "#fbf8f0"))
        self.ct.esegui(["imposta", "fondo=#123456", "modo=chiaro"])
        self.assertEqual(self.tema()["fondo"], "#123456")

    def test_ci_sono_piu_temi(self):
        ok, _, dati = self.ct.esegui(["schema"])
        self.assertTrue(ok)
        self.assertGreaterEqual(len(dati["temi"]), 17)
        for nome in ("giorno", "sabbia", "oceano", "orchidea", "menta"):
            self.assertIn(nome, dati["temi"])

    def test_layout_finestre_si_salva_e_arriva_a_hyprland(self):
        ok, msg, _ = self.ct.esegui(["imposta", "finestre_layout=master"])
        self.assertTrue(ok, msg)
        self.assertEqual(self.tema()["finestre_layout"], "master")
        lua = (self.conf / "hypr-ciel.lua").read_text()
        self.assertIn('layout = "master"', lua)
        ok, _, dati = self.ct.esegui(["schema"])
        self.assertTrue(ok)
        self.assertEqual(dati["chiavi"]["finestre_layout"]["limiti"], ("dwindle", "master", "scrolling"))

    def test_la_barra_si_puo_configurare(self):
        self.ct.esegui(["genera"])
        t = self.tema()
        self.assertEqual((t["barra_spazio"], t["barra_mostra_layout"], t["barra_mostra_orologio"],
                          t["barra_mostra_luce"], t["barra_mostra_batteria"]), (12, True, True, True, True))
        self.ct.esegui(["imposta", "barra_spazio=6", "barra_mostra_layout=false", "barra_mostra_batteria=false"])
        t = self.tema()
        self.assertEqual((t["barra_spazio"], t["barra_mostra_layout"], t["barra_mostra_batteria"]), (6, False, False))


if __name__ == "__main__":
    unittest.main(verbosity=2)
