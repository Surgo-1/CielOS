"""Le prove di CielFile, l'app che apre il file manager di CielOS (e solo quello).
python3 prove/test_cielfile.py   (non apre finestre: usa --dove, che dice la cartella senza aprire niente)"""
import shutil, subprocess, sys, tempfile, unittest
import xml.etree.ElementTree as ET
from pathlib import Path

RADICE = Path(__file__).resolve().parent.parent
VOCE = RADICE / "sistema" / "ciel-file.desktop"
COMANDO = RADICE / "bin" / "ciel-file"
ICONA = RADICE / "app" / "file" / "icona.svg"


def valore(testo, chiave):
    """Il valore di una chiave della voce di menu (nel gruppo [Desktop Entry])."""
    for riga in testo.splitlines():
        if riga.startswith(chiave + "="):
            return riga.split("=", 1)[1]
    return None


def dove(argomento):
    """La cartella che CielFile aprirebbe, senza aprirla."""
    return subprocess.run([str(COMANDO), "--dove", argomento], capture_output=True, text=True)


class VoceDiMenu(unittest.TestCase):
    def test_l_app_si_chiama_cielfile_e_apre_il_file_manager(self):
        """Nel lanciatore compare «CielFile», e quello che esegue è il file manager del repository: se il
        percorso fosse sbagliato la voce si vedrebbe lo stesso, ma non aprirebbe niente."""
        testo = VOCE.read_text()
        self.assertEqual(valore(testo, "Name"), "CielFile")
        self.assertEqual(valore(testo, "Name[en]"), "CielFile")
        self.assertEqual(valore(testo, "Terminal"), "false")
        self.assertIn("FileManager", valore(testo, "Categories"))
        self.assertEqual(valore(testo, "MimeType").rstrip(";"), "inode/directory")
        eseguibile = valore(testo, "Exec").split()[0]
        self.assertEqual(Path(eseguibile), COMANDO)
        self.assertTrue(COMANDO.stat().st_mode & 0o111, "ciel-file non è eseguibile")

    def test_l_icona_e_di_cielfile_e_c_e(self):
        """Icona propria, non quella generica del tema: esiste, è un SVG giusto e dichiara il suo nome."""
        percorso = valore(VOCE.read_text(), "Icon")
        self.assertTrue(percorso.startswith("/"), "l'icona deve avere un percorso assoluto")
        self.assertEqual(Path(percorso), ICONA)
        self.assertTrue(ICONA.is_file(), "l'icona indicata dalla voce non esiste")
        radice = ET.parse(ICONA).getroot()
        self.assertEqual(radice.get("viewBox"), "0 0 256 256")
        self.assertEqual(radice.find("{http://www.w3.org/2000/svg}title").text, "CielFile")

    def test_le_azioni_esistono_e_aprono_il_cestino(self):
        """Tasto destro sull'app: «Nuova finestra» e «Apri il cestino» devono funzionare davvero."""
        testo = VOCE.read_text()
        self.assertEqual(valore(testo, "Actions"), "nuova-finestra;cestino;")
        self.assertIn("[Desktop Action nuova-finestra]", testo)
        self.assertIn("[Desktop Action cestino]", testo)
        for azione in ("nuova-finestra", "cestino"):
            eseguibile = valore(testo.split(f"[Desktop Action {azione}]")[1], "Exec").split()[0]
            self.assertTrue(Path(eseguibile).is_file(), azione)
        cestino = valore(testo.split("[Desktop Action cestino]")[1], "Exec")
        self.assertIn("--cestino", cestino)

    def test_la_voce_e_valida_per_il_sistema(self):
        """desktop-file-validate è il controllo vero di chi le voci le legge (il lanciatore, il menu)."""
        if not shutil.which("desktop-file-validate"):
            self.skipTest("desktop-file-validate non installato")
        esito = subprocess.run(["desktop-file-validate", str(VOCE)], capture_output=True, text=True)
        self.assertEqual(esito.returncode, 0, esito.stdout + esito.stderr)


class Indirizzi(unittest.TestCase):
    def test_cartella_file_e_indirizzi_del_browser(self):
        """Arriva da «Apri con», dal %U del lanciatore e dal browser: la cartella è la stessa in tutti i modi."""
        with tempfile.TemporaryDirectory() as t:
            cartella = Path(t) / "una cartella"
            cartella.mkdir()
            foglio = cartella / "foglio.txt"
            foglio.write_text("x")
            atteso = str(cartella)
            for argomento in (str(cartella), str(foglio),
                              "file://" + str(cartella).replace(" ", "%20"),
                              "file://" + str(foglio).replace(" ", "%20")):
                esito = dove(argomento)
                self.assertEqual(esito.returncode, 0, argomento)
                self.assertEqual(esito.stdout.strip(), atteso, argomento)

    def test_una_cartella_che_non_c_e_non_diventa_vuota(self):
        """Se la cartella non esiste CielFile la apre lo stesso (e dirà «non c'è»): non deve ripiegare sulla home."""
        with tempfile.TemporaryDirectory() as t:
            mancante = str(Path(t) / "non c'è")
            esito = dove(mancante)
            self.assertEqual(esito.returncode, 0)
            self.assertEqual(esito.stdout.strip(), mancante)

    def test_il_cestino_e_una_scheda_a_parte(self):
        self.assertEqual(dove("--cestino").stdout.strip(), "cestino:")

    def test_senza_argomento_dice_come_si_usa(self):
        """--dove senza cartella è un errore d'uso, non una finestra aperta sulla home."""
        esito = subprocess.run([str(COMANDO), "--dove"], capture_output=True, text=True)
        self.assertEqual(esito.returncode, 2)
        self.assertIn("--dove", esito.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
