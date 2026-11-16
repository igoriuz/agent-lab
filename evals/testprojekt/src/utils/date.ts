/**
 * Datumshilfen für Abo- und Trial-Berechnungen.
 *
 * Alle Zeitpunkte sind UTC-Millisekunden. Das ist Absicht: Store-Belege
 * kommen in UTC, und die Umrechnung in lokale Zeit gehört ausschliesslich
 * in die Anzeigeschicht.
 */

export const MS_PRO_TAG = 24 * 60 * 60 * 1000;

/** Tage zu einem Zeitpunkt addieren. */
export function tageAddieren(zeitpunkt: number, tage: number): number {
  return zeitpunkt + tage * MS_PRO_TAG;
}

/**
 * Volle Tage zwischen zwei Zeitpunkten.
 *
 * Abgerundet: Ein angefangener Tag zählt nicht. `vergangeneTage(t, t+23h)`
 * ergibt 0.
 */
export function vergangeneTage(von: number, bis: number): number {
  return Math.floor((bis - von) / MS_PRO_TAG);
}

/**
 * Verbleibende Tage bis zu einem Stichtag, nie negativ.
 *
 * Aufgerundet: Ein angefangener Tag zählt als ganzer, weil dem Nutzer
 * "noch 1 Tag" angezeigt werden soll, solange die Zeit nicht abgelaufen ist.
 */
export function verbleibendeTage(jetzt: number, stichtag: number): number {
  if (stichtag <= jetzt) return 0;
  return Math.ceil((stichtag - jetzt) / MS_PRO_TAG);
}

/** Liegt der Zeitpunkt in der Vergangenheit? */
export function istAbgelaufen(jetzt: number, stichtag: number): boolean {
  return stichtag <= jetzt;
}

/**
 * Beginn des Tages in UTC.
 *
 * Wird für Tagesstatistiken gebraucht, damit zwei Ereignisse am selben
 * Kalendertag denselben Schlüssel bekommen.
 */
export function tagesBeginn(zeitpunkt: number): number {
  return Math.floor(zeitpunkt / MS_PRO_TAG) * MS_PRO_TAG;
}
