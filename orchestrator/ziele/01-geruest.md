# Ziel 01 — Gerüst für Zielarbeit

**Zugewiesen an:** Agent · **Harness:** offen · **Modell:** `openrouter/meta/muse-spark-1.3-contributor`
**Freigabe:** **zurückgestellt 2026-09-13** · **Versuchsbudget:** 3

> Zurückgestellt, nicht verworfen: Hermes bringt mit `/goal` einen Goal-Contract
> (`outcome`, `verification`, `constraints`, `boundaries`, `stop_when`) mit, der
> `ziel.py` und `lauf.py` weitgehend ersetzt. Erst der Hands-Trial zeigt, was
> davon noch zu bauen ist — siehe [../hermes.md](../hermes.md), Schritt 5.

> Dies ist die erste Zieldatei nach dem Format aus
> [../README.md](../README.md). Sie ist selbst ein Test des Formats.
> **Die Abnahme liegt nicht in diesem Dokument** — sie wird erst nach dem
> Lauf eingespielt, wie `pruefung.test.ts` bei den Evals.

## Absicht

agent-lab kann Aufgaben ausführen und messen, aber nicht *auf ein Ziel hin*
arbeiten. Es fehlt das Gerüst dazwischen: etwas, das ein Ziel einliest, es
gegen Veränderung sichert, daraus Aufgaben an einen Adapter gibt und die
Ergebnisse auswertet, ohne dass ein Mensch dabeisitzt.

Gebaut wird **nur dieses Gerüst**, nicht der ganze Ablauf. Recherche,
Zielableitung und die Telegram-Freigabe bleiben ausdrücklich draußen.

## Was zu bauen ist

### `orchestrator/ziel.py`

Liest eine Zieldatei, validiert sie, sichert sie gegen Veränderung.

| Funktion | Verhalten |
|---|---|
| `lade(pfad)` | Parst die Datei, gibt ein Ziel-Objekt zurück. Fehlende Pflichtfelder → verständlicher Fehler, kein Stacktrace |
| `pruefe(ziel)` | Validiert Pflichtfelder und Typen. Gibt eine Liste von Mängeln zurück, leer heißt gültig |

**Kein Hash und keine Freigabeprüfung hier.** Das Einfrieren des Ziels ist
`git rev-parse HEAD:<pfad>` und gehört ins **äußere** Skript. Ein Artefakt,
das seine eigene Freigabe prüft, prüft nichts.

Pflichtfelder: `ziel`, `absicht`, `erwartungen` (Liste, nicht leer),
`budget_versuche` (Zahl > 0). Optional: `abnahme`, `verworfene_alternativen`.

### `orchestrator/lauf.py`

Führt Aufgaben gegen ein Ziel aus. Ruft Adapter über den bestehenden Vertrag
auf — **das Muster steht in `bin/eval-run.sh`, Zeilen 57–65**, und daran ist
nichts zu ändern.

- Setzt `TASK_ID`, `TASK_REPO`, `TASK_BRANCH`, `TASK_ROLE`, `TASK_MODEL`,
  `TASK_PROMPT`, `TASK_TIMEOUT` und ruft `adapters/<harness>/run.sh`
- Liest **eine Zeile JSON** von stdout. Kaputte oder fehlende Ausgabe ist ein
  Fehlschlag mit Meldung, kein Absturz und kein geratener Wert
- Wertet `status` aus: `done` · `needs_review` · `blocked_on_human` ·
  `unsatisfiable`. Fehlt das Feld, gilt der bisherige Vertrag
  (`exit_code` plus `commits`)
- Zählt Versuche pro Ziel. Bei `budget_versuche` erschöpft: Abbruch mit
  `unsatisfiable`, nicht weiterlaufen
- Zählt offene Blocker. Bei **drei** offenen: keine neue Aufgabe mehr annehmen
- Schreibt ein zurückgegebenes `learned` nach `memory/<projekt>.md`.
  **Nur diese Datei schreibt in `memory/`** — Adapter tun das nie

### Tests

Zu jeder der beiden Dateien Tests, lauffähig mit `python3 -m unittest`. Der
Adapteraufruf wird dabei durch ein Stub-Skript ersetzt, das eine feste
JSON-Zeile ausgibt — kein Netz, kein Modell, kein Geld im Test.

## Erwartungen

Sichtbar und ausführbar. Erfüllt heißt: alle vier Befehle laufen erfolgreich
durch.

```
python3 -m unittest discover -s orchestrator -p "test_*.py"
python3 -c "import orchestrator.ziel, orchestrator.lauf"
```

Das ist alles, was der Arbeiter an sich selbst prüfen darf — eine
**Fortschrittsanzeige**, keine Abnahme.

Die **Grenzprüfung** (nur `orchestrator/` verändert) und die **Abnahme**
laufen im äußeren Skript, nach dem Lauf, gegen ein Ziel, das der Arbeiter
nie gesehen hat.

## Wer treibt, wer wird gebaut

| | Rolle |
|---|---|
| `bin/ziel-run.sh` | **Von Hand geschrieben.** Treibt diesen Lauf: Worktree, Blob-Hash, Versuchsschleife, Abnahme einspielen, Grenzprüfung. Ist die Loop und die Bremse |
| `orchestrator/lauf.py` | **Das Produkt.** Wird in diesem Lauf gebaut und hier nicht benutzt. Es treibt später *andere* Ziele, nie sich selbst |

## Grenzen

- Neue Dateien nur unter `orchestrator/`
- `adapters/*/run.sh`, `bin/*`, `config/*`, `README.md`, `evals/*`
  bleiben unverändert
- Keine Abhängigkeit außer der Standardbibliothek. Wird PyYAML gebraucht,
  muss der Fehlschlag ohne sie verständlich sein
- Kein Netzzugriff im Code, keine API-Aufrufe, keine Schlüssel lesen
- Ergebnis auf `TASK_BRANCH`, nie auf `main`

## Verworfene Alternativen

| Verworfen | Warum |
|---|---|
| Ticketsystem mit atomarem Claim | Der Orchestrator *weist zu*, statt Agenten ziehen zu lassen — dann braucht es keinen Claim. Siehe [../README.md](../README.md), „Was bewusst nicht gebaut wird" |
| Ein Orchestrator pro Projekt | Bei dieser Größe eine Schleife mit `projekt` als Parameter |
| Telegram-Freigabe in diesem Lauf | Eigener Brocken. Das Gerüst muss ohne Bridge testbar sein, sonst ist es nicht testbar |
| Recherche und Zielableitung | Eine Skill, kein Baustein |
| Zustand in SQLite | Bricht die Portabilitätsthese. Markdown in git, wie alles andere |

## Abnahme

Verdeckt. Wird nach dem Lauf eingespielt und prüft, ob das Gerüst mit einem
Ziel arbeitet, das es beim Bau nicht gesehen hat.
