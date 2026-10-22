"""Le stime di cielmodelli su PC diversi (hardware finto, CIELMODELLI_HW), senza scaricare niente:
python3 prove/test_cielmodelli.py   (stampa la tabella e controlla che i giudizi abbiano senso)"""
import importlib.machinery, importlib.util, json, os, sys, tempfile, unittest
from pathlib import Path

_l = importlib.machinery.SourceFileLoader("cielmodelli", str(Path(__file__).resolve().parent.parent / "bin/cielmodelli"))
_s = importlib.util.spec_from_loader("cielmodelli", _l)
cm = importlib.util.module_from_spec(_s)
_l.exec_module(cm)

PC = {
    "il tuo (GTX 1650 4 GB, 32 GB)": {"gpu": {"nome": "NVIDIA GeForce GTX 1650", "fornitore": "nvidia", "vram_gb": 4.0,
                                              "usata": True}, "ram_gb": 32, "banda_ram_gbs": 35},
    "RTX 3060 12 GB, 16 GB": {"gpu": {"nome": "NVIDIA GeForce RTX 3060", "fornitore": "nvidia", "vram_gb": 12.0,
                                      "usata": True}, "ram_gb": 16, "banda_ram_gbs": 40},
    "RX 7800 XT 16 GB, 32 GB": {"gpu": {"nome": "Radeon RX 7800 XT", "fornitore": "amd", "vram_gb": 16.0, "usata": True},
                                "ram_gb": 32, "banda_ram_gbs": 60},
    "RX 6600 senza ollama-rocm, 16 GB": {"gpu": {"nome": "Radeon RX 6600", "fornitore": "amd", "vram_gb": 8.0,
                                                 "usata": False}, "ram_gb": 16, "banda_ram_gbs": 40},
    "portatile Intel integrata, 8 GB": {"gpu": {"nome": "Iris Xe", "fornitore": "intel", "integrata": True,
                                                "usata": False}, "ram_gb": 8, "banda_ram_gbs": 30},
    "PC vecchio senza AVX2, 8 GB": {"gpu": None, "ram_gb": 8, "banda_ram_gbs": 15, "cpu": {"thread": 4, "avx2": False}},
}
MODELLI = [("qwen3 0.6B Q4_K_M", 0.5), ("qwen3 4B Q4_K_M", 2.5), ("qwen3 8B Q4_K_M", 5.0), ("gemma3 12B Q4_K_M", 7.3),
           ("Qwen3-30B-A3B Q4_K_M", 18.6), ("llama3 70B Q4_K_M", 42.5)]


def stime(nome_pc):
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
        json.dump(PC[nome_pc], f)
    os.environ["CIELMODELLI_HW"] = f.name
    try:
        hw = cm.hardware()
        return {m: cm.stima(gb, m, hw) for m, gb in MODELLI}
    finally:
        os.unlink(f.name)
        del os.environ["CIELMODELLI_HW"]


class Riconoscimento(unittest.TestCase):
    def test_sys_finto_amd_e_intel(self):
        with tempfile.TemporaryDirectory() as t:
            for card, forn, vram in (("card0", "0x8086", None), ("card1", "0x1002", 8 * 2**30)):
                d = Path(t) / "class/drm" / card / "device"
                d.mkdir(parents=True)
                (d / "vendor").write_text(forn + "\n")
                if vram:
                    (d / "mem_info_vram_total").write_text(str(vram))
            n = Path(t) / "class/kfd/kfd/topology/nodes/1"
            n.mkdir(parents=True)
            (n / "properties").write_text("cpu_cores_count 0\ngfx_target_version 100302\n")
            vecchio, cm.SYS = cm.SYS, Path(t)
            try:
                g = cm._gpu_fisiche()
            finally:
                cm.SYS = vecchio
        intel, amd = g
        self.assertTrue(intel["integrata"])
        self.assertEqual((amd["fornitore"], amd["vram_gb"], amd["integrata"], amd["gfx"]), ("amd", 8.0, False, "gfx1032"))

    def test_registro_di_ollama(self):
        cuda = ('time=2026-10-14T05:44:01.274+02:00 level=INFO source=types.go:32 msg="inference compute" id=0 '
                'library=CUDA compute=7.5 name=CUDA0 description="NVIDIA GeForce GTX 1650" type=discrete '
                'total="3.6 GiB" available="3.5 GiB"')
        vecchia = cuda.replace("05:44", "03:10").replace("3.6 GiB", "9.9 GiB")
        v = cm._leggi_compute(vecchia + "\n" + cuda)
        self.assertEqual(v, [{"libreria": "CUDA", "nome": "NVIDIA GeForce GTX 1650", "vram_gb": 3.6, "integrata": False}])
        cpu = 'time=2026-10-14T05:44:01.274+02:00 level=INFO msg="inference compute" id=cpu library=cpu total="31.2 GiB"'
        self.assertEqual(cm._leggi_compute(cpu), [])
        self.assertIsNone(cm._leggi_compute(""))


class Stime(unittest.TestCase):
    def test_tabella_e_buon_senso(self):
        tutte = {p: stime(p) for p in PC}
        larg = max(len(m) for m, _ in MODELLI)
        print()
        for p, s in tutte.items():
            print(f"── {p}")
            for m, _ in MODELLI:
                x = s[m]
                print(f"   {m:<{larg}}  {x['giudizio']:<20} {x['tok_s'] or '-':>6} token/s  {x['dove_testo']}")
        tuo, r3060, rx78, rx66, port, vecchio = (tutte[p] for p in PC)
        self.assertEqual(r3060["qwen3 8B Q4_K_M"]["dove"], "gpu")                       # 5 GB su 12: tutto lì
        self.assertGreater(r3060["qwen3 8B Q4_K_M"]["tok_s"], 30)
        self.assertEqual(rx78["gemma3 12B Q4_K_M"]["dove"], "gpu")
        self.assertEqual(rx66["qwen3 4B Q4_K_M"]["dove"], "cpu")                         # scheda non usata
        self.assertFalse(port["Qwen3-30B-A3B Q4_K_M"]["gira"])                           # 18 GB su 8: no
        self.assertTrue(port["qwen3 4B Q4_K_M"]["gira"])
        self.assertFalse(tuo["llama3 70B Q4_K_M"]["gira"])
        self.assertTrue(tuo["Qwen3-30B-A3B Q4_K_M"]["gira"])                            # MoE: esperti in RAM
        self.assertLess(vecchio["qwen3 4B Q4_K_M"]["tok_s"], port["qwen3 4B Q4_K_M"]["tok_s"])
        # più hardware non dà mai stime peggiori sullo stesso modello
        for m, _ in MODELLI:
            if r3060[m]["gira"] and tuo[m]["gira"] and r3060[m]["dove"] == "gpu":
                self.assertGreaterEqual(r3060[m]["tok_s"], tuo[m]["tok_s"], m)

    def test_consigli(self):
        self.assertIn("ollama-rocm", cm._consiglio({"fornitore": "amd", "gfx": "gfx1032"}, set()))
        self.assertIn("HSA_OVERRIDE", cm._consiglio({"fornitore": "amd", "gfx": "gfx1032"}, set()))
        self.assertNotIn("HSA_OVERRIDE", cm._consiglio({"fornitore": "amd", "gfx": "gfx1100"}, set()))
        self.assertIn("ollama-cuda", cm._consiglio({"fornitore": "nvidia"}, set()))
        self.assertIn("integrata", cm._consiglio({"fornitore": "intel", "integrata": True}, set()))
        self.assertIn("ollama-vulkan", cm._consiglio({"fornitore": "intel", "nome": "Arc A770"}, set()))

    def test_riga_hardware(self):
        hw = {"gpu": {"nome": "Radeon RX 6600", "vram_gb": 8, "consiglio": "la scheda video AMD non è usata: installa "
                      "ollama-rocm"}, "ram_gb": 16, "disco": {"tipo": "SSD", "libero_gb": 80}}
        self.assertIn("installa ollama-rocm", cm._hw_breve(hw))
        self.assertIn("nessuna scheda video", cm._hw_breve({**hw, "gpu": None}))


class Consigli(unittest.TestCase):
    """I consigli non devono proporre modelli da 20 GB che sbordano quasi tutti in RAM su una scheda da 4 GB."""

    def voce(self, nome, tok, dove, quota, bit=4.5, dim=4.0, par=4.0):
        return {"nome_ollama": nome, "dimensione_gb": dim, "bit": bit, "diviso": False,
                "stima": {"gira": dove != "no", "dove": dove, "tok_s": tok, "gpu_quota": quota, "parametri_b": par}}

    def test_vince_chi_sta_sulla_scheda_non_il_piu_grande_in_ram(self):
        grande = self.voce("qwen3.6:35b", 11.5, "divisa", 0.16, dim=23, par=35)
        giusto = self.voce("qwen3:4b", 24.0, "divisa", 0.93, dim=2.5, par=4)
        piccolo = self.voce("qwen3:1.7b", 50, "gpu", 1.0, dim=1.4, par=1.7)
        self.assertEqual(cm._consigliata([grande, giusto, piccolo]), "qwen3:4b")

    def test_se_niente_sta_nella_scheda_il_piu_veloce_che_gira(self):
        lento = self.voce("grande", 5, "divisa", 0.5, dim=20, par=30)
        svelto = self.voce("piccolo", 20, "divisa", 0.5, dim=6, par=8)
        self.assertEqual(cm._consigliata([lento, svelto]), "piccolo")


class Gestione(unittest.TestCase):
    """Accendi/spegni: la configurazione cambia solo se il modello è davvero in memoria, e «Usa per Ciel» non
    aspetta il caricamento (prima ci metteva fino a 90 s e, se andava male, lasciava il modello spento)."""

    def setUp(self):
        self.t = tempfile.TemporaryDirectory()
        self.veri = (cm.CONFIG, cm.CIEL_CONFIG, cm._ollama, cm.libera, cm.subprocess.run, cm.subprocess.Popen)
        cm.CONFIG = Path(self.t.name) / "modelli.json"
        cm.CIEL_CONFIG = Path(self.t.name) / "config.yaml"
        cm.CIEL_CONFIG.write_text('ollama:\n  modello: "mente:latest"\n')
        self.chiamate = []

        def ollama(percorso, dati=None, metodo=None, timeout=10, stream=False):
            self.chiamate.append(percorso)
            if percorso == "/api/ps":
                return {"models": [{"name": "libero:latest"}]}
            if percorso == "/api/tags":
                return {"models": [{"name": "libero:latest"}, {"name": "mente:latest"}]}
            return {}
        cm._ollama = ollama
        cm.libera = lambda nome: {"ok": True}
        cm.subprocess.run = lambda *a, **k: type("R", (), {"returncode": 0, "stdout": "", "stderr": ""})()
        cm.subprocess.Popen = lambda *a, **k: None

    def tearDown(self):
        (cm.CONFIG, cm.CIEL_CONFIG, cm._ollama, cm.libera, cm.subprocess.run, cm.subprocess.Popen) = self.veri
        self.t.cleanup()

    def spenti(self):
        return json.loads(cm.CONFIG.read_text())["spenti"]

    def test_accendi_carica_e_spegni_lascia_la_memoria(self):
        cm.scrivi_config({"spenti": ["libero:latest"], "fonti": {}})
        self.assertEqual(cm.spegni("libero:latest", False), {"ok": True})
        self.assertIn("/api/generate", self.chiamate)                        # caricato adesso (keep_alive=-1)
        self.assertEqual(self.spenti(), [])
        self.assertEqual(cm.spegni("libero:latest", True), {"ok": True})
        self.assertEqual(self.spenti(), ["libero:latest"])

    def test_se_il_caricamento_fallisce_non_cambia_niente(self):
        cm.scrivi_config({"spenti": ["libero:latest"], "fonti": {}})
        cm._ollama = lambda *a, **k: (_ for _ in ()).throw(OSError("Ollama è spento"))
        r = cm.spegni("libero:latest", False)
        self.assertFalse(r["ok"])
        self.assertEqual(self.spenti(), ["libero:latest"])                   # resta spento com'era

    def test_non_si_spegne_la_mente_di_ciel(self):
        cm.scrivi_config({"spenti": [], "fonti": {}})
        r = cm.spegni("mente:latest", True)
        self.assertFalse(r["ok"])
        self.assertIn("Lo usa Ciel", r["messaggio"])

    def test_elimina_prima_libera_la_memoria(self):
        """Dopo «Elimina» il modello non deve restare in RAM: prima il flush (keep_alive 0), poi i file."""
        stato = {"models": [{"name": "libero:latest", "size": 1e9, "details": {}}]}
        chiamate = []

        def ollama(percorso, dati=None, metodo=None, timeout=10, stream=False):
            chiamate.append((percorso, metodo, dati))
            if percorso == "/api/tags":
                return stato
            if percorso == "/api/ps":
                return {"models": [] if any(c[0] == "/api/generate" for c in chiamate) else stato["models"]}
            if percorso == "/api/delete":
                stato["models"] = []
            return {}
        cm._ollama = ollama
        cm.scrivi_config({"spenti": ["libero:latest"], "fonti": {},
                          "impostazioni": {"libero:latest": {"contesto": 8192}}})
        r = cm.elimina("libero:latest")
        self.assertTrue(r["ok"], r)
        percorsi = [c[0] for c in chiamate]
        self.assertLess(percorsi.index("/api/generate"), percorsi.index("/api/delete"))
        self.assertIn("keep_alive", [k for c in chiamate if c[0] == "/api/generate" for k in (c[2] or {})])
        c = json.loads(cm.CONFIG.read_text())
        self.assertNotIn("libero:latest", c["spenti"])
        self.assertNotIn("libero:latest", c["impostazioni"])

    def test_eliminare_la_mente_lascia_ciel_senza_mente(self):
        """Anche l'unico modello scaricato (quello con cui pensa Ciel) si può eliminare: Ciel non punta a un fantasma."""
        stato = {"models": [{"name": "mente:latest", "size": 1e9, "details": {}}]}

        def ollama(percorso, dati=None, metodo=None, timeout=10, stream=False):
            if percorso == "/api/tags":
                return stato
            if percorso == "/api/ps":
                return {"models": []}
            if percorso == "/api/delete":
                stato["models"] = []
            return {}
        cm._ollama = ollama
        togli = []
        cm._togli_mente_di_ciel = lambda: togli.append(True)
        cm.scrivi_config({"spenti": [], "fonti": {}, "impostazioni": {}})
        r = cm.elimina("mente:latest")
        self.assertTrue(r["ok"], r)
        self.assertEqual(togli, [True])
        self.assertIn("senza mente", r["messaggio"])

    def test_impostazioni_per_modello(self):
        """Contesto, temperatura e memoria si salvano, «memoria=no» toglie davvero dalla RAM, i valori sbagliati no."""
        chiamate = []

        def ollama(percorso, dati=None, metodo=None, timeout=10, stream=False):
            chiamate.append((percorso, dati))
            if percorso == "/api/tags":
                return {"models": [{"name": "libero:latest"}]}
            if percorso == "/api/ps":
                return {"models": []}
            return {}
        cm._ollama = ollama
        cm.scrivi_config({"spenti": [], "fonti": {}, "impostazioni": {}})
        r = cm.imposta("libero:latest", ["contesto=8192", "temperatura=0.5", "memoria=no"])
        self.assertTrue(r["ok"], r)
        imp = json.loads(cm.CONFIG.read_text())["impostazioni"]["libero:latest"]
        self.assertEqual((imp["contesto"], imp["temperatura"], imp["memoria"]), (8192, 0.5, "no"))
        self.assertTrue(any(d and d.get("keep_alive") == 0 for p, d in chiamate if p == "/api/generate"))
        self.assertIn("libero:latest", self.spenti())
        self.assertFalse(cm.imposta("libero:latest", ["temperatura=9"])["ok"])
        self.assertFalse(cm.imposta("libero:latest", ["contesto=99"])["ok"])

    def test_impostazioni_estese_e_auto(self):
        """Le impostazioni di esecuzione che Ollama sa usare: campionamento, max token, seme, strati, batch, mmap/mlock,
        ragionamento. «auto» toglie la scelta (torna il valore di serie) e i numeri fuori misura si rifiutano."""
        cm._ollama = lambda percorso, dati=None, metodo=None, timeout=10, stream=False: (
            {"models": [{"name": "libero:latest"}]} if percorso == "/api/tags" else
            {"models": []} if percorso == "/api/ps" else {})
        cm.scrivi_config({"spenti": [], "fonti": {}, "impostazioni": {}})
        r = cm.imposta("libero:latest", ["top_p=0.8", "top_k=40", "min_p=0.05", "ripetizione=1.2", "presenza=0.1",
                                         "max_token=2048", "seed=42", "strati_gpu=12", "batch=512",
                                         "mmap=si", "mlock=no", "ragiona=si"])
        self.assertTrue(r["ok"], r)
        imp = json.loads(cm.CONFIG.read_text())["impostazioni"]["libero:latest"]
        self.assertEqual((imp["top_p"], imp["top_k"], imp["min_p"], imp["ripetizione"], imp["presenza"]),
                         (0.8, 40, 0.05, 1.2, 0.1))
        self.assertEqual((imp["max_token"], imp["seed"], imp["strati_gpu"], imp["batch"]), (2048, 42, 12, 512))
        self.assertEqual((imp["mmap"], imp["mlock"], imp["ragiona"]), ("si", "no", "si"))
        r = cm.imposta("libero:latest", ["top_p=auto", "seed=auto", "mmap=auto", "batch=auto"])
        self.assertTrue(r["ok"], r)
        imp = json.loads(cm.CONFIG.read_text())["impostazioni"]["libero:latest"]
        self.assertEqual((imp.get("top_p"), imp.get("seed"), imp.get("mmap"), imp.get("batch")), (None, None, None, None))
        self.assertEqual(imp["top_k"], 40)                          # le altre restano
        self.assertFalse(cm.imposta("libero:latest", ["top_p=3"])["ok"])
        self.assertFalse(cm.imposta("libero:latest", ["strati_gpu=-1"])["ok"])
        self.assertFalse(cm.imposta("libero:latest", ["mmap=forse"])["ok"])

    def test_il_contesto_entra_nel_modello_per_tutte_le_app(self):
        """Il contesto scelto non resta una richiesta di CielOS: finisce nel Modelfile del modello (PARAMETER num_ctx),
        così anche Codice, un agente o un altro programma che carica quel modello usa gli stessi token. «auto»
        rimette il Modelfile com'era, senza perdere template e stop originali."""
        creazioni = []

        class R:
            def __init__(self, rc=0, out="", err=""):
                self.returncode, self.stdout, self.stderr = rc, out, err

        def run(cmd, **k):
            if cmd[:3] == ["ollama", "show", "--modelfile"]:
                return R(out="FROM /blobs/modello\nTEMPLATE \"{{ .Prompt }}\"\nPARAMETER num_ctx 16384\nPARAMETER stop <fine>\n")
            if cmd[:2] == ["ollama", "create"]:
                creazioni.append(Path(cmd[cmd.index("-f") + 1]).read_text())
                return R()
            return R()

        cm._ollama = lambda percorso, dati=None, metodo=None, timeout=10, stream=False: (
            {"models": [{"name": "libero:latest"}]} if percorso == "/api/tags" else {"models": []})
        cm.subprocess.run = run
        cm.scrivi_config({"spenti": [], "fonti": {}, "impostazioni": {}})
        r = cm.imposta("libero:latest", ["contesto=8192"])
        self.assertTrue(r["ok"], r)
        self.assertEqual(creazioni[-1].count("PARAMETER num_ctx"), 1)
        self.assertIn("PARAMETER num_ctx 8192", creazioni[-1])
        self.assertIn("PARAMETER stop <fine>", creazioni[-1])          # il resto del modello resta
        base = cm._base_path("libero:latest").read_text()
        self.assertIn("PARAMETER num_ctx 16384", base)                 # l'originale, per «auto»
        r = cm.imposta("libero:latest", ["contesto=auto"])
        self.assertTrue(r["ok"], r)
        self.assertIn("PARAMETER num_ctx 16384", creazioni[-1])        # torna com'era, non a 4096
        self.assertEqual(creazioni[-1].count("PARAMETER num_ctx"), 1)
        self.assertNotIn("contesto", json.loads(cm.CONFIG.read_text())["impostazioni"]["libero:latest"])

    def test_se_il_contesto_non_entra_non_si_salva(self):
        """Se Ollama rifiuta il modello nuovo, l'impostazione non viene salvata: niente «Salvato» per qualcosa che non
        è successo (prima restava il contesto vecchio e il modello poteva restare fuori dalla memoria)."""
        class R:
            def __init__(self, rc=0, out="", err=""):
                self.returncode, self.stdout, self.stderr = rc, out, err

        def run(cmd, **k):
            if cmd[:3] == ["ollama", "show", "--modelfile"]:
                return R(out="FROM /blobs/modello\n")
            if cmd[:2] == ["ollama", "create"]:
                return R(rc=1, err="memoria insufficiente")
            return R()

        cm._ollama = lambda percorso, dati=None, metodo=None, timeout=10, stream=False: (
            {"models": [{"name": "libero:latest"}]} if percorso == "/api/tags" else {"models": []})
        cm.subprocess.run = run
        cm.scrivi_config({"spenti": [], "fonti": {}, "impostazioni": {}})
        r = cm.imposta("libero:latest", ["contesto=8192"])
        self.assertFalse(r["ok"])
        self.assertIn("memoria insufficiente", r["messaggio"])
        self.assertNotIn("contesto", json.loads(cm.CONFIG.read_text())["impostazioni"].get("libero:latest", {}))

    def test_scheda_dice_anche_il_contesto_in_memoria(self):
        """La pagina deve sapere a che contesto gira DAVVERO il modello: se un'altra app l'ha caricato a 4k mentre
        hai scelto 32k, lo deve dire (prima mostrava solo il massimo dichiarato)."""
        def ollama(percorso, dati=None, metodo=None, timeout=10, stream=False):
            if percorso == "/api/tags":
                return {"models": [{"name": "libero:latest"}]}
            if percorso == "/api/show":
                return {"model_info": {"general.architecture": "llama", "llama.context_length": 131072,
                                        "llama.block_count": 42}, "capabilities": [], "parameters": ""}
            if percorso == "/api/ps":
                return {"models": [{"name": "libero:latest", "context_length": 4096}]}
            return {}
        cm._ollama = ollama
        s = cm.scheda("libero:latest")
        self.assertTrue(s["ok"], s)
        self.assertTrue(s["in_memoria"])
        self.assertEqual(s["contesto_attuale"], 4096)
        self.assertEqual(s["contesto_max"], 131072)

    def test_scheda_dice_contesto_massimo_e_capacita(self):
        """La pagina delle impostazioni ha bisogno dei limiti veri del modello (contesto massimo, strati) e di cosa sa
        fare (visione, strumenti, ragionamento), non di numeri inventati."""
        def ollama(percorso, dati=None, metodo=None, timeout=10, stream=False):
            if percorso == "/api/tags":
                return {"models": [{"name": "libero:latest"}]}
            if percorso == "/api/show":
                return {"model_info": {"general.architecture": "qwen3", "qwen3.context_length": 40960,
                                        "qwen3.block_count": 36},
                        "capabilities": ["completion", "tools", "thinking"],
                        "parameters": "temperature 0.6\ntop_p 0.95\nstop \"<|endoftext|>\""}
            return {"models": []}
        cm._ollama = ollama
        s = cm.scheda("libero:latest")
        self.assertTrue(s["ok"], s)
        self.assertEqual((s["contesto_max"], s["blocchi"], s["capacita"]), (40960, 36, ["completion", "tools", "thinking"]))
        self.assertEqual(s["predefiniti"], {"temperature": 0.6, "top_p": 0.95})
        self.assertFalse(cm.scheda("non:ce")["ok"])

    def test_ricarica_solo_se_era_in_memoria(self):
        """«Ricarica modello» applica le impostazioni al modello in memoria: lo scarica e lo ricarica col keep_alive
        scelto. Se non era in memoria non lo sveglia (niente RAM consumata per niente)."""
        stato = {"dentro": False}
        chiamate = []

        def ollama(percorso, dati=None, metodo=None, timeout=10, stream=False):
            chiamate.append((percorso, dati))
            if percorso == "/api/tags":
                return {"models": [{"name": "libero:latest"}]}
            if percorso == "/api/ps":
                return {"models": [{"name": "libero:latest"}] if stato["dentro"] else []}
            if percorso == "/api/generate":
                stato["dentro"] = (dati or {}).get("keep_alive") != 0
            return {}
        cm._ollama = ollama
        cm.scrivi_config({"spenti": [], "fonti": {}, "impostazioni": {}})
        # non era in memoria: nessuna generazione
        r = cm.ricarica("libero:latest")
        self.assertTrue(r["ok"], r)
        self.assertNotIn("/api/generate", [p for p, _ in chiamate])
        # in memoria, con «sempre»: lo ricarica con keep_alive -1 e le impostazioni
        stato["dentro"] = True
        chiamate.clear()
        cm.scrivi_config({"spenti": [], "fonti": {}, "impostazioni": {"libero:latest": {
            "memoria": "sempre", "contesto": 8192, "top_p": 0.8, "strati_gpu": 12, "mmap": "si"}}})
        r = cm.ricarica("libero:latest")
        self.assertTrue(r["ok"], r)
        gen = [d for p, d in chiamate if p == "/api/generate"]
        self.assertEqual(gen[0]["keep_alive"], 0)                   # prima il flush
        ultimo = gen[-1]
        self.assertEqual(ultimo["keep_alive"], -1)
        self.assertEqual((ultimo["options"]["num_ctx"], ultimo["options"]["top_p"], ultimo["options"]["num_gpu"],
                          ultimo["options"]["use_mmap"]), (8192, 0.8, 12, True))

    def test_la_mente_di_ciel_riceve_tutte_le_impostazioni(self):
        """Se il modello è la mente di Ciel, quello che Ciel sa usare finisce nel suo config.yaml (contesto e opzioni),
        e «auto» lo toglie (torna com'era). Un assistente installato in un altro posto non deve rompere niente."""
        (Path(self.t.name) / "configura.py").write_text(
            "import json\nfrom pathlib import Path\nP = Path(__file__).with_name('percorsi.json')\n"
            "def _l():\n    try: return json.loads(P.read_text())\n    except Exception: return {}\n"
            "def scrivi(percorso, valore):\n    d = _l(); d['.'.join(percorso)] = valore; P.write_text(json.dumps(d))\n"
            "def togli(percorso):\n    d = _l(); d.pop('.'.join(percorso), None); P.write_text(json.dumps(d))\n")
        cm._ollama = lambda percorso, dati=None, metodo=None, timeout=10, stream=False: (
            {"models": [{"name": "mente:latest"}]} if percorso == "/api/tags" else
            {"models": [{"name": "mente:latest"}]} if percorso == "/api/ps" else {})
        cm.scrivi_config({"spenti": [], "fonti": {}, "impostazioni": {"mente:latest": {
            "memoria": "sempre", "contesto": 8192, "temperatura": 0.5, "top_p": 0.8, "strati_gpu": 20,
            "batch": 512, "mmap": "si", "mlock": "no", "ragiona": "no"}}})
        r = cm.imposta("mente:latest", ["contesto=8192"])
        self.assertTrue(r["ok"], r)
        d = json.loads((Path(self.t.name) / "percorsi.json").read_text())
        self.assertEqual(d["ollama.num_ctx"], 8192)
        self.assertEqual(d["ollama.opzioni.temperature"], 0.5)
        self.assertEqual(d["ollama.opzioni.top_p"], 0.8)
        self.assertEqual(d["ollama.opzioni.num_gpu"], 20)
        self.assertEqual(d["ollama.opzioni.num_batch"], 512)
        self.assertIs(d["ollama.opzioni.use_mmap"], True)
        self.assertIs(d["ollama.opzioni.use_mlock"], False)
        self.assertIs(d["ollama.thinking"], False)
        self.assertEqual(d["ollama.keep_alive"], -1)                # «sempre» vale anche per Ciel
        self.assertFalse(cm.imposta("mente:latest", ["memoria=no"])["ok"])   # la mente non si scarica a ogni domanda
        r = cm.imposta("mente:latest", ["top_p=auto", "strati_gpu=auto"])
        self.assertTrue(r["ok"], r)
        d = json.loads((Path(self.t.name) / "percorsi.json").read_text())
        self.assertNotIn("ollama.opzioni.top_p", d)                 # rimesse com'erano
        self.assertNotIn("ollama.opzioni.num_gpu", d)
        self.assertEqual(d["ollama.num_ctx"], 8192)

    def test_la_memoria_della_mente_viene_dal_suo_config(self):
        """Se Ciel tiene il modello caricato per sempre (keep_alive -1), la scheda deve dirlo «sempre», non «5 minuti»:
        altrimenti si vedrebbe una cosa e Ciel ne farebbe un'altra."""
        cm.CIEL_CONFIG.write_text('ollama:\n  modello: "mente:latest"\n  keep_alive: -1\n  num_ctx: 6144\n')
        cm.scrivi_config({"spenti": [], "fonti": {}, "impostazioni": {}})
        imp = cm.impostazioni_di("mente:latest")
        self.assertEqual((imp["memoria"], imp["contesto"]), ("sempre", 6144))
        cm.CIEL_CONFIG.write_text('ollama:\n  modello: "mente:latest"\n  keep_alive: 0\n')
        self.assertEqual(cm.impostazioni_di("mente:latest")["memoria"], "no")
        # una scelta salvata vince sul config di Ciel
        cm.scrivi_config({"spenti": [], "fonti": {}, "impostazioni": {"mente:latest": {"memoria": "default"}}})
        self.assertEqual(cm.impostazioni_di("mente:latest")["memoria"], "default")

    def test_usa_per_ciel_solo_configurazione(self):
        cm.scrivi_config({"spenti": ["mente:latest"], "fonti": {}})
        self.chiamate.clear()
        r = cm.usa_per_ciel("mente:latest")
        self.assertTrue(r["ok"], r)
        self.assertNotIn("/api/generate", self.chiamate)                     # niente caricamento
        self.assertEqual(self.spenti(), [])


if __name__ == "__main__":
    unittest.main(verbosity=1)
