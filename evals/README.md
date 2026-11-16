# Evals

Messung an Tests statt an Meinungen. Kein Modell bewertet ein Modell.

## Aufbau

```
testprojekt/     TypeScript-Projekt in RN-Domäne (Abo, Paywall, Belegprüfung)
                 6 Quelldateien, 19 Tests, ~600 Zeilen
aufgaben/
  S-…/AUFGABE.md      Aufgabentext für den Agenten
  S-…/pruefung.test.ts  VERDECKT — kommt erst NACH dem Lauf ins Projekt
```

Der Prüfteil wird bewusst erst danach eingespielt. Läge er vorher im Repo,
könnte der Agent gegen die Prüfung hin optimieren statt die Aufgabe zu lösen,
und das Ergebnis wäre wertlos.

`erfolg: true` verlangt **drei** Dinge gleichzeitig: Prüfteil bestanden
(Aufgabe gelöst), null fehlgeschlagene Tests (nichts kaputtgemacht),
Typprüfung grün.

## Aufgabenleiter

Eine einzelne Grösse sagt nichts. Der Grundaufwand ist fix; bei kleinen
Aufgaben dominiert er und bevorzugt sparsame Paarungen, bei grossen
verschwindet er und Fähigkeit entscheidet. Erst mehrere Stufen zeigen, wo
die Kurven sich kreuzen.

| Stufe | Aufgabe | Prüft |
|---|---|---|
| S | `S-wiederholgrenze` — nicht durchgesetzte Konstante | Absicht aus Code erschliessen |
| M | `M-einstiegsangebot` — Feature über mehrere Dateien plus Tests | echte Arbeit |
| L | `L-wiederholung-extrahieren` — Refactoring mit Verhaltenserhalt | Sorgfalt |
| S′ | `S-wiederholgrenze-vertrag` — dieselbe Aufgabe **mit** Schnittstellenvertrag | was Spezifikation wert ist |

### Das Stufenpaar S / S′

S ist die einzige Stufe ohne Interface-Vertrag im Aufgabentext — M und L haben
inzwischen einen. Deshalb misst S etwas anderes als die beiden: nicht
Umsetzung, sondern Erschliessen. Der Prüfteil verlangt Dinge, die im Text
nicht stehen: dass der Zähler den Zyklus `FEHLGESCHLAGEN → WIEDERHOLEN`
überlebt, dass `MAX_VERSUCHE` Versuche *insgesamt* zählt statt Wiederholungen,
und dass Erschöpfung ein `wiederholbar: true` der Aktion überstimmt.

Am 2026-09-19 scheiterten beide Flash-Modelle fast ausschliesslich hier
(GLM 1/3, DeepSeek 1/3 auf S, gegen 6/6 und 5/6 auf M und L), während
grok-4.6 3/3 schaffte.

`S-wiederholgrenze-vertrag` ist **dieselbe Aufgabe mit demselben Prüfteil**,
nur mit einem Vertrag im Text. S bleibt unverändert daneben stehen, damit die
bisherigen Messungen vergleichbar bleiben. Die Differenz zwischen beiden ist
die Antwort auf die Frage, die im August aufkam: was ein Satz Spezifikation
wert ist. Dort senkte er Kosten um über 40 % und halbierte die Laufzeit — ob
er auch Fehlschläge in Erfolge verwandelt, misst dieses Paar.

## Ergebnisse — alle drei Stufen

Neun Läufe, **neun Erfolge**. „Eigene Tests" sind die, die der Agent über
Grundbestand und verdeckten Prüfteil hinaus selbst geschrieben hat.

| Stufe | Modell | Dauer | Runden | Token ein | Token aus | Kosten | eigene Tests | Erfolg |
|---|---|---|---|---|---|---|---|---|
| S | luna | 77 s | 15 | 341.363 | 5.663 | 0.0102 | 1 | ✓ |
| S | opus | 99 s | 14 | 345.858 | 7.728 | 0.5275 | 2 | ✓ |
| S | grok | 221 s | 16 | 554.860 | 15.060 | Abo | 1 | ✓ |
| M | luna | 89 s | 13 | 334.376 | 7.464 | 0.0117 | 4 | ✓ |
| M | opus | 102 s | 13 | 306.077 | 8.182 | 0.5506 | 14 | ✓ |
| M | grok | 99 s | 14 | 365.731 | 5.770 | Abo | 10 | ✓ |
| L | luna | 144 s | 23 | 615.023 | 10.256 | 0.0162 | 4 | ✓ |
| L | opus | 168 s | 15 | 402.851 | 12.462 | 0.7577 | 9 | ✓ |
| L | grok | 202 s | 13 | 263.321 | 2.611 | Abo | 5 | ✓ |

### Was eindeutig ist

**Luna ist durchgehend am schnellsten und kostet ein Fünfzigstel von Opus.**
Das Verhältnis bleibt über alle Grössen stabil: 52× bei S, 47× bei M, 47× bei
L. Der Fixkostenblock erklärt es also nicht — es ist der Modellpreis.

**Alle drei haben alles gelöst.** Diese Aufgaben trennen die Modelle nach
Effizienz, nicht nach Fähigkeit. Für eine Fähigkeitsaussage bräuchte es
entweder schwerere Aufgaben oder Wiederholungen, die Ausreisser sichtbar
machen.

**Opus schreibt am gründlichsten Tests** — 14 eigene bei M gegen 4 bei Luna.
Ob das Wert schafft oder nur Zeilen, entscheidet sich erst, wenn ein
Regressionsfehler auftritt, den diese Tests fangen. Vermerkt, nicht bewertet.

**Grok 4.6 ist widersprüchlich**: bei L die wenigsten Token (263.321) und
zugleich die längste Laufzeit (202 s). Es denkt länger pro Token. Bei S war
es mit 221 s am langsamsten, bei M mit 99 s gleichauf.

### Was das für mehrere grössere Apps bedeutet

Hochgerechnet auf 200 Aufgaben der Grösse L im Monat:

| Modell | pro Aufgabe | 200 Aufgaben |
|---|---|---|
| gpt-5.6-luna | 0,0162 $ | **3,24 $** |
| claude-opus-5 | 0,7577 $ | 151,54 $ |
| grok-4.6 | Abo | im xAI-Kontingent |

Das ist die belastbare Antwort auf die Kostenfrage — gemessen, nicht
geschätzt.

## DeepSeek V4 Flash — mit Wiederholungen

Neun Laeufe, **neun Erfolge**, Gesamtkosten 0,0257 $. Erstmals drei
Wiederholungen pro Stufe (`bin/eval-ladder.sh`), weil ein Lauf kein Messwert
ist.

| Stufe | Erfolg | Dauer Median | Dauer Spanne | Runden | Tok ein Ø | Kosten Ø | eigene Tests |
|---|---|---|---|---|---|---|---|
| S | 3/3 | 111 s | 108–127 s | 10–13 | 309.997 | 0,0026 | 1, 1, 1 |
| M | 3/3 | 65 s | 55–67 s | 10–12 | 239.250 | 0,0016 | 9, 9, 9 |
| L | 3/3 | 206 s | 125–211 s | 15–18 | 564.653 | 0,0043 | 6, 8, 4 |

Gegen die vorhandenen Paarungen: 3,8–7,3× billiger als luna, auf L 176×
billiger als Opus, bei gleichem Ergebnis. Auf 200 L-Aufgaben im Monat 0,86 $
gegen luna 3,24 $ gegen Opus 151,54 $. Flash schreibt dabei mehr eigene Tests
als luna (9 gegen 4 auf M).

### Der Befund, der nicht das Modell betrifft

**M ist billiger und schneller als S** — 65 s gegen 111 s, 0,0016 gegen
0,0026, bei der *groesseren* Aufgabe. Der Grund liegt im Aufgabentext, nicht
im Modell: M und L haben inzwischen explizite Interface-Vertraege, S hat
keinen. S kostet mehr, weil das Modell erst erschliessen muss, was gemeint
ist.

Ein Satz Spezifikation senkte damit die Kosten um ueber 40 % und halbierte die
Laufzeit. Das ist der billigste Hebel, der in diesen Messungen bisher
aufgetaucht ist, und er ist modellunabhaengig. S sollte einen Vertrag
bekommen — oder bewusst ohne bleiben, dann aber als *Erschliessungsaufgabe*
ausgewiesen und nicht mit M und L in eine Kostenspalte geworfen.

### Wozu die Wiederholungen taugten

**L streut, S und M nicht.** Bei L 125–211 s Dauer, 48 % Kostenspanne, eigene
Tests 6/8/4. Bei S und M ist die Streuung vernachlaessigbar, die eigenen Tests
auf M dreimal exakt 9. Mit einem einzigen Lauf waere je nach Zufall „125 s"
oder „211 s" in die Tabelle gegangen.

### Vorbehalt zur Kostenzahl

Diese Laeufe liefen ueber `opencode-go`, und der Adapter zaehlt Cache-Reads in
`tokens_in` mit (bewusst — verbrauchtes Kontingent). Rechnet man 565k
Eingabetoken zum Listenpreis von OpenRouter oder runinfra (0,14 $/M), kaeme man
auf ~0,086 $ statt 0,0043 $, Faktor 20. Die Differenz ist mit hoher
Wahrscheinlichkeit Prefix-Caching.

Der **Vergleich** mit luna und Opus ist davon unberuehrt: gleicher Adapter,
gleiche Zaehlweise, gleicher Topf. Die **Uebertragung auf einen anderen
Provider ist es nicht** — die braucht eine eigene Messung, keine
Multiplikation. Wer hier hochrechnet, rechnet falsch.

### Kontingent-Vorbehalt

Gemessen wurde ueber `opencode-go`, also das Kontingent, das Leitsatz 2 in
`config/models.yaml` dem Klassifizierer vorbehaelt. Das war eine bewusste
Ausnahme fuer eine Messung, keine Routing-Entscheidung: neun Laeufe gegen ein
Kontingent, das rund 6000 realistische Aufgaben im Monat traegt. Fuer echte
Arbeit gehoert Flash in einen anderen Topf — dafuer fehlt bislang ein
Schluessel (`OPENROUTER_API_KEY` bzw. `RUNINFRA_API_KEY`, siehe
`.env.example`).

## Ausführen

```bash
# ein Lauf
bin/eval-run.sh <aufgabe> <harness> <modell>
bin/eval-run.sh S-wiederholgrenze oh-my-pi opencode-go/gpt-5.6-luna

# ganze Leiter mit Wiederholungen — eine JSON-Zeile pro Lauf
bin/eval-ladder.sh <harness> <modell> [wiederholungen] [stufen…]
bin/eval-ladder.sh oh-my-pi opencode-go/deepseek-v4-flash 3
```

Ein Lauf ist kein Messwert. Für belastbare Aussagen mehrfach laufen lassen —
die Docstring-Messung hatte bei mimo-v2.5 einen Fehlschlag in drei Läufen.

## Ergebnisse — Hermes über die Ladder (2026-09-13)

Vierter Harness, andere Topologie: Hermes läuft in CT 103 und arbeitet per
SSH-Backend in CT 102, siehe [../adapters/hermes/README.md](../adapters/hermes/README.md).
Drei Läufe pro Stufe. `turns` sind bei Hermes API-Aufrufe.

### grok-4.6 über `xai-oauth` — 9 von 9

| Stufe | W | Dauer | API-Aufrufe | Token ein | Token aus | davon Reasoning | Tests | Erfolg |
|---|---|---|---|---|---|---|---|---|
| S | 1 | 216 s | 13 | 212.641 | 8.706 | 5.999 | 24/0 | ✓ |
| S | 2 | 196 s | 11 | 200.029 | 9.781 | 7.009 | 24/0 | ✓ |
| S | 3 | 232 s | 15 | 240.792 | 8.024 | 5.657 | 24/0 | ✓ |
| M | 1 | 128 s | 9 | 114.184 | 5.433 | 2.319 | 36/0 | ✓ |
| M | 2 | 163 s | 10 | 149.831 | 6.263 | 4.194 | 37/0 | ✓ |
| M | 3 | 162 s | 8 | 110.268 | 4.711 | 3.060 | 35/0 | ✓ |
| L | 1 | 131 s | 10 | 150.020 | 6.808 | 4.557 | 30/0 | ✓ |
| L | 2 | 144 s | 11 | 142.223 | 8.195 | 5.449 | 32/0 | ✓ |
| L | 3 | 156 s | 11 | 147.226 | 8.957 | 6.027 | 30/0 | ✓ |

Mittelwerte: S 215 s / 13,0 Aufrufe / 217.821 ein — M 151 s / 9,0 / 124.761 —
L 144 s / 10,7 / 146.490. Kosten: Abo, Hermes meldet `cost_status: unknown`.

**Dasselbe Modell, anderer Harness.** grok-4.6 lief am 2026-08-19 über oh-my-pi
(Tabelle oben). Gegenüberstellung der Eingabe-Token:

| Stufe | oh-my-pi | Hermes (Ø) | Faktor |
|---|---|---|---|
| S | 554.860 | 217.821 | 2,5× weniger |
| M | 365.731 | 124.761 | 2,9× weniger |
| L | 263.321 | 146.490 | 1,8× weniger |

Gleiches Bild wie beim Harness-Vergleich: der Grundaufwand hängt an der
Paarung. Hermes trägt mit `-t terminal,file` deutlich weniger Kontext
zusammen als oh-my-pi im vollen Modus. Die Dauer ist bei S gleich (215 gegen
221 s), bei M länger (151 gegen 99 s), bei L kürzer (144 gegen 202 s) — bei
drei Läufen gegen einen ist das Rauschen, keine Aussage.

**Die kleinste Stufe ist die teuerste.** S braucht bei Hermes mehr Aufrufe
und mehr Token als M und L. Die Aufgabe „Absicht aus Code erschließen" kostet
Lesen; das Modell liest sich durch das Projekt, bevor es eine Zeile ändert.

### GLM-5.3-Flash über OpenRouter — nicht gemessen

Null von neun, und **keine Aussage über das Modell**: Der erste Lauf endete
mit HTTP 402 von OpenRouter („requires more credits, or fewer max_tokens —
you requested up to 131072 tokens, but can only afford 78598"), die acht
folgenden brachen nach einer Sekunde ohne API-Aufruf ab. Das Guthaben war
aufgebraucht, bevor ein Modell etwas gesagt hat.

Zwei Lehren, beide eingebaut: Der Adapter meldet seit diesem Lauf
`kein_api_aufruf` und `null` statt `0 Token`, damit ein Infrastrukturausfall
nicht wie ein gescheitertes Modell aussieht. Und die Ladder braucht vor dem
Start eine Guthabenprüfung — der Wächter aus dem Orchestrator-Entwurf,
diesmal nicht als Kostenbremse, sondern als Vorbedingung.

Rohdaten: `rohdaten/2026-09-13-hermes-*-leiter.jsonl`.

## Ergebnisse — drei Flash-Modelle über Hermes (2026-09-19)

Die am 2026-09-13 an HTTP 402 gescheiterte GLM-Messung, nachgeholt und um
zwei Kandidaten erweitert. Drei Läufe pro Stufe, alle über den
Hermes-Adapter, alle über OpenRouter. Vorbedingung diesmal geprüft:
[`bin/openrouter-guthaben.sh`](../bin/openrouter-guthaben.sh).

| Modell | Erfolg | S | M | L | Kosten (9 Läufe) |
|---|---|---|---|---|---|
| `x-ai/grok-4.6` (13.09.) | **9/9** | 3/3 | 3/3 | 3/3 | Abo — siehe unten |
| `qwen/qwen3.7-flash` | **8/9** | 2/3 | 3/3 | 3/3 | 0,0580 $ |
| `z-ai/glm-5.3-flash` | 7/9 | 1/3 | 3/3 | 3/3 | 0,0649 $ |
| `deepseek/deepseek-v4-flash` | 6/9 | 1/3 | 3/3 | 2/3 | 0,0240 $ |

Spalten: Median, Spanne, API-Aufrufe Ø, Eingabe-Token Ø, Reasoning Ø, Kosten.

### `qwen/qwen3.7-flash` — 8 von 9

| Stufe | Läufe | Median | Spanne | Aufrufe | Tok ein Ø | Reasoning Ø | Kosten |
|---|---|---|---|---|---|---|---|
| S | ✓ ✗ ✓ | 253 s | 156–409 s | 18,7 | 210.999 | 15.482 | 0,0138 |
| M | ✓ ✓ ✓ | 150 s | 120–224 s | 15,7 | 188.333 | 3.860 | 0,0146 |
| L | ✓ ✓ ✓ | 317 s | 182–638 s | 21,7 | 333.935 | 18.251 | 0,0295 |

### `z-ai/glm-5.3-flash` — 7 von 9

| Stufe | Läufe | Median | Spanne | Aufrufe | Tok ein Ø | Reasoning Ø | Kosten |
|---|---|---|---|---|---|---|---|
| S | ✓ ✗ ✗ | 113 s | 109–126 s | 9,7 | 82.830 | 500 | 0,0110 |
| M | ✓ ✓ ✓ | 137 s | 107–159 s | 12,7 | 124.445 | 20 | 0,0221 |
| L | ✓ ✓ ✓ | 246 s | 197–**1335** s | 13,7 | 149.235 | 12.855 | 0,0318 |

### `deepseek/deepseek-v4-flash` — 6 von 9

| Stufe | Läufe | Median | Spanne | Aufrufe | Tok ein Ø | Reasoning Ø | Kosten |
|---|---|---|---|---|---|---|---|
| S | ✗ ✓ ✗ | 186 s | 142–223 s | 12,0 | 144.156 | 3.345 | 0,0066 |
| M | ✓ ✓ ✓ | 113 s | 89–116 s | 11,7 | 149.191 | 1.931 | 0,0082 |
| L | ✗ ✓ ✓ | 114 s | 98–**523** s | 11,0 | 160.502 | 9.107 | 0,0092 |

### Derselbe Harness schlägt anders durch als gedacht

DeepSeek V4 Flash lief am 2026-08-19 über oh-my-pi **9/9** und hier über
Hermes **6/9** — dasselbe Modell, dieselbe Leiter, dieselben Prüfteile. Die
Paarung entscheidet, nicht das Modell allein. Ein Leaderboard misst genau
diese Größe nicht.

### pass@3: alle drei lösen jede Stufe

Die drei Wiederholungen sind nebenbei eine pass@3-Messung. **Kein einziger
Fehlschlag war deterministisch** — wo ein Modell scheiterte, schaffte es
dieselbe Aufgabe in einem anderen Lauf:

| Modell | pass@1 | pass@3 (Stufen gelöst) |
|---|---|---|
| qwen3.7-flash | 89 % | 3/3 |
| glm-5.3-flash | 78 % | 3/3 |
| deepseek-v4-flash | 67 % | 3/3 |

Das ist die Voraussetzung, ohne die eine Wiederholschleife nichts bringt.
Sie braucht zusätzlich einen Prüfer, dem man traut — den haben wir
(Typprüfung, bestehende Tests, verdeckter Prüfteil), und er ist bewusst
getrennt von den Tests, die das Modell selbst schreibt.

### Was das Abo-Ende kostet

grok-4.6 war „Abo-gedeckt". Ohne Abo, zu OpenRouter-Listenpreis
(2 $/6 $ je Mio), kostet dieselbe Leiter mit grok **rund 3,33 $** — ein
einzelner S-Lauf allein 0,49 $. Dagegen kostet ein GLM-Lauf 0,0072 $.

**Drei Versuche mit einem Flash-Modell kosten rund ein Zwanzigstel eines
einzigen grok-Laufs**, und pass@3 sagt, dass drei Versuche reichen. Damit
ist die Begründung im [Hermes-Plan](../orchestrator/hermes.md) („Default
bleibt grok-4.6, Abo-gedeckt") hinfällig; die Ablösung ist gemessen, nicht
geraten.

### Der Vorbehalt

Drei Stufen, drei Läufe — pass@3 = 3/3 sind drei Datenpunkte, kein Beweis.
Und alle drei Modelle scheitern fast nur auf **S**, der einzigen Stufe ohne
Vertrag im Aufgabentext. Ob das an den Modellen liegt oder an der Aufgabe,
entscheidet das Stufenpaar S/S′.

Rohdaten: `rohdaten/2026-09-19-hermes-*-leiter.jsonl`.

## Was ein Vertrag wert ist — das Stufenpaar S/S′ (2026-09-21)

Dieselbe Aufgabe, derselbe verdeckte Prüfteil, ein Absatz Spezifikation
Unterschied. Drei Läufe je Modell.

| Modell | S (ohne Vertrag) | S′ (mit Vertrag) |
|---|---|---|
| `z-ai/glm-5.3-flash` | ✓ ✗ ✗ — **1/3** | ✓ ✓ ✓ — **3/3** |
| `deepseek/deepseek-v4-flash` | ✗ ✓ ✗ — **1/3** | ✓ ✓ ✓ — **3/3** |

Beide springen von einem Drittel auf alles. Kein Lauf auf S′ scheiterte, und
kein einziger Prüfteil war rot.

### Je Lauf teurer, je Erfolg billiger

Der Vertrag macht den *einzelnen* Lauf aufwendiger — mehr Kontext, längere
Laufzeit. Das ist aber die falsche Bezugsgröße: Fehlschläge kosten auch.
Gerechnet auf einen **Erfolg**:

| Modell | | Erfolg | $/Lauf | $/Erfolg | s/Erfolg |
|---|---|---|---|---|---|
| glm-5.3-flash | S | 1/3 | 0,0037 | 0,0110 | 339 |
| glm-5.3-flash | S′ | 3/3 | 0,0096 | **0,0096** | **246** |
| deepseek-v4-flash | S | 1/3 | 0,0022 | 0,0066 | 558 |
| deepseek-v4-flash | S′ | 3/3 | 0,0031 | **0,0031** | **236** |

GLM: 13 % billiger und 27 % schneller je Erfolg. DeepSeek: 53 % billiger und
58 % schneller. Dazu fällt das Schwanzrisiko weg — bei p = 1/3 scheitern
drei Versuche in 30 % der Fälle immer noch alle drei.

Damit ist der August-Befund bestätigt, aber präziser gefasst: Spezifikation
senkt nicht die Kosten *pro Lauf*, sie senkt die Kosten *pro Ergebnis*.

### Spezifikation schlägt Wiederholung

Beides wirkt, aber nicht gleich gut. Die Wiederholschleife rettet einen
Fehlschlag im Nachhinein und zahlt dafür jedes Mal den vollen Lauf. Der
Vertrag verhindert ihn. Reihenfolge also: **erst den Vertrag, dann die
Schleife als Netz** — nicht umgekehrt.

### Was das für den `cheap`-Default heißt

M und L tragen inzwischen ihre Verträge, S war die Ausnahme. Rechnet man
S′ an die Stelle von S, ergibt sich die Leiter, wie sie bei ordentlich
gestellten Aufgaben tatsächlich aussieht:

| Modell | S′ | M | L | gesamt | Kosten |
|---|---|---|---|---|---|
| `z-ai/glm-5.3-flash` | 3/3 | 3/3 | 3/3 | **9/9** | 0,083 $ |
| `deepseek/deepseek-v4-flash` | 3/3 | 3/3 | 2/3 | 8/9 | 0,040 $ |
| `x-ai/grok-4.6` | 3/3 | 3/3 | 3/3 | 9/9 | ~3,33 $ ohne Abo |

**GLM-5.3-Flash erreicht grok-4.6s Ergebnis zum vierzigsten Teil des
Preises**, sobald die Aufgaben Verträge tragen. Das ist der Ersatz für den
weggefallenen Abo-Default.

Vorbehalt bleibt: drei Läufe je Zelle. 3/3 heißt nicht p = 1, es heißt nur,
dass p hoch genug ist, um in drei Versuchen nicht aufzufallen.

Rohdaten: `rohdaten/2026-09-21-hermes-*-vertrag.jsonl`.

## Claude über Claude Code: Haiku, Sonnet, Opus (2026-10-14)

Anlass ist die Umstellung aller Rollen auf Claude Code mit dem Abo
([../config/models.yaml](../config/models.yaml)). Gesucht ist das Modell für
`cheap`. Vier Stufen (S, S′, M, L), je drei Läufe, Claude Code 2.1.299. Die
drei Reihen liefen **parallel** in CT 102, deshalb sind die Laufzeiten
untereinander nur eingeschränkt vergleichbar; Erfolg und Token sind es.
Kosten sind der Listenpreis aus `total_cost_usd`, im Abo also
Kontingent, kein Geld.

| Modell, Effort | S | S′ | M | L | gesamt | $/Erfolg |
|---|---|---|---|---|---|---|
| Haiku 5.5, medium | 2/3 | 3/3 | 3/3 | 3/3 | **11/12** | **0,0146** |
| Sonnet 5.5, medium | 3/3 | 3/3 | 3/3 | 3/3 | 12/12 | 0,0967 |
| Opus 5.5, low | 3/3 | 3/3 | 3/3 | 3/3 | 12/12 | 0,2015 |

Rohdaten: `rohdaten/2026-10-14-claude-*-leiter.jsonl`.

### Haiku scheitert, wo Flash scheitert

Der eine Fehlschlag liegt auf S, der Stufe ohne Vertrag: Typen grün, ein
Test rot, verdeckter Prüfteil rot. Mit Vertrag (S′) 3/3. Dasselbe Muster wie
bei GLM und DeepSeek, nur schwächer (1 von 3 statt 2 von 3). Die Regel aus
dem Abschnitt davor gilt also auch hier: **erst den Vertrag**.

### Haiku arbeitet mehr, kostet trotzdem ein Siebtel

Haiku braucht mehr Runden und liest drei- bis fünfmal so viele Token
(159k–552k je Lauf gegen ~100k bei Sonnet und Opus) und ist auf M und L
langsamer. Bei einem Zwanzigstel des Tokenpreises bleibt es trotzdem
siebenmal billiger je Erfolg als Sonnet.

### Opus auf low ist keine Abkürzung

Die Gegenprobe "ein Modell auf niedrigem Effort statt zwei Modelle" geht
fehlerfrei durch, kostet aber das Doppelte von Sonnet medium bei gleichem
Ergebnis. Für `cheap` lohnt die Vereinfachung nicht.

### Der Vorbehalt

Die Ladder misst **Korrektheit**, nicht Codequalität. Ob ein Modell
God-Classes baut, überflüssige Tests schreibt oder Behauptungen ohne Beleg
aufstellt, sieht sie nicht — und auf dieser Ladder sind alle drei gesättigt.
Ein Unterschied zwischen Haiku und Sonnet zeigt sich erst an einer Stufe,
die Haiku reißt, oder an einem Prüfteil für Qualität, den es noch nicht gibt.

**Entscheidung:** `cheap` = Haiku 5.5 auf medium, **nur mit Vertrag**.
Sonnet 5.5 medium ist der erste Kandidat, falls Haiku in echter Arbeit
nachgebessert werden muss.
