"""Le prove di CielGiochi: i giochi dalle librerie di Steam, ProtonDB, l'anti-cheat su Linux e il confronto con questo PC.
python3 prove/test_cielgiochi.py   (niente rete: le risposte di ProtonDB, Steam e Are We Anti-Cheat Yet? sono finte,
e la cache è in una cartella temporanea; l'unica cosa vera è questo PC, che serve al confronto)"""
import importlib.util, json, os, shutil, subprocess, sys, tempfile, unittest
import xml.etree.ElementTree as ET
from pathlib import Path
from unittest import mock

RADICE = Path(__file__).resolve().parent.parent
VOCE = RADICE / "sistema" / "ciel-giochi.desktop"
ICONA = RADICE / "app" / "giochi" / "icona.svg"


def carica():
    from importlib.machinery import SourceFileLoader
    caricatore = SourceFileLoader("cielgiochi", str(RADICE / "bin" / "cielgiochi"))
    modulo = importlib.util.module_from_spec(importlib.util.spec_from_loader("cielgiochi", caricatore))
    caricatore.exec_module(modulo)
    return modulo


cg = carica()

MINIMI = ("<strong>Minimi:</strong><br><ul><li><strong>Sistema operativo:</strong> Windows 7 o successivo<br>"
          "<li><strong>Processore:</strong> Intel dual core 2,8 GHz<br><li><strong>Memoria:</strong> 4 GB di RAM<br>"
          "<li><strong>Grafica:</strong> NVIDIA GeForce 8600 512 MB<br><li><strong>DirectX:</strong> Versione 11<br>"
          "<li><strong>Memoria disco:</strong> 60 GB disponibili</ul>")
CONSIGLIATI = ("<strong>Consigliati:</strong><br><ul><li><strong>Memoria:</strong> 8 GB di RAM<br>"
               "<li><strong>Grafica:</strong> NVIDIA GeForce GTX 1060 6GB<br>"
               "<li><strong>Memoria disco:</strong> 60 GB disponibili</ul>")
# la tabella di Are We Anti-Cheat Yet? com'è davvero: gli AppID di Steam stanno in storeIds
TABELLA = [
    {"name": "Halo: The Master Chief Collection", "slug": "halo-the-master-chief-collection", "status": "Supported",
     "anticheats": ["Easy Anti-Cheat"], "native": False, "storeIds": {"steam": "976730"},
     "notes": [["All-modes enabled with minor caveats", ""]]},
    {"name": "Destiny 2", "slug": "destiny-2", "status": "Broken", "anticheats": ["BattlEye"], "native": False,
     "storeIds": {"steam": "1085660"}, "notes": []},
    {"name": "Factorio", "slug": "factorio", "status": "Denied", "anticheats": ["Finto"], "native": True,
     "storeIds": {"steam": "999"}, "notes": []},
]


class Requisiti(unittest.TestCase):
    def test_i_requisiti_di_steam_diventano_campi_con_un_nome(self):
        """Steam manda i requisiti come HTML; qui devono diventare campi leggibili (RAM, scheda video, disco),
        altrimenti la finestra mostrerebbe un muro di tag."""
        c = cg.campi_requisiti(MINIMI)
        self.assertEqual(c["os"], "Windows 7 o successivo")
        self.assertEqual(c["cpu"], "Intel dual core 2,8 GHz")
        self.assertEqual(c["ram"], "4 GB di RAM")
        self.assertIn("GeForce 8600", c["gpu"])
        self.assertEqual(c["directx"], "Versione 11")
        self.assertEqual(c["disco"], "60 GB disponibili")

    def test_i_numeri_si_leggono_dove_sono(self):
        self.assertEqual(cg._giga("4 GB di RAM"), 4.0)
        self.assertEqual(cg._giga("512 MB"), 0.5)
        self.assertEqual(cg._giga("senza numeri"), None)
        self.assertEqual(cg._vram("NVIDIA GeForce GTX 1060 6GB"), 6.0)
        self.assertEqual(cg._vram("2 GB VRAM"), 2.0)
        self.assertEqual(cg._vram("scheda video qualsiasi"), None)

    def test_il_confronto_dice_no_solo_sui_numeri(self):
        """Con poca RAM il verdetto è «no», non «da confrontare»: i numeri veri non si addolciscono. Con i numeri
        a posto resta «quasi», perché CPU e scheda video non si possono confrontare onestamente per nome."""
        minimi = cg.campi_requisiti(MINIMI)
        hw = {"cpu": "Intel i5", "ram": 16.0, "gpu": "GTX 1650", "vram": 4.0, "disco": 200.0}
        c = cg.confronta(minimi, cg.campi_requisiti(CONSIGLIATI), hw)
        self.assertEqual(c["esito"], "quasi")
        ram = next(x for x in c["controlli"] if x["cosa"] == "RAM")
        self.assertEqual((ram["serve"], ram["hai"], ram["stato"]), (4.0, 16.0, "ok"))
        self.assertTrue(all(x["stato"] != "no" for x in c["controlli"]))
        c = cg.confronta(minimi, {}, dict(hw, ram=2.0))
        self.assertEqual(c["esito"], "no")
        self.assertEqual(next(x for x in c["controlli"] if x["cosa"] == "RAM")["stato"], "no")

    def test_una_scheda_integrata_non_inventa_la_vram(self):
        """Se la VRAM non si sa (integrata), lo stato è «?» e non un «sì» di comodo."""
        minimi = {"ram": "8 GB", "gpu": "GTX 1060 6GB"}
        c = cg.confronta(minimi, {}, {"cpu": "x", "ram": 16.0, "gpu": "Intel UHD", "vram": None, "disco": 100.0})
        vram = next(x for x in c["controlli"] if x["cosa"] == "VRAM")
        self.assertEqual((vram["serve"], vram["hai"], vram["stato"]), (6.0, None, "?"))
        self.assertEqual(c["esito"], "quasi")

    def test_steam_risponde_e_i_requisiti_arrivano_alla_finestra(self):
        risposta = {"570": {"success": True, "data": {"name": "Dota 2", "pc_requirements": {"minimum": MINIMI, "recommended": CONSIGLIATI},
                                                     "genres": [{"description": "Azione"}]}}}
        def finto_json(url, tempo=8):
            return risposta if "appdetails" in url else TABELLA
        with tempfile.TemporaryDirectory() as t:
            with mock.patch.object(cg, "CACHE", Path(t)), mock.patch.object(cg, "_json", side_effect=finto_json) as finto:
                r = cg.requisiti("570")
                self.assertEqual(r["nome"], "Dota 2")
                self.assertEqual(r["minimi"]["ram"], "4 GB di RAM")
                self.assertEqual(r["confronto"]["controlli"][0]["cosa"], "RAM")
                self.assertIn("anticheat", r)
                cg.requisiti("570")
                self.assertEqual(finto.call_count, 2, "la seconda volta: solo la tabella (i requisiti sono in cache)")


class ProtonDB(unittest.TestCase):
    def test_il_giudizio_arriva_e_resta_in_cache(self):
        risposta = {"tier": "platinum", "bestReportedTier": "platinum", "trendingTier": "gold",
                    "score": 0.85, "confidence": "strong", "total": 33}
        with tempfile.TemporaryDirectory() as t:
            with mock.patch.object(cg, "CACHE", Path(t)), mock.patch.object(cg, "_json", return_value=risposta) as finto:
                p = cg.proton("2135150")
                self.assertEqual((p["tier"], p["giudizio"], p["prove"]), ("platinum", "platino", 33))
                self.assertEqual(p["pagina"], "https://www.protondb.com/app/2135150")
                cg.proton("2135150")
                self.assertEqual(finto.call_count, 1)

    def test_se_protondb_non_risponde_lo_dice(self):
        with tempfile.TemporaryDirectory() as t:
            with mock.patch.object(cg, "CACHE", Path(t)), mock.patch.object(cg, "_json", side_effect=OSError("rete giù")):
                p = cg.proton("570")
                self.assertIsNone(p["tier"])
                self.assertIn("rete giù", p["errore"])


class AntiCheat(unittest.TestCase):
    def test_il_gioco_si_trova_per_appid_di_steam(self):
        """La tabella porta gli AppID di Steam: così «Halo» è il gioco che hai, non l'omonimo di un altro store."""
        with tempfile.TemporaryDirectory() as t:
            with mock.patch.object(cg, "CACHE", Path(t)), mock.patch.object(cg, "_json", return_value=TABELLA):
                a = cg.anticheat(appid="976730", nome="nome sbagliato")
        self.assertTrue(a["trovato"])
        self.assertEqual((a["stato"], a["tono"]), ("funziona", "ok"))
        self.assertEqual(a["anticheat"], ["Easy Anti-Cheat"])
        self.assertEqual(a["pagina"], "https://areweanticheatyet.com/game/halo-the-master-chief-collection")

    def test_uno_stato_rotto_diventa_un_no(self):
        """«Broken» non è «da confrontare»: su Linux il gioco non parte, e la finestra lo deve dire con il rosso."""
        with tempfile.TemporaryDirectory() as t:
            with mock.patch.object(cg, "CACHE", Path(t)), mock.patch.object(cg, "_json", return_value=TABELLA):
                a = cg.anticheat(nome="Destiny 2")
        self.assertEqual((a["stato"], a["tono"]), ("non funziona (ancora)", "no"))

    def test_la_tabella_si_chiede_una_volta_sola(self):
        with tempfile.TemporaryDirectory() as t:
            with mock.patch.object(cg, "CACHE", Path(t)), mock.patch.object(cg, "_json", return_value=TABELLA) as finto:
                cg.anticheat(appid="976730")
                cg.anticheat(appid="1085660")
                self.assertEqual(finto.call_count, 1)

    def test_un_gioco_senza_anti_cheat_non_inventa_un_giudizio(self):
        """Chi non è nella tabella (tanti giochi single player) non ha un anti-cheat: lo si dice, senza spaventare."""
        with tempfile.TemporaryDirectory() as t:
            with mock.patch.object(cg, "CACHE", Path(t)), mock.patch.object(cg, "_json", return_value=TABELLA):
                a = cg.anticheat(appid="1", nome="Gioco Inventato")
        self.assertFalse(a["trovato"])
        self.assertEqual(a["pagina"], "https://areweanticheatyet.com")

    def test_se_il_sito_non_risponde_il_gioco_si_apre_lo_stesso(self):
        with tempfile.TemporaryDirectory() as t:
            with mock.patch.object(cg, "CACHE", Path(t)), mock.patch.object(cg, "_json", side_effect=OSError("rete giù")):
                a = cg.anticheat(appid="976730")
        self.assertFalse(a["trovato"])
        self.assertIn("rete giù", a["errore"])


class Librerie(unittest.TestCase):
    def _steam(self, radice):
        """Un Steam finto: due librerie, due giochi veri e i pezzi che non sono giochi."""
        prima = radice / "steam"; (prima / "steamapps").mkdir(parents=True)
        (prima / "steamapps" / "appmanifest_570.acf").write_text(
            '"AppState"\n{\n\t"appid"\t\t"570"\n\t"name"\t\t"Dota 2"\n\t"installdir"\t\t"dota 2 beta"\n'
            '\t"SizeOnDisk"\t\t"32212254720"\n}\n')
        (prima / "steamapps" / "appmanifest_228980.acf").write_text(
            '"AppState"\n{\n\t"appid"\t\t"228980"\n\t"name"\t\t"Steamworks Common Redistributables"\n}\n')
        seconda = radice / "altra"; (seconda / "steamapps").mkdir(parents=True)
        (seconda / "steamapps" / "appmanifest_427520.acf").write_text(
            '"AppState"\n{\n\t"appid"\t\t"427520"\n\t"name"\t\t"Factorio"\n\t"installdir"\t\t"Factorio"\n}\n')
        (seconda / "steamapps" / "appmanifest_1493710.acf").write_text(
            '"AppState"\n{\n\t"appid"\t\t"1493710"\n\t"name"\t\t"Proton Experimental"\n}\n')
        (prima / "steamapps" / "libraryfolders.vdf").write_text(
            '"libraryfolders"\n{\n\t"0"\n\t{\n\t\t"path"\t\t"%s"\n\t}\n\t"1"\n\t{\n\t\t"path"\t\t"%s"\n\t}\n}\n'
            % (prima, seconda))
        return prima

    def test_i_giochi_di_tutte_le_librerie_e_i_pezzi_di_steam_fuori(self):
        """I giochi stanno anche nelle altre librerie, e Proton/i runtime non sono giochi da mostrare in elenco."""
        with tempfile.TemporaryDirectory() as t:
            prima = self._steam(Path(t))
            with mock.patch.dict(os.environ, {"STEAM_ROOT": str(prima)}):
                g = cg.giochi()
        self.assertEqual([x["nome"] for x in g], ["Dota 2", "Factorio"])
        self.assertEqual(g[0]["appid"], "570")
        self.assertEqual(g[0]["giga"], 30.0)

    def test_senza_steam_non_si_rompe(self):
        with mock.patch.dict(os.environ, {"STEAM_ROOT": "/nonexistent/steam"}):
            self.assertEqual(cg.giochi(), [])


class Comandi(unittest.TestCase):
    def test_la_guida_e_le_righe_di_commento(self):
        r = subprocess.run([str(RADICE / "bin" / "cielgiochi"), "--aiuto"], capture_output=True, text=True)
        self.assertEqual(r.returncode, 0)
        self.assertGreaterEqual(len(r.stdout.strip().splitlines()), 4)
        self.assertIn("cielgiochi elenco", r.stdout)

    def test_un_comando_che_non_esiste_lo_dice(self):
        r = subprocess.run([str(RADICE / "bin" / "cielgiochi"), "pippo"], capture_output=True, text=True)
        self.assertEqual(r.returncode, 2)
        self.assertIn("pippo", r.stderr)

    def test_elenco_json_non_aspetta_la_rete(self):
        """La finestra si apre subito: l'elenco non deve chiedere a ProtonDB per ogni gioco (i giudizi arrivano dopo,
        uno alla volta). Qui la cache è vuota e non c'è rete: deve uscire lo stesso, e in fretta."""
        with tempfile.TemporaryDirectory() as t:
            with mock.patch.dict(os.environ, {"STEAM_ROOT": "/nonexistent/steam", "CIELGIOCHI_CACHE": t}), \
                 mock.patch.object(cg, "_json", side_effect=AssertionError("l'elenco non deve usare la rete")):
                with mock.patch("sys.stdout") as fuori:
                    codice = cg.main(["elenco", "--json"])
        self.assertEqual(codice, 0)


class VoceDiMenu(unittest.TestCase):
    def test_l_app_c_e_e_apre_cielgiochi(self):
        testo = VOCE.read_text()
        self.assertIn("Name=CielGiochi", testo)
        eseguibile = testo.split("Exec=")[1].splitlines()[0]
        self.assertTrue(Path(eseguibile).is_file(), eseguibile)
        self.assertTrue(os.access(eseguibile, os.X_OK))
        icona = Path(testo.split("Icon=")[1].splitlines()[0])
        self.assertEqual(icona, ICONA)
        self.assertEqual(ET.parse(ICONA).getroot().find("{http://www.w3.org/2000/svg}title").text, "CielGiochi")

    def test_la_voce_e_valida_per_il_sistema(self):
        if not shutil.which("desktop-file-validate"):
            self.skipTest("desktop-file-validate non installato")
        esito = subprocess.run(["desktop-file-validate", str(VOCE)], capture_output=True, text=True)
        self.assertEqual(esito.returncode, 0, esito.stdout + esito.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
