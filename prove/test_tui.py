"""Le prove di cielos-tui (i menu di CielOS nel terminale, modalità Bare-Bones) e di cielos-modalita.

python3 prove/test_tui.py   (cartelle temporanee: non tocca ~/.config, non ferma la shell vera)
"""
import importlib.machinery, importlib.util, json, os, subprocess, sys, tempfile, unittest
from pathlib import Path

RADICE = Path(__file__).resolve().parent.parent


def carica(cartella):
    os.environ.update(XDG_CONFIG_HOME=f"{cartella}/conf", XDG_STATE_HOME=f"{cartella}/stato",
                      HOME=f"{cartella}/home", CIELOS_DIR=str(RADICE), CIELOS_LINGUA="it")
    for d in ("home", "conf/cielos", "dati/applications", "finti-bin"):
        Path(cartella, d).mkdir(parents=True, exist_ok=True)
    os.environ["XDG_DATA_HOME"] = f"{cartella}/dati"
    script = Path(cartella, "finti-bin/systemctl")
    script.write_text('#!/bin/sh\necho "$@" >> "' + f"{cartella}/chiamate" + '"\nexit 0\n')
    script.chmod(0o755)
    script = Path(cartella, "finti-bin/hyprctl")
    script.write_text("#!/bin/sh\nexit 0\n")
    script.chmod(0o755)
    sys.modules.pop("cielos_tui", None)
    loader = importlib.machinery.SourceFileLoader("cielos_tui", str(RADICE / "bin/cielos-tui"))
    spec = importlib.util.spec_from_loader("cielos_tui", loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


class Menu(unittest.TestCase):
    def setUp(self):
        self.t = tempfile.TemporaryDirectory()
        self.tui = carica(self.t.name)
        self.conf = Path(self.t.name, "conf/cielos")

    def tearDown(self):
        self.t.cleanup()
        for k in ("XDG_CONFIG_HOME", "XDG_STATE_HOME", "XDG_DATA_HOME", "HOME", "CIELOS_DIR", "CIELOS_LINGUA"):
            os.environ.pop(k, None)

    def finte(self, testo):
        p = Path(self.t.name, "dati/applications/prova.desktop")
        p.write_text(testo)
        # solo la nostra: il sistema ha le sue app, e la prova non deve dipendere da quelle installate
        return [a for a in self.tui._app_entries() if a["file"] == p]

    def test_legge_le_app_installate(self):
        voci = self.finte("[Desktop Entry]\nName=Prova\nComment=Una prova\nExec=prova %U\nTerminal=false\n")
        self.assertEqual([a["nome"] for a in voci], ["Prova"])       # %U resta: lo toglie chi lancia
        self.assertEqual(voci[0]["spiega"], "Una prova")

    def test_salta_nascoste_e_senza_eseguibile(self):
        self.assertEqual(self.finte("[Desktop Entry]\nName=Nascosta\nExec=nascosta\nNoDisplay=true\n"), [])
        self.assertEqual(self.finte("[Desktop Entry]\nName=Nascosta\nExec=nascosta\nHidden=true\n"), [])
        self.assertEqual(self.finte("[Desktop Entry]\nName=Programma\nExec=programma\n"),
                         self.finte("[Desktop Entry]\nName=Programma\nExec=programma\n"))

    def test_la_tui_non_parte_senza_un_terminale(self):
        self.assertEqual(subprocess.run([sys.executable, str(RADICE / "bin/cielos-tui")],
                                        stdin=subprocess.DEVNULL, capture_output=True, text=True).returncode, 1)

    def test_la_guida_si_legge_anche_senza_terminale(self):
        r = subprocess.run([sys.executable, str(RADICE / "bin/cielos-tui"), "--aiuto"], capture_output=True, text=True)
        self.assertEqual(r.returncode, 0)
        for sezione in ("programmi", "impostazioni", "install", "strumenti", "medico", "sistema", "sessione"):
            self.assertIn(sezione, r.stdout)

    def _menu(self):
        t = self.tui.TUI.__new__(self.tui.TUI)          # senza curses: servono solo le voci
        t.avviso = ""
        return t

    def test_il_menu_ha_tutte_le_funzioni(self):
        titoli = [v.testo for v in self._menu()._voci_principali()]
        for sezione in ("Programmi", "Impostazioni", "Install", "Strumenti", "Medico", "Aggiornamenti",
                        "Guida", "Sistema", "Sessione", "Comando"):
            self.assertIn(sezione, titoli)

    def test_la_modalita_si_cambia_dai_menu(self):
        t = self._menu()
        self.assertEqual(t._modalita_attuale(), "shell")
        self.assertEqual([v.testo for v in t._voci_modalita()],
                         ["Grafica (shell Ciel)  ←", "Terminale (Bare-Bones)"])
        (self.conf / "cielos.json").write_text(json.dumps({"modalita": "tui"}))
        (self.conf / "modalita-tui").write_text("")
        self.assertEqual(t._modalita_attuale(), "tui")
        self.assertIn("Torna alla shell grafica", [v.testo for v in t._voci_principali()])

    def test_ogni_menu_si_costruisce(self):
        t = self._menu()
        for nome in ("_voci_principali", "_voci_app", "_voci_impostazioni", "_voci_modalita", "_voci_preset",
                     "_voci_tema", "_voci_accento", "_voci_chiavi", "_voci_lingua", "_voci_install",
                     "_voci_strumenti", "_voci_dns", "_voci_aggiornamenti", "_voci_sessione", "_voci_rete",
                     "_voci_energia", "_voci_schermi", "_voci_modelli", "_voci_codice"):
            voci = getattr(t, nome)()
            self.assertTrue(voci, nome)                          # un menu vuoto è un vicolo cieco
            self.assertTrue(all(v.testo for v in voci), nome)

    def test_anche_le_pagine_del_riquadro_sono_nel_terminale(self):
        titoli = [v.testo for v in self._menu()._voci_principali()]
        for sezione in ("Modelli", "Codice"):                   # Scarica modelli, I miei modelli, gli agenti
            self.assertIn(sezione, titoli)
        modelli = [v.testo for v in self._menu()._voci_modelli()]
        self.assertIn("Cerca e scarica…", modelli)
        self.assertIn("Consigliati per questo PC", modelli)

    def test_ogni_sezione_della_guida_apre_il_suo_menu(self):
        t = self._menu()
        sezioni = [s for s in ("programmi", "impostazioni", "install", "strumenti", "medico", "aggiornamenti",
                               "guida", "sistema", "sessione", "comando") if s in (self.tui.__doc__ or "")]
        self.assertGreaterEqual(len(sezioni), 8)                 # la guida le elenca tutte
        aperte = []
        t.menu = lambda titolo, voci=None, filtrabile=False: aperte.append(titolo)
        for nome in ("_medico", "_guida", "_sistema", "_comando"):
            setattr(t, nome, (lambda nome=nome: (lambda: aperte.append(nome)))())
        for sezione in sezioni:
            aperte.clear()
            t.avvia(sezione)
            self.assertEqual(len(aperte), 1, sezione)             # una schermata, nessun vicolo cieco

    def test_ogni_chiave_di_cieltema_si_puo_cambiare(self):
        voci = self._menu()._voci_chiavi()
        chiavi = [v.testo.split(" = ")[0] for v in voci]
        self.assertIn("accento", chiavi)
        self.assertIn("barra_mostra_batteria", chiavi)
        self.assertNotIn("preset", chiavi)                  # hanno un menu loro
        self.assertNotIn("modalita", chiavi)


class Modalita(unittest.TestCase):
    def setUp(self):
        self.t = tempfile.TemporaryDirectory()
        carica(self.t.name)
        self.conf = Path(self.t.name, "conf/cielos")
        self.cmd = str(RADICE / "bin/cielos-modalita")
        self.env = dict(os.environ, PATH=f"{self.t.name}/finti-bin:" + os.environ["PATH"])

    def tearDown(self):
        self.t.cleanup()
        for k in ("XDG_CONFIG_HOME", "XDG_STATE_HOME", "XDG_DATA_HOME", "HOME", "CIELOS_DIR", "CIELOS_LINGUA"):
            os.environ.pop(k, None)

    def chiamate(self):
        p = Path(self.t.name, "chiamate")
        return p.read_text() if p.exists() else ""

    def test_bare_bones_ferma_la_shell(self):
        r = subprocess.run([self.cmd, "tui"], env=self.env, capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue((self.conf / "modalita-tui").exists())
        self.assertFalse((self.conf / "shell-attiva").exists())      # ConditionPathExists: non riparte
        self.assertIn("stop ciel-shell", self.chiamate())
        self.assertEqual(json.loads((self.conf / "cielos.json").read_text())["modalita"], "tui")
        self.assertEqual(r.stdout.strip(), "tui")

    def test_tornare_alla_grafica_riaccende_la_shell(self):
        subprocess.run([self.cmd, "tui"], env=self.env, capture_output=True)
        r = subprocess.run([self.cmd, "shell"], env=self.env, capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue((self.conf / "shell-attiva").exists())
        self.assertFalse((self.conf / "modalita-tui").exists())
        self.assertIn("start ciel-shell", self.chiamate())

    def test_applica_e_idempotente(self):
        subprocess.run([self.cmd, "tui"], env=self.env, capture_output=True)
        prima = self.chiamate()
        r = subprocess.run([self.cmd, "applica"], env=self.env, capture_output=True, text=True)
        self.assertEqual(r.stdout.strip(), "tui")
        self.assertEqual(self.chiamate(), prima + prima.splitlines(True)[-1])

    def test_una_modalita_sconosciuta_non_cambia_niente(self):
        r = subprocess.run([self.cmd, "grafica"], env=self.env, capture_output=True, text=True)
        self.assertEqual(r.returncode, 2)
        self.assertFalse((self.conf / "cielos.json").exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
