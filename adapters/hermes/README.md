# Adapter: hermes

Erfüllt den Vertrag aus [../README.md](../README.md). Hermes Agent (Nous
Research, MIT), laufend in CT 103 auf dem Mini-PC. Warum Hermes überhaupt und
was es im Gesamtbild ist: [../../orchestrator/hermes.md](../../orchestrator/hermes.md).

## Topologie — der Unterschied zu den anderen drei

Die anderen Adapter rufen einen Harness auf derselben Maschine auf. Hermes
läuft **woanders** (CT 103), und sein Terminal-Backend zeigt per SSH zurück
auf den Worker (CT 102), wo der Adapter und das Arbeitsverzeichnis liegen:

```
CT 102 (Worker)                          CT 103 (Hermes)
run.sh ── ssh hermes@.21 ──────────────▶ hermes -z "$PROMPT" …
   ▲                                           │ TERMINAL_ENV=ssh
   └────── Terminal- und Dateibefehle ◀────────┘ TERMINAL_CWD=$TASK_REPO
           landen in $TASK_REPO
```

Gemessen 2026-09-13: Terminal **und** Dateiwerkzeuge (`write_file` usw.)
arbeiten über das Backend auf 102, nicht lokal auf 103. `TERMINAL_CWD`
setzt das Arbeitsverzeichnis im Backend; `--in DIR` tut das nicht.

Folge: Modell-Keys liegen nur in 103. Der Agent kann seine eigene `.env`
nicht lesen und seinen Code nicht ändern. Das ist das von Hermes dokumentierte
Sicherheitsmuster, kein Zufall der Topologie.

## Einrichtung

| Wo | Was |
|---|---|
| CT 102, User `agent` | `~/.ssh/id_ed25519`, Public Key in 103 bei `hermes` autorisiert; Host-Key von `.21` in `known_hosts` |
| CT 103, User `hermes` | `~/.ssh/id_ed25519`, Public Key in 102 bei `agent` autorisiert; `TERMINAL_ENV=ssh`, `TERMINAL_SSH_HOST=192.168.1.20`, `TERMINAL_SSH_USER=agent`, `TERMINAL_SSH_KEY` in `~/.hermes/.env` **und** `terminal.backend: ssh` samt `ssh_host`/`ssh_user`/`ssh_port` in `config.yaml` — der `terminal:`-Block der Config überschreibt die `.env`, den Schlüsselpfad liest aber nur die `.env` |
| CT 103, Credentials | `hermes auth add <provider> --type api-key` (verdeckte Abfrage) bzw. `hermes model` für OAuth. Nie per `config set` und nie über eine Shell-History |

`HERMES_SSH` (Standard `hermes@192.168.1.21`) und `HERMES_TOOLSETS`
(Standard `terminal,file`, leer = Hermes-Standard) sind die beiden Regler.

Modellangabe `provider/modell`, getrennt am **ersten** Schrägstrich:
`xai-oauth/grok-4.6`, `openrouter/z-ai/glm-5.3-flash`.

`install.sh` spiegelt `skills/` einweg nach `~/.hermes/skills/agent-lab/`.
`memory/` wird bewusst nicht übertragen.

## Was er liefert

Quelle ist der `--usage-file`-Bericht von `hermes -z`, der auch bei
Fehlschlag geschrieben wird.

| Feld | Quelle | Verlässlich |
|---|---|---|
| `turns` | `api_calls` | ja — aber es sind **API-Aufrufe**, keine „Runden" wie bei oh-my-pi (`turn_start`). In einem Tool-Loop ist das dasselbe: eine Modellantwort pro Aufruf |
| `tokens_in` | `input_tokens + cache_read_tokens + cache_write_tokens` | ja; Cache zählt zur Eingabe wie im Claude-Adapter |
| `tokens_out` | `output_tokens` | ja; `reasoning_tokens` separat als Zusatzfeld, ob sie in `output_tokens` enthalten sind, sagt Hermes nicht |
| `cost_usd` | `estimated_cost_usd`, nur wenn `cost_status ≠ unknown` | bei OAuth-Abos `null` — Hermes schreibt dort `0.0` mit `cost_status: unknown`, und **0 ist nicht „nicht gemessen"** |
| `commits` | `git rev-list BEFORE..AFTER` im Worker | ja |
| `exit_code` | SSH-Rückgabe, überstimmt von `failed`/`completed` im Bericht | ja |
| `model` | `provider/model` aus dem Bericht | ja |

## Ohne Vorgeschichte

Jeder `-z`-Lauf ist eine neue Session, aber Hermes' eingebautes Gedächtnis
überlebt Sessions. Ein zweiter Lauf derselben Aufgabe hätte damit einen
Vorteil, den kein anderer Harness hat. Deshalb der Standard
`HERMES_TOOLSETS=terminal,file`: kein `memory`, keine Skills, kein Web. Für
Zielarbeit außerhalb der Evals ist das falsch — dort gehört das Gedächtnis
dazu, und der Aufrufer setzt `HERMES_TOOLSETS=`.

## Beobachtungen aus der Inbetriebnahme

**Der Schleifenweg kostet nichts Messbares.** Neun Läufe über 102 → 103 → 102,
kein SSH-Aussetzer, keine hängende Verbindung. Die Dauer liegt im Bereich der
anderen Harnesses.

**Weniger Kontext als oh-my-pi bei gleichem Modell.** grok-4.6 braucht über
Hermes mit `-t terminal,file` 1,8- bis 2,9-mal weniger Eingabe-Token als über
oh-my-pi im vollen Modus, bei 9/9 auf S/M/L. Zahlen in
[../../evals/README.md](../../evals/README.md).

**Ein 402 sieht aus wie ein schlechtes Modell, wenn man nicht aufpasst.** Die
GLM-Flash-Ladder scheiterte komplett an fehlendem OpenRouter-Guthaben. Der
erste Lauf trug die Fehlermeldung, die acht weiteren nur `exit_code: 1`,
`tokens_in: 0`, kein Text. Seitdem: null API-Aufrufe → `error:
kein_api_aufruf`, Token-Felder `null`. Dieselbe Klasse Messfehler wie der
fehlende OAuth-Token beim Claude-Adapter.

**`reasoning_tokens` sind erheblich**: bei grok-4.6 zwischen 40 und 70 % der
`output_tokens`. Ob sie darin enthalten sind, sagt der Bericht nicht; sie
stehen als eigenes Feld in den Rohdaten.
