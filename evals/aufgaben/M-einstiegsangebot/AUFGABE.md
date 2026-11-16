Neue Anforderung: Erstkäufer bekommen ein **Einstiegsangebot** — die erste
Abrechnungsperiode zum halben Preis, danach regulär.

Setze das in `src/pricing.ts` um. Die Schnittstelle ist vorgegeben, damit
anderer Code sich darauf verlassen kann:

```ts
export interface Einstiegsangebot {
  preisCent: number;      // Preis der verguenstigten Perioden
  perioden: number;       // wie viele Perioden verguenstigt sind
}

// Stufe bekommt ein optionales Feld:
//   einstieg?: Einstiegsangebot

/**
 * Preis fuer eine bestimmte Abrechnungsperiode (1-basiert).
 * Erstkaeufer zahlen in den Angebotsperioden den Angebotspreis,
 * danach regulaer. Wer die Stufe schon besass, zahlt immer regulaer.
 */
export function periodenPreisCent(
  stufe: Stufe,
  periode: number,
  istErstkaeufer: boolean
): number;

/**
 * Anzeigetext fuer die Paywall.
 * Mit Angebot:  "2,49 € fuer den ersten Monat, danach 4,99 €"
 * Ohne Angebot: "4,99 €"
 * Die Periodenbezeichnung richtet sich nach der Laufzeit:
 *   30 Tage -> "Monat", 365 Tage -> "Jahr", sonst "Zeitraum".
 */
export function angebotsText(stufe: Stufe, istErstkaeufer: boolean): string;
```

Werte: `monatlich` und `jaehrlich` bekommen je **eine** Periode zum halben
regulären Preis (abgerundet auf ganze Cent), `lebenslang` kein Angebot.

Ungültige Perioden (kleiner als 1) werden wie Periode 1 behandelt.

Schreibe Tests für das neue Verhalten. Bestehende Tests müssen grün bleiben.
Committe die Änderung.
