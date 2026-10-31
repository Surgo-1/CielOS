#!/usr/bin/env python3
"""Strumento per annotare sessioni CielOS nel vault Obsidian."""

import os
import sys
import json
from datetime import datetime
from pathlib import Path

VAULT = Path(os.environ.get("OBSIDIAN_VAULT", Path.home() / "Documenti" / "Obsidian" / "AI"))
PROJ = VAULT / "Progetti" / "CielOS"
DIARIO = PROJ / "Diario"

def ensure_dirs():
    DIARIO.mkdir(parents=True, exist_ok=True)
    (PROJ / ".obsidian").mkdir(exist_ok=True)

def today_file():
    now = datetime.now()
    return DIARIO / f"{now:%Y-%m-%d %H.%M}.md"

def write_note(title: str, body: str):
    ensure_dirs()
    tf = today_file()
    existing = tf.read_text() if tf.exists() else ""
    now = datetime.now().strftime("%d %b %Y %H:%M")
    block = f"## {now} — {title}\n\n{body}\n\n"
    tf.write_text(existing + block)
    return tf

def main():
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help"):
        print("usage: note.py <title> <body...>")
        print("       note.py --index")
        print("       note.py --recent [n]")
        return
    
    if sys.argv[1] == "--index":
        idx = PROJ / "CielOS.md"
        print(idx.read_text() if idx.exists() else "Indice non creato")
    elif sys.argv[1] == "--recent":
        n = int(sys.argv[2]) if len(sys.argv) > 2 else 10
        files = sorted(DIARIO.glob("*.md"), reverse=True)[:n]
        for f in files:
            print(f" - {f.name}")
    else:
        title = sys.argv[1]
        body = " ".join(sys.argv[2:]) if len(sys.argv) > 2 else ""
        tf = write_note(title, body)
        print(f"Nota aggiunta: {tf}")

if __name__ == "__main__":
    main()
