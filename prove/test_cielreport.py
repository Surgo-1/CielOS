"""La repo dei report: i report ci arrivano davvero, con la loro scheda, l'indice e il README, anche in fila.

  python3 prove/test_cielreport.py

Non serve GitHub: la repo è un git locale (CIEL_REPORT_REPO), la copia di lavoro e le impostazioni stanno in una
cartella temporanea. Prova il comando vero (bin/cielreport) e i tre produttori: la visita del Medico, il rapporto
del collaudo e «cielos segnala» (la funzione che pubblica, senza raccogliere niente dal PC).
"""
import importlib.machinery
import importlib.util
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

RADICE = Path(__file__).resolve().parent.parent
COMANDO = RADICE / "bin" / "cielreport"


def carica(nome, percorso):
    caricatore = importlib.machinery.SourceFileLoader(nome, str(percorso))
    modulo = importlib.util.module_from_spec(importlib.util.spec_from_loader(nome, caricatore))
    caricatore.exec_module(modulo)
    return modulo


class Repo(unittest.TestCase):
    def setUp(self):
        self._cartella = tempfile.TemporaryDirectory()
        self.tmp = Path(self._cartella.name)
        self.repo = self.tmp / "repo.git"
        subprocess.run(["git", "init", "-q", "--bare", str(self.repo)], check=True)
        self.env = dict(os.environ,
                        CIEL_REPORT_REPO=str(self.repo),
                        CIEL_REPORT_CACHE=str(self.tmp / "cache"),
                        CIEL_REPORT_STATO=str(self.tmp / "stato"),
                        CIEL_REPORT_CONFIG=str(self.tmp / "report.json"),
                        CIEL_REPORT_MACCHINA="pc-prova",
                        CIEL_REPORT_DATA="2026-10-21T22:40:00+02:00",
                        CIELOS_LINGUA="it")
        for v in ("CIEL_REPORT_SPENTO", "CIELOS_DIR"):
            self.env.pop(v, None)
        self.env["CIELOS_DIR"] = str(RADICE)

    def tearDown(self):
        self._cartella.cleanup()

    def esegui(self, *argomenti, env=None):
        return subprocess.run([str(COMANDO), *argomenti], capture_output=True, text=True, timeout=120,
                              env=env or self.env)

    def git(self, *argomenti):
        return subprocess.run(["git", f"--git-dir={self.repo}", *argomenti], capture_output=True, text=True)

    def mostra(self, percorso):
        r = self.git("show", f"main:{percorso}")
        self.assertEqual(r.returncode, 0, r.stderr)
        return r.stdout

    def file(self, nome="rapporto.md", testo="# Collaudo del 21/10/2026 22:40\n\nProblemi nuovi: 2\n"):
        p = self.tmp / nome
        p.write_text(testo)
        return p

    def pubblica(self, *extra, file=None, env=None):
        return self.esegui("pubblica", str(file or self.file()), "--tipo", "collaudo", *extra,
                           "--json", env=env)

    def test_un_report_arriva_con_scheda_indice_e_readme(self):
        r = self.pubblica("--titolo", "Collaudo del 21/10", "--esito", "2 problemi nuovi", "--versione", "r117")
        self.assertEqual(r.returncode, 0, r.stderr)
        d = json.loads(r.stdout)
        self.assertTrue(d["pubblicato"])
        self.assertEqual(d["file"], "rapporti/2026/10/21-2240-collaudo-pc-prova.md")
        testo = self.mostra(d["file"])
        self.assertTrue(testo.startswith("---\ntipo: collaudo\nmacchina: pc-prova\ndata: 2026-10-21T22:40+02:00\n"))
        self.assertIn("titolo: Collaudo del 21/10\n", testo)
        self.assertIn("esito: 2 problemi nuovi\n", testo)
        self.assertIn("versione: r117\n---\n", testo)
        self.assertIn("# Collaudo del 21/10/2026 22:40", testo)
        indice = json.loads(self.mostra("indice.json"))
        self.assertEqual([m["file"] for m in indice["report"]], [d["file"]])
        readme = self.mostra("README.md")
        self.assertIn(d["file"], readme)
        self.assertIn("**1** report", readme)
        self.assertIn("report: collaudo del 21/10/2026 22:40", self.git("log", "--format=%s", "main").stdout)

    def test_due_report_insieme_non_si_sovrascrivono(self):
        primo = json.loads(self.pubblica("--titolo", "Primo").stdout)
        secondo = json.loads(self.pubblica("--titolo", "Secondo").stdout)
        self.assertNotEqual(primo["file"], secondo["file"])
        self.assertTrue(secondo["file"].endswith("-2.md"))
        indice = json.loads(self.mostra("indice.json"))
        self.assertEqual(len(indice["report"]), 2)
        readme = self.mostra("README.md")
        self.assertIn(primo["file"], readme)
        self.assertIn(secondo["file"], readme)
        self.assertEqual(len([r for r in self.git("ls-tree", "-r", "--name-only", "main").stdout.splitlines()
                              if r.startswith("rapporti/")]), 2)

    def test_toglie_nome_utente_pc_e_mac(self):
        utente = os.environ.get("USER", "")
        mac = "aa:bb:cc:dd:ee:ff"
        testo = f"# Segnalazione di {utente} su {os.uname().nodename}\n\nScheda {mac}\n"
        r = self.esegui("pubblica", str(self.file("s.md", testo)), "--tipo", "segnalazione",
                        "--titolo", "Il microfono non va", "--json")
        self.assertEqual(r.returncode, 0, r.stderr)
        pubblicato = self.mostra(json.loads(r.stdout)["file"])
        if len(utente) > 2:
            self.assertNotIn(utente, pubblicato)
            self.assertIn("UTENTE", pubblicato)
        if len(os.uname().nodename) > 2:
            self.assertNotIn(os.uname().nodename, pubblicato)
            self.assertIn("PC", pubblicato)
        self.assertNotIn(mac, pubblicato)
        self.assertIn("xx:xx:xx:xx:xx:xx", pubblicato)
        self.assertTrue(pubblicato.startswith("---\ntipo: segnalazione\n"))

    def test_spegnere_la_pubblicazione_ferma_tutto(self):
        c = self.esegui("configura", "--spegni")
        self.assertEqual(c.returncode, 0, c.stderr)
        conf = json.loads((self.tmp / "report.json").read_text())
        self.assertFalse(conf["acceso"])
        r = self.pubblica()
        self.assertEqual(r.returncode, 3)
        self.assertFalse(json.loads(r.stdout)["pubblicato"])
        self.assertNotEqual(self.git("rev-parse", "main").returncode, 0)      # la repo è rimasta vuota
        c = self.esegui("configura", "--accendi")
        self.assertEqual(c.returncode, 0, c.stderr)
        self.assertEqual(self.pubblica().returncode, 0)

    def test_stato_ed_elenco(self):
        self.pubblica("--titolo", "Collaudo", "--esito", "2 problemi nuovi")
        s = json.loads(self.esegui("stato", "--json").stdout)
        self.assertEqual(s["macchina"], "pc-prova")
        self.assertTrue(s["acceso"])
        self.assertEqual(s["repo"], str(self.repo))
        self.assertTrue(s["ultimi"])
        e = json.loads(self.esegui("elenco", "--json").stdout)
        self.assertEqual(len(e), 1)
        self.assertEqual(e[0]["tipo"], "collaudo")
        self.assertIn("21/10/2026 22:40", self.esegui("elenco").stdout)

    def test_errori_di_uso_non_pubblicano(self):
        self.assertEqual(self.esegui("pubblica", str(self.tmp / "manca.md"), "--tipo", "collaudo").returncode, 1)
        self.assertEqual(self.esegui("pubblica", str(self.file())).returncode, 2)
        self.assertEqual(self.esegui("pubblica", str(self.file()), "--tipo", "boh").returncode, 2)
        self.assertEqual(self.esegui("comando-inventato").returncode, 2)
        self.assertNotEqual(self.git("rev-parse", "main").returncode, 0)

    def test_la_visita_del_medico_diventa_un_report(self):
        medico = carica("cielmedico_prova", RADICE / "bin" / "cielmedico")
        voci = [
            {"id": "spazio", "gravita": "problema", "titolo": "Poco spazio", "dettaglio": "/ 3% libero",
             "rimedio": "Libera spazio", "ripara": {"tipo": "utente"}},
            {"id": "kernel", "gravita": "ok", "titolo": "Kernel", "dettaglio": "7.2.11", "rimedio": "", "ripara": None},
            {"id": "orfani", "gravita": "consiglio", "titolo": "16 pacchetti orfani", "dettaglio": "",
             "rimedio": "Li tolgo", "ripara": {"tipo": "guardiano"}},
        ]
        testo, esito = medico.rapporto_visita(voci)
        self.assertIn("# Visita del PC del", testo)
        self.assertIn("- ✗ **Poco spazio** — / 3% libero", testo)
        self.assertIn("`cielmedico ripara spazio`", testo)
        self.assertEqual(esito, "1 problema, 1 consiglio")
        medico.STATO = self.tmp / "medico.json"              # non toccare lo stato vero del PC
        with mock.patch.dict(os.environ, self.env):
            url, motivo = medico.pubblica_visita(voci)
        self.assertEqual(motivo, "")
        self.assertIn("rapporti/", url)
        indice = json.loads(self.mostra("indice.json"))
        self.assertEqual(indice["report"][0]["tipo"], "visita")
        self.assertIn("tipo: visita", self.mostra(indice["report"][0]["file"]))

    def test_il_rapporto_del_collaudo_si_pubblica(self):
        rapporto = carica("rapporto_prova", RADICE / "prove" / "collaudo" / "rapporto.py")
        f = self.file("collaudo.md", "# Collaudo del 21/10/2026 22:40\n\n**Problemi nuovi: 1**\n")
        with mock.patch("builtins.print"), mock.patch.dict(os.environ, self.env):
            rapporto.pubblica(f, [{"titolo": "Uno"}], [{"titolo": "Due"}], "r117.abc")
        indice = json.loads(self.mostra("indice.json"))
        self.assertEqual(indice["report"][0]["tipo"], "collaudo")
        self.assertEqual(indice["report"][0]["macchina"], "collaudo")
        self.assertEqual(indice["report"][0]["esito"], "1 problema nuovo, 1 già visti")

    def test_cielos_segnala_pubblica_la_sua_copia(self):
        cielos = carica("cielos_prova", RADICE / "bin" / "cielos")
        f = self.file("segnalazione.txt", "Segnalazione di CielOS, 21/10/2026 22:40\n\n=== il problema ===\nIl microfono non va\n")
        with mock.patch.object(cielos, "BIN", RADICE / "bin"), mock.patch.dict(os.environ, self.env):
            url = cielos.pubblica_report(f, "Il microfono non va")
        self.assertTrue(url)
        indice = json.loads(self.mostra("indice.json"))
        self.assertEqual(indice["report"][0]["tipo"], "segnalazione")
        self.assertEqual(indice["report"][0]["titolo"], "Il microfono non va")


if __name__ == "__main__":
    unittest.main(verbosity=2)
