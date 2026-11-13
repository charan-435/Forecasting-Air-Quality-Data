// Shows how the interval width changes when the reader changes the coverage slider. This
// page uses errors from the displayed data; the separate calibrated experiment is run in
// R.

import { useMemo, useState } from "react";
import { Link } from "react-router-dom";
import Detail from "../components/Detail";
import Katex, { EqBlock } from "../components/Katex";
import Plot from "../components/Plot";
import { COLORS, plotLayout } from "../lib/plotlyTheme";
import { useData } from "../state/DataContext";

function quantile(arr: number[], p: number) {
  // Sort a copy so this calculation does not change the saved residual order.
  const a = arr.filter(Number.isFinite).slice().sort((u, v) => u - v);
  if (!a.length) return 0;
  const i = (a.length - 1) * p;
  const lo = Math.floor(i);
  const hi = Math.ceil(i);
  if (lo === hi) return a[lo];
  return a[lo] * (hi - i) + a[hi] * (i - lo);
}

export default function ConformalPage() {
  const { conformal } = useData();
  const [pct, setPct] = useState(0.95);

  const view = useMemo(() => {
    if (!conformal?.y?.length || !conformal.yhat?.length) return null;
    // This display uses the plotted errors. It is not a held-out calibration experiment.
    const resid = conformal.y.map((yi, i) => Math.abs(yi - conformal.yhat[i]));
    const win = 24;
    const u = resid.map((_, i) => {
      const lo = Math.max(0, i - win + 1);
      let s = 0;
      for (let k = lo; k <= i; k++) s += resid[k];
      return Math.max(s / (i - lo + 1), 1e-6);
    });
    // Scale errors by their recent size, then use the chosen quantile to set the band.
    const cs = resid.map((r, i) => r / u[i]);
    const cq = quantile(cs, pct);
    const half = u.map((ui) => cq * ui);
    const lower = conformal.yhat.map((yh, i) => Math.max(0, yh - half[i]));
    const upper = conformal.yhat.map((yh, i) => yh + half[i]);
    const cover =
      conformal.y.filter((yi, i) => yi >= lower[i] && yi <= upper[i]).length / conformal.y.length;
    const width = half.reduce((a, b) => a + 2 * b, 0) / half.length;
    const t = conformal.y.map((_, i) => i);
    return { lower, upper, cover, width, cq, t };
  }, [conformal, pct]);

  return (
    <div className="stack">
      <header>
        <div className="kicker">Conformal prediction</div>
        <h2>What does a wider band mean?</h2>
        <p className="lead">Point forecast fixed; nominal coverage changes interval width.</p>
      </header>

      <div className="glass panel">
        <h3>Paper formulation</h3>
        <EqBlock>
          <Katex display tex="CS_t=\dfrac{\bigl|Y_t-\mathrm{WaveCatBoost}(Y_{t-p})\bigr|}{\hat U(Y_{t-p})}" />
          <Katex
            display
            tex="CQ_t=\inf\Bigl\{q:\dfrac{1}{\min(\kappa,t-1)}\sum_{t'=1}^{t-1}CS_{t'}\,w_{t}\ge 1-\alpha\Bigr\}"
          />
          <Katex display tex="w_t=\mathbf{1}(t'\ge t-\kappa)" />
          <Katex
            display
            tex="\bigl[\mathrm{WaveCatBoost}(Y_{t-p})\ \pm\ CQ_t\,\hat U(Y_{t-p})\bigr]"
          />
        </EqBlock>
        <p className="muted" style={{ fontSize: "0.88rem", marginTop: 8 }}>
          CSₜ is the conformal score, Û an uncertainty model, κ a trailing window, and α = 1 −
          nominal coverage.
        </p>
      </div>

      <label className="field" style={{ maxWidth: 200 }}>
        Coverage band
        <select value={pct} onChange={(e) => setPct(Number(e.target.value))}>
          <option value={0.8}>80%</option>
          <option value={0.9}>90%</option>
          <option value={0.95}>95%</option>
          <option value={0.99}>99%</option>
        </select>
      </label>

      {view && conformal && (
        <>
          <p className="muted" style={{ fontSize: "0.9rem" }}>
            α = {(1 - pct).toFixed(2)} · CQ = {view.cq.toFixed(2)} · empirical cover ={" "}
            {(100 * view.cover).toFixed(1)}% · mean width = {view.width.toFixed(2)}
          </p>
          <Plot
            height={420}
            data={[
              {
                x: view.t.concat([...view.t].reverse()),
                y: view.upper.concat([...view.lower].reverse()),
                fill: "toself",
                fillcolor: COLORS.band,
                line: { color: "transparent" },
                name: `${(100 * pct).toFixed(0)}% PI`,
                hoverinfo: "skip",
              },
              {
                x: view.t,
                y: conformal.y,
                type: "scatter",
                mode: "lines",
                name: "Y",
                line: { color: COLORS.y, width: 1.2 },
              },
              {
                x: view.t,
                y: conformal.yhat,
                type: "scatter",
                mode: "lines",
                name: "Ŷ",
                line: { color: COLORS.yhat, width: 1.3 },
              },
            ]}
            layout={plotLayout({
              title: {
                text: `${conformal.sensor} · ${conformal.horizon} · ${(100 * pct).toFixed(0)}%`,
                font: { size: 13 },
              },
              height: 420,
            })}
          />
        </>
      )}

      <Detail title="Reading the plot" open>
        <p>
          Raising nominal coverage increases CQ and widens the band. Empirical coverage on the plotted
          window may differ from the nominal level under serial dependence.
        </p>
      </Detail>

      <p className="takeaway">
        Wider nominal coverage → larger CQ → wider bands.{" "}
        <Link to="/extensions">Extensions →</Link>
      </p>
    </div>
  );
}
