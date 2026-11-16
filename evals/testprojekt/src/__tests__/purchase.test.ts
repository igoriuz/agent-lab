import { kaufReducer, START, istFreigeschaltet, istBeschaeftigt, KaufZustand } from "../store/purchase";

const laufen = (aktionen: Parameters<typeof kaufReducer>[1][]): KaufZustand =>
  aktionen.reduce(kaufReducer, START);

describe("kaufReducer", () => {
  it("führt den Glücksfall bis zum Erfolg", () => {
    const z = laufen([
      { typ: "STUFE_GEWAEHLT", stufe: "jaehrlich" },
      { typ: "KAUF_GESTARTET" },
      { typ: "BELEG_ERHALTEN", beleg: "abc" },
      { typ: "PRUEFUNG_OK", gekauftAm: 123 },
    ]);
    expect(z.phase).toBe("erfolg");
    expect(istFreigeschaltet(z)).toBe(true);
  });

  it("ignoriert Kaufstart ohne Auswahl", () => {
    expect(kaufReducer(START, { typ: "KAUF_GESTARTET" })).toEqual(START);
  });

  it("meldet Beschäftigung während Lauf und Prüfung", () => {
    const laeuft = laufen([{ typ: "STUFE_GEWAEHLT", stufe: "monatlich" }, { typ: "KAUF_GESTARTET" }]);
    expect(istBeschaeftigt(laeuft)).toBe(true);
    const pruefung = kaufReducer(laeuft, { typ: "BELEG_ERHALTEN", beleg: "x" });
    expect(istBeschaeftigt(pruefung)).toBe(true);
  });

  it("erlaubt Wiederholung nur bei wiederholbarem Fehler", () => {
    const basis = laufen([{ typ: "STUFE_GEWAEHLT", stufe: "monatlich" }, { typ: "KAUF_GESTARTET" }]);
    const hart = kaufReducer(basis, { typ: "FEHLGESCHLAGEN", grund: "abgelehnt", wiederholbar: false });
    expect(kaufReducer(hart, { typ: "WIEDERHOLEN" })).toEqual(hart);

    const weich = kaufReducer(basis, { typ: "FEHLGESCHLAGEN", grund: "netz", wiederholbar: true });
    expect(kaufReducer(weich, { typ: "WIEDERHOLEN" }).phase).toBe("laeuft");
  });

  it("setzt bei Abbruch zurück", () => {
    const z = laufen([{ typ: "STUFE_GEWAEHLT", stufe: "monatlich" }, { typ: "ABGEBROCHEN" }]);
    expect(z).toEqual(START);
  });
});
