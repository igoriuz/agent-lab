# Hermes als Laufzeit

**Stand: 2026-09-13, fortgeschrieben 2026-09-23.** Schritte 0–3 durch, 4 und 5
offen. Was sich seitdem geändert hat, steht gesammelt im Abschnitt
[Stand 2026-09-23](#stand-2026-09-23); die Ladder-Zahlen in
[../evals/README.md](../evals/README.md). Die Quellen vom selben Tag (PRD,
Entscheidungsbericht, Best-Practices-Sammlung) sind nicht Teil der
öffentlichen Fassung.

> **2026-10-14: Hermes ist als Coder vorerst raus.** Alle Rollen laufen über
> Claude Code mit dem Anthropic-Abo, gestaffelt über Modell und Effort — siehe
> [../config/models.yaml](../config/models.yaml). Die GLM-Linie unten ist
> damit Historie. Offen bleibt, ob Hermes als Rückkanal (Telegram, Cron) noch
> etwas beiträgt.

## Die Entscheidung

**Hermes Agent ist die Laufzeit, agent-lab ist die Wertschicht.**

Hermes bringt, was in der Offen-Liste des [Orchestrator-Entwurfs](README.md)
seit Wochen steht und nie gebaut wurde: Scheduler (Cron), Rückkanal
(Gateway), Gedächtnis, Profile mit eigenem Modell und eigenen Skills, und mit
`/goal` sogar eine Zielarbeit. Es ist MIT, BYOK, an keinen Anbieter gebunden,
und hält Skills und Memory als Dateien. Das passt zum Leitgedanken.

Was Hermes **nicht** hat, bleibt agent-lab: Einfrieren eines Ziels per
Freigabe, verdeckte Abnahme, verworfene Alternativen, Versuchsbudget,
Versucht-Liste. Das sind Konventionen und dünne Skripte, kein eigener
Orchestrator in Python.

Die Regel aus dem Tracker-Abschnitt gilt unverändert: **agent-lab ist Quelle,
Hermes bekommt eine Einweg-Projektion.** Skills, Manifeste (als `AGENTS.md`)
und Modellrollen wandern per Adapter nach Hermes, nie zurück.

Die Prüfung vom 2026-09-07 hatte Hermes nicht auf dem Zettel, obwohl der
Container seit dem 08-30 lief. Dieser Text schließt die Lücke; die Zeile in
der Fremdprojekt-Tabelle steht in [README.md](README.md).

## Ist-Zustand, geprüft 2026-09-13

| | CT 103 `hermes` | CT 102 `agent-lab` |
|---|---|---|
| Adresse | `192.168.1.21`, Tailnet `hermes` | `192.168.1.20`, Tailnet `agent-lab` |
| Ressourcen | 4 GB, 4 Kerne | 8 GB, 4 Kerne |
| Zustand | Hermes **v0.21.2** (2026.9.11), heute aktualisiert. `hermes-serve` aktiv, Gateway nie eingerichtet | heute wieder gestartet, User `agent`, `/opt/agent-lab` vorhanden |
| Modell | `xai-oauth` / `grok-4.6` | Harnesses `claude`, `oh-my-pi`, `opencode` |
| Inhalt | 0 Sessions, Memory leer, 12 Stock-Skills | Repo-Kopie vom 2026-08-30 |
| Keys | `OPENCODE_GO_API_KEY` — **verletzt Leitsatz 2**, raus | `.env` aus dem Repo |

Beide hängen auf `vmbr0` im selben Netz, die Proxmox-Firewall ist aus. Sie
sehen sich. Hostdetails in
der Proxmox-Doku des Mini-PCs.

## Rollenteilung

```
CT 103  hermes       denkt und redet
        Telegram-Gateways, Profile, Memory, Cron, alle Keys
              │  SSH  (TERMINAL_ENV=ssh, User agent)
              ▼
CT 102  agent-lab    arbeitet
        Repos, Toolchains, claude / oh-my-pi / opencode, /opt/agent-lab
```

Das ist das von Hermes dokumentierte Sicherheitsmuster: der Agent kann seine
eigene `.env` nicht lesen und seinen Code nicht ändern, der Worker hat
passwortloses `sudo`, weil der Container die Sandbox ist. Die LAN-Adresse
statt des Tailnet-Namens ist Absicht: sie funktioniert auch, wenn nach einem
Restore `/dev/net/tun` fehlt. Die Netztrennung aus der Offen-Liste braucht
später eine Regel `.21 → .20:22`.

Pro Profil ist das Backend frei, weil jedes Profil seine eigene `.env` hat.
Der Orchestrator-Bot bleibt `local`, die Spezialisten arbeiten in 102.

## Rückkanal: Telegram

Entschieden 2026-09-13. Ein Bot pro Profil, jeder Bot ein eigener
systemd-Dienst über `hermes gateway install`. Telegram-Bots holen per
Long-Polling ab, es braucht keinen eingehenden Port. Bots sehen in Gruppen
einander nicht; Bot-zu-Bot läuft intern über `message_agent`.

Damit wird [../bridge/](../bridge/) überflüssig. Die README dort bleibt als
Anforderungsliste: **vor dem ersten Gruppeneinsatz prüfen**, ob Hermes wie
dort beschrieben Absender *und* Chat prüft, Knopfdrücke (`callback_query`)
absichert und Fremde stumm verwirft.

Discord wäre die zweite Wahl für viele Bots in Kanälen; die Hermes-Doku warnt
dort vor Bot-zu-Bot-Schleifen. Signal fällt raus: `signal-cli`, Java, eine
Instanz pro Nummer, kein Editieren.

## Der Plan

Jeder Schritt hat einen Beweis. Ohne Beweis kein nächster Schritt.

### 0 · Aufräumen (heute begonnen)

- [x] Hermes aktualisiert auf v0.21.2, `hermes-serve` neu gestartet
- [x] CT 102 gestartet, `onboot: 1` ist jetzt Absicht
- [x] `OPENCODE_GO_API_KEY` aus `~/.hermes/.env` und aus dem Credential-Pool in 103 entfernt
- [ ] Stock-Skills in 103 ausdünnen — nur, was zweimal gebraucht wurde
- [x] Tailscale-Update in 102, Zeitzone auf `Europe/Berlin`, `sudo` installiert und `agent` passwortlos

**Beweis:** `hermes doctor` ohne Leitsatz-2-Key, `hermes skills list` kurz.

### 1 · SSH-Backend nach 102

1. Schlüsselpaar für User `hermes` in 103 (`ssh-keygen -t ed25519`)
2. Public Key nach 102 in `/home/agent/.ssh/authorized_keys`
3. In 103 `~/.hermes/.env`:
   ```
   TERMINAL_ENV=ssh
   TERMINAL_SSH_HOST=192.168.1.20
   TERMINAL_SSH_USER=agent
   TERMINAL_SSH_KEY=/home/hermes/.ssh/id_ed25519
   ```
4. `hermes-serve` neu starten

Schritte 1–4 sind seit dem 2026-09-13 durch, roher SSH von 103 nach 102 antwortet
`agent-lab`. Gesetzt ist beides, `terminal.backend: ssh` mit `ssh_host`/`ssh_user`/`ssh_port`
in `config.yaml` **und** `TERMINAL_ENV`/`TERMINAL_SSH_*` in `.env`, weil ein
`terminal:`-Block in `config.yaml` die `.env` überschreibt; `TERMINAL_SSH_KEY` kennt nur
die `.env`.

**Beweis:** `hermes -z "gib hostname aus"` antwortet `agent-lab`, nicht
`hermes`. **Erbracht 2026-09-13**: Antwort `agent-lab` / `agent` / `/home/agent`.
Vorher war der xAI-OAuth-Token in 103 nach dem Update weg (*logged out*), der Betreiber hat
sich mit `hermes model` neu angemeldet.

### 2 · Modell und Keys

- [x] xAI-OAuth in 103 neu angemeldet (2026-09-13)
- [x] OpenRouter-Key in 103 als gepoolte Credential `openrouter-default` (2026-09-13,
  über die verdeckte Abfrage von `hermes auth add openrouter --type api-key`)
- **Default bleibt `grok-4.6`.** Abo-gedeckt, in agent-lab als `cheap`
  gemessen. GLM-5.3-Flash ist Kandidat, nicht Default — die Best Practices
  warnen vor halluzinierten Tool-Calls bei kleinen Modellen, und gemessen
  wurde Flash bisher nur in anderen Harnesses.
- `/review` auf einem anderen Anbieter, wie `reviewer_provider_differs_from_strong`
  es verlangt. Umsetzung über die Hermes-Auxiliary-Modelle, Quelle bleibt
  `config/models.yaml`.

**Beweis erbracht 2026-09-13:** xAI-Default antwortet `grok-4.6`, OpenRouter mit
`--provider openrouter -m z-ai/glm-5.3-flash` antwortet, und GLM Flash hat über das
SSH-Backend `hostname` in 102 ausgeführt (`agent-lab`). Ein Tool-Aufruf ist noch
keine Ladder — das ist Schritt 3.

### 3 · Hermes-Adapter in agent-lab

`adapters/hermes/` nach dem [Adapter-Vertrag](../adapters/README.md):

| Datei | Tut |
|---|---|
| `install.sh` | `skills/` nach `~/.hermes/skills/` (Einweg, `rsync --delete`), Manifeste als `AGENTS.md` ins jeweilige Repo in 102 |
| `run.sh` | `hermes -z "$TASK_PROMPT"` mit `-p <profil>`, Ausgabe in das JSON des Vertrags |

Danach die S/M/L-Ladder durch den Adapter, drei Läufe pro Stufe, wie bei den
drei anderen. Erst mit `grok-4.6`, dann mit GLM-5.3-Flash.

**Beweis, halb erbracht 2026-09-13.** Adapter gebaut
([../adapters/hermes/](../adapters/hermes/)), Ladder gelaufen, Zahlen in
[../evals/README.md](../evals/README.md):

- **grok-4.6: 9/9**, und bei gleichem Modell 1,8- bis 2,9-mal weniger
  Eingabe-Token als über oh-my-pi. Hermes ist damit als Harness gemessen und
  taugt.
- **GLM-5.3-Flash: nicht gemessen.** OpenRouter-Guthaben aufgebraucht (HTTP 402)
  bevor ein Modell antwortete. Die Entscheidung Flash ja/nein steht damit noch
  nicht auf Messwerten — **Default bleibt grok-4.6.** Nachholen, sobald das
  Guthaben aufgeladen ist: `eval-ladder.sh hermes openrouter/z-ai/glm-5.3-flash 3`
  in CT 102.

### 4 · Profile und Telegram

- Profil `stab` — der Orchestrator. `SOUL.md` aus dem Klassifizierer-Prompt,
  Backend `local`, liest Zustand, verteilt Arbeit per `message_agent`.
- Profil `coder` — Backend `ssh` nach 102, Modell nach Rolle `cheap`.
- Optional `review` — anderer Anbieter, eingeschränktes Toolset.
- Je Profil ein Telegram-Bot, `TELEGRAM_ALLOWED_USERS` auf die eine ID,
  `hermes gateway install`. Der bestehende `@dein_bot` wird der Bot
  von `stab`.

**Beweis:** drei Chats auf dem Handy, `stab` schickt `coder` eine Aufgabe,
die Antwort kommt mit Attribution zurück.

### 5 · Hands-Trial = die kleinste Version

Der Trial aus dem PRD und die *kleinste Version* aus dem
[Orchestrator-Entwurf](README.md) sind dasselbe Experiment:

Ein Projekt, sequenziell. Zieldatei → gerendert in einen `/goal`-Contract
(`outcome`, `verification`, `constraints`, `boundaries`, `stop_when`) →
Freigabe per Telegram → zwei Aufgaben → eine endet in `blocked_on_human`.
**Ohne Portal.**

**Beweis und Ausgang:** ein Bericht — was lief, was brach, Kosten- und
Latenzgefühl, ob ein Abo etwas geändert hätte. Der Bericht ist Gate B des
PRD. Und die Differenz zwischen `/goal`-Contract und Zieldatei zeigt, was
von Einfrieren, verdeckter Abnahme und Versucht-Liste tatsächlich noch zu
bauen ist.

## Stand 2026-09-23

**Versionen.** Hermes v0.21.4 in CT 103; in CT 102 omp 18.2.9, claude 2.1.280,
opencode 1.18.32, dazu Godot 4.7.2 headless, xvfb und Mesa für Spiele-Screenshots.
Zwei Update-Fallen: `omp update` scheitert an seiner eigenen Verifikation (das
Binary ist in Ordnung, von Hand nach `~/.local/bin/omp` installieren, Release
von `github.com/can1357/oh-my-pi`); `hermes update` auf 0.21.3 stürzte im
Aufräumschritt ab (`_find_stale_dashboard_pids() … scope_home`), der Zustand
blieb gesund.

**Gateway.** Läuft in 103 manuell als `hermes gateway run`, nicht als Dienst.
Achtung: der Prozess heißt so, er ist kein hängender Befehl, nicht abschießen.
Plattformen: keine. `hermes gateway install` gehört zu Schritt 4, ebenso die
Frage `gateway.multiplex_profiles` (ein Gateway für alle Profile).

**SSH.** Vom Mac geht `ssh hermes` über den SSH-Agent; fällt das aus, erreicht man
103 über 102: `ssh agent-lab`, dann `sudo -u agent ssh hermes@192.168.1.21`.
Als `root` in 102 fehlt der Host-Key, als `agent` nicht.

**Modell-Default: `glm-5.3-flash` statt `grok-4.6`.** Das grok-Abo ist
beendet; über OpenRouter kostet dieselbe Ladder mit grok rund 3,33 $, mit GLM
0,08 $. Gemessen (Hermes, drei Läufe je Stufe): qwen3.7-flash 8/9,
glm-5.3-flash 7/9, deepseek-v4-flash 6/9, fast alle Fehlschläge auf S, der
Stufe ohne Interface-Vertrag. Mit Vertrag (S′) gehen GLM und DeepSeek von 1/3
auf 3/3, und zwar billiger und schneller **je Erfolg**. Damit GLM 9/9 wie grok.
Befund: **erst den Vertrag, dann die Schleife als Netz.** `config/models.yaml`
ist umgestellt (2026-09-23): `cheap` = `openrouter/z-ai/glm-5.3-flash` über
Hermes, `billing: api`, Fallback Anthropic-Abo; `strong` hat keinen Fallback
mehr, der alte lag im xAI-Abo.

**`/goal` geprüft.** Es ist die Ralph-Schleife: ein `GoalContract` mit genau
`outcome`, `verification`, `constraints`, `boundaries`, `stop_when`, ein
Hilfsmodell als Richter nach jeder Runde, `/goal gate add <cmd>` als harter
Prüfer, `max_turns` als Budget. Der Richter ist **fail-open**: fällt er aus,
läuft die Schleife weiter. Nie ohne Gate und Rundenbudget. Ein erster echter
`/goal`-Lauf steht noch aus (Schritt 5); Kandidat war ein Spieleprojekt in CT 102
(`/opt/spiel`, Gate `make test`).

**OpenRouter-Konto.** Das Guthaben gilt fürs Konto, nicht für den Key, und das
Konto teilt sich agent-lab mit anderen Projekten (u. a. Bildgenerierung). Die
Abflüsse, die hier zuerst fremd aussahen (2,70 $ am 19.09., rund 6,40 $ bis
23.09.), waren Bild-Batches in anderen Sitzungen: gpt-5.4-image-2 8,32 $,
Nano Banana 2 1,21 $ laut Dashboard. `bin/openrouter-guthaben.sh` weist Konto
und Key getrennt aus und läuft vor jeder Ladder als Vorbedingung; ein niedriger
Kontostand kann also von anderen Projekten kommen.

## Was die Best Practices geändert haben

Gegen die Sammlung vom 2026-09-13 geprüft. Vier Änderungen, der Rest
bestätigt den Kurs.

| Punkt | Vorher | Jetzt |
|---|---|---|
| Version | v0.20.6 vom 27.08. | erst aktualisieren, dann bauen — **erledigt** |
| Trial-Modell | GLM-5.3-Flash als Default | `grok-4.6` bleibt, Flash wird gemessen |
| Wächter, Blocker-Deckel, Tagesbericht | Python im Orchestrator | Hermes-Cron mit `no_agent`, Gate-Skript, `context_from` — das Modell bleibt draußen |
| Zielarbeit | eigener Runner `ziel.py` / `lauf.py` ([Ziel 01](ziele/01-geruest.md)) | `/goal` zuerst prüfen; Ziel 01 **zurückgestellt** |

Bestätigt: Portal bleibt hinter den Gates (die Sammlung empfiehlt
`--portal`, das PRD hält dagegen). Profile als getrennte Agenten. Review auf
anderem Modell. Sandbox per SSH statt Docker, gleiche Idee. Gefährliche
Befehle auf `session`, nie `always`. Schicht für Schicht beweisen.

**Zwei Gedächtnisse, bewusst getrennt.** Hermes-Memory schreibt der Bot
selbst: Fakten, Pfade, Korrekturen, pro Profil. `memory/` in Git schreibt
nur der Orchestrator: Faden und Versucht-Liste. Kein Bot schreibt in
`memory/`. Das ist die `learned`-Regel aus dem Entwurf, nur mit Namen.

## Was nicht kommt

- **Nous Portal** — nur bei (Gate A ∨ Gate B) ∧ Gate C, siehe PRD. Kein Kauf
  wegen Tier-Namen auf einer Landingpage.
- **Hermes Cloud** — der Mini-PC ist der Dauerläufer.
- **Headscale auf einem gemieteten Server** — Tailscale läuft mit allen Geräten, Bots
  brauchen keinen eingehenden Port. Ein eigener Control-Server wäre schwerer,
  nicht leichter.
- **Orchestrator in Python** — solange Cron, Profile und `/goal` reichen.
- **Zweite Bridge** — `bridge/` wird durch das Gateway ersetzt.

## Offen

- [ ] Prüft Hermes' Telegram-Allowlist `from.id` *und* `chat.id`, auch bei
      `callback_query`? Vor dem ersten Gruppeneinsatz klären
- [ ] Deckt Claude- oder ChatGPT-OAuth Hermes ohne Portal? (PRD, Frage 2)
- [ ] Wie sieht ein `/goal`-Contract im Gateway aus — geht das per Telegram?
- [ ] `python-telegram-bot` fehlt in 103 laut `hermes doctor`; kommt mit dem
      Gateway-Setup
- [ ] Netztrennung: Regel `.21 → .20:22`, bevor die Container vom Heimnetz
      getrennt werden
- [x] OpenRouter-Guthaben aufladen, dann GLM-Flash-Ladder nachholen (Schritt 3), 2026-09-19
- [x] Guthabenprüfung vor jeder Ladder — `bin/openrouter-guthaben.sh`, 2026-09-19
- [x] `config/models.yaml`: Default auf `glm-5.3-flash`, grok aus der Abo-Rolle, 2026-09-23
- [ ] Erster `/goal`-Lauf mit Gate und `max_turns` (Schritt 5)
- [x] Wer hat am OpenRouter-Konto 6,40 $ verbraucht? Bildgenerierung eines anderen Projekts, 2026-09-23
- [ ] Gateway in 103 als Dienst (`hermes gateway install`) statt manuell
