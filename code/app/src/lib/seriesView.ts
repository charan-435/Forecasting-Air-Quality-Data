/** Shared helpers for readable time-series charts. */

export function parseLabTime(s: string): Date {
  const m = /^(\d{2})-(\d{2})-(\d{4})[ T](\d{2}):(\d{2})/.exec(s);
  if (m) {
    return new Date(`${m[3]}-${m[2]}-${m[1]}T${m[4]}:${m[5]}:00`);
  }
  const d = new Date(s.replace(" ", "T"));
  return Number.isFinite(d.getTime()) ? d : new Date(NaN);
}

/** Drop long leading/trailing constant plateaus (imputed gaps / stuck sensors). */
export function trimFlatEdges(t: string[], y: number[], minFlat = 12) {
  const n = y.length;
  if (n < minFlat + 8) return { t, y, trimmedLead: 0, trimmedTail: 0 };

  const nearlyEq = (a: number, b: number) =>
    Number.isFinite(a) && Number.isFinite(b) && Math.abs(a - b) <= 1e-6;

  let lo = 0;
  while (lo + 1 < n && nearlyEq(y[lo + 1], y[lo])) lo++;
  let lead = lo + 1 >= minFlat ? lo + 1 : 0;

  let hi = n - 1;
  while (hi - 1 >= lead && nearlyEq(y[hi - 1], y[hi])) hi--;
  const tailCut = n - 1 - hi >= minFlat ? n - 1 - hi : 0;
  const hiExcl = n - tailCut;

  if (hiExcl - lead < 24) {
    lead = Math.max(0, n - 24 * 7);
    return {
      t: t.slice(lead),
      y: y.slice(lead),
      trimmedLead: lead,
      trimmedTail: 0,
    };
  }

  return {
    t: t.slice(lead, hiExcl),
    y: y.slice(lead, hiExcl),
    trimmedLead: lead,
    trimmedTail: tailCut,
  };
}

export const dateAxisLayout = {
  type: "date" as const,
  tickformat: "%d %b",
  nticks: 6,
  tickangle: 0,
  automargin: true,
  gridcolor: "rgba(21,34,56,0.08)",
  zeroline: false,
};
