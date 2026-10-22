"""La scansione di cielos-hardware: una sola lettura dei repository e dei pacchetti installati, non una per
pacchetto (la pagina Hardware aspettava secondi), con pacman e lsusb finti.
python3 prove/test_hardware.py"""
import importlib.machinery, importlib.util, os, subprocess, tempfile, unittest
from pathlib import Path

BIN = Path(__file__).resolve().parent.parent / "bin"


def carica():
    """il comando come modulo (bin/cielos-hardware non è importabile per via del trattino)"""
    l = importlib.machinery.SourceFileLoader("cielos_hardware", str(BIN / "cielos-hardware"))
    s = importlib.util.spec_from_loader("cielos_hardware", l)
    m = importlib.util.module_from_spec(s)
    l.exec_module(m)
    return m


REPO = ("mesa", "vulkan-intel", "intel-ucode", "lib32-mesa", "linux")
INSTALLATI = ("mesa", "linux")

PACMAN = """#!/bin/sh
echo "$@" >> "$FAKE_LOG"
case "$1" in
  -Slq) [ -n "$FAKE_VUOTO" ] || echo @REPO@ ;;
  -Qq)  echo @INSTALLATI@ ;;
  -Si)  shift; for p in @REPO@; do [ "$p" = "$1" ] && exit 0; done; exit 1 ;;
  -Q)   shift; for p in @INSTALLATI@; do [ "$p" = "$1" ] && exit 0; done; exit 1 ;;
esac
exit 0
""".replace("@REPO@", " ".join(REPO)).replace("@INSTALLATI@", " ".join(INSTALLATI))

LSUSB = """#!/bin/sh
echo "lsusb" >> "$FAKE_LOG"
echo 'Bus 001 Device 002: ID 045e:02ea Microsoft Xbox Controller'
echo 'Bus 001 Device 003: ID 8087:0029 Intel Corp. AX201 Bluetooth'
"""


class Scansione(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls._tmp = tempfile.TemporaryDirectory()
        cls.dir = Path(cls._tmp.name)
        cls.log = cls.dir / "chiamate"
        for nome, testo in (("pacman", PACMAN), ("lsusb", LSUSB)):
            f = cls.dir / nome
            f.write_text(testo)
            f.chmod(0o755)
        cls.vecchio_path = os.environ["PATH"]
        os.environ["PATH"] = f"{cls.dir}:{cls.vecchio_path}"
        os.environ["FAKE_LOG"] = str(cls.log)
        cls.ch = carica()
        # come su un PC con i repository già scaricati
        cls.ch.SINCRONIZZATO = True
        cls.ch.MULTILIB = True
        cls.ch.MULTILIB_SCARICATO = True

    @classmethod
    def tearDownClass(cls):
        os.environ["PATH"] = cls.vecchio_path
        os.environ.pop("FAKE_LOG", None)
        os.environ.pop("FAKE_VUOTO", None)
        cls._tmp.cleanup()

    def setUp(self):
        self.log.unlink(missing_ok=True)
        os.environ.pop("FAKE_VUOTO", None)
        self.ch._ELENCO = None
        self.ch._INSTALLATI = None
        self.ch._USB = None

    def chiamate(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def test_repository_letti_una_volta(self):
        """20 pacchetti proposti = una chiamata, non 20"""
        for p in ("mesa", "vulkan-intel", "intel-ucode", "lib32-mesa"):
            self.assertTrue(self.ch.esiste(p), p)
        self.assertFalse(self.ch.esiste("non-esiste"))
        self.assertEqual([c for c in self.chiamate() if c.startswith("-Slq")], ["-Slq"])

    def test_installati_letti_una_volta(self):
        self.assertTrue(self.ch.installato("mesa"))
        self.assertFalse(self.ch.installato("vulkan-intel"))
        self.assertEqual(self.ch.kernel(), ["linux"])
        self.assertEqual([c for c in self.chiamate() if c.startswith("-Qq")], ["-Qq"])

    def test_senza_elenco_si_chiede_a_pacman(self):
        """se l'elenco dei repository non si riesce a leggere, si torna a domandare pacchetto per pacchetto"""
        os.environ["FAKE_VUOTO"] = "1"
        self.assertTrue(self.ch.esiste("mesa"))
        self.assertFalse(self.ch.esiste("non-esiste"))
        self.assertEqual([c for c in self.chiamate() if c.startswith("-Si")], ["-Si mesa", "-Si non-esiste"])

    def test_libusb_letto_una_volta(self):
        self.assertEqual(len(self.ch.usb()), 2)
        self.ch.usb()
        self.assertEqual([c for c in self.chiamate() if c == "lsusb"], ["lsusb"])

    def test_guida_non_scansiona(self):
        """«--aiuto» non deve mettersi a leggere l'hardware (lo diceva già la promessa del 15/10)"""
        r = subprocess.run([str(BIN / "cielos-hardware"), "--aiuto"], capture_output=True, text=True, timeout=20)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("cielos-hardware", r.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
