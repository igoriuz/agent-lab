Die Wiederhollogik steckt fest in `BelegPruefer` (`src/api/receipts.ts`):
Schleife, Backoff-Verdopplung, Unterscheidung zwischen vorübergehenden und
endgültigen Fehlern.

Ziehe sie in einen wiederverwendbaren Baustein heraus. Die Schnittstelle ist
vorgegeben, damit anderer Code sie nutzen kann:

```ts
// neue Datei: src/utils/retry.ts

export interface WiederholOptionen {
  maxVersuche: number;
  backoffMs: number;             // verdoppelt sich nach jedem Fehlversuch
  schlafen: (ms: number) => Promise<void>;
  /** true = nochmal versuchen, false = sofort aufgeben und werfen */
  istWiederholbar: (fehler: unknown) => boolean;
}

/**
 * Fuehrt `aktion` aus und wiederholt bei wiederholbaren Fehlern.
 * Gibt das Ergebnis zurueck oder wirft den letzten Fehler, wenn alle
 * Versuche scheitern oder ein Fehler nicht wiederholbar ist.
 */
export async function mitWiederholung<T>(
  aktion: () => Promise<T>,
  opt: WiederholOptionen
): Promise<T>;
```

`BelegPruefer` muss diesen Baustein verwenden statt eigener Schleifenlogik.

Bedingungen:

- Das nach außen sichtbare Verhalten von `BelegPruefer` bleibt **exakt**
  gleich: gleiche Rückgabewerte, gleiche Ausnahmen mit gleichen Meldungen,
  gleiche Anzahl Versuche, gleiches Backoff.
- Alle bestehenden Tests bleiben **unverändert** grün. Passe sie nicht an.
- Der neue Baustein ist für sich getestet.

Committe die Änderung.
