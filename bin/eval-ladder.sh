#!/usr/bin/env bash
# Faehrt die ganze Aufgabenleiter mit EINER Harness/Modell-Paarung, mehrfach
# pro Stufe, und schreibt jede Zeile als JSON in eine Sammeldatei.
#
#   eval-ladder.sh <harness> <modell> [wiederholungen] [stufen…]
#   eval-ladder.sh oh-my-pi opencode-go/deepseek-v4-flash 3
#
# WARUM WIEDERHOLUNGEN:
# Ein Lauf ist kein Messwert. Bei mimo-v2.5 lag die Fehlerquote bei einem von
# drei Laeufen — mit einem einzigen Lauf waere das Modell entweder als
# zuverlaessig oder als kaputt in die Tabelle gegangen, je nachdem welchen man
# erwischt. Flakiness ist erst ab mehreren Laeufen ueberhaupt sichtbar, und
# genau sie entscheidet, ob ein Modell in einer Schleife taugt.
#
# Ausgabe: eine JSON-Zeile pro Lauf auf stdout, plus Fortschritt auf stderr.
# Jede Zeile traegt `wiederholung`, damit Ausreisser zuordenbar bleiben.

set -uo pipefail

LAB="${LAB_ROOT:-/opt/agent-lab}"
HARNESS="${1:?Harness fehlt}"
MODELL="${2:?Modell fehlt}"
WIEDERHOLUNGEN="${3:-3}"
shift 3 2>/dev/null || shift $#
STUFEN=("$@")
if [ ${#STUFEN[@]} -eq 0 ]; then
  STUFEN=(S-wiederholgrenze M-einstiegsangebot L-wiederholung-extrahieren)
fi

log() { echo "[leiter] $*" >&2; }

# Vorbedingung, nicht Bremse: Ein leeres OpenRouter-Konto erzeugt neun Laeufe
# mit HTTP 402, die wie eine Aussage ueber das Modell aussehen. Lieber gar nicht
# starten als falsch messen. Siehe bin/openrouter-guthaben.sh.
case "$MODELL" in
  openrouter/*)
    if ! "$(dirname "$0")/openrouter-guthaben.sh" "${LADDER_MIN_GUTHABEN:-0.50}" >/dev/null; then
      log "Ladder abgebrochen: OpenRouter-Guthaben reicht nicht."
      exit 1
    fi
    ;;
esac

GESAMT=$(( ${#STUFEN[@]} * WIEDERHOLUNGEN ))
NR=0

for STUFE in "${STUFEN[@]}"; do
  for ((W=1; W<=WIEDERHOLUNGEN; W++)); do
    NR=$((NR+1))
    log "[$NR/$GESAMT] $STUFE, Wiederholung $W von $WIEDERHOLUNGEN"
    START=$(date +%s)

    ZEILE=$("$LAB/bin/eval-run.sh" "$STUFE" "$HARNESS" "$MODELL" 2>/dev/null | tail -1)
    RC=$?

    DAUER=$(( $(date +%s) - START ))

    # Auch ein kaputter Lauf muss eine Zeile erzeugen. Faellt er still aus,
    # verschiebt sich der Erfolgsanteil nach oben und das Modell sieht
    # zuverlaessiger aus als es ist — genau der Fehler, den Wiederholungen
    # aufdecken sollen.
    python3 - "$ZEILE" "$STUFE" "$W" "$RC" "$DAUER" "$MODELL" "$HARNESS" <<'PY'
import json, sys
zeile, stufe, w, rc, dauer, modell, harness = sys.argv[1:8]
try:
    d = json.loads(zeile)
    if not isinstance(d, dict):
        raise ValueError
except Exception:
    d = {
        "erfolg": False,
        "error": "runner_ohne_json",
        "rohausgabe": (zeile or "")[:200],
        "harness": harness,
        "model": modell,
    }
d.setdefault("aufgabe", stufe)
d["wiederholung"] = int(w)
d["runner_exit"] = int(rc)
d.setdefault("duration_s", int(dauer))
print(json.dumps(d, ensure_ascii=False))
PY
  done
done

log "fertig: $GESAMT Laeufe"
