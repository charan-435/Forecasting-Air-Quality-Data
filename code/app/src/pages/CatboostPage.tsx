import { useMemo, useState } from "react";
import { Link } from "react-router-dom";
import Detail from "../components/Detail";
import Katex, { EqBlock } from "../components/Katex";
import Plot from "../components/Plot";
import { COLORS, plotLayout } from "../lib/plotlyTheme";
import { useData } from "../state/DataContext";

export default function CatboostPage() {
  const { series, sensor, pollutant } = useData();
  const [etaPct, setEtaPct] = useState(15);
  const [M, setM] = useState(12);

  const toy = useMemo(() => {
    const y = (series?.y ?? []).slice(-120);
    if (!y.length) return null;
    const eta = etaPct / 100;
    let F = y.map(() => y.reduce((a, b) => a + b, 0) / y.length);
    for (let m = 0; m < M; m++) {
      const resid = y.map((yi, i) => yi - F[i]);
      const block = Math.max(4, Math.floor(y.length / 8));
      const step = resid.map((_, i) => {
        const lo = Math.floor(i / block) * block;
        const hi = Math.min(y.length, lo + block);
        let s = 0;
        for (let k = lo; k < hi; k++) s += resid[k];
        return s / (hi - lo);
      });
      F = F.map((f, i) => f + eta * step[i]);
    }
    return { y, F, x: y.map((_, i) => i) };
  }, [series, etaPct, M]);

  return (
    <div className="stack">
      <header>
        <div className="kicker">CatBoost</div>
        <h2>How do trees improve a forecast?</h2>
        <p className="lead">
          Gradient boosting adds shallow trees on residuals. WaveCatBoost does this per MODWT
          component, then sums.
        </p>
      </header>

      <div className="row two">
        <div className="glass panel">
          <h3>Boosting update</h3>
          <EqBlock>
            <Katex display tex="F_m(x)=F_{m-1}(x)+\eta\,f_m(x)" />
            <Katex display tex="\ell=\tfrac12\bigl(y-F(x)\bigr)^2" />
          </EqBlock>
          <p className="muted" style={{ fontSize: "0.88rem", marginTop: 8 }}>
            Under squared error, each tree fits the current residual. The sliders below illustrate
            the idea on the selected window.
          </p>
        </div>
        <div className="glass panel">
          <h3>WaveCatBoost</h3>
          <EqBlock>
            <Katex display tex="\hat Y=\sum_j \hat Y_{D_j}+\hat Y_{S_K}" />
          </EqBlock>
          <p className="muted" style={{ fontSize: "0.88rem", marginTop: 8 }}>
            One model per MRA component, lag features on that component, then sum to reconstruct the
            series forecast.
          </p>
        </div>
      </div>

      <div className="glass panel toolbar-row">
        <label className="field">
          η = {(etaPct / 100).toFixed(2)}
          <input
            type="range"
            min={5}
            max={40}
            value={etaPct}
            onChange={(e) => setEtaPct(Number(e.target.value))}
          />
        </label>
        <label className="field">
          trees M = {M}
          <input type="range" min={1} max={40} value={M} onChange={(e) => setM(Number(e.target.value))} />
        </label>
      </div>

      {toy && (
        <Plot
          height={320}
          data={[
            {
              x: toy.x,
              y: toy.y,
              type: "scatter",
              mode: "lines",
              name: "Y",
              line: { color: COLORS.y, width: 1.3 },
            },
            {
              x: toy.x,
              y: toy.F,
              type: "scatter",
              mode: "lines",
              name: "Fₘ",
              line: { color: COLORS.yhat, width: 1.5 },
            },
          ]}
          layout={plotLayout({
            title: { text: `${sensor} · ${pollutant}`, font: { size: 13 } },
            xaxis: { title: "t (window)" },
            margin: { t: 40, r: 16, b: 44, l: 48 },
          })}
        />
      )}

      <Detail title="Learning rate and depth" open>
        <p>
          η scales each tree’s contribution. More trees fit residuals further until overfitting.
          Production fits use validation MASE with early stopping.
        </p>
      </Detail>

      <Detail title="Recursive vs direct multi-step">
        <p>
          <strong>Recursive:</strong> one-step model rolled forward (main CPCB / ID1 comparison).{" "}
          <strong>Direct:</strong> separate heads per horizon (some Shillong experiments). Do not mix
          MASE tables across these protocols.
        </p>
      </Detail>

      <p className="takeaway">
        Compare recorded scores on Results. <Link to="/results">Results →</Link>
      </p>
    </div>
  );
}
