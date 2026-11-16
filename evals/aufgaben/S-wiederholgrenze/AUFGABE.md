Im Kaufvorgang (`src/store/purchase.ts`) ist die Konstante `MAX_VERSUCHE`
definiert, wird aber nirgends durchgesetzt: Ein fehlgeschlagener Kauf lässt
sich unbegrenzt oft wiederholen.

Setze die Grenze durch. Nach `MAX_VERSUCHE` Versuchen darf `WIEDERHOLEN`
keinen neuen Lauf mehr starten, sondern muss im Fehlerzustand bleiben — und
dieser Zustand darf dann nicht mehr als wiederholbar gelten.

Bestehende Tests müssen grün bleiben. Committe die Änderung.
