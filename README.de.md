# agent-lab

**Status: eingestellt (November 2026).** Das Repo wird nicht weiterentwickelt. Es bleibt als Referenz für die Eval-Leiter, den Adapter-Vertrag und die Messungen zu Hermes Agent und Flash-Modellen.

Werkstatt für private Agenten-Arbeit: mehrere Anbieter statt nur einer,
Skills die sich messbar verbessern, und ein Rückkanal aufs Handy, damit das
Ganze auch dann arbeiten kann, wenn niemand davorsitzt.

Läuft auf einem Mini-PC (Proxmox), bedient wird es vom Mac.

Status: **eingestellt.** Messen und Ausführen standen: drei Adapter, Eval-Runner,
Telegram-Rückkanal, erste Messreihen über die Aufgabenladder. Entscheiden und
Erinnern fehlen — `orchestrator/` und `memory/` sind leer. Wohin es von hier
geht, steht unter [Wohin das läuft](#wohin-das-läuft).

## Der Leitgedanke

Die Agenten von heute sind in achtzehn Monaten ausgetauscht. Wertvoll ist
nicht der Harness, sondern was sich **ansammelt**: Skills, Gedächtnis, Evals
und die Aufzeichnung darüber, was funktioniert hat.

> **Alles Wertvolle ist portabel, versioniert und langlebiger als jeder Harness.**

Daraus folgt der Rest: Markdown und JSON in Git statt Datenbanken. Modelle als
Konfiguration statt im Code. Ein dünner Adapter pro Harness statt Verdrahtung.
Wenn in zwei Jahren nichts von dem, was heute installiert ist, noch aktuell
ist, bleibt trotzdem alles erhalten, was zählt.

**Kein Anbieter ist gesetzt — auch Claude nicht.** Skills, Gedächtnis, Evals
und Manifeste sind Markdown und JSON; kein Harness besitzt sie. Wo ein Harness
eigene Konventionen hat, sitzt das in `adapters/` und nirgends sonst. Fällt
einer weg, fehlt ein Adapter, sonst nichts. Der Vertrag dafür steht in
[adapters/README.md](adapters/README.md).

## Aufbau

```
skills/        Fähigkeiten als Markdown. Quelle der Wahrheit.
memory/        Projektgedächtnis, Markdown mit Frontmatter.
evals/         Runner und Score-Historie.
               Die Testfälle selbst liegen bei der jeweiligen Skill.
adapters/      Pro Harness: bringt skills/ und memory/ dorthin,
               wo der Harness sie erwartet.
orchestrator/  Scheduler, Zielarbeit, Wächter, Durchsetzung der
               Projekt-Manifeste. Entwurf steht, Code nicht.
bridge/        Telegram — Rückkanal, Freigaben, Bewertungen.
config/
  models.yaml       Rollen (cheap/strong/reviewer/media) → Anbieter
  projects/*.yaml   Ein Manifest pro Projekt
bin/           bootstrap und Wartung
```

## Die drei Werkzeuge gegen falsche Ausgaben

„Wir bauen alles als RAG, dann halluziniert nichts" funktioniert so nicht.
Retrieval reduziert Halluzination, beseitigt sie aber nicht — und für den
größten Teil der Fragen ist es ohnehin das falsche Mittel. Drei Fragetypen,
drei Werkzeuge:

| Frage | Werkzeug | Warum |
|---|---|---|
| „Wie haben wir das letzte Mal gelöst?" | **Retrieval** über `memory/` | unscharfes Erinnern, genau richtig |
| „Was ist in diesem Projekt verboten?" | **Manifest**, durchgesetzt | Retrieval übersieht das irgendwann |
| „Ist dieser Code korrekt?" | **Ausführen** — Tests, Compiler, Linter | Grundwahrheit, kostenlos |

Der stärkste Hebel ist der dritte. Ein Agent, der seine Testsuite laufen
lässt, ist zuverlässiger als jedes Retrieval-Setup. Deshalb hat jedes
Projekt-Manifest ein `checks:`-Feld — das ist der Maßstab, an dem Ergebnisse
gemessen werden.

Dazu die Disziplin, dass jede Behauptung aus dem Gedächtnis ihre Quelle
mitführt. Wer nicht belegen kann, sagt „weiß ich nicht".

## Skills, die sich verbessern

Eine Skill ist Markdown. Verbessert wird sie über einen Kreislauf:

```
Skill läuft  →  Ergebnis wird geprüft  →  Lektion fließt in die Datei
     ↑                                              │
     └──────── Evals sagen, ob es besser wurde ─────┘
```

Zwei Dinge entscheiden darüber, ob das Lernen ist oder Driften:

**1. Ohne Feedbacksignal ist es ein Zufallslauf.** Ein Reviewer-Agent, der
„das war gut" sagt, rät genauso wie der, den er bewertet. Deshalb pro Skill
eine Handvoll Referenzaufgaben, die vor und nach einer Änderung laufen.
Format steht schon — siehe unten.

### Zwei Ebenen, die nicht vermischt werden dürfen

Wenn ein Ergebnis schlecht ist, gibt es zwei völlig verschiedene Ursachen:

| Ebene | Frage | Was sie verbessert |
|---|---|---|
| **Wahl** | War das überhaupt das Richtige? | Urteilsvermögen: wann welches Werkzeug |
| **Ausführung** | Das Richtige, aber gut gemacht? | Skill- und Harness-Qualität |

Evals messen nur die **Ausführung**. Beides in einen Topf zu werfen macht die
Verbesserungsschleife wertlos: Bei einem schlechten Ergebnis weiß niemand, ob
das falsche Werkzeug gewählt oder das richtige schlecht bedient wurde — und
verbessert dann womöglich die Skill, obwohl die Wahl der Fehler war.

Bei einem offenen Workflow ist die **Wahl** die schwierigere und wichtigere
Ebene. Deshalb fragt die Bridge nach beidem getrennt: erst „war das der
richtige nächste Schritt?", dann „war die Umsetzung gut?".

**2. Skills müssen schrumpfen, nicht nur wachsen.** Jede angehängte Lektion
macht die Datei länger. Eine Skill mit 3000 Zeilen angesammelter Sonderfälle
ist *schlechter* als eine mit 200, weil sich die Aufmerksamkeit des Modells
verteilt. Der Kreislauf braucht einen Konsolidierungsschritt, der
zusammenstreicht und nur behält, was das Verhalten tatsächlich ändert.

### Eval-Format

Stammt aus der `launchpad`-Skill, die inzwischen aussortiert ist — das Format
hat sie überlebt, weil es taugt:

```json
{
  "skill_name": "launchpad",
  "evals": [
    {
      "id": 1,
      "prompt": "…",
      "expected_output": "Prosa, für Menschen",
      "expectations": [
        "@phosphor-icons/web listed in package.json dependencies",
        "At least 2 language directories (en/, de/) in i18n structure"
      ]
    }
  ]
}
```

`expectations` ist der wertvolle Teil: **deterministisch prüfbare Aussagen.**
Grep-bar, objektiv, kein Modell nötig, das über ein Modell urteilt.
`expected_output` ist nur Prosa für den menschlichen Leser.

## Der Skill-Bestand

Hier liegt genau **eine** Skill: `app-monetization-audit`.

Das ist Absicht. Von den acht aus `~/.claude/skills/` übernommenen waren drei
bereits per `skillOverrides` in `settings.json` abgeschaltet — also seit
Monaten ungenutzt. Zwei davon (`launchpad`, `website-ux-architect`)
überschnitten sich zudem stark, was erklärt, warum keine von beiden richtig
saß. `find-skills` löst agent-lab selbst ab.

Alle liegen weiterhin in `~/.claude/skills/`.

> **Öffentliche Fassung:** Die eine Skill `app-monetization-audit` ist hier
> nicht enthalten, sie beruht auf dem Playbook eines Dritten. `skills/` ist
> deshalb leer; die Beispiele unten zeigen ihren Namen trotzdem.

Skills sind ein **Werkzeugkasten**, keine Stationen einer Reihe. Jede hat
Bedingungen, unter denen sie überhaupt anwendbar ist —
`app-monetization-audit` taugt, wenn es eine Paywall zu prüfen gibt, und ist
davor sinnlos. Was fehlt, sind Werkzeuge für frühe Zustände: Recherche und
Konzeptarbeit. Bauen selbst ist Sache des Harness, keine Skill.

## Offener Workflow

**Es gibt keine feste Reihenfolge.** Projekte steigen mittendrin ein — eines
hat schon eine Store-Seite, aber keine Tests; ein anderes ist eine Idee ohne
Zeile Code; ein drittes läuft seit Monaten und braucht nur Pflege. Ein
System, das immer bei Schritt 1 anfängt, ist für alle drei unbrauchbar.

Die zentrale Frage ist deshalb nicht „welcher Schritt kommt als Nächstes",
sondern:

> **Wo steht dieses Projekt gerade, und was ist von hier aus das Nützlichste?**

Das setzt voraus, dass der Zustand überhaupt festgehalten wird. Das Manifest
in `config/projects/` hält nur das **Statische** — Sprache, Grenzen, Checks.
Der **bewegliche** Teil gehört ins Gedächtnis, eine Datei pro Projekt:

```markdown
---
project: beispiel-app
updated: 2026-08-16
---

## Zustand
- Paywall existiert, ungetestet
- Store-Seite steht, Screenshots veraltet
- Keine Testabdeckung im Bezahlpfad

## Versucht
- 2026-08-10 Preis von 4,99 auf 6,99 — Conversion unverändert, zurückgedreht
- 2026-08-14 Onboarding gekürzt — Abbruch von 60 % auf 41 %

## Hängt gerade an
- Unklar, ob Trial oder Direktkauf besser trägt
```

Das ist das eigentliche Substrat für „von da aus anfangen, wo es steht" — und
es ist auch das, was sich durch Arbeit **ansammelt**. Nicht die Skills sind
das Wertvolle, sondern das hier.

## Harness-Vergleich

Ziel ist nicht „welcher Harness ist objektiv der beste", sondern **„welcher
ist der beste für meine Arbeit"**. Synthetische Benchmarks beantworten das
nicht.

Deshalb: Derselbe Auftrag geht an verschiedene Harnesses, jeder auf einem
eigenen Branch. Objektives fällt automatisch an — Checks grün, Dauer, Token,
Kosten, Anzahl Runden. Subjektives kommt über die Bridge: Zusammenfassung und
Diff aufs Handy, du antwortest mit 👍/👎 und einer Zeile.

Nach ein paar Wochen liegen Vergleichsdaten über echte Arbeit vor, ohne dass
je ein Benchmark geschrieben wurde.

## Wer entscheidet, und womit man redet

Zwei Betriebsarten, die beide bleiben müssen:

```
"Mach mir X"          →  Orchestrator → klassifiziert → Harness → Ergebnis + Kosten
"Ich arbeite gerade"  →  direkt in den Harness (OpenCode-Weboberfläche)
```

Beim Orchestrator gibst du ein Ziel ab. Beim direkten Weg sitzt du selbst am
Steuer und willst keinen Vermittler. Ein System, das jede Kleinigkeit durch
den Orchestrator zwingt, nervt; eines ohne kann nichts allein.

Telegram, Terminal und später eine kleine Weboberfläche sind nur verschiedene
Türen zum selben Orchestrator.

### Die Klassifizierung

Drei Möglichkeiten, wer die Aufgabe zuordnet:

| Wer | Stärke | Schwäche |
|---|---|---|
| Du | kostet nichts, kennt die Absicht | du musst da sein |
| Eine Regel | deterministisch, gratis | spröde, kennt den Projektzustand nicht |
| **Ein Modell** | flexibel, liest den Zustand | kostet einen Aufruf, kann irren |

Für einen festen Ablauf wäre explizites Dispatch richtig. Bei einem **offenen**
Workflow trägt es nicht: Wenn von dort angefangen werden soll, wo ein Projekt
gerade steht, muss etwas den Zustand lesen und daraus schließen — das kann
keine Regel.

Also ein Modell, unter drei Bedingungen:

**Es klassifiziert mit dem billigen Modell.** Teuer zu entscheiden, was billig
erledigt werden soll, wäre absurd.

**Das Modell ist festgenagelt** (`pinned: true` in `config/models.yaml`).
Sonst bewerten alle Rückmeldungen zur Wahl ein bewegliches Ziel. Festgenagelt
bleibt als einzige Variable die Anweisungsdatei — als Diff lesbar.

**Die Entscheidung ist sichtbar**, nicht implizit:

```json
{
  "aufgabe": "Paywall-Conversion verbessern",
  "projekt": "beispiel-app",
  "zustand_gelesen": ["Paywall existiert, ungetestet",
                      "Preisversuch 6,99 lief bereits, zurückgedreht"],
  "vorschlag": { "skill": "app-monetization-audit",
                 "rolle": "strong", "harness": "opencode" },
  "begruendung": "Paywall vorhanden, also auditierbar. Preisexperiment
                  nicht wiederholen, das lief schon.",
  "kosten_schaetzung_usd": 0.40
}
```

Das ist die **Wahl**-Ebene: bewertet wird sie getrennt vom Ergebnis, und aus
den Bewertungen verbessert sich die Anweisungsdatei des Klassifizierers.

### Das Risiko

Der Klassifizierer ist ein Einzelpunkt, an dem eine Fehlentscheidung das ganze
Aufgabenbudget verbrennt — falsches Werkzeug, zwanzig Minuten Laufzeit,
Unsinn am Ende. Dagegen zwei Dinge: Er ist selbst fast gratis, und **oberhalb
einer Kostenschwelle fragt er, statt zu handeln**. Schätzung und Begründung
gehen dann per Telegram raus.

Die Schwelle ist der Regler zwischen Autonomie und Kontrolle. Anfangs niedrig,
und hochziehen, sobald die Vorschläge sichtbar taugen.

## Kosten

Ein Deckel allein reicht nicht — man muss **sehen**, wohin das Geld geht.
Jeder Lauf liefert `cost_usd` über den Adapter-Vertrag; daraus wird
aufsummiert nach **Projekt**, **Harness**, **Rolle** und **Tag**. Die Zahlen
landen als Datei im Repo, sind also versioniert und nachlesbar.

### Abo ist nicht gleich API

Der wichtigste Unterschied in der Aufstellung:

| | Abrechnung | In der Aufstellung |
|---|---|---|
| **OpenRouter** (classifier, cheap, strong, media) | pro Token | echtes Geld |
| **Abo-Harnesses** (Claude Code, Codex) | Flatrate | am Rand **kostenlos** |

Ein Abo-Harness kann bei gleicher Qualität schlicht die bessere Wahl sein,
weil er nichts zusätzlich kostet — er zehrt nur an Kontingenten. Wer das nicht
auseinanderhält, vergleicht bezahlte gegen bereits bezahlte Arbeit und kommt
zu falschen Schlüssen. Deshalb trägt jede Rolle ein `billing:`-Feld, und der
Deckel greift nur für `api`.

Zwei weitere Dinge werden erst durch die Aufstellung sichtbar:

**Kosten sind die Hälfte des Harness-Vergleichs.** Ein Harness, der 10 %
bessere Ergebnisse liefert und dabei das Fünffache kostet, ist nicht besser.
Qualitätsbewertung ohne Preis daneben führt zuverlässig zur teuren Antwort.

**Die `cheap`-Rolle rechtfertigt sich oder nicht.** Läuft mechanische Arbeit
tatsächlich über das billige Modell, oder eskaliert am Ende doch alles nach
oben? Und was kostet DeepSeek Flash über den Monat wirklich? Billig ist nicht
gratis.

**Selbstverbesserung hat ein eigenes Kontingent** (`self_improvement_pct`,
derzeit 20 %). Eval-Läufe kosten echtes Geld für Arbeit, die nichts
ausliefert. Getrennt ausgewiesen kann sie den eigentlichen Zweck nie
verdrängen — und du siehst, was dich das Lernen kostet.

Dazu die harte Grenze aus `config/models.yaml` — bei Erreichen meldet sich
das System über die Bridge, statt weiterzulaufen. Eine autonome Schleife mit
API-Schlüssel und ohne Deckel ist der klassische Weg zu einer vierstelligen
Monatsrechnung.

Ein Tagesbericht auf dem Handy schließt das ab: was lief, was kam dabei
heraus, was hat es gekostet.

## Deploy

Ziel: **ein Rechner, ein `git clone`, eine Secrets-Datei — läuft.**

Die Trennlinie ist hart: **Config ja, Secrets niemals.** Ins Repo kommt alles
außer Zugangsdaten.

```
Im Repo                         Getrennt eingespeist (.env)
────────────────────            ───────────────────────────
skills/  memory/  evals/        TELEGRAM_BOT_TOKEN
config/  orchestrator/          OPENROUTER_API_KEY
adapters/  bridge/              ANTHROPIC_API_KEY
```

Das System **committet sein eigenes Gedächtnis zurück ins Repo**. Damit ist
das Repo gleichzeitig das Backup: Stirbt die Maschine, klonst du woanders und
machst weiter. Skill-Verbesserungen und Gedächtniswachstum sind dabei lesbare
Diffs statt undurchsichtiger Datenbankzustände.

Zwei Startmodi — aus vorhandenem Repo wiederherstellen, oder leeres Skelett
anlegen.

## Autonomie und ihre Grenzen

Festgelegt: läuft frei innerhalb Budget und Leitplanken, merged Triviales
selbst, meldet sich bei echten Blockaden.

Was das System **selbst** darf: sein Gedächtnis pflegen, seine
Konventionsdateien schärfen, Projektwissen aufschreiben, triviale PRs mergen.

Was es **nicht** allein darf: seinen eigenen Code umschreiben, seine
Architektur ändern, neue Projekte tatsächlich starten. Das schlägt es als PR
vor und fragt über die Bridge.

Der Grund ist Erfahrung, nicht Prinzipienreiterei: Selbstbauende Systeme
erzeugen sehr schnell sehr viel plausibel aussehendes Gerüst. Das Problem ist
nicht die erste Woche, sondern die dritte — niemand hat den Code je gelesen,
die Komplexität wächst schneller als das Verständnis, und „selbstverbessernd"
wird zu **selbstverkomplizierend**. Es verbessert, was es weiß, nicht was es
ist.

## Wohin das läuft

Der Ist-Zustand ist eine Messmaschine: Aufgaben laufen, Zahlen fallen an,
Modelle lassen sich vergleichen. Was fehlt, ist die Fähigkeit, über Wochen am
**selben Thema** zu arbeiten. Das ist das Ziel — und es ist kein
Modellproblem.

Wie das konkret aussehen soll — vom vagen Satz über Recherche und Zielfreigabe
bis zu den drei Ausgängen einer Aufgabe — steht als Entwurf in
[orchestrator/README.md](orchestrator/README.md), zusammen mit den neun
Bausteinen, die dabei **gestrichen** wurden, und der Prüfung, ob es das
fertig gibt.

### Faden und Episode

Lange Arbeit zerfällt in zwei Dinge, die gern verwechselt werden:

| | Was es ist | Wo es lebt |
|---|---|---|
| **Episode** | ein Arbeitsschritt, ein Branch, ein PR | Git, kurzlebig |
| **Faden** | das Thema, das viele Episoden überdauert | `memory/`, langlebig |

Ein PR ist irgendwann fertig oder verworfen. Ein Faden ist Wochen später noch
offen und muss beantworten können: wo stehen wir, was wurde schon versucht,
woran hängt es. Ohne ihn fängt jede Sitzung von vorn an — bei beliebig großem
Kontextfenster und beliebig gutem Modell.

Der Hebel ist dabei nicht der Status, sondern die **Versucht-Liste**. Ein
Agent, der in Woche drei das Preisexperiment aus Woche eins wiederholt, ist
nicht schlecht gewählt, sondern schlecht erinnert.

### Die Reihenfolge

1. **Zustandsdatei pro Thema** in `memory/`, Format wie unter
   [Offener Workflow](#offener-workflow). Ohne sie hat der Klassifizierer
   nichts zu lesen und entscheidet im Blindflug.
2. **Eskalation nach Fehlschlag.** Bisher wählt der Klassifizierer die Rolle
   vorab. Was fehlt: `checks` rot → dieselbe Aufgabe an die stärkere Rolle,
   und der Fehlschlag wandert in die Versucht-Liste. Erst das macht aus dem
   Router ein System mit Gedächtnis.
3. **Eine Ladder-Stufe, die das billige Modell reißt.** DeepSeek Flash steht
   bei 9/9 auf S/M/L — die Ladder ist gesättigt. Solange jeder Kandidat
   besteht, entscheidet allein der Preis, und ein stärkeres Modell kann sich
   gar nicht qualifizieren.

### Der Tracker ist Ansicht, nicht Wahrheit

Issues, PRs und Labels sind bequem und vom Handy brauchbar — GitHub, Forgejo
oder GitLab tun das alle. Aber ein Tracker ist eine Datenbank, und der
Leitgedanke oben schließt Datenbanken als Quelle der Wahrheit aus.

Also: **Markdown in `memory/` ist die Wahrheit, der Tracker ist eine
Einweg-Projektion daraus.** Nie bidirektional synchronisieren — das sind zwei
Autoren auf einem Zustand.

### Wo Fremdwerkzeuge sitzen, und wo nicht

Geprüft 2026-09-07. Vier verbreitete Werkzeuge, alle verworfen oder
zurückgestellt:

| Werkzeug | Entscheidung |
|---|---|
| **9router** | Nein. Stilles Ausweichen im selben Anfragepfad läuft Leitsatz 4 zuwider, die Kostenanzeige ist ausdrücklich fiktiv, und Abo-Pooling ist bei Anthropic seit April 2026 blockiert |
| **Headroom** | Zurückgestellt. Komprimiert Werkzeug-Ausgaben, nicht die Grundlast — und die ist hier der Kostentreiber. Sein `learn` schreibt zudem in die Gedächtnisschicht, wäre also ein zweiter Autor |
| **OpenHands** | Nein für Abo-Rollen. Spricht Modelle nur über API-Schlüssel, macht damit alles zu `billing: api` und löscht Leitsatz 1 |
| **Diffy** | Irrelevant. Für die Handy-Ansicht reicht ein Compare-Link aus der Bridge |

Das Muster dahinter: alle vier beantworten „wie werden Token billiger". Die
Frage hier ist „wie sammelt sich an, was funktioniert hat". Für die zweite
gibt es keinen Anbieter.

### Was bewusst nicht kommt

Mehr Messung. Der Harness-Vergleich hat geliefert, was er sollte — der
Grundaufwand hängt an der Paarung aus Harness und Modell, nicht am Harness
allein. Weiter zu messen liefert befriedigende Zahlen und wächst von selbst.
Die dritte Woche aus [Autonomie und ihre Grenzen](#autonomie-und-ihre-grenzen)
gilt auch für den, der das hier baut.

## Offen

- [x] Telegram-Bridge verbunden — @dein_bot, Zugangsdaten in `.env`
- [x] PVE-Benachrichtigungen laufen zusätzlich über Telegram
      (`bin/pve-telegram-notify.sh`, end-to-end verifiziert)
- [x] Skill-Bestand durchgegangen und ausgedünnt — siehe oben
- [x] Adapter für `claude`, `oh-my-pi` und `opencode` — der Vertrag trägt,
      Messreihen liegen vor
- [ ] Eskalation nach Fehlschlag: `checks` rot → stärkere Rolle, Fehlschlag
      in die Versucht-Liste. **Als Nächstes**, zusammen mit der Zustandsdatei
- [ ] Ladder-Stufe, die das billige Modell reißt — ohne sie bestehen alle
      Kandidaten und die Wahl fällt allein auf den Preis
- [ ] Bridge-Logik: Rückfragen, Freigaben, Bewertungen
- [ ] Eval-Runner gegen das JSON-Format
- [ ] Orchestrator: Scheduler, Aufgabenliste, Budgetwächter
- [ ] `app-monetization-audit` hat noch keine `expectations` —
      nachziehen, sobald der Runner steht
- [ ] `skills/` per Symlink zur Quelle der Wahrheit machen —
      aktuell **Kopie**, das Original liegt in `~/.claude/skills/`
      und läuft sonst auseinander
- [ ] Zustandsdatei pro Projekt in `memory/` — das Substrat für
      „von da aus anfangen, wo es steht"
- [ ] Kostenaufstellung nach Projekt/Harness/Rolle/Tag, plus Tagesbericht
      über die Bridge
- [ ] Bridge fragt Wahl und Ausführung **getrennt** ab
- [ ] Erstes Projekt-Manifest anlegen (Beispiel-App?)
- [ ] Privates GitHub-Repo als Deploy-Quelle
- [x] Container auf dem Mini-PC — CT 102 (Worker) und CT 103 (Hermes), seit 2026-09-13
      in der Rollenteilung aus [orchestrator/hermes.md](orchestrator/hermes.md).
      Netztrennung gegen HA und AdGuard weiter offen
- [ ] Hermes-Adapter `adapters/hermes/` und Ladder-Lauf — Plan in
      [orchestrator/hermes.md](orchestrator/hermes.md)
- [ ] `bridge/` durch Hermes-Gateway ablösen; README dort bleibt als Prüfliste
- [ ] Research- und Konzept-Skill — die Lücke am vorderen Ende der Pipeline
