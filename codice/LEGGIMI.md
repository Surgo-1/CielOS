# Ciel Codice

Il Codex di CielOS, fatto da noi: un agente che programma nei tuoi progetti.

- **App**: `ciel-codice app` (o dal lanciatore). Finestra flottante e centrata (regola in `cieltema`), una sola
  alla volta. Progetti e conversazioni a sinistra; in cima il modello e i permessi.
  Super+A → **Codice** non apre più questa app: è la pagina degli agenti da scaricare e aprire (FreeBuff, OpenCode,
  Aider, Crush, `cielagenti`). Ciel Codice resta qui, nel lanciatore e con `ciel-codice`.
- **Terminale**: `ciel-codice` nella cartella del progetto.
- **Motore** (`cielcodice/`, Python senza dipendenze esterne):
  - `fornitori.py`: Ollama (API sua, contesto scelto; se la scheda video è piena ripiega sul processore) e servizi
    in cloud compatibili OpenAI con piano gratuito (OpenRouter `:free`, Gemini, Groq, Cerebras, Mistral). Le chiavi
    le crea l'utente e le incolla nell'app: `~/.config/cielos/codice/chiavi.json` (0600).
  - `strumenti.py`: list_dir, read_file, search (ripgrep), write_file, edit_file, run_command. Modi dei permessi:
    piano (solo lettura), chiedi, progetto (di serie), libero (comandi isolati con bubblewrap). Comandi pericolosi
    chiedono sempre. Ogni turno si può annullare (copie degli originali).
  - `mcp.py`: plugin MCP (stdio), in `~/.config/cielos/codice/plugin.json`.
  - `sessione.py`: progetti, sessioni salvate (`~/.local/share/cielos/codice`), istruzioni di CielOS + `AGENTS.md`
    (globale in `~/.config/cielos/codice/`, e del progetto), il ciclo agente.
  - `__main__.py`: terminale, `servi` (protocollo JSON a righe per l'app), comandi di gestione.
- **IPC dell'app**: `qs -p ~/cielos/codice/app ipc call codice progetto|invia|modo|modello …`
- **Prove** senza toccare la scheda video: `CIEL_CODICE_CPU=1`.

Da fare: la Programmatrice di Ciel (assistente-vocale/ciel_code.py) passa a questo motore; Ciel che apre Codice a
voce; compattare la storia con un riassunto invece di accorciare le uscite vecchie; annullare anche gli effetti dei
comandi (oggi solo i file scritti dagli strumenti).
