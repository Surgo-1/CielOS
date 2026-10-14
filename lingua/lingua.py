"""La lingua di CielOS per i comandi in Python: tr("testo in italiano") → la traduzione nella lingua scelta.

La lingua: CIELOS_LINGUA (it/en), poi ~/.config/cielos/lingua (la scelta nelle Impostazioni), poi quella del sistema
(LANG: italiano se comincia con «it», senza lingua o C italiano, altrimenti inglese). Le traduzioni stanno in
lingua/en.json: la chiave è la frase italiana, così chi scrive il codice scrive in italiano e basta; quello che manca
nel dizionario resta in italiano. Segnaposto: %1, %2… (tr("Ho trovato %1 file", n))."""
import json, os
from pathlib import Path

DIR = Path(__file__).resolve().parent
LINGUE = ("it", "en")


def codice():
    v = os.environ.get("CIELOS_LINGUA", "").strip()
    if v not in LINGUE:
        conf = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "cielos" / "lingua"
        try:
            v = conf.read_text().strip()
        except OSError:
            v = ""
    if v not in LINGUE:
        loc = os.environ.get("LC_ALL") or os.environ.get("LC_MESSAGES") or os.environ.get("LANG") or ""
        v = "it" if loc.startswith("it") or loc.split(".")[0] in ("", "C", "POSIX") else "en"
    return v


LINGUA = codice()
_diz = None


def dizionario():
    global _diz
    if _diz is None:
        _diz = {}
        if LINGUA != "it":
            try:
                _diz = json.loads((DIR / f"{LINGUA}.json").read_text())
            except (OSError, ValueError):
                pass
    return _diz


def tr(testo, *valori):
    r = dizionario().get(testo, testo) if LINGUA != "it" else testo
    for i, v in enumerate(valori, 1):
        r = r.replace(f"%{i}", str(v))
    return r


if __name__ == "__main__":       # per gli script in bash: lingua.py "testo" [valori…], o «lingua.py --codice»
    import sys
    a = sys.argv[1:]
    print(LINGUA if not a or a[0] == "--codice" else tr(a[0], *a[1:]), end="" if a and a[0] != "--codice" else "\n")
