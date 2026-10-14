#!/usr/bin/env python3
"""Il controllo dell'avvio dopo un aggiornamento (cielos-avvio.service, root, a ogni avvio; senza niente in prova
esce subito: 0 risorse).

Con un aggiornamento «in prova» (aggiornamenti.IN_PROVA):
  1. conta il tentativo (scritto subito su disco: se il PC si pianta o si riavvia, il conto resta);
  2. se è il tentativo numero TENTATIVI_MAX+1 senza che il desktop sia mai partito → torna indietro e riavvia;
  3. aspetta il desktop: va bene quando una sessione grafica resta su per SESSIONE_OK secondi.
     Se il gestore del login (display-manager) fallisce, o le sessioni grafiche si chiudono entro CORTA_S
     secondi per SESSIONI_CORTE_MAX volte → torna indietro e riavvia.
     Se il login resta su ma nessuno entra, il tentativo non conta come fallito (il conto torna a zero) e
     l'aggiornamento resta in prova fino alla prima sessione riuscita.

Per la macchina virtuale, che non ha un desktop: /etc/cielos/avvio.conf con «segnale=servizio:NOME» (va bene
quando quel servizio è attivo da SESSIONE_OK secondi; male se fallisce)."""
import json, os, subprocess, sys, time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import aggiornamenti as A  # noqa: E402

SESSIONE_OK = int(os.environ.get("CIELOS_SESSIONE_OK", 90))
DM_OK = 180                       # login su da 3 minuti senza errori: il tentativo non è fallito
SESSIONI_CORTE_MAX = 3
CORTA_S = 20                      # una sessione che si chiude prima di così: il desktop è crollato
ATTESA_MAX = 6 * 3600             # poi si smette di guardare (resta in prova)
CONF = A.R / "etc/cielos/avvio.conf"


def log(*a):
    print("cielos-avvio:", *a, flush=True)


def _uscita(*c):
    r = subprocess.run(c, capture_output=True, text=True, timeout=30)
    return r.stdout.strip()


def stato_unita(u):
    return _uscita("systemctl", "show", "-p", "ActiveState,ActiveEnterTimestampMonotonic,NRestarts", "--value", u).split("\n")


def sessioni_grafiche():
    """id delle sessioni wayland/x11 attive adesso"""
    out = []
    try:
        for s in json.loads(_uscita("loginctl", "list-sessions", "-j") or "[]"):
            t = _uscita("loginctl", "show-session", str(s["session"]), "-p", "Type", "-p", "Class", "--value").split("\n")
            if t and t[0] in ("wayland", "x11") and (len(t) < 2 or t[1] == "user"):
                out.append(str(s["session"]))
    except (ValueError, KeyError):
        pass
    return out


def segnale():
    try:
        for riga in CONF.read_text().splitlines():
            if riga.startswith("segnale="):
                return riga.split("=", 1)[1].strip()
    except OSError:
        pass
    return "sessione"


def torna_e_riavvia(p, motivo):
    log("torno indietro:", motivo)
    try:
        A.ritorna(p["prima"], p.get("id"), motivo, cambiati=p.get("pacchetti"))
    except Exception as e:                     # non si riesce: si lascia tutto com'è e lo si dice nel registro
        log("ritorno indietro NON riuscito:", e)
        p["errore_ritorno"] = str(e)
        A._scrivi(A.IN_PROVA, p)
        return
    subprocess.run(["systemctl", "reboot"])


def main():
    p = A._leggi(A.IN_PROVA, None)
    if not p:
        return
    p["tentativi"] = p.get("tentativi", 0) + 1
    A._scrivi(A.IN_PROVA, p)
    log(f"aggiornamento {p.get('id')} in prova, tentativo {p['tentativi']}")
    if p["tentativi"] > A.TENTATIVI_MAX:
        return torna_e_riavvia(p, f"il desktop non è partito in {A.TENTATIVI_MAX} avvii")

    sg = segnale()
    inizio = time.monotonic()
    viste, corte, dm_buono = {}, 0, False
    while time.monotonic() - inizio < ATTESA_MAX:
        time.sleep(5)
        if sg.startswith("servizio:"):
            st = stato_unita(sg.split(":", 1)[1])
            if st[0] == "failed":
                return torna_e_riavvia(p, f"{sg.split(':', 1)[1]} non parte")
            if st[0] == "active" and time.monotonic() - inizio > SESSIONE_OK:
                A.conferma(f"{sg} attivo")
                return log("confermato")
            continue
        dm = stato_unita("display-manager.service")
        if dm[0] == "failed":
            return torna_e_riavvia(p, "il login grafico non parte")
        if not dm_buono and dm[0] == "active" and time.monotonic() - inizio > DM_OK:
            dm_buono = True                     # il login c'è: questo avvio non è un tentativo fallito
            p["tentativi"] = 0
            A._scrivi(A.IN_PROVA, p)
        ora = set(sessioni_grafiche())
        adesso = time.monotonic()
        for s in ora:
            viste.setdefault(s, adesso)
            if adesso - viste[s] >= SESSIONE_OK:
                A.conferma("sessione grafica riuscita")
                return log("confermato")
        for s in list(viste):
            if s not in ora:
                if adesso - viste[s] < CORTA_S:     # chiusa appena aperta: il desktop crolla
                    corte += 1
                    log("sessione grafica chiusa subito", corte)
                del viste[s]
        if corte >= SESSIONI_CORTE_MAX:
            return torna_e_riavvia(p, "il desktop si chiude appena entri")
    log("nessuna sessione grafica: l'aggiornamento resta in prova")


if __name__ == "__main__":
    main()
