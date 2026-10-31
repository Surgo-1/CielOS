"""Le prove del bluetooth di CielOS: la lettura di quello che dice BlueZ (bluetoothctl) e i pezzi che lo mostrano —
la schedina della barra, la pagina delle Impostazioni, il centro di controllo della Nightly, la voce del menu nel
terminale. La radio non si tocca: la shell vera si guarda con CIELOS_PROVA=1 qs -p shell (qui sotto, se c'è Wayland).

python3 prove/test_bluetooth.py
"""
import importlib.machinery, importlib.util, os, shutil, subprocess, tempfile, time, unittest
from pathlib import Path

RADICE = Path(__file__).resolve().parent.parent
BARRA = RADICE / "shell/moduli/Barra.qml"
BARRA_BT = RADICE / "shell/moduli/barra/Bluetooth.qml"
IMPOSTAZIONI = RADICE / "shell/moduli/Impostazioni.qml"
PAGINA = RADICE / "shell/moduli/impostazioni/PaginaBluetooth.qml"
TEMA = RADICE / "shell/servizi/Tema.qml"
CIELTEMA = RADICE / "bin/cieltema"
TUI = RADICE / "bin/cielos-tui"
NI_BARRA = RADICE / "shell-nightly/moduli/Barra.qml"
NI_CENTRO = RADICE / "shell-nightly/moduli/Centro.qml"

SHOW = """Controller CC:D9:AC:51:62:55 (public)
\tName: Luca-PC
\tAlias: Luca-PC
\tPowered: yes
\tDiscovering: no
"""

INFO = """Device A0:FA:9C:76:19:60 (public)
\tName: DualSense Wireless Controller
\tAlias: DualSense Wireless Controller
\tIcon: input-gaming
\tPaired: yes
\tBonded: yes
\tTrusted: no
\tConnected: yes
\tBattery Percentage: 0x64 (100)
"""

INFO_SENZA_BATTERIA = """Device 40:58:99:34:DD:25 (public)
\tName: G435 SE Bluetooth Gaming Headset
\tIcon: audio-headset
\tPaired: yes
\tConnected: no
"""


def carica():
    loader = importlib.machinery.SourceFileLoader("cielbluetooth", str(RADICE / "bin/cielbluetooth"))
    spec = importlib.util.spec_from_loader("cielbluetooth", loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


class BlueZ(unittest.TestCase):
    """Come si legge quello che risponde bluetoothctl (senza bluetoothctl: le risposte sono scritte qui)."""

    @classmethod
    def setUpClass(cls):
        cls.b = carica()

    def test_legge_lo_stato_dell_adattatore(self):
        self.assertTrue(self.b.si(SHOW, "Powered"))
        self.assertFalse(self.b.si(SHOW, "Discovering"))       # «no» non è un sì
        self.assertEqual(self.b.campo(SHOW, "Alias"), "Luca-PC")
        self.assertEqual(self.b.campo(SHOW, "NonEsiste"), "")
        self.assertEqual(self.b.indirizzi_adattatori(SHOW), ["CC:D9:AC:51:62:55"])

    def test_senza_adattatori_non_c_e_il_bluetooth(self):
        self.assertEqual(self.b.indirizzi_adattatori("No default controller available\n"), [])

    def test_legge_i_dispositivi_e_i_nomi_con_gli_spazi(self):
        elenco = self.b.indirizzi_da_testo("Device A0:FA:9C:76:19:60 DualSense Wireless Controller\n"
                                           "Device 38:68:A4:5E:DC:9A\n"
                                           "qualche riga di disturbo\n")
        self.assertEqual(elenco, [("A0:FA:9C:76:19:60", "DualSense Wireless Controller"),
                                  ("38:68:A4:5E:DC:9A", "")])

    def test_il_dispositivo_dai_dati_di_bluez(self):
        d = self.b.dispositivo("a0:fa:9c:76:19:60", INFO)
        self.assertEqual(d["nome"], "DualSense Wireless Controller")
        self.assertEqual(d["indirizzo"], "A0:FA:9C:76:19:60")   # sempre maiuscolo
        self.assertTrue(d["collegato"])
        self.assertTrue(d["accoppiato"])
        self.assertEqual(d["batteria"], 100)
        self.assertEqual(d["icona"], "input-gaming")

    def test_la_batteria_c_e_solo_se_il_dispositivo_la_dice(self):
        self.assertIsNone(self.b.dispositivo("40:58:99:34:DD:25", INFO_SENZA_BATTERIA)["batteria"])
        self.assertFalse(self.b.dispositivo("40:58:99:34:DD:25", INFO_SENZA_BATTERIA)["collegato"])

    def test_gli_indirizzi_scritti_a_mano(self):
        self.assertEqual(self.b.buono("40-ed-00-8c-44-3b"), "40:ED:00:8C:44:3B")
        self.assertEqual(self.b.buono(" 40:ED:00:8C:44:3B "), "40:ED:00:8C:44:3B")
        for storto in ("", "pippo", "40:ED:00:8C:44", "40:ED:00:8C:44:3B:11"):
            self.assertEqual(self.b.buono(storto), "", storto)


class Barra(unittest.TestCase):
    def test_il_bluetooth_si_vede_e_si_spegne(self):
        barra = BARRA.read_text()
        self.assertIn("Bluetooth { id: bt; visible: Tema.mostraBluetooth && bt.presente }", barra)
        self.assertIn('readonly property bool mostraBluetooth: v("barra_mostra_bluetooth", true)', TEMA.read_text())

    def test_lo_stato_arriva_da_bluez_non_da_un_sondaggio(self):
        """Un processo ogni pochi secondi per un'icona non si paga (MAPPA.md): lo stato è quello che BlueZ dice
        sulla sua presa D-Bus, e la schedina si aggiorna da sola quando qualcosa cambia."""
        b = BARRA_BT.read_text()
        self.assertIn("import Quickshell.Bluetooth as Bt", b)
        self.assertIn("Bt.Bluetooth.defaultAdapter", b)
        self.assertNotIn("Process {", b)
        self.assertNotIn("nmcli", b)
        self.assertIn("bluetooth_connected", b)
        self.assertIn("bluetooth_disabled", b)
        self.assertIn("Schedina", b)

    def test_cieltema_conosce_la_chiave_della_barra(self):
        c = CIELTEMA.read_text()
        self.assertIn('"barra_mostra_bluetooth"', c)
        self.assertIn('"barra_mostra_bluetooth": v("barra_mostra_bluetooth")', c)


class Impostazioni(unittest.TestCase):
    def test_c_e_la_sezione_bluetooth(self):
        i = IMPOSTAZIONI.read_text()
        self.assertIn('{ nome: "Bluetooth", icona: "bluetooth", chiavi: [], pagina: "PaginaBluetooth" }', i)
        self.assertIn('"barra_mostra_bluetooth"', i)              # e si spegne dalla sezione Barra

    def test_la_pagina_accede_spegne_e_collega(self):
        p = PAGINA.read_text()
        self.assertIn("Interruttore", p)
        self.assertIn("adattatore.enabled = v", p)
        self.assertIn("modelData.connect()", p)
        self.assertIn("modelData.disconnect()", p)
        self.assertIn("modelData.pair()", p)
        self.assertIn("modelData.forget()", p)
        self.assertIn("discovering = true", p)                    # la ricerca
        self.assertIn("p.presente", p)                            # e se il PC non ce l'ha, lo dice

    def test_la_voce_c_e_anche_nel_menu_del_terminale(self):
        """In Bare-Bones (e nella Nightly) le impostazioni sono cielos-tui: il bluetooth deve stare anche lì."""
        t = TUI.read_text()
        self.assertIn('BIN / "cielbluetooth"', t)
        self.assertIn('Voce(tr("Bluetooth"), self._bluetooth,', t)


class Nightly(unittest.TestCase):
    def test_la_barra_ha_l_icona_del_bluetooth(self):
        b = NI_BARRA.read_text()
        self.assertIn("import Quickshell.Bluetooth as Bt", b)
        self.assertIn("Bt.Bluetooth.defaultAdapter", b)
        self.assertIn("visible: finestra.btPresente", b)
        self.assertIn("bluetooth_connected", b)
        self.assertIn("btCollegati", b)                           # il disegno dice anche se qualcosa è collegato

    def test_il_centro_di_controllo_accende_e_spegne(self):
        c = NI_CENTRO.read_text()
        self.assertIn('{ nome: Lingua.t("Bluetooth"), acceso: c.bt, fai: () => c.cambiaBt() }', c)
        self.assertIn("function cambiaBt()", c)
        self.assertIn("c.adattatore.enabled = !c.adattatore.enabled", c)
        # gli interruttori si dividono la riga: col bluetooth sono tre, senza sono due
        self.assertIn("(c.interruttori.length - 1)) / c.interruttori.length", c)
        self.assertNotIn("(parent.width - 10) / 2", c)


@unittest.skipUnless(shutil.which("qs") and os.environ.get("WAYLAND_DISPLAY"), "serve una sessione Wayland con qs")
class Avvio(unittest.TestCase):
    def test_la_shell_sta_in_piedi_con_i_pezzi_nuovi(self):
        """La shell vera: se il QML nuovo ha un errore, si vede qui (e non la prima volta che apri la schedina)."""
        log = Path(tempfile.mkstemp(suffix=".log")[1])
        flusso = log.open("w")
        env = dict(os.environ, CIELOS_PROVA="1",
                   CIELOS_DIR=os.environ.get("CIELOS_DIR") or str(RADICE))
        p = subprocess.Popen(["qs", "-p", str(RADICE / "shell")], env=env, stdout=flusso,
                             stderr=subprocess.STDOUT, start_new_session=True)
        try:
            for _ in range(40):                                   # 10 s: il tempo di caricare tutto
                time.sleep(0.25)
                if p.poll() is not None:
                    break
            self.assertIsNone(p.poll(), "la shell è uscita da sola (vedi " + str(log) + ")")
            testo = log.read_text(errors="replace")
            for guaio in ("Failed to load configuration", "caused by", "ReferenceError", "is not a type",
                          "WARN scene"):
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
