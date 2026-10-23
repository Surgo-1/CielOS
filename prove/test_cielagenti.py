"""Gli agenti di codice del riquadro (Super+A → Codice): l'elenco, cosa è installato, e i comandi veri che
«Installa» eseguirebbe — senza eseguirli davvero.
python3 prove/test_cielagenti.py
"""
import importlib.machinery, importlib.util, json, shutil, subprocess, unittest
from pathlib import Path

RADICE = Path(__file__).resolve().parent.parent
_l = importlib.machinery.SourceFileLoader("cielagenti", str(RADICE / "bin/cielagenti"))
_s = importlib.util.spec_from_loader("cielagenti", _l)
ca = importlib.util.module_from_spec(_s)
_l.exec_module(ca)


class Elenco(unittest.TestCase):
    def test_i_quattro_agenti_con_tutti_i_campi(self):
        r = json.loads(subprocess.run([str(RADICE / "bin/cielagenti"), "elenco", "--json"],
                                      capture_output=True, text=True, timeout=10).stdout)
        self.assertEqual([a["id"] for a in r["agenti"]], ["freebuff", "opencode", "aider", "crush"])
        for a in r["agenti"]:
            for campo in ("nome", "comando", "icona", "spiega", "come"):
                self.assertTrue(a[campo], f"{a['id']}: manca {campo}")
            self.assertIsInstance(a["installato"], bool)
            self.assertNotIn("script", a)                     # le funzioni non finiscono nel JSON

    def test_ogni_agente_ha_il_comando_giusto(self):
        attesi = {"freebuff": "freebuff", "opencode": "opencode", "aider": "aider", "crush": "crush"}
        for a in ca.AGENTI:
            self.assertEqual(a["comando"], attesi[a["id"]])


class Installazione(unittest.TestCase):
    def test_ogni_agente_ha_i_suoi_comandi_veri(self):
        self.assertIn("npm install -g freebuff", ca.script_installa(ca.trova("freebuff")))
        opencode = ca.script_installa(ca.trova("opencode"))
        self.assertIn("pacman -S --needed --noconfirm opencode", opencode)
        self.assertIn("opencode-bin", opencode)                # se l'ondata non lo ha, dall'AUR
        self.assertIn("https://aider.chat/install.sh", ca.script_installa(ca.trova("aider")))
        self.assertIn("crush-bin", ca.script_installa(ca.trova("crush")))
        for a in ca.AGENTI:
            self.assertIn("set -e", ca.script_installa(a))     # un passo che fallisce ferma tutto

    def test_un_agente_sconosciuto_non_fa_niente(self):
        r = subprocess.run([str(RADICE / "bin/cielagenti"), "installa", "non-esiste"],
                           capture_output=True, text=True, timeout=10)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("sconosciuto", r.stderr + r.stdout)

    def test_apri_senza_il_comando_lo_dice(self):
        vero = shutil.which
        shutil.which = lambda *a, **k: None
        try:
            self.assertEqual(ca.apri("crush"), 1)
        finally:
            shutil.which = vero


class Interfaccia(unittest.TestCase):
    def test_super_a_apre_la_pagina_e_non_piu_il_codex(self):
        r = (RADICE / "shell/moduli/Riquadro.qml").read_text()
        self.assertIn('icona: "code"; nome: Lingua.t("Codice")', r)
        self.assertIn('onPremuto: q.vai("codice")', r)
        self.assertIn('source: "riquadro/Codice.qml"', r)          # la pagina c'è, caricata alla prima apertura
        self.assertNotIn('Percorsi.bin("ciel-codice")', r)

    def test_la_pagina_installa_e_apre_con_i_comandi_veri(self):
        c = (RADICE / "shell/moduli/riquadro/Codice.qml").read_text()
        self.assertIn('motore, "installa"', c)
        self.assertIn('motore, "apri"', c)
        self.assertIn('Percorsi.bin("cielagenti")', c)


if __name__ == "__main__":
    unittest.main(verbosity=1)
