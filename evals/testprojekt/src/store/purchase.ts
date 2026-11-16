/**
 * Zustandsautomat des Kaufvorgangs.
 *
 * Bewusst als Reducer, damit der Ablauf ohne UI testbar ist.
 */

import { StufenId } from "../pricing";

export type KaufZustand =
  | { phase: "leer" }
  | { phase: "auswahl"; stufe: StufenId }
  | { phase: "laeuft"; stufe: StufenId; versuch: number }
  | { phase: "pruefung"; stufe: StufenId; beleg: string }
  | { phase: "erfolg"; stufe: StufenId; gekauftAm: number }
  | { phase: "fehler"; stufe: StufenId | null; grund: string; wiederholbar: boolean };

export type KaufAktion =
  | { typ: "STUFE_GEWAEHLT"; stufe: StufenId }
  | { typ: "KAUF_GESTARTET" }
  | { typ: "BELEG_ERHALTEN"; beleg: string }
  | { typ: "PRUEFUNG_OK"; gekauftAm: number }
  | { typ: "FEHLGESCHLAGEN"; grund: string; wiederholbar: boolean }
  | { typ: "WIEDERHOLEN" }
  | { typ: "ABGEBROCHEN" };

export const START: KaufZustand = { phase: "leer" };

/** Wie oft ein Kauf höchstens automatisch wiederholt wird. */
export const MAX_VERSUCHE = 3;

export function kaufReducer(zustand: KaufZustand, aktion: KaufAktion): KaufZustand {
  switch (aktion.typ) {
    case "STUFE_GEWAEHLT":
      return { phase: "auswahl", stufe: aktion.stufe };

    case "KAUF_GESTARTET":
      if (zustand.phase !== "auswahl") return zustand;
      return { phase: "laeuft", stufe: zustand.stufe, versuch: 1 };

    case "BELEG_ERHALTEN":
      if (zustand.phase !== "laeuft") return zustand;
      return { phase: "pruefung", stufe: zustand.stufe, beleg: aktion.beleg };

    case "PRUEFUNG_OK":
      if (zustand.phase !== "pruefung") return zustand;
      return { phase: "erfolg", stufe: zustand.stufe, gekauftAm: aktion.gekauftAm };

    case "FEHLGESCHLAGEN": {
      const stufe =
        zustand.phase === "leer" || zustand.phase === "fehler" ? null : zustand.stufe;
      return {
        phase: "fehler",
        stufe: zustand.phase === "fehler" ? zustand.stufe : stufe,
        grund: aktion.grund,
        wiederholbar: aktion.wiederholbar,
      };
    }

    case "WIEDERHOLEN": {
      if (zustand.phase !== "fehler" || !zustand.wiederholbar || zustand.stufe === null) {
        return zustand;
      }
      return { phase: "laeuft", stufe: zustand.stufe, versuch: 1 };
    }

    case "ABGEBROCHEN":
      return START;

    default:
      return zustand;
  }
}

/** Darf der Nutzer die Inhalte sehen? */
export function istFreigeschaltet(zustand: KaufZustand): boolean {
  return zustand.phase === "erfolg";
}

/** Soll ein Ladeindikator laufen? */
export function istBeschaeftigt(zustand: KaufZustand): boolean {
  return zustand.phase === "laeuft" || zustand.phase === "pruefung";
}
