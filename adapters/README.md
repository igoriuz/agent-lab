# Adapter

Ein Adapter macht einen Harness benutzbar, ohne dass irgendetwas sonst im
Repo von ihm weiß. Das ist die Stelle, an der Harness-Eigenheiten sich
sammeln — und die einzige.

**agent-lab hängt an keinem Anbieter.** Skills, Gedächtnis, Evals und
Manifeste sind Markdown und JSON; kein Harness besitzt sie. Wenn Claude Code
morgen verschwindet, fehlt ein Adapter, sonst nichts.

## Warum das Skill-Format so aussieht, wie es aussieht

`SKILL.md` mit YAML-Frontmatter ist Claude Codes Konvention — behalten wird
sie aber nicht deshalb, sondern weil sie die **minimale neutrale Form** ist:

```markdown
---
name: app-monetization-audit
description: Wofür die Skill da ist und wann sie greift.
---

# Titel

Anweisungen in Markdown.
```

Ein Bezeichner, eine Beschreibung fürs Routing, ein Anweisungstext. Mehr
braucht keine Skill, und weniger geht nicht. Ein eigenes Format zu erfinden
wäre nur eine andere willkürliche Wahl mit demselben Inhalt.

Dass der Claude-Adapter dadurch fast ein No-Op ist, ist ein glücklicher
Nebeneffekt, keine Abhängigkeit.

## Vertrag

Jeder Adapter liegt unter `adapters/<harness>/` und liefert drei Dinge:

### `install.sh`

Bringt `skills/` und `memory/` dorthin, wo der Harness sie sucht.
Idempotent — mehrfaches Ausführen ändert nichts.

| Harness | Was zu tun ist |
|---|---|
| `claude` | Symlinks nach `~/.claude/skills/` — Format passt unverändert |
| `opencode` | Aus dem Frontmatter Agent-Definitionen erzeugen (`opencode agent create`), Anweisungstext als Body |
| neu | Frontmatter lesen, in die Konvention des Harness übersetzen |

### `run.sh` — der wichtige Teil

Führt **eine** Aufgabe aus. Damit Harnesses vergleichbar sind, müssen Ein-
und Ausgabe bei allen gleich aussehen. Sonst vergleicht man Äpfel mit Birnen
und merkt es nicht.

Eingabe über Umgebungsvariablen:

| Variable | Bedeutung |
|---|---|
| `TASK_PROMPT` | Was zu tun ist |
| `TASK_PROJECT` | Projektname, Manifest liegt in `config/projects/<name>.yaml` |
| `TASK_REPO` | Arbeitsverzeichnis (git worktree, exklusiv für diese Aufgabe) |
| `TASK_BRANCH` | Branch, auf dem das Ergebnis landen muss |
| `TASK_ROLE` | Rollenname aus `config/models.yaml` (`cheap`, `strong`, `heavy`, …) — Adapter löst dort auf |
| `TASK_ID` | Eindeutig, für die Zuordnung von Ergebnissen |
| `TASK_EFFORT` | Optional, `low` bis `max` — überschreibt `effort:` der Rolle. Bisher nur der Claude-Adapter |

Ausgabe: **eine Zeile JSON auf stdout**, sonst nichts. Logs nach stderr.

```json
{
  "task_id": "…",
  "harness": "opencode",
  "model": "opencode-zen/deepseek-v4-flash",
  "exit_code": 0,
  "duration_s": 143,
  "turns": 7,
  "tokens_in": 48210,
  "tokens_out": 3120,
  "cost_usd": 0.0,
  "branch": "…",
  "commits": 3
}
```

Nicht ermittelbare Felder: `null` statt geraten. **Eine erfundene Zahl ist
schlimmer als eine fehlende** — sie verfälscht den Vergleich still.

**Geplante Erweiterung.** Für Zielarbeit braucht der Vertrag ein `status`-Feld
(`done | needs_review | blocked_on_human | unsatisfiable`) und ein `learned`,
über das Lektionen zurückkommen, ohne dass Agenten selbst in `memory/`
schreiben. Begründung und Format: [../orchestrator/README.md](../orchestrator/README.md).
Noch nicht umgesetzt — die drei vorhandenen Adapter liefern es nicht.

### `README.md`

Was der Harness kann, was nicht, und welche Felder er nicht liefert.

## Was der Vergleich misst

Objektives fällt beim Ausführen an: laufen die `checks:` aus dem Manifest
durch, wie lange, wie viele Runden, was hat es gekostet. Das Subjektive
kommt über die Bridge — Zusammenfassung und Diff aufs Handy, 👍/👎 und eine
Zeile Begründung.

Beides zusammen, über Wochen, auf **echter Arbeit**. Das ist der Punkt:
Synthetische Benchmarks sagen dir, welcher Harness allgemein gut ist. Du
willst wissen, welcher für deine Projekte gut ist.

## Stand

| Adapter | Status |
|---|---|
| `claude` | offen |
| `opencode` | offen — Provider `opencode-go`, `opencode-zen`, `openrouter` konfiguriert |
| `oh-my-pi` | gemessen, drei Modelle über die Ladder |
| `hermes` | seit 2026-09-13 — Harness läuft in CT 103, Arbeit in CT 102, siehe [hermes/README.md](hermes/README.md) |

Zwei Adapter reichen als Beweis, dass der Vertrag trägt. Erst danach lohnt
ein dritter.
