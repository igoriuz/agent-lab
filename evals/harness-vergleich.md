# Harness-Vergleich — Messungen

Rohdaten aus echten Läufen. Keine synthetischen Benchmarks: Es geht darum,
welcher Harness für **diese** Arbeit taugt, nicht welcher allgemein gut ist.

## Aufgabe A — Docstring ergänzen und committen

Trivial und eindeutig prüfbar: `calc.py` mit einer Funktion `add`, Auftrag
lautet Docstring ergänzen und committen. Erfolg = `commits: 1` **und** Datei
tatsächlich geändert.

| Datum | Harness | Modell | Dauer | Runden | Token ein | Token aus | „Kosten" | Erfolg |
|---|---|---|---|---|---|---|---|---|
| 2026-08-16 | opencode | mimo-v2.5 | 21 s | 3 | 6.203 | 186 | 0,00102 | **nein** |
| 2026-08-16 | opencode | mimo-v2.5 | 18 s | 5 | 6.209 | 216 | 0,00104 | ja |
| 2026-08-16 | opencode | mimo-v2.5 | 19 s | 5 | 6.243 | 224 | 0,00105 | ja |
| 2026-08-16 | claude | claude-opus-5 | 14 s | 5 | 110.627 | 671 | 0,13506 | ja |
| 2026-08-16 | oh-my-pi | kimi-k2.7-code | 18 s | 6 | 81.312 | 489 | 0,02745 | ja |
| 2026-08-16 | oh-my-pi | gpt-5.6-luna | 16 s | 5 | 73.124 | 702 | **0,00289** | ja |
| 2026-08-16 | oh-my-pi | deepseek-v4-pro | 20 s | 6 | 104.466 | 859 | 0,00870 | ja |
| 2026-08-16 | claude | claude-opus-5 | 16 s | 5 | 110.255 | 573 | 0,13080 | ja |
| 2026-08-16 | oh-my-pi | anthropic/claude-opus-5 | 19 s | 6 | 153.200 | 691 | 0,24311 | ja |
| 2026-08-16 | oh-my-pi | xai-oauth/grok-4.6 | 17 s | 5 | 85.097 | 741 | Abo | ja |
| 2026-08-16 | oh-my-pi | xai-oauth/grok-build | 25 s | 14 | 234.668 | 1.770 | Abo | ja |

### Kosten bei gleichem Harness und gleicher Aufgabe

Alles über oh-my-pi, damit nur das Modell variiert:

| Modell | Kosten | gegen Luna |
|---|---|---|
| **gpt-5.6-luna** | **0,00289** | 1× |
| deepseek-v4-pro | 0,00870 | 3× |
| kimi-k2.7-code | 0,02745 | 9,5× |
| claude-opus-5 (über `claude`) | 0,13506 | 47× |

Luna war zugleich das **schnellste bis auf Claude** und das einzige, das den
Code zur Prüfung ausgeführt hat. Bei dieser Aufgabe schlägt es die anderen
in allen drei Dimensionen — und es liegt bereits im Go-Abo.

Ein Datenpunkt, keine Statistik. Aber ein deutlicher.

### Der Kontext-Grundaufwand ist eine HARNESS-Eigenschaft

Das ist der auffälligste Befund, und er ist unabhängig vom Modell:

| Harness | Token ein für dieselbe triviale Aufgabe |
|---|---|
| opencode | **~6.200** |
| oh-my-pi | ~81.000 |
| claude | ~110.600 |

Faktor 18 zwischen sparsamstem und aufwendigstem Harness — bei identischem
Auftrag. Das ist nicht das Modell, das ist, was der Harness vorher an Kontext
zusammenträgt: Werkzeugbeschreibungen, Projektdateien, LSP, Hooks.

Und es hat eine Kehrseite: **opencode ist am sparsamsten und zugleich das
einzige, das gescheitert ist** (ein Fehlschlag in drei Läufen). Wenig Kontext
heisst wenig Verbrauch, aber offenbar auch weniger Halt. Ob das an mimo-v2.5
oder am schmalen Kontext liegt, trennt erst ein Lauf mit demselben Modell in
einem anderen Harness — genau dafür ist oh-my-pi jetzt da.

### Was daraus schon ablesbar ist

**Faktor 135 im Kontingentverbrauch.** Beide laufen über Abos, der Geldbetrag
ist also fiktiv — der Verbrauch nicht. Bei einem Abo mit Wochenlimit ist das
der Unterschied zwischen „hält einen Monat" und „hält zwei Tage".

**Claude war schneller trotz 18-fachem Kontext.** Weniger Runden-Leerlauf,
kein Fehlversuch. Geschwindigkeit korreliert hier nicht mit Sparsamkeit.

**mimo-v2.5 ist unzuverlässig bei Werkzeugnutzung** — ein Fehlschlag in drei
Läufen bei einer Aufgabe, die kaum einfacher sein könnte. Im ersten Lauf
behauptete das Modell im Text, es sei fertig, während die Datei unverändert
war. Deshalb ist `commits` das Erfolgsmaß und nicht der Rückgabewert.

**110.000 Eingabe-Token für einen Docstring** sind Claude Codes Kontextaufbau
(Hooks, LSP, Plugin-Sync, CLAUDE.md-Suche). Die Option `--bare` überspringt
das — für mechanische Kleinarbeit vermutlich der bessere Modus. Eigener
Messpunkt, noch offen.

## Messfehler in der eigenen Metrik — Build-Artefakte

Der `gpt-5.6-luna`-Lauf wurde zunächst als unsauber gewertet, weil
`git status --short` eine offene Änderung meldete. Es war `__pycache__/`.

Das Modell hatte den Code also **ausgeführt**, um sein Ergebnis zu prüfen —
als einziges der getesteten. Die Metrik hat damit ausgerechnet das
gründlichste Verhalten bestraft.

**Konsequenz:** „offene Änderungen" darf nur *nachverfolgte* Dateien zählen,
nicht unversionierte Artefakte. Ein Erfolgsmaß, das Sorgfalt als Fehler
verbucht, ist schlimmer als keines — es führt die Auswahl aktiv in die
falsche Richtung.

Zu prüfen: `git status --short --untracked-files=no`, plus ein `.gitignore`
im Testaufbau.

## Derselbe Harness ist NICHT immer der beste — der Kerntest

Identisches Modell, identisches Abo, identische Aufgabe. Nur der Harness
unterscheidet sich:

| Harness | Dauer | Runden | Token ein | Kosten |
|---|---|---|---|---|
| **claude** | **16 s** | 5 | **110.255** | **0,1308** |
| oh-my-pi | 19 s | 6 | 153.200 | 0,2431 |

**Claude Code ist mit Claude 46 % günstiger und 16 % schneller als oh-my-pi.**

Das widerspricht der Konsolidierung „ein Harness für alles". Der
Hersteller-Harness kennt sein Modell offenbar besser — vermutlich
Prompt-Format, Werkzeugbeschreibungen und Caching, die auf genau dieses
Modell abgestimmt sind.

Und es korrigiert eine frühere Vermutung: Ich hatte Claude Code für den
aufwendigen Harness gehalten (110.000 Token). Mit demselben Modell braucht
oh-my-pi **mehr** (153.000). Der Grundaufwand hängt also von der **Paarung**
Harness/Modell ab, nicht vom Harness allein.

### Grok über das xAI-Abo

| Modell | Dauer | Runden | Token ein |
|---|---|---|---|
| **grok-4.6** | 17 s | 5 | **85.097** |
| grok-build | 25 s | 14 | 234.668 |

`grok-4.6` ist sparsam und schnell — auf dem Niveau der besten Go-Modelle.
`grok-build` brauchte für dasselbe Ergebnis **fast das Dreifache an Token
und 14 statt 5 Runden**. Für kleine Aufgaben ist es die falsche Wahl; ob es
bei großen seine Gründlichkeit ausspielt, ist offen.

**Hinweis zur Kostenspalte:** Bei OAuth-Abos meldet oh-my-pi `cost 0`. Für
xAI und Anthropic-über-omp sind die Token-Zahlen deshalb der einzige
Maßstab für den Kontingentverbrauch.

## Klassifizierer-Grundaufwand — warum er ohne Harness läuft

Gemessen mit identischem Klassifizierer-Prompt
(`evals/classifier-overhead.sh`, 2026-08-16):

| Variante | Token ein | gegen Grundlinie |
|---|---|---|
| direkter API-Aufruf | **131** | 1× |
| omp `--no-tools --no-lsp` | 2.123 | 16× |
| omp voller Modus | 15.417 | 118× |

Bei 100 Aufgaben täglich: 13.000 gegenüber 212.000 gegenüber 1,5 Millionen
Token — allein fürs Entscheiden, wer die Arbeit macht.

Der Klassifizierer läuft bei **jeder** Aufgabe und braucht weder Werkzeuge
noch LSP noch Dateizugriff. Ein Harness ist dort reiner Aufschlag auf die
häufigste Operation im System. Deshalb: direkter Aufruf, alles andere über
oh-my-pi.

Nebenbefund: Der Endpunkt antwortet ohne `User-Agent`-Header mit 403.

Zweiter Nebenbefund: omp erzeugt deutlich mehr Ausgabe-Token (3.210 gegen
333). Sein Systemprompt macht das Modell gesprächiger — bei einer Rolle, die
nur ein kleines JSON zurückgeben soll, ist auch das verschenktes Kontingent.

### Der Test, der am meisten sagen wird

**Dasselbe Modell, zwei Harnesses.** Alles andere vermischt Modell- und
Harness-Wirkung. Möglich wird das durch oh-my-pi, das sich per OAuth an
denselben Abos anmelden kann wie die Hersteller-Werkzeuge:

| Vergleich | trennt |
|---|---|
| Claude Opus über `claude` vs. über `oh-my-pi` | Harness-Wirkung bei gleichem Modell |
| kimi-k2.7-code über `opencode` vs. `oh-my-pi` | dasselbe, im Go-Abo |
| Grok 4.6 über `oh-my-pi` gegen beides | Modellwirkung bei gleichem Harness |

### Noch nicht gemessen

- Claude Opus **über oh-my-pi** — wartet auf die OAuth-Anmeldung
- `claude --bare` gegen den Normalmodus (drückt es die 110.000 Token?)
- Grok 4.6 über xAI-Abo via `oh-my-pi/xai-oauth`
  (grok-4.5 als Stellvertreter verworfen, zu schwach)
- Aufgaben mit echtem Umfang — bisher nur eine triviale. Der
  Kontext-Grundaufwand ist ein Fixkostenblock und amortisiert sich bei
  grösseren Aufgaben womöglich anders

## Hermes — Ladder statt Aufgabe A

Der vierte Harness wurde am 2026-09-13 nicht mehr an Aufgabe A gemessen,
sondern direkt über die Aufgabenleiter, drei Läufe pro Stufe. Ergebnis und
Gegenüberstellung mit oh-my-pi bei gleichem Modell (grok-4.6): 9/9, und
1,8- bis 2,9-mal weniger Eingabe-Token — siehe
[README.md → Ergebnisse — Hermes über die Ladder](README.md#ergebnisse--hermes-über-die-ladder-2026-09-13).
