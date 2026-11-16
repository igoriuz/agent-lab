import { BelegPruefer, istWiederholbar } from "../api/receipts";

const antwort = (status: number, body: unknown = {}): Response =>
  ({ ok: status >= 200 && status < 300, status, json: async () => body }) as Response;

const ohneWarten = async () => {};

describe("istWiederholbar", () => {
  it("stuft Serverfehler und Drosselung als wiederholbar ein", () => {
    expect(istWiederholbar(500)).toBe(true);
    expect(istWiederholbar(429)).toBe(true);
  });
  it("stuft Client-Fehler als endgültig ein", () => {
    expect(istWiederholbar(400)).toBe(false);
    expect(istWiederholbar(403)).toBe(false);
  });
});

describe("BelegPruefer", () => {
  it("gibt das Ergebnis bei Erfolg zurück", async () => {
    const p = new BelegPruefer({
      basisUrl: "https://x/",
      fetcher: async () => antwort(200, { valid: true, purchased_at: 42 }),
      schlafen: ohneWarten,
    });
    await expect(p.pruefen("beleg")).resolves.toEqual({ gueltig: true, gekauftAm: 42, laeuftAbAm: null });
  });

  it("wiederholt bei Serverfehler und hat am Ende Erfolg", async () => {
    let n = 0;
    const p = new BelegPruefer({
      basisUrl: "https://x",
      fetcher: async () => (++n < 3 ? antwort(503) : antwort(200, { valid: true, purchased_at: 1 })),
      schlafen: ohneWarten,
    });
    await expect(p.pruefen("b")).resolves.toMatchObject({ gueltig: true });
    expect(n).toBe(3);
  });

  it("wiederholt bei Client-Fehler nicht", async () => {
    let n = 0;
    const p = new BelegPruefer({
      basisUrl: "https://x",
      fetcher: async () => { n++; return antwort(400); },
      schlafen: ohneWarten,
    });
    await expect(p.pruefen("b")).rejects.toThrow(/abgelehnt/);
    expect(n).toBe(1);
  });
});
