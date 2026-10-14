"""Una volta sola per profilo: il bottone di Ciel nella barra in alto (di serie il browser lo nasconde nel menu delle
estensioni). Tocca prefs.js solo a browser chiuso; dopo, se lo sposti tu, resta dove l'hai messo."""
import json, re, sys
from pathlib import Path

P = Path(sys.argv[1])
segno, prefs = P / ".ciel-nella-barra", P / "prefs.js"
def aperto():                          # il lucchetto di Firefox: «ip:+pid», a volte resta anche a browser chiuso
    try:
        return Path("/proc", __import__("os").readlink(P / "lock").rsplit("+", 1)[1]).exists()
    except (OSError, IndexError):
        return False
if segno.exists() or not prefs.exists() or aperto():
    sys.exit()
testo = prefs.read_text()
m = re.search(r'user_pref\("browser\.uiCustomization\.state", "(.*)"\);', testo)
if not m:
    sys.exit()
stato = json.loads(json.loads('"' + m.group(1) + '"'))
ID = "ciel_cielos-browser-action"
pl = stato["placements"]
for area in pl.values():
    if ID in area:
        area.remove(ID)
nav = pl.setdefault("nav-bar", [])
dopo = nav.index("urlbar-container") + 1 if "urlbar-container" in nav else len(nav)
nav.insert(dopo, ID)
nuovo = json.dumps(json.dumps(stato, separators=(",", ":")))[1:-1]
prefs.write_text(testo[:m.start(1)] + nuovo + testo[m.end(1):])
segno.touch()
