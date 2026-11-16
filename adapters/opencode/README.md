# Adapter: opencode

Erfüllt den Vertrag aus [../README.md](../README.md).

## Einrichtung

Provider wird deklarativ in `~/.config/opencode/opencode.json` konfiguriert,
Schlüssel kommt aus der Umgebung:

```json
{
  "provider": {
    "opencode-go": {
      "npm": "@ai-sdk/openai-compatible",
      "options": {
        "baseURL": "https://opencode.ai/zen/go/v1",
        "apiKey": "{env:OPENCODE_API_KEY}"
      }
    }
  }
}
```

## Was er liefert

| Feld | Quelle | Verlässlich |
|---|---|---|
| `turns` | Anzahl `step_start`-Ereignisse | ja |
| `tokens_in` / `tokens_out` | `step_finish.part.tokens` | ja |
| `cost_usd` | `step_finish.part.cost`, aufsummiert | siehe unten |
| `commits` | `git rev-list BEFORE..AFTER` | ja |
| `duration_s` | Wanduhr | ja |

**`cost_usd` ist bei Abo-Abrechnung kein Rechnungsbetrag**, sondern der
Maßstab für den **Kontingentverbrauch**. Genau die Zahl, die zählt, wenn
Geld nicht mehr die knappe Ressource ist, sondern das Kontingent.

Fehlen Nutzungsdaten, stehen die Felder auf `null` statt `0` — „nicht
gemessen" ist etwas anderes als „nichts verbraucht", und nur dieser
Unterschied hält den Vergleich ehrlich.

## Beobachtungen aus der Inbetriebnahme

**Jeder Lauf kostet rund 6.200 Eingabe-Token Grundlast**, unabhängig von der
Aufgabengröße — Systemprompt und Werkzeugbeschreibungen. Bei einem
Abo-Kontingent ist das die dominierende Größe für kleine Aufgaben: Zehn
Kleinstaufgaben kosten mehr als eine mittlere.

**`exit_code: 0` heißt nicht, dass die Aufgabe erledigt ist.** Im ersten
Testlauf meldete das Modell im Text, es habe den Docstring hinzugefügt — die
Datei war unverändert. Der Vertrag zeigte das korrekt als `commits: 0`.

Daraus die Regel: **`commits` und die `checks:` aus dem Projekt-Manifest sind
das Erfolgsmaß, nicht der Rückgabewert.** Ein Agent, der behauptet fertig zu
sein, ist keine Evidenz.

**`mimo-v2.5` ist bei Werkzeugnutzung nicht zuverlässig**: dieselbe triviale
Aufgabe (Docstring ergänzen, committen) ging zwei von drei Läufen durch.
Erster Datenpunkt für den Modellvergleich, noch keine Statistik.
