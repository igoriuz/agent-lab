import { kaufReducer, START, MAX_VERSUCHE, KaufZustand, KaufAktion } from "../store/purchase";

const lauf = (aktionen: KaufAktion[]): KaufZustand => aktionen.reduce(kaufReducer, START);

const bisFehler = (): KaufZustand =>
  lauf([
    { typ: "STUFE_GEWAEHLT", stufe: "monatlich" },
    { typ: "KAUF_GESTARTET" },
    { typ: "FEHLGESCHLAGEN", grund: "netz", wiederholbar: true },
  ]);

describe("Wiederholgrenze", () => {
  it("zaehlt Versuche ueber Wiederholungen hinweg hoch", () => {
    let z = bisFehler();
    z = kaufReducer(z, { typ: "WIEDERHOLEN" });
    expect(z.phase).toBe("laeuft");
    expect((z as any).versuch).toBe(2);
  });

  it("verweigert Wiederholung nach MAX_VERSUCHE", () => {
    let z = bisFehler();
    for (let i = 1; i < MAX_VERSUCHE; i++) {
      z = kaufReducer(z, { typ: "WIEDERHOLEN" });
      expect(z.phase).toBe("laeuft");
      z = kaufReducer(z, { typ: "FEHLGESCHLAGEN", grund: "netz", wiederholbar: true });
    }
    const vorher = z;
    z = kaufReducer(z, { typ: "WIEDERHOLEN" });
    expect(z.phase).toBe("fehler");
    expect(z).toEqual(vorher.phase === "fehler" ? { ...vorher, wiederholbar: false } : vorher);
  });

  it("meldet den erschoepften Zustand als nicht wiederholbar", () => {
    let z = bisFehler();
    for (let i = 1; i < MAX_VERSUCHE; i++) {
      z = kaufReducer(z, { typ: "WIEDERHOLEN" });
      z = kaufReducer(z, { typ: "FEHLGESCHLAGEN", grund: "netz", wiederholbar: true });
    }
    expect((z as any).wiederholbar).toBe(false);
  });

  it("setzt den Zaehler nach Abbruch zurueck", () => {
    let z = bisFehler();
    z = kaufReducer(z, { typ: "WIEDERHOLEN" });
    z = kaufReducer(z, { typ: "ABGEBROCHEN" });
    z = lauf([{ typ: "STUFE_GEWAEHLT", stufe: "monatlich" }, { typ: "KAUF_GESTARTET" }]);
    expect((z as any).versuch).toBe(1);
  });
});
