import { mitWiederholung, WiederholOptionen } from "../utils/retry";

const ohneWarten = async () => {};

const basis = (ueberschreiben: Partial<WiederholOptionen> = {}): WiederholOptionen => ({
  maxVersuche: 3,
  backoffMs: 100,
  schlafen: ohneWarten,
  istWiederholbar: () => true,
  ...ueberschreiben,
});

describe("mitWiederholung", () => {
  it("gibt bei Erfolg direkt zurueck, ohne zu wiederholen", async () => {
    let n = 0;
    const r = await mitWiederholung(async () => { n++; return "ok"; }, basis());
    expect(r).toBe("ok");
    expect(n).toBe(1);
  });

  it("wiederholt bis zum Erfolg", async () => {
    let n = 0;
    const r = await mitWiederholung(async () => {
      if (++n < 3) throw new Error("voruebergehend");
      return n;
    }, basis());
    expect(r).toBe(3);
    expect(n).toBe(3);
  });

  it("gibt nach maxVersuche auf und wirft den letzten Fehler", async () => {
    let n = 0;
    await expect(mitWiederholung(async () => {
      n++; throw new Error("fehler-" + n);
    }, basis())).rejects.toThrow("fehler-3");
    expect(n).toBe(3);
  });

  it("wirft sofort bei nicht wiederholbarem Fehler", async () => {
    let n = 0;
    await expect(mitWiederholung(async () => {
      n++; throw new Error("endgueltig");
    }, basis({ istWiederholbar: () => false }))).rejects.toThrow("endgueltig");
    expect(n).toBe(1);
  });

  it("verdoppelt die Wartezeit nach jedem Fehlversuch", async () => {
    const wartezeiten: number[] = [];
    let n = 0;
    await expect(mitWiederholung(async () => {
      n++; throw new Error("x");
    }, basis({ maxVersuche: 4, backoffMs: 50, schlafen: async (ms) => { wartezeiten.push(ms); } })))
      .rejects.toThrow();
    expect(wartezeiten).toEqual([50, 100, 200]);
  });

  it("wartet nach dem letzten Versuch nicht mehr", async () => {
    const wartezeiten: number[] = [];
    await expect(mitWiederholung(async () => { throw new Error("x"); },
      basis({ maxVersuche: 2, schlafen: async (ms) => { wartezeiten.push(ms); } })))
      .rejects.toThrow();
    expect(wartezeiten).toHaveLength(1);
  });
});
