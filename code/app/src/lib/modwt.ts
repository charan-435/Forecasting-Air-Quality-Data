/** Client MODWT / MRA (Haar exact; D4/LA8 additive smooth view). */

export type FilterName = "haar" | "d4" | "la8";

const FILTERS: Record<FilterName, { g: number[]; h: number[] }> = {
  haar: { g: [0.5, 0.5], h: [0.5, -0.5] },
  d4: {
    g: [0.4829629131445341, 0.8365163037378079, 0.2241438680420134, -0.1294095225512604],
    h: [-0.1294095225512604, -0.2241438680420134, 0.8365163037378079, -0.4829629131445341],
  },
  la8: {
    g: [
      -0.0757657147893407, -0.0296355276459541, 0.4976186676325621, 0.8037387518052163,
      0.2978577956055422, -0.0992195435769564, -0.0126039672622618, 0.0322231006040713,
    ],
    h: [
      -0.0322231006040713, -0.0126039672622618, 0.0992195435769564, 0.2978577956055422,
      -0.8037387518052163, 0.4976186676325621, 0.0296355276459541, -0.0757657147893407,
    ],
  },
};

function rollRight(x: number[], s: number): number[] {
  const n = x.length;
  s = ((s % n) + n) % n;
  if (s === 0) return x.slice();
  return x.slice(n - s).concat(x.slice(0, n - s));
}

function rollLeft(x: number[], s: number): number[] {
  const n = x.length;
  s = ((s % n) + n) % n;
  if (s === 0) return x.slice();
  return x.slice(s).concat(x.slice(0, s));
}

function convCircular(x: number[], taps: number[], stride: number): number[] {
  const n = x.length;
  const out = new Array(n);
  for (let t = 0; t < n; t++) {
    let s = 0;
    for (let l = 0; l < taps.length; l++) {
      const idx = (((t - stride * l) % n) + n) % n;
      s += taps[l] * x[idx];
    }
    out[t] = s;
  }
  return out;
}

export function haarStep(V: number[], j: number) {
  const s = 1 << (j - 1);
  const Vlag = rollRight(V, s);
  const W = V.map((v, i) => (v - Vlag[i]) / 2);
  const Vn = V.map((v, i) => (v + Vlag[i]) / 2);
  return { W, V: Vn, s, Vlag };
}

function haarMra(x: number[], J: number) {
  let V = x.slice();
  const W: number[][] = [];
  for (let j = 1; j <= J; j++) {
    const step = haarStep(V, j);
    W.push(step.W);
    V = step.V;
  }
  const zeros = W.map((w) => w.map(() => 0));
  const invStep = (Wj: number[], Vj: number[], j: number) => {
    const s = 1 << (j - 1);
    const Wl = rollLeft(Wj, s);
    const Vl = rollLeft(Vj, s);
    return Wj.map((_, i) => (Wj[i] - Wl[i] + Vj[i] + Vl[i]) / 2);
  };
  const imodwt = (WW: number[][], VJ: number[]) => {
    let VV = VJ.slice();
    for (let j = WW.length; j >= 1; j--) VV = invStep(WW[j - 1], VV, j);
    return VV;
  };
  const D: number[][] = [];
  for (let j = 0; j < J; j++) {
    const Wj = zeros.map((z) => z.slice());
    Wj[j] = W[j].slice();
    D.push(imodwt(Wj, V.map(() => 0)));
  }
  const S = imodwt(zeros, V);
  return { D, S, J, filter: "haar" as FilterName };
}

function smoothMra(x: number[], J: number, name: FilterName) {
  const f = FILTERS[name];
  let Vprev = x.slice();
  const D: number[][] = [];
  for (let j = 1; j <= J; j++) {
    const stride = 1 << (j - 1);
    const V = convCircular(Vprev, f.g, stride);
    D.push(Vprev.map((v, i) => v - V[i]));
    Vprev = V;
  }
  return { D, S: Vprev, J, filter: name };
}

export type Mra = { D: number[][]; S: number[]; J: number; filter: FilterName };

export function mra(x: number[], J: number, filter: FilterName = "haar"): Mra {
  const y = x.map(Number);
  if (filter === "haar") return haarMra(y, J);
  return smoothMra(y, J, filter);
}

export function energy(m: Mra) {
  const rows = m.D.map((d, i) => {
    const e = d.reduce((a, b) => a + b * b, 0);
    return { component: `D${i + 1}`, energy: e };
  });
  const se = m.S.reduce((a, b) => a + b * b, 0);
  rows.push({ component: `S${m.J}`, energy: se });
  const tot = rows.reduce((a, r) => a + r.energy, 0) || 1;
  return rows.map((r) => ({ ...r, share: r.energy / tot }));
}

export function reconstruct(m: Mra) {
  const out = m.S.slice();
  for (const d of m.D) for (let i = 0; i < out.length; i++) out[i] += d[i];
  return out;
}

export function maxAbsDiff(a: number[], b: number[]) {
  let m = 0;
  for (let i = 0; i < a.length; i++) m = Math.max(m, Math.abs(a[i] - b[i]));
  return m;
}
