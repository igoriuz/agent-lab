# Bridge

Der Rückkanal: Rückfragen, Freigaben, Bewertungen, Tagesberichte. Über
Telegram, weil das überall funktioniert — auch ohne Tailscale, auch ohne
Browser.

Bot: `@dein_bot`

## Absicherung — zuerst lesen

**Telegram-Bots sind öffentlich adressierbar. Jeder, der den Namen kennt,
kann schreiben, und das lässt sich nicht abschalten.** Bot-Namen sind zudem
durchprobierbar; Unauffälligkeit ist kein Schutz.

Ohne Absicherung wäre die Bridge eine **offene Fernsteuerung des
Orchestrators** — auf einer Maschine mit API-Schlüsseln und Schreibrechten
auf die Repos. Freigaben erteilen, Läufe auslösen, Anweisungen einschleusen.

Deshalb gilt, nicht verhandelbar:

### 1. Allowlist — auf Absender UND Chat

Geprüft werden **beide** Felder:

| Feld | Bedeutung |
|---|---|
| `from.id` | **wer** geschrieben hat — die eigentliche Kontrolle |
| `chat.id` | **wo** geschrieben wurde |

Im privaten Einzelchat sind beide identisch (hier `123456789`). Sie laufen
erst auseinander, wenn der Bot je in eine **Gruppe** gerät: Dann ist
`chat.id` die Gruppe, `from.id` weiterhin die einzelne Person. Wer nur
`chat.id` prüft, hätte damit **jedes Gruppenmitglied** freigeschaltet.

Verworfen wird, **bevor** irgendetwas mit der Nachricht geschieht — kein
Parsen, kein Weiterreichen an ein Modell, keine Antwort.

Die erlaubten IDs stehen als **Liste** in `.env`
(`TELEGRAM_ALLOWED_USER_IDS`, kommagetrennt) — auch wenn dort heute nur eine
steht. Das kostet jetzt nichts und spart den Umbau, sobald ein zweites Gerät
oder eine zweite Person dazukommt.

```python
msg = update.get("message") or {}
if str(msg.get("from", {}).get("id")) not in ALLOWED_USER_IDS \
   or str(msg.get("chat", {}).get("id")) not in ALLOWED_CHAT_IDS:
    log_rejected(update)        # zählen, nicht antworten
    return
```

**Nicht antworten, auch nicht mit „Kein Zugriff".** Eine Antwort bestätigt,
dass hinter dem Bot etwas Aktives läuft, und macht ihn zum lohnenden Ziel für
weitere Versuche. Der Preis ist, dass jemand, der sich legitim vertippt, keine
Rückmeldung bekommt — bei einem privaten Automatisierungsbot verschmerzbar.

Ebenfalls prüfen: `edited_message`, `callback_query` (die Knöpfe unter
Freigaben!) und `channel_post`. Ein Knopfdruck kommt als `callback_query` und
hat seine eigene `from.id` — wer nur `message` absichert, lässt die Freigaben
offen.

### Wie das geprüft wird — ohne zweiten Account

Die Prüfung ist eine **reine Funktion** (`allowlist.py`): Update rein,
erlaubt/verworfen raus, kein Netzwerk. Damit ist sie mit erfundenen Updates
vollständig durchtestbar — auch in Fällen, die man live gar nicht herstellen
könnte.

```
python3 bridge/test_allowlist.py
```

16 Fälle, darunter die beiden, auf die es ankommt:

| Fall | Deckt auf |
|---|---|
| Fremder schreibt in den erlaubten Chat | eine reine `chat.id`-Prüfung wäre umgangen |
| Ich selbst schreibe in einer Gruppe | eine reine `from.id`-Prüfung wäre umgangen |

Dazu Knopfdrücke von Fremden, bearbeitete Nachrichten, Kanalbeiträge, IDs als
Zahl **und** als Text, und Updates mit fehlenden Feldern.

Und der Fall, der beim Deploy zur Falle wird: **leere Allowlist sperrt
alles.** Wäre der Default umgekehrt, würde eine vergessene `.env` den Bot
lautlos öffnen — der Bot liefe, alles sähe normal aus, und jeder käme durch.

Ein Live-Test mit absichtlich falscher ID in `.env` ist als Gegenprobe
möglich, aber nicht nötig: Die Tabelle deckt mehr ab, als sich von Hand
herstellen lässt.

### 2. Erst prüfen, dann verstehen

Die Prüfung steht **vor** jeder Verarbeitung. Nachrichtentext von Fremden
darf nie in einen Modell-Prompt geraten — sonst ist die Allowlist umgangen,
sobald jemand Anweisungen in eine Nachricht schreibt, die das System als
Kontext einliest.

### 3. Abgewiesene Zugriffe zählen

Nicht beantworten, aber protokollieren. Häufen sich Versuche, weiss man,
dass jemand am Bot herumprobiert — und kann den Bot bei BotFather löschen
und neu anlegen.

### 4. Schreibende Aktionen brauchen eine Bestätigung

Auch aus dem richtigen Chat: Freigaben mit Folgen (Merge, Deploy,
Budgeterhöhung) werden mit einer Rückfrage bestätigt, nicht mit einem
einzelnen Tastendruck ausgeführt. Schützt gegen ein entsperrtes Telefon in
fremder Hand — der Fall, den die Allowlist nicht abdeckt.

### Was die Allowlist nicht leistet

- **Token-Verlust.** Wer den Bot-Token hat, kann Nachrichten an den Bot
  lesen und in seinem Namen senden. Er liegt in `.env` mit Rechten 600 und
  gehört nie ins Repo. Bei Verdacht: bei BotFather neu erzeugen.
- **Vertraulichkeit.** Bot-Nachrichten sind nicht Ende-zu-Ende
  verschlüsselt. Telegram sieht mit. Für Freigaben und Statusmeldungen
  vertretbar — keine Geheimnisse über diesen Kanal schicken.

## Aufgaben

| Richtung | Inhalt |
|---|---|
| System → du | Rückfragen bei Verzweigungen, Kostenschätzung über Schwelle, Ergebnis mit Diff, Tagesbericht, Kontingentwarnungen |
| du → System | Freigabe, Ablehnung, Bewertung, freie Anweisung |

### Bewertungen sind zweistufig

Getrennt gefragt, weil sie Verschiedenes verbessern:

1. **War das der richtige nächste Schritt?** → Urteilsvermögen des
   Klassifizierers
2. **War die Umsetzung gut?** → Skill- und Harness-Qualität

Zusammengeworfen wird die Verbesserungsschleife wertlos: Bei einem schlechten
Ergebnis weiss sonst niemand, ob das falsche Werkzeug gewählt oder das
richtige schlecht bedient wurde.

## Stand

- [x] Bot angelegt, Zugangsdaten in `.env`, Versand verifiziert
- [x] PVE-Benachrichtigungen laufen bereits darüber
      (`bin/pve-telegram-notify.sh`)
- [x] Allowlist implementiert und getestet (`allowlist.py`, 16 Fälle)
- [ ] Empfang: Polling-Schleife, die den Filter benutzt
- [ ] Freigabe-Ablauf
- [ ] Zweistufige Bewertung
- [ ] Tagesbericht mit Kontingentstand
