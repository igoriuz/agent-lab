import { STUFEN, periodenPreisCent, angebotsText } from "../pricing";

describe("Einstiegsangebot: Preise", () => {
  it("berechnet Periode 1 zum halben Preis fuer Erstkaeufer", () => {
    expect(periodenPreisCent(STUFEN.monatlich, 1, true)).toBe(249);
    expect(periodenPreisCent(STUFEN.jaehrlich, 1, true)).toBe(1999);
  });

  it("berechnet ab Periode 2 regulaer", () => {
    expect(periodenPreisCent(STUFEN.monatlich, 2, true)).toBe(499);
    expect(periodenPreisCent(STUFEN.jaehrlich, 3, true)).toBe(3999);
  });

  it("gibt Bestandskunden kein Angebot", () => {
    expect(periodenPreisCent(STUFEN.monatlich, 1, false)).toBe(499);
    expect(periodenPreisCent(STUFEN.jaehrlich, 1, false)).toBe(3999);
  });

  it("laesst Einmalkauf unveraendert", () => {
    expect(periodenPreisCent(STUFEN.lebenslang, 1, true)).toBe(8999);
    expect(periodenPreisCent(STUFEN.lebenslang, 1, false)).toBe(8999);
  });

  it("behandelt ungueltige Perioden wie Periode 1", () => {
    expect(periodenPreisCent(STUFEN.monatlich, 0, true)).toBe(249);
    expect(periodenPreisCent(STUFEN.monatlich, -5, true)).toBe(249);
  });
});

describe("Einstiegsangebot: Anzeigetext", () => {
  it("nennt Angebots- und Regulaerpreis mit passender Periode", () => {
    const t = angebotsText(STUFEN.monatlich, true);
    expect(t).toContain("2,49 €");
    expect(t).toContain("4,99 €");
    expect(t).toContain("Monat");
  });

  it("nutzt Jahr bei der Jahresstufe", () => {
    const t = angebotsText(STUFEN.jaehrlich, true);
    expect(t).toContain("19,99 €");
    expect(t).toContain("39,99 €");
    expect(t).toContain("Jahr");
  });

  it("zeigt Bestandskunden nur den Regulaerpreis", () => {
    const t = angebotsText(STUFEN.monatlich, false);
    expect(t).toContain("4,99 €");
    expect(t).not.toContain("2,49 €");
  });

  it("zeigt beim Einmalkauf nur den Preis", () => {
    const t = angebotsText(STUFEN.lebenslang, true);
    expect(t).toContain("89,99 €");
  });
});
