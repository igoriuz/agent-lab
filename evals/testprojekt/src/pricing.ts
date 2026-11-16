/**
 * Abo-Stufen, Preise und Trial-Regeln.
 */

import { MS_PRO_TAG, tageAddieren, verbleibendeTage, istAbgelaufen } from "./utils/date";

export type StufenId = "monatlich" | "jaehrlich" | "lebenslang";

export interface Stufe {
  id: StufenId;
  /** Preis in kleinster Währungseinheit (Cent). Nie als Gleitkomma rechnen. */
  preisCent: number;
  waehrung: string;
  /** Laufzeit in Tagen; null bei Einmalkauf. */
  laufzeitTage: number | null;
  /** Trial-Dauer in Tagen; 0 = kein Trial. */
  trialTage: number;
}

export const STUFEN: Record<StufenId, Stufe> = {
  monatlich: { id: "monatlich", preisCent: 499, waehrung: "EUR", laufzeitTage: 30, trialTage: 7 },
  jaehrlich: { id: "jaehrlich", preisCent: 3999, waehrung: "EUR", laufzeitTage: 365, trialTage: 14 },
  lebenslang: { id: "lebenslang", preisCent: 8999, waehrung: "EUR", laufzeitTage: null, trialTage: 0 },
};

/** Preis für die Anzeige formatieren. */
export function preisFormatieren(preisCent: number, waehrung: string): string {
  const einheiten = Math.floor(preisCent / 100);
  const rest = preisCent % 100;
  const symbol = waehrung === "EUR" ? "€" : waehrung;
  return `${einheiten},${String(rest).padStart(2, "0")} ${symbol}`;
}

/**
 * Ersparnis der Jahres- gegenüber der Monatsstufe, in Prozent.
 *
 * Gerundet auf ganze Prozent, weil auf der Paywall "spare 33 %" steht.
 */
export function jahresErsparnisProzent(): number {
  const monat = STUFEN.monatlich;
  const jahr = STUFEN.jaehrlich;
  const monatAufsJahr = (monat.preisCent / monat.laufzeitTage!) * 365;
  return Math.round((1 - jahr.preisCent / monatAufsJahr) * 100);
}

export interface TrialStatus {
  aktiv: boolean;
  verbleibendeTage: number;
  endetAm: number;
}

/**
 * Trial-Status einer Stufe zu einem Zeitpunkt.
 *
 * `beginn` ist der Zeitpunkt, an dem der Trial gestartet wurde.
 */
export function trialStatus(stufe: Stufe, beginn: number, jetzt: number): TrialStatus {
  if (stufe.trialTage === 0) {
    return { aktiv: false, verbleibendeTage: 0, endetAm: beginn };
  }
  const endetAm = tageAddieren(beginn, stufe.trialTage);
  return {
    aktiv: !istAbgelaufen(jetzt, endetAm),
    verbleibendeTage: verbleibendeTage(jetzt, endetAm),
    endetAm,
  };
}

/**
 * Ablaufzeitpunkt eines Abos.
 *
 * Bei Einmalkauf null — läuft nie ab.
 */
export function ablaufZeitpunkt(stufe: Stufe, gekauftAm: number): number | null {
  if (stufe.laufzeitTage === null) return null;
  return tageAddieren(gekauftAm, stufe.laufzeitTage);
}

/** Tagespreis in Cent, für den Vergleich der Stufen auf der Paywall. */
export function tagesPreisCent(stufe: Stufe): number {
  if (stufe.laufzeitTage === null) {
    // Einmalkauf: auf zwei Jahre Nutzungsdauer umgelegt, so rechnet die
    // Marketing-Seite. Bewusst eine Annahme, kein Naturgesetz.
    return Math.round(stufe.preisCent / (2 * 365));
  }
  return Math.round(stufe.preisCent / stufe.laufzeitTage);
}
