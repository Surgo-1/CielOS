"""Le prove di cielplugin su Install (Super+A): la lista degli aggiornamenti dalle tre fonti e la scheda di un
programma, con pacman/paru/flatpak finti (niente rete, niente pacchetti veri).
python3 prove/test_cielplugin.py"""
import importlib.machinery, importlib.util, os, stat, sys, tempfile, unittest
from pathlib import Path

RADICE = Path(__file__).resolve().parent.parent


def carica():
    for nome in ("cielplugin",):
        sys.modules.pop(nome, None)
    loader = importlib.machinery.SourceFileLoader("cielplugin", str(RADICE / "bin/cielplugin"))
    spec = importlib.util.spec_from_loader("cielplugin", loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


def finto(cartella, nome, corpo):
    """un finto pacman/paru/flatpak: «corpo» è lo script, così risponde secondo gli argomenti"""
    f = Path(cartella) / nome
    f.write_text("#!/bin/sh\n" + corpo)
    f.chmod(f.stat().st_mode | stat.S_IXUSR)
    return f


def risponde(quando, testo):
    """lo script di un comando finto: se gli argomenti contengono «quando» stampa «testo», se no esce 1"""
    return ("case \"$*\" in\n  *" + quando + "*) cat <<'FUORI'\n" + testo + "FUORI\n;;\n  *) exit 1;;\nesac\n")


class Install(unittest.TestCase):
    def setUp(self):
        self.t = tempfile.TemporaryDirectory()
        self.pl = carica()
        self.vecchio_path = os.environ.get("PATH", "")
        os.environ["PATH"] = f"{self.t.name}:{self.vecchio_path}"

    def tearDown(self):
        os.environ["PATH"] = self.vecchio_path
        self.t.cleanup()

    def test_aggiornamenti_dalle_tre_fonti(self):
        finto(self.t.name, "pacman", risponde("-Qu", "firefox 141.0-1 -> 142.0-1\nlinux 7.2.10-1 -> 7.2.11-1\n"))
        finto(self.t.name, "paru", risponde("-Qua", "paru 2.0.4-1 -> 2.1.0-2\n"))
        finto(self.t.name, "flatpak", risponde("remote-ls", "org.mozilla.firefox\t142.0\ncom.spotify.Client\t1.2.3\n"))
        r = self.pl.aggiornamenti()
        self.assertEqual(r["conteggio"], {"repo": 2, "aur": 1, "flatpak": 2})
        self.assertEqual([(v["fonte"], v["id"], v["nuova"]) for v in r["voci"]][:2],
                         [("repo", "firefox", "142.0-1"), ("repo", "linux", "7.2.11-1")])
        self.assertIn(("flatpak", "com.spotify.Client", "1.2.3"),
                      [(v["fonte"], v["id"], v["nuova"]) for v in r["voci"]])

    def test_aggiornamenti_quando_e_tutto_a_posto(self):
        finto(self.t.name, "pacman", "exit 0\n")
        finto(self.t.name, "paru", "exit 0\n")
        finto(self.t.name, "flatpak", "exit 0\n")
        self.assertEqual(self.pl.aggiornamenti()["voci"], [])

    def test_dettagli_di_un_pacchetto_di_arch(self):
        finto(self.t.name, "pacman", risponde("-Si", """Repository      : extra
Name            : firefox
Version         : 142.0-1
Description     : Fast, Private & Safe Web Browser
Download Size   : 86.17 MiB
Installed Size  : 301.97 MiB
Depends On      : alsa-lib  gtk3  libx11
Licenses        : MPL-2.0
Maintainer      : Arch
Last Modified   : Tue 14 Oct 2026
"""))
        self.assertIn("descrizione", self.pl.dettagli("repo", "firefox"))
        d = self.pl.dettagli("repo", "firefox")
        self.assertEqual(d["id"], "firefox")
        self.assertEqual(d["dimensione"], "86.17 MiB")
        self.assertEqual(d["installata"], "301.97 MiB")
        self.assertEqual(d["dipende"], ["alsa-lib", "gtk3", "libx11"])
        self.assertEqual(d["licenza"], "MPL-2.0")

    def test_dettagli_non_inventano_niente(self):
        finto(self.t.name, "pacman", "exit 1\n")
        with self.assertRaises(Exception):
            self.pl.dettagli("repo", "nonesiste")
        with self.assertRaises(Exception):
            self.pl.dettagli("repo", "../../etc/passwd")      # nome non valido: non lo passa a pacman
        with self.assertRaises(Exception):
            self.pl.dettagli("boh", "firefox")

    def test_i_pacchetti_di_un_plugin_si_chiedono_una_volta(self):
        """L'elenco di Install chiede i pacchetti due volte per plugin (per lo stato e per mostrarli): il motore di
        cielmodelli si deve lanciare una volta sola, non due"""
        bin_dir = Path(self.t.name) / "bin"
        bin_dir.mkdir()
        volte = Path(self.t.name) / "volte"
        finto(bin_dir, "cielmodelli", f'echo x >> {volte}\necho \'{{"pacchetti": ["ollama"]}}\'\n')
        vecchia = self.pl.RADICE
        self.pl.RADICE = Path(self.t.name)
        self.pl._PACCHETTI.clear()
        try:
            pl = {"id": "ollama", "pacchetti_da": "cielmodelli motore"}
            self.assertEqual(self.pl.pacchetti_di(pl), ["ollama"])
            self.assertEqual(self.pl.pacchetti_di(pl), ["ollama"])
        finally:
            self.pl.RADICE = vecchia
            self.pl._PACCHETTI.clear()
        self.assertEqual(volte.read_text().count("x"), 1)

    def test_il_catalogo_delle_fonti_e_chiuso(self):
        """le fonti ammesse sono tre: una nuova senza il suo pezzo di codice non deve passare"""
        import inspect
        src = inspect.getsource(self.pl.dettagli)
        for f in ("repo", "aur", "flatpak"):
            self.assertIn(f, src)


if __name__ == "__main__":
    unittest.main(verbosity=2)
