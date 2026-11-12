/** Autocorrelation and partial autocorrelation for interactive EDA. */

export function acf(y: number[], maxLag: number): { lag: number; r: number }[] {
  const x = y.filter((v) => Number.isFinite(v));
  const n = x.length;
  if (n < 3) return [];
  const mean = x.reduce((a, b) => a + b, 0) / n;
  let c0 = 0;
  for (const v of x) c0 += (v - mean) ** 2;
  c0 /= n;
  if (c0 <= 0) return Array.from({ length: maxLag + 1 }, (_, lag) => ({ lag, r: lag === 0 ? 1 : 0 }));
  const out: { lag: number; r: number }[] = [{ lag: 0, r: 1 }];
  for (let k = 1; k <= maxLag; k++) {
    let ck = 0;
    for (let t = k; t < n; t++) ck += (x[t] - mean) * (x[t - k] - mean);
    out.push({ lag: k, r: ck / n / c0 });
  }
  return out;
}

/** Durbin–Levinson PACF from ACF values. */
export function pacf(y: number[], maxLag: number): { lag: number; phi: number }[] {
  const r = acf(y, maxLag).map((d) => d.r);
  const out: { lag: number; phi: number }[] = [{ lag: 0, phi: 1 }];
  if (r.length < 2) return out;
  const phi: number[][] = [];
  const v: number[] = [];
  phi[1] = [];
  phi[1][1] = r[1];
  v[1] = 1 - r[1] ** 2;
  out.push({ lag: 1, phi: phi[1][1] });
  for (let k = 2; k <= maxLag; k++) {
    let num = r[k];
    for (let j = 1; j < k; j++) num -= phi[k - 1][j] * r[k - j];
    const pk = v[k - 1] > 1e-12 ? num / v[k - 1] : 0;
    phi[k] = [];
    phi[k][k] = pk;
    for (let j = 1; j < k; j++) phi[k][j] = phi[k - 1][j] - pk * phi[k - 1][k - j];
    v[k] = v[k - 1] * (1 - pk * pk);
    out.push({ lag: k, phi: pk });
  }
  return out;
}

export function hourOfDayMeans(t: string[], y: number[]): { hour: number; mean: number }[] {
  const buckets: number[][] = Array.from({ length: 24 }, () => []);
  for (let i = 0; i < y.length; i++) {
    if (!Number.isFinite(y[i])) continue;
    const d = new Date(t[i].replace(" ", "T"));
    const h = Number.isFinite(d.getTime()) ? d.getHours() : i % 24;
    buckets[h].push(y[i]);
  }
  return buckets.map((vals, hour) => ({
    hour,
    mean: vals.length ? vals.reduce((a, b) => a + b, 0) / vals.length : NaN,
  }));
}
