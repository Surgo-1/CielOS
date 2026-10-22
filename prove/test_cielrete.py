"""Le prove di cielrete: la lettura dell'uscita di nmcli e il DNS scelto, senza toccare la rete.
python3 prove/test_cielrete.py"""
import importlib.machinery, importlib.util, unittest
from pathlib import Path

RADICE = Path(__file__).resolve().parent.parent


def carica():
    loader = importlib.machinery.SourceFileLoader("cielrete", str(RADICE / "bin/cielrete"))
    spec = importlib.util.spec_from_loader("cielrete", loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


class Rete(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.r = carica()

    def test_i_due_punti_nei_nomi(self):
        self.assertEqual(self.r.separa(r"Connessione:802-11-wireless:con\:due"), ["Connessione", "802-11-wireless", "con:due"])

    def test_reti_vicine_senza_doppioni(self):
        testo = """
IN-USE:
SSID:                                   Casa
SIGNAL:                                 40
SECURITY:                               WPA2
IN-USE:                                 *
SSID:                                   Casa
SIGNAL:                                 80
SECURITY:                               WPA2
IN-USE:
SSID:                                   Bar
SIGNAL:                                 20
SECURITY:
""".lstrip()
        reti = self.r.reti_da_testo(testo)
        self.assertEqual([x["ssid"] for x in reti], ["Casa", "Bar"])
        self.assertEqual(reti[0]["segnale"], 80)                  # vale il segnale migliore
        self.assertTrue(reti[0]["collegata"])
        self.assertEqual(reti[1]["sicurezza"], "")                 # rete aperta
        self.assertFalse(reti[1]["collegata"])

    def test_il_dns_si_riconosce_dal_segno_o_dal_vecchio_commento(self):
        self.assertEqual(self.r.dns_da_testo("fornitore=cloudflare\nservers=1.1.1.1\n"), "cloudflare")
        self.assertEqual(self.r.dns_da_testo("# fornitore=quad9\n[global-dns]\n"), "quad9")
        self.assertEqual(self.r.dns_da_testo("# DNS di tutto il PC scelto in CielOS (cielstrumenti dns cloudflare)\n"),
                         "cloudflare")
        self.assertEqual(self.r.dns_da_testo("[global-dns]\n"), "automatico")

    def test_i_server_si_leggono_da_resolvectl(self):
        testo = """
Global:
Link 3 (wlan0): 1.1.1.1 2606:4700:4700::1111 fe80::1%3
Link 2 (enp2s0): 1.1.1.1 1.0.0.1 fe80::1%2
""".lstrip()
        self.assertEqual(self.r.dns_da_resolvectl(testo),
                         ["1.1.1.1", "2606:4700:4700::1111", "fe80::1", "1.0.0.1"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
