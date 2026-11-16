/**
 * Belegprüfung gegen den Server.
 *
 * Netzwerkzugriff ist über `Fetcher` injizierbar, damit die Tests ohne Netz
 * auskommen.
 */

export interface PruefErgebnis {
  gueltig: boolean;
  gekauftAm: number | null;
  /** Vom Server gemeldeter Ablauf, falls vorhanden. */
  laeuftAbAm: number | null;
}

export type Fetcher = (url: string, init: RequestInit) => Promise<Response>;

export interface PrueferOptionen {
  basisUrl: string;
  fetcher: Fetcher;
  /** Wartezeit vor dem ersten Wiederholversuch, verdoppelt sich danach. */
  backoffMs?: number;
  maxVersuche?: number;
  schlafen?: (ms: number) => Promise<void>;
}

const STANDARD_BACKOFF = 500;
const STANDARD_VERSUCHE = 3;

/** Serverfehler sind vorübergehend, Client-Fehler nicht. */
export function istWiederholbar(status: number): boolean {
  if (status === 429) return true;
  return status >= 500;
}

export class BelegPruefer {
  private readonly basisUrl: string;
  private readonly fetcher: Fetcher;
  private readonly backoffMs: number;
  private readonly maxVersuche: number;
  private readonly schlafen: (ms: number) => Promise<void>;

  constructor(opt: PrueferOptionen) {
    this.basisUrl = opt.basisUrl.replace(/\/+$/, "");
    this.fetcher = opt.fetcher;
    this.backoffMs = opt.backoffMs ?? STANDARD_BACKOFF;
    this.maxVersuche = opt.maxVersuche ?? STANDARD_VERSUCHE;
    this.schlafen = opt.schlafen ?? ((ms) => new Promise((r) => setTimeout(r, ms)));
  }

  /**
   * Beleg prüfen, mit Wiederholung bei vorübergehenden Fehlern.
   *
   * Wirft, wenn alle Versuche scheitern oder der Fehler dauerhaft ist.
   */
  async pruefen(beleg: string): Promise<PruefErgebnis> {
    let wartezeit = this.backoffMs;
    let letzterFehler: Error | null = null;

    for (let versuch = 1; versuch <= this.maxVersuche; versuch++) {
      let antwort: Response;
      try {
        antwort = await this.fetcher(`${this.basisUrl}/verify`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ receipt: beleg }),
        });
      } catch (e) {
        // Netzfehler gelten als vorübergehend.
        letzterFehler = e instanceof Error ? e : new Error(String(e));
        if (versuch < this.maxVersuche) {
          await this.schlafen(wartezeit);
          wartezeit *= 2;
          continue;
        }
        break;
      }

      if (antwort.ok) {
        const daten = (await antwort.json()) as {
          valid: boolean;
          purchased_at?: number;
          expires_at?: number;
        };
        return {
          gueltig: daten.valid,
          gekauftAm: daten.purchased_at ?? null,
          laeuftAbAm: daten.expires_at ?? null,
        };
      }

      if (!istWiederholbar(antwort.status)) {
        throw new Error(`Belegpruefung abgelehnt: ${antwort.status}`);
      }

      letzterFehler = new Error(`Belegpruefung fehlgeschlagen: ${antwort.status}`);
      if (versuch < this.maxVersuche) {
        await this.schlafen(wartezeit);
        wartezeit *= 2;
      }
    }

    throw letzterFehler ?? new Error("Belegpruefung fehlgeschlagen");
  }
}
