import { useMemo, useState } from "react";
import { Link } from "react-router-dom";
import Detail from "../components/Detail";
import Katex, { EqBlock } from "../components/Katex";
import Plot from "../components/Plot";
import { COLORS, plotLayout } from "../lib/plotlyTheme";
import { useData } from "../state/DataContext";

export default function ResultsPage() {
  const { scores, sensor, pollutant, setPollutant } = useData();
  const pollutants = useMemo(
    () => Array.from(new Set(scores.map((r) => r.pollutant))).sort(),
    [scores]
  );
  const horizons = useMemo(
    () => Array.from(new Set(scores.map((r) => r.horizon))).sort(),
    [scores]
  );
  const [h, setH] = useState("1d");
  const [metric, setMetric] = useState<"MASE" | "MAE" | "RMSE">("MASE");

  const rows = useMemo(() => {
    return scores
      .filter((r) => r.sensor === sensor && r.pollutant === pollutant && r.horizon === h)
      .slice()
      .sort((a, b) => (a[metric] ?? 99) - (b[metric] ?? 99));
  }, [scores, sensor, pollutant, h, metric]);

  const best = rows[0]?.[metric];

  const wavePairs = useMemo(() => {
    const want = [
      ["catboost", "wavecatboost"],
      ["lgb", "wavelgb"],
      ["xgb", "wavexgb"],
      ["sarima", "wavesarima"],
    ] as const;
    const by = Object.fromEntries(rows.map((r) => [r.method, r]));
    return want
      .map(([plain, wave]) => {
        if (!by[plain] || !by[wave]) return null;
        return {
          pair: `${plain} → ${wave}`,
          plain: by[plain][metric],
          wave: by[wave][metric],
          delta: by[wave][metric] - by[plain][metric],
        };
      })
      .filter(Boolean) as { pair: string; plain: number; wave: number; delta: number }[];
  }, [rows, metric]);

  return (
    <div className="stack">
      <header>
        <div className="kicker">Results</div>
        <h2>How were models compared?</h2>
        <p className="lead">
          Recorded recursive multi-step scores for {sensor} · {pollutant}.
        </p>
      </header>

      <span className="badge recorded">Recursive multi-step protocol · S = 24</span>

      {wavePairs.length > 0 && (
        <div className="glass panel">
          <h3>Wave* vs baseline · {metric}</h3>
          <p className="muted" style={{ margin: "4px 0 10px" }}>
            Negative Δ means the Wave* variant improved (lower is better).
          </p>
          <Plot
            height={260}
            data={[
              {
                x: wavePairs.map((p) => p.pair),
                y: wavePairs.map((p) => p.delta),
                type: "bar",
                marker: {
                  color: wavePairs.map((p) => (p.delta < 0 ? COLORS.yhat : COLORS.bandLine)),
                },
                text: wavePairs.map((p) => (p.delta >= 0 ? "+" : "") + p.delta.toFixed(3)),
                textposition: "outside",
              },
            ]}
            layout={plotLayout({
              title: { text: `Δ ${metric} (Wave − baseline)`, font: { size: 13 } },
              showlegend: false,
              margin: { t: 40, r: 16, b: 64, l: 48 },
            })}
          />
        </div>
      )}

      <div className="glass panel">
        <h3>MASE (paper)</h3>
        <EqBlock>
          <Katex
            display
            tex="\mathrm{MASE}=\dfrac{N-S}{h}\,\dfrac{\sum_{t=N+1}^{N+h}|\hat Y_t-Y_t|}{\sum_{t=S+1}^{N}|Y_t-Y_{t-S}|}"
          />
        </EqBlock>
        <p className="muted" style={{ fontSize: "0.88rem", marginTop: 8 }}>
          h = forecast horizon, N = training length, S = seasonality (hourly data: S = 24). Lower is
          better.
        </p>
      </div>

      <div className="glass panel" style={{ display: "flex", flexWrap: "wrap", gap: 16 }}>
        <label className="field">
          Pollutant
          <select value={pollutant} onChange={(e) => setPollutant(e.target.value)}>
            {pollutants.map((p) => (
              <option key={p}>{p}</option>
            ))}
          </select>
        </label>
        <label className="field">
          Horizon
          <select value={h} onChange={(e) => setH(e.target.value)}>
            {horizons.map((x) => (
              <option key={x}>{x}</option>
            ))}
          </select>
        </label>
        <label className="field">
          Metric
          <select value={metric} onChange={(e) => setMetric(e.target.value as typeof metric)}>
            <option>MASE</option>
            <option>MAE</option>
            <option>RMSE</option>
          </select>
        </label>
      </div>

      {rows.length === 0 ? (
        <p className="takeaway">
          Unavailable for {sensor} · {pollutant} · {h}.
        </p>
      ) : (
        <>
          <Plot
            data={[
              {
                x: rows.map((r) => r.method),
                y: rows.map((r) => r[metric]),
                type: "bar",
                marker: {
                  color: rows.map((r) => (r[metric] === best ? COLORS.bandLine : COLORS.yhat)),
                },
              },
            ]}
            layout={plotLayout({
              title: { text: `${metric} · ${sensor} · ${pollutant} · ${h}`, font: { size: 13 } },
              showlegend: false,
            })}
          />
          <div className="table-wrap">
            <table className="data">
              <thead>
                <tr>
                  <th>method</th>
                  <th>MASE</th>
                  <th>MAE</th>
                  <th>RMSE</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((r) => (
                  <tr key={r.method} className={r.MASE === rows[0].MASE ? "best" : undefined}>
                    <td>{r.method}</td>
                    <td>{r.MASE?.toFixed(3)}</td>
                    <td>{r.MAE?.toFixed(3)}</td>
                    <td>{r.RMSE?.toFixed(3)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </>
      )}

      <Detail title="Recursive vs rolling evaluation" open>
        <p>
          <strong>Recursive multi-step:</strong> fit a one-step model, then roll it forward for h
          steps, feeding predictions back as lags. Errors compound over the horizon. The scores on
          this page use that protocol.
        </p>
        <p>
          <strong>Rolling one-step:</strong> at each origin, forecast only the next step with
          observed history (refit or update as the origin advances). The paper’s Table 1 style
          evaluation is closer to rolling one-step and is not interchangeable with these recursive
          MASE values.
        </p>
      </Detail>

      <Detail title="Hyperparameters">
        <p>
          Lag window p, tree depth, learning rate, and iterations are chosen by validation MASE on a
          chronological split. Test hours are held out. Decomposition depth K follows an energy elbow
          or ln N.
        </p>
      </Detail>

      <p className="muted">
        Next: <Link to="/conformal">Prediction intervals →</Link>
      </p>
    </div>
  );
}
