

# i testi per l'utente nella lingua di CielOS (lingua/lingua.py; senza, restano in italiano)
import sys as _sys
from pathlib import Path as _Path
_sys.path.insert(0, str(_Path(__file__).resolve().parent.parent.parent / "lingua"))
try:
    from lingua import tr
except ImportError:
    def tr(testo, *valori):
        for i, v in enumerate(valori, 1):
            testo = testo.replace(f"%{i}", str(v))
        return testo
