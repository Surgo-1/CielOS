"""L'archivio su Archil: i file che devono sopravvivere a un'esecuzione.

Il disco è quello indicato da ARCHIL_DISK_ID (dsk-…). La chiave API sta in ARCHIL_API_KEY (comincia con «key-»: un
token di disco/mount adt_… non vale) e la regione in ARCHIL_REGION (di serie aws-us-east-1: la chiave funziona solo
nella regione in cui è stata creata). Tutto resta lato server: la chiave non va mai in una pagina web.

    from archivio import disco, esegui, scrivi, leggi

    disco()                                 # il disco di ARCHIL_DISK_ID
    esegui("ls -l /mnt/data")               # exec: disco montato in /mnt/data, ogni exec un container nuovo
    scrivi("rapporti/oggi.txt", "ciao")     # put_object
    leggi("rapporti/oggi.txt")              # get_object

Serve il pacchetto archil==0.17.0 (requirements.txt).
"""
import os
from pathlib import Path

import archil

REGIONE_DI_SERIE = "aws-us-east-1"
ENV = Path(__file__).resolve().parent.parent / ".env"


def _carica_env():
    """Legge il .env del repository (se c'è): le variabili già nell'ambiente vincono."""
    try:
        righe = ENV.read_text().splitlines()
    except OSError:
        return
    for riga in righe:
        riga = riga.strip()
        if not riga or riga.startswith("#") or "=" not in riga:
            continue
        nome, valore = riga.split("=", 1)
        os.environ.setdefault(nome.strip(), valore.strip().strip("\"'"))


def chiave():
    """La chiave API Archil (ARCHIL_API_KEY); un token di disco/mount (adt_…) non vale."""
    _carica_env()
    valore = (os.environ.get("ARCHIL_API_KEY") or "").strip()
    if not valore:
        raise RuntimeError("ARCHIL_API_KEY non impostata: serve una chiave API Archil (comincia con «key-»)")
    if not valore.startswith("key-"):
        raise RuntimeError("ARCHIL_API_KEY non è una chiave API (deve cominciare con «key-»): "
                           "i token dei dischi (adt_…) non funzionano, le chiavi valgono solo nella loro regione")
    return valore


def regione():
    """La regione della chiave (ARCHIL_REGION, di serie aws-us-east-1)."""
    _carica_env()
    return (os.environ.get("ARCHIL_REGION") or "").strip() or REGIONE_DI_SERIE


def configura():
    """Configura l'SDK Archil dalle variabili d'ambiente; solleva RuntimeError se la chiave manca."""
    archil.configure(api_key=chiave(), region=regione())
    return archil


def identificativo():
    """L'identificativo del disco (ARCHIL_DISK_ID, dsk-…)."""
    _carica_env()
    valore = (os.environ.get("ARCHIL_DISK_ID") or "").strip()
    if not valore:
        raise RuntimeError("ARCHIL_DISK_ID non impostato: serve l'identificativo del disco (dsk-…)")
    return valore


def disco(ident=None):
    """Il disco indicato (di serie quello di ARCHIL_DISK_ID)."""
    configura()
    return archil.get_disk(ident or identificativo())


def crea_disco(nome):
    """Crea un disco nuovo e restituisce il disco. Il token di mount resta qui: non si stampa mai."""
    configura()
    return archil.create_disk(name=nome).disk


def esegui(comando, d=None):
    """Esegue un comando sul disco (exec): montato in /mnt/data, ogni exec è un container nuovo."""
    return (d or disco()).exec(comando)


def scrivi(chiave_oggetto, contenuto, d=None):
    """Scrive un file sul disco (put_object); contenuto testo o bytes."""
    return (d or disco()).put_object(chiave_oggetto, contenuto)


def leggi(chiave_oggetto, d=None):
    """Legge un file dal disco (get_object) e lo restituisce come testo."""
    contenuto = (d or disco()).get_object(chiave_oggetto)
    if isinstance(contenuto, (bytes, bytearray)):
        return contenuto.decode("utf-8", "replace")
    return contenuto
