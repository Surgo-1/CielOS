#!/usr/bin/env python3
"""Il rapporto di un giro del collaudo (prove/collaudo/collaudo.sh): legge quello che è uscito dalla VM, trova i
problemi e li confronta con quelli già visti nei giri prima (una «firma» per problema, senza numeri, indirizzi e orari:
lo stesso guasto ha la stessa firma). I problemi NUOVI diventano una issue «[collaudo] …» su Surgo-1/CielOS
(etichetta «collaudo»); quelli già segnalati e ancora aperti ricevono solo «rivisto il …». Il rapporto completo resta
in vm/collaudo/giri/<giro>/rapporto.md.
  rapporto.py GIRO [--no-issue] [--non-parte]
  rapporto.py --modello           il modello di Ollama per l'esploratore (il più piccolo che sa chiacchierare)"""
import hashlib, json, re, subprocess, sys, time, urllib.request
from pathlib import Path

REPO = "Surgo-1/CielOS"
C = Path.home() / "cielos/vm/collaudo"
FIRME = C / "firme.json"
# rumore della VM o di Arch, non di CielOS: non diventa una issue
RUMORE = [r"TDX not supported", r"nl80211", r"multicast RX", r"pcspkr", r"vmwgfx", r"bochs", r"virtio_balloon", r"EDID",
          r"Failed to find module 'nvidia", r"kvm: ", r"sev", r"RAPL", r"ACPI", r"cannot get freq at ep", r"bluetooth",
          r"hci0", r"wpa_supplicant", r"pkcs11", r"gkr-pam", r"No such file or directory: '/dev/dri/renderD",
          r"Failed to open .*/dev/rfkill", r"Bluetooth", r"wireplumber.*(libcamera|bluez)", r"rtkit", r"sddm-helper.*pam"]


def firma(testo):
    t = testo.lower()
    t = re.sub(r"^\s*\[\s*[\d.]+\]\s*", "", t, flags=re.M)              # [ 123.456] del kernel
    t = re.sub(r"\b0x[0-9a-f]+\b|\b[0-9a-f]{8,}\b", "H", t)              # indirizzi, hash
    t = re.sub(r"\d+", "N", t)
    t = re.sub(r"/tmp/\S+", "/tmp/X", t)
    t = re.sub(r"\s+", " ", t).strip()
    return hashlib.sha1(t[:400].encode()).hexdigest()[:12]


def rumore(riga):
    return any(re.search(r, riga) for r in RUMORE)


def problemi_del_giro(R, non_parte):
    P = []    # {titolo, dettaglio, dove, firma}

    def aggiungi(titolo, dettaglio, dove, chiave=None):
        P.append({"titolo": titolo, "dettaglio": dettaglio.strip()[-3000:], "dove": dove, "firma": firma(chiave or titolo + dettaglio[:300])})

    if non_parte:
        ser = (R / "seriale.log").read_text(errors="replace")[-4000:] if (R / "seriale.log").exists() else ""
        aggiungi("La VM non si accende (o non risponde) dopo l'aggiornamento", ser, "avvio", "non-parte")
    agg = (R / "aggiornamento.log")
    if agg.exists():
        err = [r for r in agg.read_text(errors="replace").splitlines() if r.startswith("error:") or "errore:" in r.lower()]
        if err:
            aggiungi("L'aggiornamento (pacman -Syu) dà errori", "\n".join(err[-30:]), "aggiornamento", "agg:" + "\n".join(err[:3]))
    ser = R / "seriale.log"
    if ser.exists():
        k = [r for r in ser.read_text(errors="replace").splitlines() if re.search(r"Kernel panic|BUG:|Oops|Call Trace", r)]
        if k:
            aggiungi("Errori gravi del kernel (console seriale)", "\n".join(k[-40:]), "kernel", "ser:" + k[0])
    ris = R / "collaudo" / "risultati.json"
    if not ris.exists():
        if not non_parte:
            aggiungi("Le prove non hanno prodotto risultati", (R / "prove.log").read_text(errors="replace")[-3000:]
                     if (R / "prove.log").exists() else "", "collaudo", "senza-risultati")
        return P, {}
    d = json.loads(ris.read_text())
    for p in d["prove"]:
        if not p["ok"]:
            aggiungi(f"{p['fase']}: {p['nome']}", p["dettaglio"], p["fase"], p["fase"] + p["nome"].split(" ")[0] + p["dettaglio"][:200])
    s = d["sistema"]
    for riga in (s.get("coredump") or "").splitlines():
        m = re.search(r"\s(\d+)\s+\d+\s+\d+\s+\S+\s+\S+\s+(\S+)\s*$", riga)
        exe = m.group(2) if m else riga.split()[-1] if riga.split() else riga
        aggiungi(f"Crash: {exe}", riga, "coredump", "core:" + exe)
    for chiave, titolo in (("kernel", "Kernel"), ("falliti_sistema", "Servizio di sistema fallito"),
                           ("falliti_utente", "Servizio dell'utente fallito")):
        for riga in (s.get(chiave) or "").splitlines():
            if riga.strip() and not rumore(riga):
                aggiungi(f"{titolo}: {riga.split()[0]}", riga, chiave)
    for chiave in ("errori_sistema", "errori_utente"):
        visti = set()
        for riga in (s.get(chiave) or "").splitlines():
            if not riga.strip() or rumore(riga):
                continue
            corpo = re.sub(r"^\[\s*[\d.]+\]\s*\S+\s+", "", riga)       # senza tempo e nome del PC
            corpo = re.sub(r"^\w{3} \d+ [\d:]+ \S+ ", "", corpo)
            f = firma(corpo)
            if f in visti:
                continue
            visti.add(f)
            aggiungi(f"Registro: {corpo[:90]}", riga, chiave, corpo)
    return P, d


def gh(*a, entrata=None):
    return subprocess.run(["gh", *a], capture_output=True, text=True, input=entrata, timeout=120)


def main():
    a = sys.argv[1:]
    if "--modello" in a:
        try:
            with urllib.request.urlopen("http://127.0.0.1:11434/api/tags", timeout=5) as r:
                m = json.loads(r.read())["models"]
        except OSError:
            return
        chat = [x for x in m if (x.get("details") or {}).get("family") not in ("bert", "nomic-bert") and x["size"] > 1e9
                and not x["name"].endswith("-testo")]
        if chat:
            print(min(chat, key=lambda x: ("instruct" not in x["name"].lower(), x["size"]))["name"])   # meglio un instruct
        return
    R = Path(a[0])
    no_issue, non_parte = "--no-issue" in a, "--non-parte" in a
    P, d = problemi_del_giro(R, non_parte)
    viste = json.loads(FIRME.read_text()) if FIRME.exists() else {}
    oggi = time.strftime("%d/%m/%Y %H:%M")
    nuovi = [p for p in P if p["firma"] not in viste]
    gia = [p for p in P if p["firma"] in viste]
    prove = d.get("prove", [])
    saltate = [p for p in prove if p.get("saltata")]        # non c'è in questa versione: non sono guasti
    versioni = (R / "versioni.txt").read_text().strip() if (R / "versioni.txt").exists() else "?"
    fasi = {}
    for p in prove:
        f = fasi.setdefault(p["fase"], [0, 0])
        f[0] += 1
        f[1] += 0 if p["ok"] else 1
    righe = [f"# Collaudo del {oggi}", "", f"Versioni: `{' · '.join(versioni.splitlines())}`",
             f"Modello dell'esploratore: {d.get('modello') or 'nessuno (azioni a caso)'}", "",
             "| fase | prove | non riuscite |", "|---|---|---|"]
    righe += [f"| {k} | {v[0]} | {v[1]} |" for k, v in fasi.items()]
    righe += ["", f"**Problemi nuovi: {len(nuovi)}** · già visti: {len(gia)}" +
              (f" · prove saltate (non in questa versione di CielOS): {len(saltate)}" if saltate else ""), ""]
    for p in nuovi:
        righe += [f"### {p['titolo'][:120]}", f"Dove: {p['dove']} · firma `{p['firma']}`", "", "```", p["dettaglio"][-2000:], "```", ""]
    if gia:
        righe += ["### Già visti", ""] + [f"- {p['titolo'][:120]} (firma `{p['firma']}`, issue #{viste[p['firma']].get('issue') or '—'})" for p in gia]
    if saltate:
        righe += ["### Prove saltate (non sono guasti)", "",
                  "Nella VM gira una CielOS più vecchia del repository: questi comandi arrivano con l'aggiornamento."]
        righe += [f"- {p['nome'][:120]}" for p in saltate]
    righe += ["", f"Il giro completo (foto di ogni passo, registri) sul PC: `{R}`"]
    testo = "\n".join(righe)
    (R / "rapporto.md").write_text(testo + "\n")
    print(f"rapporto: {R / 'rapporto.md'} — {len(nuovi)} problemi nuovi, {len(gia)} già visti")
    numero = None
    # i problemi del collaudo stesso (eccezioni nello script) restano nel rapporto ma non aprono issue
    da_segnalare = [p for p in nuovi if "eccezione nel collaudo" not in p["dettaglio"]]
    if da_segnalare and not no_issue:
        gh("label", "create", "collaudo", "--color", "E8B04A", "--description", "Trovato dal collaudo automatico", "--repo", REPO, "--force")
        titolo = f"[collaudo] {len(da_segnalare)} problem{'a' if len(da_segnalare) == 1 else 'i'}: {da_segnalare[0]['titolo'][:70]}"
        r = gh("issue", "create", "-R", REPO, "--title", titolo, "--label", "collaudo", "--body-file", "-", entrata=testo[:60000])
        if r.returncode == 0:
            numero = r.stdout.strip().rsplit("/", 1)[-1]
            print(f"issue: {r.stdout.strip()}")
        else:
            print("issue non aperta: " + r.stderr.strip()[:300])
    if not no_issue:
        # i già visti: un commento sulle issue ancora aperte (una volta per giro e per issue)
        commentate = set()
        for p in gia:
            n = viste[p["firma"]].get("issue")
            if n and n not in commentate:
                commentate.add(n)
                gh("issue", "comment", str(n), "-R", REPO, "--body", f"Rivisto dal collaudo del {oggi} (`{versioni.splitlines()[0] if versioni else ''}`).")
    if no_issue:              # una prova del collaudo: le firme non si segnano (il prossimo giro vero le segnala)
        return
    for p in nuovi:
        viste[p["firma"]] = {"titolo": p["titolo"][:120], "prima": oggi, "volte": 1, "issue": numero if p in da_segnalare else None}
    for p in gia:
        viste[p["firma"]]["volte"] = viste[p["firma"]].get("volte", 1) + 1
        viste[p["firma"]]["ultima"] = oggi
    FIRME.write_text(json.dumps(viste, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
