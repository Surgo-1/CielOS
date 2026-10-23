"""Le prove del risparmio batteria: il profilo che segue la presa, i servizi che a batteria aspettano, e l'icona
nella barra che mostra il livello e la carica.
python3 prove/test_energia.py   (lavora in cartelle temporanee: non tocca /sys, né ~/.config)
"""
import importlib.machinery, importlib.util, os, sys, tempfile, unittest
from pathlib import Path

RADICE = Path(__file__).resolve().parent.parent


def carica(cartella):
    """cielos-energia con le sue cartelle puntate sulla cartella di prova."""
    os.environ.update(XDG_STATE_HOME=f"{cartella}/stato", CIELOS_POWER_SUPPLY=f"{cartella}/power")
    sys.modules.pop("cielos_energia", None)
    loader = importlib.machinery.SourceFileLoader("cielos_energia", str(RADICE / "bin/cielos-energia"))
    spec = importlib.util.spec_from_loader("cielos_energia", loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


class Batteria(unittest.TestCase):
    def setUp(self):
        self.t = tempfile.TemporaryDirectory()
        self.base = Path(self.t.name, "power")
        self.base.mkdir(parents=True)
        self.mod = carica(self.t.name)

    def tearDown(self):
        self.t.cleanup()
        for k in ("XDG_STATE_HOME", "CIELOS_POWER_SUPPLY"):
            os.environ.pop(k, None)

    def pila(self, ac=None, stato=None, carica=None):
        if ac is not None:
            d = self.base / "AC"
            d.mkdir(exist_ok=True)
            (d / "online").write_text(ac)
        if stato is not None:
            d = self.base / "BAT0"
            d.mkdir(exist_ok=True)
            (d / "status").write_text(stato)
            if carica is not None:
                (d / "capacity").write_text(str(carica))

    def test_legge_presa_e_batteria(self):
        self.pila(ac="1", stato="Discharging")
        self.assertFalse(self.mod.su_batteria())
        self.pila(ac="0")
        self.assertTrue(self.mod.su_batteria())
        (self.base / "AC" / "online").unlink()
        self.pila(stato="Discharging")
        self.assertTrue(self.mod.su_batteria())
        (self.base / "BAT0" / "status").write_text("Charging")
        self.assertFalse(self.mod.su_batteria())
        self.pila(stato="Full")
        self.assertFalse(self.mod.su_batteria())

    def test_senza_batteria_non_sa_niente(self):
        self.assertIsNone(self.mod.su_batteria())
        self.assertFalse(self.mod.stato()["presente"])

    def test_stato_dice_carica_e_presa(self):
        self.pila(ac="0", stato="Discharging", carica=42)
        s = self.mod.stato()
        self.assertEqual((s["presente"], s["carica"], s["batteria"]), (True, 42, True))

    def test_con_due_batterie_il_livello_e_pesato_sull_energia(self):
        """BAT0 all'80% e BAT1 al 20%, ma la prima è nove volte più grande: il PC è al 74%, non al 50%."""
        for nome, carica, piena in (("BAT0", 80, 9000), ("BAT1", 20, 1000)):
            d = self.base / nome
            d.mkdir()
            (d / "capacity").write_text(str(carica))
            (d / "energy_full").write_text(str(piena))
        self.assertEqual(self.mod.carica_percento(), 74)
        self.assertEqual(self.mod.stato()["carica"], 74)
        # senza energy_full/charge_full ogni batteria pesa uguale
        (self.base / "BAT0" / "energy_full").unlink()
        (self.base / "BAT1" / "energy_full").unlink()
        self.assertEqual(self.mod.carica_percento(), 50)

    def test_a_batteria_mette_risparmio_e_ricorda_il_profilo(self):
        scelte, salvati, note = [], [], []
        self.mod.profilo = lambda: "balanced"
        self.mod._leggi_stato = lambda: None
        self.mod._scrivi_stato = lambda p=None: salvati.append(p)
        self.mod.imposta = lambda p: (scelte.append(p), True)[1]
        self.mod._nota = note.append
        self.assertEqual(self.mod.transizione(True), "power-saver")
        self.assertEqual(scelte, ["power-saver"])
        self.assertEqual(salvati, ["balanced"])           # alla presa si torna a questo

    def test_alla_presa_rimette_solo_il_profilo_di_prima(self):
        scelte, salvati = [], []
        self.mod.profilo = lambda: "power-saver"
        self.mod._leggi_stato = lambda: "balanced"
        self.mod._scrivi_stato = lambda p=None: salvati.append(p)
        self.mod.imposta = lambda p: (scelte.append(p), True)[1]
        self.mod._nota = lambda t: None
        self.assertEqual(self.mod.transizione(False), "balanced")
        self.assertEqual(scelte, ["balanced"])
        self.assertEqual(salvati, [None])

    def test_una_scelta_esplicita_non_si_sovrascrive(self):
        scelte = []
        self.mod.profilo = lambda: "performance"
        self.mod._leggi_stato = lambda: None
        self.mod._scrivi_stato = lambda p=None: None
        self.mod.imposta = lambda p: (scelte.append(p), True)[1]
        self.mod._nota = lambda t: None
        self.assertEqual(self.mod.transizione(True), "performance")
        self.assertEqual(scelte, [])                      # «prestazioni» resta tua
        # e se a batteria hai cambiato profilo, tornando alla presa non te lo cambia sotto
        self.mod.profilo = lambda: "performance"
        self.mod._leggi_stato = lambda: "balanced"
        self.assertEqual(self.mod.transizione(False), "performance")
        self.assertEqual(scelte, [])

    def test_i_servizi_pesanti_aspettano_la_presa(self):
        plocate = (RADICE / "sistema/prestazioni/plocate-cielos.conf").read_text()
        fstrim = (RADICE / "sistema/prestazioni/fstrim-cielos.conf").read_text()
        for testo in (plocate, fstrim):
            self.assertIn("ConditionACPower=true", testo)
            self.assertIn("IOSchedulingClass=idle", testo)
        self.assertIn("Nice=19", plocate)
        self.assertIn("CPUWeight=10", plocate)

    def test_il_servizio_esiste_solo_sui_portatili(self):
        s = (RADICE / "sistema/cielos-energia.service").read_text()
        self.assertIn("ConditionPathExistsGlob=/sys/class/power_supply/BAT*", s)
        self.assertIn("ExecStart=%h/cielos/bin/cielos-energia", s)
        self.assertIn("Restart=on-failure", s)
        install = (RADICE / "pacchetti/cielos/cielos.install").read_text()
        self.assertIn("cielos-energia.service", install)
        pkg = (RADICE / "pacchetti/cielos/PKGBUILD").read_text()
        self.assertIn("cielos-energia", pkg)
        self.assertIn("fstrim-cielos.conf", pkg)

    def test_il_medico_si_accorpa_con_gli_altri_risvegli(self):
        t = (RADICE / "sistema/cielos-medico.timer").read_text()
        self.assertIn("AccuracySec=30min", t)
        self.assertIn("RandomizedDelaySec=10min", t)


if __name__ == "__main__":
    unittest.main(verbosity=2)
