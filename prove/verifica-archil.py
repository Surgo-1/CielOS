#!/usr/bin/env python3
"""Prova che l'archivio Archil duri più di un'esecuzione: scrive in un exec, rilegge in un altro.

  .venv/bin/python prove/verifica-archil.py     (oppure python3, con archil installato: requirements.txt)

Serve ARCHIL_API_KEY (chiave API, comincia con «key-»; non un token di mount adt_…), letta anche dal .env del
repository. Il disco è ARCHIL_DISK_ID; se manca ne crea uno nuovo e ne stampa nome e identificativo (da mettere in
.env), mai il token di mount. Esce diverso da zero se la seconda esecuzione non rilegge quello che ha scritto la prima.
"""
import os
import shlex
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

try:
    from archivio import chiave, crea_disco, disco, regione
except ImportError as errore_import:
    print(f"ERRORE: manca il pacchetto archil ({errore_import}).\n"
          "Installa: pip install --only-binary=:all: archil==0.17.0 (oppure usa .venv/bin/python).", file=sys.stderr)
    sys.exit(2)


def errore(testo):
    print(f"ERRORE: {testo}", file=sys.stderr)
    return 1


def main():
    try:
        chiave()            # carica il .env e controlla che ci sia una chiave API (key-)
    except RuntimeError as e:
        return errore(f"{e}\nUna chiave API si prende da https://console.archil.com/api-keys.")

    identificativo = (os.environ.get("ARCHIL_DISK_ID") or "").strip()
    creato = False
    try:
        if identificativo:
            d = disco(identificativo)
        else:
            d = crea_disco(f"cielos-prova-{uuid.uuid4().hex[:8]}")
            creato = True
    except Exception as e:
        return errore(f"non riesco ad aprire o creare il disco: {e}")

    print(f"Disco:   {d.name} ({d.id}){' — creato ora' if creato else ''}")
    print(f"Regione: {regione()}")
    if creato:
        print(f"Metti in .env: ARCHIL_DISK_ID={d.id}")

    # Sottocartella nuova a ogni giro: in exec il disco è montato in condivisione e l'impronta la prende chi scrive.
    cartella = f"prova-{uuid.uuid4().hex[:12]}"
    percorso = f"{cartella}/riga.txt"
    riga = f"cielos {datetime.now(timezone.utc).isoformat()} {uuid.uuid4().hex}"

    primo = d.exec(f"mkdir -p {shlex.quote(cartella)} && printf '%s\\n' {shlex.quote(riga)} > {shlex.quote(percorso)}")
    if primo.exit_code != 0:
        return errore(f"la scrittura è fallita (exit {primo.exit_code}): {(primo.stderr or '').strip()}")

    secondo = d.exec(f"cat {shlex.quote(percorso)}")              # un'altra esecuzione, un altro container
    if secondo.exit_code != 0:
        return errore(f"la rilettura è fallita (exit {secondo.exit_code}): {(secondo.stderr or '').strip()}")

    letto = (secondo.stdout or "").strip()
    if riga not in letto:
        return errore(f"la seconda esecuzione non ha riletto la riga scritta: {letto!r}")

    print(f"Scritto: {percorso}")
    print(f"Riletto: {letto}")
    print("OK: il file è sopravvissuto all'esecuzione.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
