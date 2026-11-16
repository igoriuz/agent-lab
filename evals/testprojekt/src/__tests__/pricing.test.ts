import { STUFEN, preisFormatieren, jahresErsparnisProzent, trialStatus, ablaufZeitpunkt, tagesPreisCent } from "../pricing";
import { MS_PRO_TAG } from "../utils/date";

const T0 = 1_700_000_000_000;

describe("preisFormatieren", () => {
  it("formatiert Euro mit zwei Nachkommastellen", () => {
    expect(preisFormatieren(499, "EUR")).toBe("4,99 €");
    expect(preisFormatieren(3999, "EUR")).toBe("39,99 €");
  });
  it("füllt einstellige Cent auf", () => {
    expect(preisFormatieren(505, "EUR")).toBe("5,05 €");
  });
});

describe("jahresErsparnisProzent", () => {
  it("liegt im plausiblen Bereich", () => {
    const p = jahresErsparnisProzent();
    expect(p).toBeGreaterThan(0);
    expect(p).toBeLessThan(100);
  });
});

describe("trialStatus", () => {
  it("ist am Starttag aktiv", () => {
    const s = trialStatus(STUFEN.monatlich, T0, T0);
    expect(s.aktiv).toBe(true);
    expect(s.verbleibendeTage).toBe(7);
  });
  it("ist nach Ablauf inaktiv", () => {
    const s = trialStatus(STUFEN.monatlich, T0, T0 + 8 * MS_PRO_TAG);
    expect(s.aktiv).toBe(false);
    expect(s.verbleibendeTage).toBe(0);
  });
  it("meldet für Stufen ohne Trial nichts", () => {
    const s = trialStatus(STUFEN.lebenslang, T0, T0);
    expect(s.aktiv).toBe(false);
  });
});

describe("ablaufZeitpunkt", () => {
  it("ist bei Einmalkauf null", () => {
    expect(ablaufZeitpunkt(STUFEN.lebenslang, T0)).toBeNull();
  });
  it("liegt bei Monatsabo 30 Tage später", () => {
    expect(ablaufZeitpunkt(STUFEN.monatlich, T0)).toBe(T0 + 30 * MS_PRO_TAG);
  });
});

describe("tagesPreisCent", () => {
  it("ist beim Jahresabo günstiger als beim Monatsabo", () => {
    expect(tagesPreisCent(STUFEN.jaehrlich)).toBeLessThan(tagesPreisCent(STUFEN.monatlich));
  });
});
