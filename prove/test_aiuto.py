"""La guida di ogni comando di Ciel: «aiuto», «--aiuto», «-h» e «help» devono fare la stessa cosa su tutti.
python3 prove/test_aiuto.py   (lancia i comandi veri: nessuno deve aprire finestre, toccare la rete o mettersi a
lavorare — se uno lo fa, questa prova lo dice)"""
import os, subprocess, unittest
from pathlib import Path

RADICE = Path(__file__).resolve().parent.parent
BIN = RADICE / "bin"
NON_COMANDI = {"ciel-shell"}        # è un collegamento a qs (il motore): non ha una guida sua
ALIAS = ("aiuto", "--aiuto", "-h", "help")
MAX = 8                              # secondi: oltre, non è una guida ma un'applicazione che si è aperta


def comandi():
    for f in sorted(BIN.iterdir()):
        if f.name in NON_COMANDI or f.is_dir() or not os.access(f, os.X_OK):
            continue
        yield f


def guida(f, alias, env=None):
    """(righe di guida, uscita) oppure il motivo per cui non si è potuta leggere."""
    try:
        r = subprocess.run([str(f), alias], capture_output=True, text=True, timeout=MAX, env=env)
    except subprocess.TimeoutExpired:
        return None, f"si è piantato dopo {MAX} s (ha aperto qualcosa invece di rispondere)"
    righe = [x for x in r.stdout.splitlines() if x.strip()]
    if r.returncode != 0:
        return None, f"è uscito con {r.returncode}: {r.stderr.strip()[:80] or r.stdout.strip()[:80]}"
    if righe and righe[0].startswith("{"):
        return None, "ha stampato un JSON: ha fatto il suo lavoro invece di dare la guida"
    if len(righe) < 2:
        return None, f"ha stampato {len(righe)} righe di guida (una guida è almeno una riga di cosa fa e una di uso)"
    return righe, ""


class Guida(unittest.TestCase):
    def test_ogni_comando_risponde_a_tutti_i_modi(self):
        """Promesso dal 15/10 («aiuto», «--aiuto», «-h» e «help» uguali per tutti i comandi), mantenuto male:
        ciel-file, ciel-monitor, cielfox e cielos-installatore aprivano la loro finestra; cielos-hardware faceva la
        scansione dell'hardware, cielos-peso e cielomonitor stampavano il loro JSON (il peso, la fotografia del PC);
        cielos-utente preparava l'utente per davvero e non stampava niente; ciel-apri non rispondeva affatto;
        cielos-sistema e cielos-installa-sistema pretendevano root per mostrare una guida; e altri uscivano con 1 o 2."""
        rotti = []
        for f in comandi():
            for alias in ALIAS:
                _, male = guida(f, alias)
                if male:
                    rotti.append(f"{f.name} {alias}: {male}")
        self.assertEqual(rotti, [], "comandi senza una guida vera:\n  " + "\n  ".join(rotti))

    def test_la_guida_funziona_anche_in_inglese(self):
        """La guida non deve rompersi quando la lingua è l'inglese (chi la legge non deve vedere un errore Python)."""
        env = dict(os.environ, CIELOS_LINGUA="en")
        rotti = [f"{f.name}: {male}" for f in comandi() for male in [guida(f, "--aiuto", env)[1]] if male]
        self.assertEqual(rotti, [], "comandi che in inglese non danno la guida:\n  " + "\n  ".join(rotti))


if __name__ == "__main__":
    unittest.main(verbosity=2)
