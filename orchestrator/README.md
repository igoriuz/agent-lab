# Orchestrator

**Status: Entwurf. Nichts davon ist gebaut** — dieses Verzeichnis ist leer.
Aufgeschrieben ist es trotzdem, weil die Begründungen teuer erarbeitet sind
und sonst in einem halben Jahr neu erarbeitet werden.

Der Orchestrator ist die Instanz, die aus einem vagen Satz Arbeit macht:

> „Mach mal XY" → Recherche → Zielvorschlag → **Freigabe** → Arbeit bis zum
> Ziel oder bis eine Entscheidung fehlt.

## Der Ablauf

```
ein Satz vom Menschen
        │
        ▼
   Recherche          was gibt es, was ist Stand der Dinge
        │             (Skill, kein Baustein — siehe README, Offen)
        ▼
  Zielvorschlag       Absicht als Prosa + Erwartungen als Prüfbares
        │             + die VERWORFENEN Alternativen
        ▼
   FREIGABE ◄──────── Mensch, einmal, über die Bridge
        │             danach eingefroren
        ▼
     Arbeit           Aufgaben gegen die Erwartungen
        │             Aushandlung im Thread, wenn nötig
        ▼
   drei Ausgänge      erfüllt · Entscheidung fehlt · nicht erreichbar
```

## Das Ziel ist ein Artefakt

„Bis dahin arbeiten" braucht ein „dahin", das eine Maschine prüfen kann.
Sonst entscheidet ein Modell, ob ein Modell fertig ist — die Schleife, die
[../README.de.md](../README.de.md) als wertlos abtut.

### Zweistufig: sichtbar zielen, verdeckt abnehmen

Das Eval-Format liefert die Form (`expectations` als deterministisch
prüfbare Aussagen), aber **nicht ohne Umbau.** In den Evals wird der Prüfteil
verdeckt gehalten — `evals/README.md`:

> „Läge er vorher im Repo, könnte der Agent gegen die Prüfung hin optimieren
> statt die Aufgabe zu lösen, und das Ergebnis wäre wertlos."

Ein Ziel muss der Arbeiter dagegen **sehen**, sonst kann er nicht darauf
zielen. Damit kehrt sich die Sicherheitseigenschaft um: sichtbare, grep-bare
Erwartungen sind buchstäblich erfüllbar — der String erscheint, das Feature
nicht. Einfrieren hilft dagegen nicht, es schützt etwas anderes.

Also zwei Stufen:

| | Sichtbar für den Arbeiter | Zweck |
|---|---|---|
| **Absicht** | ja, Prosa | damit er versteht, worum es geht |
| **Erwartungen** | ja, aber **ausführbar** statt grep-bar | damit er Fortschritt selbst messen kann |
| **Abnahme** | **nein** — verdeckt wie `pruefung.test.ts` | damit sie nicht optimierbar ist |

Grep-bare Erwartungen bleiben erlaubt, wo nichts anderes geht. Sie sind dann
Fortschrittsanzeige, nicht Abnahme.

```yaml
ziel: "Bezahlpfad in der Beispiel-App ist getestet und die Conversion messbar"
absicht: >
  Warum das lohnt, in zwei Sätzen. Für Menschen.
erwartungen:                       # sichtbar, ausführbar
  - "swift test --filter PaywallTests läuft grün"
  - "Trial und Direktkauf sind beide implementiert"
abnahme: aufgaben/beispiel-paywall/abnahme.test.swift   # verdeckt
verworfene_alternativen:           # Pflicht, siehe Freigabe
  - "Preis erneut anheben — lief 2026-08-10 schon, zurückgedreht"
budget_versuche: 8                 # siehe Der dritte Ausgang
```

## Freigabe und Einfrieren

Setzt derselbe Agent das Ziel und wird daran gemessen, **senkt er das Ziel,
bis es erfüllt ist.** Nicht aus Bosheit — weil „fertig" der Zustand ist, auf
den alles optimiert.

Deshalb: die Recherche *schlägt vor*, ein Mensch gibt *einmal* frei, danach
ist das Ziel eingefroren. Mechanik: Datei committen, Hash notieren, Arbeit
verweigern wenn der Hash nicht mehr passt. Eine Änderung braucht eine neue
Freigabe und ist als Diff sichtbar. Dasselbe Prinzip wie `pinned: true` beim
Klassifizierer, aus demselben Grund.

**Das Gate ist billig und folgenschwer — die schlechteste Kombination.** Eine
Freigabe in zehn Sekunden auf dem Handy entscheidet alles danach. Gegenmittel:
Der Vorschlag muss die **verworfenen Alternativen** aus der Recherche
mitliefern. Wer die liest, liest auch das Ziel.

## Zwei Blocker

| Wann | Was der Mensch entscheidet | Kosten |
|---|---|---|
| **Vor der Arbeit** | Ist das das richtige Ziel? | billig, einmal, bestimmt alles danach |
| **Während der Arbeit** | Entwurf, Richtungsfrage, echtes Entweder-oder | teuer, aber selten |

## Der Thread: wo Agenten sich treffen

Übergabe und Aushandlung sind zwei verschiedene Dinge. Artefakt plus
Ticketstatus ist eine **Übergabe**. Ein Entwurf, der *durchdiskutiert* wird,
braucht **Dialog**.

Der Raum dafür ist eine Datei, deren Runden der Orchestrator serialisiert:

```
threads/<thema>.md      der Raum — wer sagte was, in Runden, darf lang werden
memory/<projekt>.md     das Destillat — Zustand, Versucht-Liste, bleibt kurz
```

Diffbar, versioniert, nachlesbar. Und weil immer nur einer schreibt, gibt es
keinen Merge-Konflikt auf der Datei, die am meisten wehtut.

**Du bist Teilnehmer im Raum**, nicht nur Freigabeinstanz: die Bridge hängt
deinen Beitrag als Runde an, wie bei jedem anderen.

Vier Dinge, die einen Chatroom zuverlässig ruinieren:

| Risiko | Gegenmittel |
|---|---|
| Token-Explosion — jeder liest alles, Kosten wachsen quadratisch | Rundengrenze, und nur ein Auszug in den Prompt statt des ganzen Verlaufs |
| Kein Abschluss — Modelle diskutieren höflich endlos | Ein benannter **Entscheider** pro Thread, der abschließen muss; Rundendeckel als Notausgang |
| Konsens-Illusion — zwei Instanzen desselben Modells stimmen zu | `reviewer_provider_differs_from_strong` gilt im Raum genauso |
| Reden statt bauen — reden ist billiger | Der Thread braucht einen Zweck im Ticket. „Entwurf abstimmen" ja, „Vorgehen klären" ist ein Warnsignal |

Der Rundendeckel ist das Wichtigste: er ist für einen Dialog das, was
`commits` und `checks:` für eine Aufgabe sind — ein objektives Abbruchkriterium
in einem Format, das sonst keins hat.

**Thread und Destillat nicht vermischen.** Ein Thread, der nach drei Wochen
ungefiltert ins Gedächtnis wandert, ist dieselbe Krankheit, die
[../README.de.md](../README.de.md) bei Skills beschreibt: länger ist nicht besser,
und Aufmerksamkeit verteilt sich.

## Was der Adapter-Vertrag zusätzlich braucht

Der Vertrag in [../adapters/README.md](../adapters/README.md) kennt Erfolg und
Fehlschlag. Für Zielarbeit fehlen drei Dinge:

```json
{ "task_id": "…",
  "status": "done | needs_review | blocked_on_human | unsatisfiable",
  "frage": "Trial oder Direktkauf?",
  "optionen": ["7 Tage Trial", "Direktkauf 6,99"],
  "artefakt": "mockups/paywall-v2.html",
  "learned": "mimo bricht bei mehr als drei Dateien pro Aufgabe ab",
  "commits": 2 }
```

**`needs_review` und `blocked_on_human` sind nicht dasselbe.** „Entwurf
fertig, schau mal" ist `needs_review` — der Agent ist durch. „Das darf ich
nicht entscheiden" ist `blocked_on_human`. Beides in einen Status zu legen
macht jede Design-Aufgabe zum Alarm, und dann liest niemand den Kanal mehr.

**`learned` statt Schreibzugriff.** Agenten schreiben nicht selbst in
`memory/` — N Agenten, die an dieselbe Versucht-Liste anhängen, erzeugen
Merge-Konflikte auf genau der Datei, die am meisten zählt. Sie geben die
Lektion zurück, der Orchestrator schreibt.

### Der dritte Ausgang

„Arbeitet, bis die Erwartungen erfüllt sind oder ein Mensch blockiert" hat
keinen Ausgang für **Erwartungen nicht erreichbar**. Eine Schleife gegen eine
falsche Erwartung läuft sonst unbegrenzt. Deshalb `budget_versuche` pro Ziel
und `status: unsatisfiable`, das über die Bridge eskaliert statt weiterzulaufen.

## Der Wächter: Backoff, nicht Buchhaltung

**Entschieden 2026-09-07: Kosten sind nicht der kritische Pfad.** OpenRouter
ist Prepaid — das Guthaben *ist* der Deckel, es gibt keine Nachforderung. Ein
durchbrochenes Abo-Kontingent bedeutet warten, nicht zahlen. Ein Wächter, der
davor bremst, verhindert nichts, was nicht ohnehin verhindert wäre.

Also: Token zählen, sichtbar machen, bei 429 zurückweichen. Abo-Fenster sind
ohnehin opak (Claude 5-Stunden-Fenster, xAI und Go veröffentlichen nichts
Brauchbares, OAuth-Harnesses melden `cost 0`) — als Buchhaltung wäre der
Wächter falsch mit Selbstvertrauen.

Zwei Ausnahmen, und beide sind keine Geldfragen:

| Ausnahme | Warum |
|---|---|
| **Der Klassifizierer-Topf** | Leitsatz 2: fällt der aus, kann das System nicht einmal mehr melden, dass es nicht mehr kann. Verfügbarkeit, nicht Kosten. Bleibt exklusiv |
| **`media` über console.x.ai** | Postpaid pro Stück, 0,48 $ für sechs Sekunden Video. Dort produziert eine Schleife eine Rechnung. Bleibt `deferred`, bis pro Aufruf gezählt wird |

### Der Deckel wandert

Wenn Geld nicht bremst, bremst nichts mehr — außer der einen knappen
Ressource: **Aufmerksamkeit.** Ein billiger Swarm produziert Entscheidungs-
anfragen schneller, als ein Mensch mit einem Handy sie beantwortet.

Deshalb liegt der Deckel auf **offenen menschlichen Entscheidungen**:
höchstens drei unbeantwortete Blocker, danach nimmt der Orchestrator keine
neue Arbeit an. Niedrig anfangen, hochziehen, wenn die Anfragen sichtbar
taugen — derselbe Regler wie `ask_above_usd`, nur auf der Ressource, die
wirklich knapp ist.

`ask_above_usd` behält seinen Sinn, aber aus einem anderen Grund: nicht was es
kostet, sondern wie viel Arbeit in die falsche Richtung laufen kann, bevor
jemand hinschaut.

## Was bewusst nicht gebaut wird

Der erste Entwurf hatte vierzehn Teile. Neun sind gestrichen, und die
Begründungen sind wichtiger als die Teile:

| Gestrichen | Grund |
|---|---|
| Ticketsystem mit atomarem Claim | Löst ein Problem, das der Orchestrator beseitigt: **weist er Arbeit zu, statt Agenten sie ziehen zu lassen, braucht es keinen Claim.** Kein Claim, keine Datenbank |
| Ein Orchestrator **pro Projekt** | Bei dieser Größe eine Schleife in einem Prozess mit `projekt` als Parameter. N=1 |
| **Globaler** Kontingentwächter | Folgt aus N=1 und aus „Kosten sind nicht kritisch" — bleibt ein Zähler mit Bericht |
| `art style` **durchgesetzt** | `forbidden: firebase` ist ein grep auf `package.json`. „Flach, keine Gradienten" ist nicht deterministisch prüfbar. Das Manifest-Feld darf bleiben, aber als **Reviewer-Prüfung** deklariert, nicht als Durchsetzung |
| Gewerke als Adapter | Drei Achsen, die getrennt bleiben: Harness in `adapters/`, Modellstärke in `config/models.yaml`, Gewerk in `skills/`. Ein Design-Agent ist ein Gewerk |
| Recherche als Baustein | Eine Skill. Steht als Lücke schon in der Offen-Liste |
| Vager Satz als Eingang, Visuelles als Code | Keine Bausteine, sondern Konventionen. Bildgenerierung bleibt `deferred` mit gemessenen Zahlen |

Bleiben sechs: Zieldatei, Einfrieren, zwei Blocker, Gedächtnisdatei, die
Vertragserweiterung, Kommunikation über das Repo. Vier Dateien.

## Fremdprojekte, geprüft 2026-09-07

Sechs Recherchestränge, Sterne und Lizenzen gegen die GitHub-API geprüft.
**Nichts zum Übernehmen** — aber drei Projekte mit Lehren:

| Projekt | Lizenz | Sterne | Lehre / Preis |
|---|---|---|---|
| [Symphony](https://github.com/openai/symphony) | Apache-2.0 | 27,1k | Nächste Verwandtschaft in der Philosophie: Board als Steuerungsebene, ein isolierter Lauf pro Aufgabe, Freigabe plus CI vor dem Merge, geschriebenes Protokoll. Preis: Linear als SaaS-Board, Elixir, keine Zielebene |
| [Beads](https://github.com/gastownhall/beads) + [Gas Town](https://github.com/gastownhall/gastown) | MIT | 27,0k / 18,0k | Der einzige Stack, der Tickets, Wissen, Merge-Serialisierung und Deckel zusammen abdeckt. Preis: Dolt/SQLite als Quelle der Wahrheit — gebaut, *weil* Markdown-Backlogs bei 20–30 Agenten nicht trugen. Killt die Portabilitätsthese, kennt keine Abo-Töpfe |
| [Ralph](https://github.com/snarktank/ralph) | MIT | 21,7k | Die Anti-These: Shell-Schleife mit `prd.json` und `progress.txt`, 80 % des Nutzens mit 5 % der Teile. Der Maßstab für „nicht überbauen" |
| [Hermes Agent](https://github.com/nousresearch/hermes-agent) | MIT | — | **Nachgetragen 2026-09-13, lief seit dem 08-30 als CT 103 und fehlte hier.** Cron, Gateway, Profile, Memory, Skills, `/goal`-Contract — deckt die Offen-Liste unten weitgehend ab. Preis: kein Einfrieren, keine verdeckte Abnahme, keine Versucht-Liste. Entscheidung: **Laufzeit**, siehe [hermes.md](hermes.md) |

Für drei Dinge gibt es **überhaupt nichts**: deterministische Erwartungen auf
Themenebene, ein Wächter über Abo-Kontingente, und der `style:`-Block im
Manifest. Spezifikations-Werkzeuge (spec-kit, 133,9k; OpenSpec, 67,5k) liefern
Prosa-Kriterien ohne Freigabe, Einfrieren oder maschinelle Prüfung.

Das Muster: die verbreiteten Werkzeuge beantworten „wie koordiniert man viele
Agenten". Die Frage hier ist „wie kommt man von einem Satz zu einem geprüften
Ziel". Für die zweite gibt es keinen Anbieter.

## Die kleinste Version

Ein Durchlauf, der jedes Element beweist:

**Ein** Projekt, **ein** Orchestrator, sequenziell.
Recherche → Zielvorschlag mit verworfenen Alternativen → Freigabe per
Telegram → zwei Aufgaben gegen die Erwartungen → eine endet in
`blocked_on_human`.

Läuft das einmal durch, sind Ziel, Freigabe, Arbeit und Blocker bewiesen.
Parallelität und ein zweiter Orchestrator sind danach ein Konfigurationswert,
kein Umbau.

Alles darüber ist Architektur für Woche drei, geschrieben in Woche eins — und
die Warnung dagegen steht in [../README.de.md](../README.de.md) unter *Autonomie und
ihre Grenzen*.

## Offen

- [ ] Zieldatei-Format festziehen, ein echtes Ziel damit schreiben
- [ ] Verdeckte Abnahme: wie der Runner sie einspielt (`bin/eval-run.sh` macht
      das schon für Aufgaben — dieselbe Mechanik)
- [ ] `status`-Enum und `learned` in den Adapter-Vertrag, drei Adapter nachziehen
- [ ] Strukturierte Ausgabe pro Harness: `claude --output-format json` ist da,
      `oh-my-pi` und `opencode` brauchen eine Konvention
- [ ] Thread-Format und Rundendeckel, Entscheider benennen
- [ ] Blocker-Deckel in der Bridge — höchstens drei offene Entscheidungen
- [ ] `style:` ins Manifest-Schema, als Reviewer-Prüfung deklariert
