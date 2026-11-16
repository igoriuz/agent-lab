Im Kaufvorgang (`src/store/purchase.ts`) ist die Konstante `MAX_VERSUCHE`
definiert, wird aber nirgends durchgesetzt: Ein fehlgeschlagener Kauf lässt
sich unbegrenzt oft wiederholen.

Setze die Grenze durch. Der Zustand ist vorgegeben, damit anderer Code sich
darauf verlassen kann:

```ts
// Der Fehlerzustand traegt den Zaehler mit:
//   { phase: "fehler"; stufe: StufenId | null; grund: string;
//     wiederholbar: boolean; versuch: number }

/**
 * `MAX_VERSUCHE` zaehlt Versuche INSGESAMT, nicht Wiederholungen:
 * der erste Lauf ist Versuch 1, nach MAX_VERSUCHE Fehlschlaegen ist Schluss.
 *
 * KAUF_GESTARTET  beginnt bei `versuch: 1`.
 *
 * FEHLGESCHLAGEN  uebernimmt den Zaehler des laufenden Versuchs in den
 *                 Fehlerzustand. Ist er bei `MAX_VERSUCHE` angekommen, gilt
 *                 der Zustand als nicht wiederholbar — auch dann, wenn die
 *                 Aktion selbst `wiederholbar: true` meldet.
 *
 * WIEDERHOLEN     erhoeht den Zaehler um eins und startet einen neuen Lauf.
 *                 Auf einem nicht wiederholbaren Zustand passiert nichts:
 *                 der Zustand wird unveraendert zurueckgegeben.
 *
 * ABGEBROCHEN     setzt den Vorgang samt Zaehler zurueck.
 */
```

Das nach außen sichtbare Verhalten aller anderen Aktionen bleibt unverändert.

Bestehende Tests müssen grün bleiben. Schreibe Tests für das neue Verhalten.
Committe die Änderung.
