"""La condivisione dello schermo di Discord e Vesktop: le voci del menu e le opzioni che le fanno partire su
Wayland con PipeWire (senza, la condivisione esce nera).
python3 prove/test_condivisione.py"""
import shutil, subprocess, unittest
from pathlib import Path

RADICE = Path(__file__).resolve().parent.parent
APP = RADICE / "sistema/applicazioni"
PKGBUILD = (RADICE / "pacchetti/cielos/PKGBUILD").read_text()
INSTALL = (RADICE / "pacchetti/cielos/cielos.install").read_text()
UTENTE = (RADICE / "bin/cielos-utente").read_text()

OPZIONI = ("--ozone-platform-hint=auto", "--enable-features=WebRTCPipeWireCapturer",
           "--disable-accelerated-video-decode")


def voce(nome):
    """le righe «chiave=valore» di una voce .desktop (la prima sezione [Desktop Entry])"""
    d, dentro = {}, False
    for riga in (APP / nome).read_text().splitlines():
        if riga.startswith("["):
            if dentro:
                break
            dentro = riga == "[Desktop Entry]"
            continue
        if dentro and "=" in riga and not riga.startswith("#"):
            k, v = riga.split("=", 1)
            d[k] = v
    return d


class VociDelMenu(unittest.TestCase):
    def test_discord_e_vesktop_partono_su_wayland_con_pipewire(self):
        for nome, exe in (("discord.desktop", "/usr/bin/discord"), ("vesktop.desktop", "/usr/bin/vesktop")):
            d = voce(nome)
            self.assertEqual(d["Type"], "Application")
            self.assertEqual(d["TryExec"], exe, "la voce deve sparire se il programma non c'è")
            self.assertTrue(d["Exec"].startswith(exe + " "), d["Exec"])
            for o in OPZIONI:
                self.assertIn(o, d["Exec"].split(), f"{nome}: manca {o}")
            self.assertIn("x-scheme-handler/discord", d["MimeType"])
            # il nome del file è lo stesso del pacchetto: /usr/local/share vince su /usr/share, niente doppioni
            self.assertNotIn("NoDisplay", d)

    def test_le_voci_sono_valide_per_il_menu(self):
        if not shutil.which("desktop-file-validate"):
            self.skipTest("serve desktop-file-validate (desktop-file-utils)")
        r = subprocess.run(["desktop-file-validate", str(APP / "discord.desktop"), str(APP / "vesktop.desktop")],
                           capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_il_pacchetto_le_mette_dove_vincono_senza_conflitti(self):
        for nome in ("discord.desktop", "vesktop.desktop"):
            self.assertIn(f'"$D$R/sistema/applicazioni/{nome}" "$D/usr/local/share/applications/{nome}"', PKGBUILD)
        # nelle voci di CielOS (sistema/*.desktop) non ci finiscono: lì il pacchetto discord avrebbe un conflitto
        self.assertNotIn('install -Dm644 "$D$R/sistema/applicazioni/', PKGBUILD.split("# Discord e Vesktop")[0])
        self.assertIn("update-desktop-database -q /usr/local/share/applications", INSTALL)


class LancioDalTerminale(unittest.TestCase):
    def test_cielos_utente_aggiunge_le_opzioni_a_vesktop_senza_cancellare_le_tue(self):
        self.assertIn("/vesktop-flags.conf", UTENTE)
        self.assertIn("# CielOS: condivisione dello schermo", UTENTE)
        for o in OPZIONI:
            self.assertIn(o, UTENTE)
        # niente «>» sul file: le righe dell'utente restano, si aggiunge solo il blocco di CielOS
        self.assertIn('>> "$V" 2>/dev/null', UTENTE)
        self.assertNotIn(' > "$V"', UTENTE)


class LaGuida(unittest.TestCase):
    def test_la_guida_dice_che_ora_parte_su_wayland(self):
        errori = (RADICE / "wiki/errori.json").read_text()
        wiki = (RADICE / "wiki/12-errori.md").read_text()
        giochi = (RADICE / "wiki/09-giochi.md").read_text()
        for testo in (errori, wiki, giochi):
            self.assertIn("Wayland", testo)
            self.assertIn("Discord", testo)
        self.assertIn("PipeWire", errori)
        self.assertIn("PipeWire", wiki)


if __name__ == "__main__":
    unittest.main(verbosity=2)
