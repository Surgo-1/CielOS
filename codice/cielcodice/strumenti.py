"""Gli strumenti di Ciel Codice: leggere, elencare, cercare, scrivere, modificare file, eseguire comandi.
Nomi e descrizioni in inglese (i modelli, soprattutto i piccoli locali, li usano meglio), etichette in italiano per l'app.

Permessi, per progetto (modo):
  «piano»     solo lettura: guarda il codice e propone, non scrive e non esegue niente che modifichi
  «chiedi»    ogni scrittura e ogni comando chiede a te
  «progetto»  (di serie) scrive liberamente dentro la cartella del progetto; i comandi chiedono, tranne quelli
              che leggono soltanto (ls, cat, git status/diff/log, rg…)
  «libero»    scrive e esegue da solo, ma i comandi girano isolati (bubblewrap): il disco è in sola lettura tranne
              la cartella del progetto e /tmp
Fuori dalla cartella del progetto si chiede sempre, e anche per i comandi pericolosi (sudo, rm -rf ~, mkfs, dd…). Prima di ogni scrittura il file originale viene copiato: un turno
si può annullare per intero."""
import difflib, os, re, shlex, shutil, subprocess, time
from pathlib import Path

MAX_USCITA = 20000

DEFINIZIONI = [
    {"name": "list_dir", "description": "List files and folders (respects .gitignore). Use it to explore the project.",
     "parameters": {"type": "object", "properties": {
         "path": {"type": "string", "description": "Folder, relative to the project root. Default: ."},
         "depth": {"type": "integer", "description": "How many levels deep (1-4). Default: 2"}}}},
    {"name": "read_file", "description": "Read a text file, with line numbers. For big files read a window with offset/limit.",
     "parameters": {"type": "object", "properties": {
         "path": {"type": "string"}, "offset": {"type": "integer", "description": "First line (1-based)"},
         "limit": {"type": "integer", "description": "How many lines (default 400)"}}, "required": ["path"]}},
    {"name": "search", "description": "Search file contents with a regular expression (ripgrep). Returns file:line:text.",
     "parameters": {"type": "object", "properties": {
         "pattern": {"type": "string"}, "path": {"type": "string", "description": "Folder or file. Default: ."},
         "glob": {"type": "string", "description": "Only files matching this glob, e.g. *.py"}}, "required": ["pattern"]}},
    {"name": "write_file", "description": "Create a file or replace its whole content. Prefer edit_file for small changes.",
     "parameters": {"type": "object", "properties": {
         "path": {"type": "string"}, "content": {"type": "string"}}, "required": ["path", "content"]}},
    {"name": "edit_file", "description": "Replace an exact piece of text in a file. old_text must appear exactly once "
                                         "(include enough surrounding lines), unless replace_all is true.",
     "parameters": {"type": "object", "properties": {
         "path": {"type": "string"}, "old_text": {"type": "string"}, "new_text": {"type": "string"},
         "replace_all": {"type": "boolean"}}, "required": ["path", "old_text", "new_text"]}},
    {"name": "run_command", "description": "Run a shell command (bash) in the project folder and get its output. "
                                           "No sudo: for admin actions, tell the user.",
     "parameters": {"type": "object", "properties": {
         "command": {"type": "string"}, "timeout": {"type": "integer", "description": "Seconds (default 120, max 900)"}},
         "required": ["command"]}},
]

ETICHETTE = {"list_dir": "Guarda la cartella", "read_file": "Legge", "search": "Cerca", "write_file": "Scrive",
             "edit_file": "Modifica", "run_command": "Esegue"}

# comandi che leggono soltanto: in modo «progetto» non chiedono (il primo comando di ogni pezzo della pipeline)
SOLO_LETTURA = {"ls", "cat", "head", "tail", "wc", "pwd", "rg", "grep", "find", "tree", "file", "stat", "du", "df",
                "which", "echo", "sort", "uniq", "diff", "less", "env", "date", "uname", "basename", "dirname", "realpath"}
PERICOLOSI = re.compile(r"(^|[;&|]\s*)(sudo|su|doas|pkexec)\b|\brm\s+-[a-z]*r[a-z]*\s+(/|~|\$HOME)(\s|/?$)|\bmkfs|"
                        r"\bdd\s+if=|:\(\)\s*\{|>\s*/dev/sd|\bshutdown\b|\breboot\b|\bgit\s+push\b.*--force|"
                        r"\bchmod\s+-R\s+777\s+/|\bpacman\s+-R", re.I)
GIT_LETTURA = {"status", "diff", "log", "show", "branch", "remote", "blame", "rev-parse", "ls-files"}


class Strumenti:
    def __init__(self, radice, modo="progetto", copie=None):
        self.radice = Path(radice).resolve()
        self.modo = modo
        self.copie = Path(copie) if copie else None       # cartella dove salvare gli originali di questo turno
        self.toccati = []                                 # [(percorso, copia o None se il file non c'era)]

    # ── dove ─────────────────────────────────────────────────────────────────────────────────────────────────
    def percorso(self, p):
        p = Path(os.path.expanduser(p or "."))
        return (p if p.is_absolute() else self.radice / p).resolve()

    def dentro(self, p):
        try:
            self.percorso(p).relative_to(self.radice)
            return True
        except ValueError:
            return False

    def relativo(self, p):
        q = self.percorso(p)
        try:
            return str(q.relative_to(self.radice)) or "."
        except ValueError:
            return str(q)

    # ── permessi ─────────────────────────────────────────────────────────────────────────────────────────────
    def serve_permesso(self, nome, a):
        """None se si può fare da solo, altrimenti il motivo (per la domanda all'utente)"""
        if nome in ("list_dir", "read_file", "search"):
            p = a.get("path", ".")
            if not self.dentro(p) and not str(self.percorso(p)).startswith(("/usr/", "/etc/", "/opt/")):
                return "vuole leggere fuori dal progetto"
            return None
        if self.modo == "piano" and (nome in ("write_file", "edit_file") or
                                     (nome == "run_command" and not _solo_lettura(a.get("command", "")))):
            return "NO"                            # in modo piano non si chiede nemmeno: è vietato
        if nome in ("write_file", "edit_file"):
            if not self.dentro(a.get("path", "")):
                return "vuole scrivere fuori dal progetto"
            return "vuole modificare un file" if self.modo == "chiedi" else None
        if nome == "run_command":
            if PERICOLOSI.search(a.get("command", "")):
                return "vuole eseguire un comando pericoloso"
            if self.modo == "libero":
                return None
            if self.modo == "progetto" and _solo_lettura(a.get("command", "")):
                return None
            return "vuole eseguire un comando"
        if nome.startswith("mcp__"):
            return None if self.modo == "libero" else "vuole usare un plugin"
        return "strumento sconosciuto"

    # ── esecuzione ───────────────────────────────────────────────────────────────────────────────────────────
    def esegui(self, nome, a, approvato=False):
        try:
            f = getattr(self, "_" + nome)
        except AttributeError:
            return f"Unknown tool: {nome}"
        try:
            return f(approvato=approvato, **{k: v for k, v in a.items() if not k.startswith("_")})
        except TypeError as e:
            return f"Error: wrong arguments for {nome}: {e}"
        except Exception as e:
            return f"Error: {e}"

    def _list_dir(self, path=".", depth=2, approvato=False):
        base = self.percorso(path)
        if not base.is_dir():
            return f"Error: {self.relativo(path)} is not a folder"
        depth = max(1, min(int(depth or 2), 4))
        r = subprocess.run(["rg", "--files", "--hidden", "-g", "!.git", "--max-depth", str(depth), str(base)],
                           capture_output=True, text=True, timeout=20)
        file = sorted(Path(x).relative_to(base) for x in r.stdout.splitlines())
        cartelle = sorted({str(p.parent) for p in file if str(p.parent) != "."})
        righe = [c + "/" for c in cartelle] + [str(p) for p in file]
        if len(righe) > 400:
            righe = righe[:400] + [f"… and {len(righe) - 400} more"]
        return "\n".join(righe) or "(empty)"

    def _read_file(self, path, offset=1, limit=400, approvato=False):
        p = self.percorso(path)
        if not p.is_file():
            return f"Error: {self.relativo(path)} does not exist"
        if p.stat().st_size > 5_000_000:
            return "Error: file too big (over 5 MB)"
        dati = p.read_bytes()
        if b"\0" in dati[:4000]:
            return "Error: binary file"
        righe = dati.decode(errors="replace").splitlines()
        offset = max(1, int(offset or 1))
        limit = max(1, min(int(limit or 400), 2000))
        pezzo = righe[offset - 1: offset - 1 + limit]
        testo = "\n".join(f"{i:>5}\t{r}" for i, r in enumerate(pezzo, offset))
        if offset - 1 + limit < len(righe):
            testo += f"\n… ({len(righe)} lines in total; continue with offset={offset + limit})"
        return testo or "(empty file)"

    def _search(self, pattern, path=".", glob=None, approvato=False):
        cmd = ["rg", "-n", "--no-heading", "--max-count", "50", "--max-columns", "300", "-e", pattern]
        if glob:
            cmd += ["-g", glob]
        r = subprocess.run(cmd + [str(self.percorso(path))], capture_output=True, text=True, timeout=30)
        uscita = r.stdout.replace(str(self.radice) + "/", "")
        return _tronca(uscita) or "(no matches)"

    def _salva_originale(self, p):
        if any(t[0] == p for t in self.toccati):
            return
        copia = None
        if p.exists() and self.copie:
            self.copie.mkdir(parents=True, exist_ok=True)
            copia = self.copie / f"{len(self.toccati)}_{p.name}"
            shutil.copy2(p, copia)
        self.toccati.append((p, copia))

    def _write_file(self, path, content, approvato=False):
        p = self.percorso(path)
        prima = p.read_text(errors="replace") if p.is_file() else None
        self._salva_originale(p)
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content)
        if prima is None:
            return f"Created {self.relativo(path)} ({len(content.splitlines())} lines)"
        return f"Rewrote {self.relativo(path)}\n" + diff(prima, content, self.relativo(path))

    def _edit_file(self, path, old_text, new_text, replace_all=False, approvato=False):
        p = self.percorso(path)
        if not p.is_file():
            return f"Error: {self.relativo(path)} does not exist"
        prima = p.read_text(errors="replace")
        n = prima.count(old_text)
        if n == 0:
            return "Error: old_text not found. Read the file again and copy the text exactly (spaces included)."
        if n > 1 and not replace_all:
            return f"Error: old_text appears {n} times: add more surrounding lines to make it unique, or set replace_all."
        dopo = prima.replace(old_text, new_text) if replace_all else prima.replace(old_text, new_text, 1)
        self._salva_originale(p)
        p.write_text(dopo)
        return f"Edited {self.relativo(path)}\n" + diff(prima, dopo, self.relativo(path))

    def _run_command(self, command, timeout=120, approvato=False):
        timeout = max(5, min(int(timeout or 120), 900))
        cmd = ["bash", "-lc", command]
        isolato = self.modo == "libero" and not approvato and shutil.which("bwrap")
        if isolato:
            cmd = ["bwrap", "--ro-bind", "/", "/", "--dev", "/dev", "--proc", "/proc", "--tmpfs", "/tmp",
                   "--bind", str(self.radice), str(self.radice), "--die-with-parent", "--chdir", str(self.radice)] + cmd
        t0 = time.time()
        try:
            r = subprocess.run(cmd, cwd=self.radice, capture_output=True, text=True, timeout=timeout,
                               env={**os.environ, "GIT_PAGER": "cat", "PAGER": "cat", "TERM": "dumb"},
                               stdin=subprocess.DEVNULL)
        except subprocess.TimeoutExpired as e:
            out = (e.stdout or b"").decode(errors="replace") if isinstance(e.stdout, bytes) else (e.stdout or "")
            return _tronca(out) + f"\n[stopped after {timeout} s]"
        out = r.stdout + (("\n[stderr]\n" + r.stderr) if r.stderr.strip() else "")
        return _tronca(out) + f"\n[exit code {r.returncode}, {time.time() - t0:.1f} s{', sandboxed' if isolato else ''}]"

    # ── annulla ──────────────────────────────────────────────────────────────────────────────────────────────
    def annulla(self):
        """rimette i file toccati in questo turno come erano (quelli nuovi li toglie)"""
        fatti = []
        for p, copia in reversed(self.toccati):
            if copia and copia.exists():
                shutil.copy2(copia, p)
            elif copia is None and p.exists():
                p.unlink()
            fatti.append(str(p))
        self.toccati = []
        return fatti


def _solo_lettura(comando):
    if re.search(r"[>`]|\$\(|\b(rm|mv|cp|tee|dd|chmod|chown|sudo|curl|wget)\b", comando):
        return False
    for pezzo in re.split(r"\|\||&&|\||;", comando):
        try:
            parole = shlex.split(pezzo)
        except ValueError:
            return False
        if not parole:
            continue
        if parole[0] == "git":
            if len(parole) < 2 or parole[1] not in GIT_LETTURA:
                return False
        elif parole[0] not in SOLO_LETTURA:
            return False
        if parole[0] == "find" and any(x in parole for x in ("-delete", "-exec", "-execdir", "-fprint")):
            return False
    return True

def _tronca(s):
    if len(s) <= MAX_USCITA:
        return s
    meta = MAX_USCITA // 2
    return s[:meta] + f"\n… [{len(s) - MAX_USCITA} characters cut] …\n" + s[-meta:]

def diff(prima, dopo, nome):
    righe = list(difflib.unified_diff(prima.splitlines(), dopo.splitlines(), f"a/{nome}", f"b/{nome}", lineterm="", n=2))
    if len(righe) > 200:
        righe = righe[:200] + [f"… ({len(righe) - 200} more diff lines)"]
    return "\n".join(righe)
