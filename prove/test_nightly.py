"""Le prove della shell Nightly: i pezzi ci sono, non tocca la stabile, il pacchetto sta in una cartella sua, e (in una
sessione Wayland) la shell si avvia senza errori di QML.

python3 prove/test_nightly.py
"""
import os, shutil, subprocess, sys, tempfile, time, unittest
from pathlib import Path

RADICE = Path(__file__).resolve().parent.parent
NI = RADICE / "shell-nightly"


class Pezzi(unittest.TestCase):
    def test_ci_sono_tutti_i_file(self):
        for f in ("shell.qml", "servizi/Tema.qml", "servizi/Percorsi.qml", "servizi/Pannelli.qml",
                  "servizi/Avvia.qml", "servizi/Lingua.qml", "moduli/Barra.qml", "moduli/Lanciatore.qml",
                  "moduli/Centro.qml", "moduli/Sessione.qml", "moduli/Sfondo.qml",
                  "componenti/Hud.qml", "componenti/Icona.qml"):
            self.assertTrue((NI / f).is_file(), f)

    def test_non_sa_niente_della_home_di_chi_la_scrive(self):
        for f in NI.rglob("*.qml"):
            self.assertNotIn("/home/", f.read_text(), f)

    def test_ha_i_suoi_nomi_e_i_suoi_tasti(self):
        self.assertIn("nightly-barra", (NI / "moduli/Barra.qml").read_text())
        lancio = (NI / "moduli/Lanciatore.qml").read_text()
        self.assertIn('appid: "ciel-nightly"', lancio)          # non ruba i tasti alla stabile
        self.assertIn('target: "nightly"', lancio)

    def test_i_comandi_sono_quelli_di_cielos(self):
        tema = (NI / "servizi/Tema.qml").read_text()
        self.assertIn("cielos/tema.json", tema)               # legge le scelte, non ne scrive
        self.assertNotIn("cielos-nightly/tema.json", tema)
        centro = (NI / "moduli/Centro.qml").read_text()
        self.assertIn('Percorsi.bin("cieltema")', centro)


class Pacchetto(unittest.TestCase):
    def test_si_installa_in_una_cartella_sua(self):
        p = (RADICE / "pacchetti/cielos-nightly/PKGBUILD").read_text()
        self.assertIn('local R=/usr/share/cielos-nightly', p)
        self.assertIn('ln -s "$R" "$D/etc/xdg/quickshell/ciel-nightly"', p)
        self.assertNotIn("conflicts=", p)                      # convive con la stabile
        self.assertIn("depends=(cielos", p)                     # i comandi sono quelli di CielOS

    def test_il_servizio_non_parte_da_solo(self):
        u = (RADICE / "sistema/ciel-nightly.service").read_text()
        self.assertIn("ConditionPathExists=%h/.config/cielos-nightly/attiva", u)
        self.assertIn("MemoryTHP=disable", u)
        self.assertIn("KillMode=process", u)

    def test_il_comando_sa_trovare_la_shell(self):
        b = (RADICE / "bin/ciel-nightly").read_text()
        self.assertIn("-c ciel-nightly", b)
        self.assertIn("-p \"$QUI/../shell-nightly\"", b)


@unittest.skipUnless(shutil.which("qs") and os.environ.get("WAYLAND_DISPLAY"), "serve una sessione Wayland con qs")
class Avvio(unittest.TestCase):
    def test_la_shell_si_avvia_senza_errori(self):
        log = Path(tempfile.mkstemp(suffix=".log")[1])
        flusso = log.open("w")
        env = dict(os.environ, CIELOS_NIGHTLY_PROVA="1",
                   CIELOS_DIR=os.environ.get("CIELOS_DIR") or str(RADICE))
        p = subprocess.Popen(["qs", "-p", str(NI)], env=env, stdout=flusso,
                             stderr=subprocess.STDOUT, start_new_session=True)
        try:
            for _ in range(40):                                 # 10 s: il tempo di caricare tutto
                time.sleep(0.25)
                if p.poll() is not None:
                    break
            self.assertIsNone(p.poll(), "la Nightly è uscita da sola (vedi " + str(log) + ")")
            testo = log.read_text(errors="replace")
            for guaio in ("Failed to load configuration", "caused by", "ReferenceError", "is not a type"):
                self.assertNotIn(guaio, testo, guaio)
        finally:
            if p.poll() is None:
                p.terminate()
            try:
                p.wait(timeout=8)
            except subprocess.TimeoutExpired:
                p.kill()
            flusso.close()


if __name__ == "__main__":
    unittest.main(verbosity=2)
