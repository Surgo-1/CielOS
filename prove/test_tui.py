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

    def test_aprire_un_programma_non_chiude_i_menu(self):
        # In Bare-Bones la TUI è l'unica cosa accesa: se si chiude aprendo un'app, lo schermo resta vuoto e per
        # riaverla bisogna riavviare (difetto vero, 23/10). L'app parte, i menu restano.
        t = self._menu()
        lanciati = []
        originale, tui = self.tui.subprocess.Popen, self.tui.subprocess
        tui.Popen = lambda *a, **k: lanciati.append(a[0])
        try:
            t._lancia({"nome": "Prova", "exec": "gio launch prova.desktop", "terminale": False,
                       "file": Path(self.t.name, "dati/applications/prova.desktop")})
        finally:
            tui.Popen = originale
        self.assertEqual(len(lanciati), 1)                       # è partita
        self.assertIn("Prova", t.avviso)                         # e la TUI dice cosa ha aperto

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


class PesoSistema(unittest.TestCase):
    def test_dice_quanto_pesa_il_pc_e_quanto_e_di_cielos(self):
        # «1,1 GB usati» non sono la shell: qui si separa quello che aggiunge CielOS da quello che c'è comunque
        # (Hyprland, portal, PipeWire, la rete). Senza questa distinzione i confronti erano sbagliati (23/10).
        r = subprocess.run([sys.executable, str(RADICE / "bin/cielos-peso"), "--sistema"],
                           capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        riga = r.stdout.strip().splitlines()[0]
        self.assertTrue(riga.startswith("Sistema:"), riga)
        for pezzo in ("CielOS", "shell", "menu", "cield", "Ciel", "il resto del sistema"):
            self.assertIn(pezzo, riga)


class EsciSessione(unittest.TestCase):
    """cielos-esci: «Esci» deve chiudere la sessione anche senza XDG_SESSION_ID (difetto vero, 23/10: la voce non
    faceva niente né nella stabile né nella Nightly, perché «hyprctl dispatch exit» non esiste più con la
    configurazione in Lua di Hyprland 0.56)."""

    def setUp(self):
        self.t = tempfile.TemporaryDirectory()
        self.bin = Path(self.t.name, "bin")
        self.bin.mkdir()
        self.registro = Path(self.t.name, "registro")
        (self.bin / "loginctl").write_text(
            "#!/bin/sh\n"
            f'echo "loginctl $*" >> "{self.registro}"\n'
            'if [ "$1" = list-sessions ]; then\n'
            '  echo "1 1000 utente seat0 tty1"; echo "2 1000 utente seat0 tty2"\n'
            'elif [ "$1" = show-session ] && [ "$3" = -p ]; then\n'
            '  case "$2" in\n'
            '    2) [ "$4" = Type ] && echo wayland || echo 2 ;;\n'
            '    1) [ "$4" = Type ] && echo tty || echo 1 ;;\n'
            '    *) exit 1 ;;\n'
            '  esac\n'
            'elif [ "$1" = terminate-session ]; then\n'
            f'  echo "TERMINATA $2" >> "{self.registro}"\n'
            'fi\n')
        (self.bin / "loginctl").chmod(0o755)
        (self.bin / "hyprctl").write_text(
            "#!/bin/sh\n"
            f'echo "hyprctl $*" >> "{self.registro}"\n'
            '[ "$2" = "hl.dsp.exit()" ] && exit 0\n'
            'exit 1\n')
        (self.bin / "hyprctl").chmod(0o755)
        self.env = dict(os.environ, PATH=f"{self.bin}:" + os.environ["PATH"], USER="utente")
        self.env.pop("XDG_SESSION_ID", None)

    def tearDown(self):
        self.t.cleanup()

    def test_esce_dalla_sessione_grafica_anche_senza_la_variabile(self):
        r = subprocess.run([str(RADICE / "bin/cielos-esci")], env=self.env, capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("TERMINATA 2", self.registro.read_text())     # la wayland, non il tty

    def test_usa_la_sessione_di_systemd_quando_c_e(self):
        env = dict(self.env, XDG_SESSION_ID="1")
        r = subprocess.run([str(RADICE / "bin/cielos-esci")], env=env, capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("TERMINATA 1", self.registro.read_text())

    def test_se_loginctl_non_puo_ci_ripensa_hyprland(self):
        (self.bin / "loginctl").write_text("#!/bin/sh\nexit 1\n")
        r = subprocess.run([str(RADICE / "bin/cielos-esci")], env=self.env, capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("hl.dsp.exit()", self.registro.read_text())

    def test_le_tre_voci_esci_lo_usano(self):
        for f in ("shell/moduli/Sessione.qml", "shell-nightly/moduli/Sessione.qml", "bin/cielos-tui"):
            testo = (RADICE / f).read_text()
            self.assertIn("cielos-esci", testo, f)
            self.assertNotIn('dispatch", "exit"', testo, f)        # il dispatcher che non esiste più


if __name__ == "__main__":
    unittest.main(verbosity=2)
