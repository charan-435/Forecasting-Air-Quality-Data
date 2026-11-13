// Displays saved wavelet-filter and decomposition comparisons. Selection controls choose
// which recorded scores to show.

import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import Detail from "../components/Detail";
import Plot from "../components/Plot";
import { loadJson } from "../lib/paths";
import { COLORS, plotLayout } from "../lib/plotlyTheme";
import { useData } from "../state/DataContext";

type FilterRow = {
  sensor: string;
  pollutant: string;
  horizon: string;
  method: string;
  filter: string;
  MASE: number;
  MAE: number;
  RMSE: number;
};

type DirectRow = { h: number; model: string; MASE: number; MAE: number; RMSE: number };

const FILTER_COLORS: Record<string, string> = {
  haar: "#1a3358",
  d4: "#2f7a7a",
  la8: "#c47a3a",
  fourier: "#6b8f71",
  emd: "#8a5a12",
};

export default function ExtensionsPage() {
  const { sensor, pollutant, setPollutant } = useData();
  const [filters, setFilters] = useState<FilterRow[]>([]);
  const [ext, setExt] = useState<FilterRow[]>([]);
  const [direct, setDirect] = useState<DirectRow[]>([]);
  const [method, setMethod] = useState("wavecatboost");

  useEffect(() => {
    loadJson<FilterRow[]>("data/filter_scores.json").then(setFilters).catch(() => setFilters([]));
    loadJson<FilterRow[]>("data/extension_scores.json").then(setExt).catch(() => setExt([]));
    loadJson<DirectRow[]>("data/shillong_direct_scores.json").then(setDirect).catch(() => setDirect([]));
  }, []);

  const pollutants = useMemo(
    () => Array.from(new Set(filters.map((r) => r.pollutant))).sort(),
    [filters]
  );
  const methods = useMemo(
    () => Array.from(new Set(filters.map((r) => r.method))).sort(),
    [filters]
  );

  const filterView = useMemo(() => {
    return filters
      .filter((r) => r.sensor === sensor && r.pollutant === pollutant && r.method === method)
      .slice()
      .sort((a, b) => a.MASE - b.MASE);
  }, [filters, sensor, pollutant, method]);

  const bestFilter = filterView[0];

  const decompView = useMemo(() => {
    return ext
      .filter((r) => r.sensor === sensor && r.pollutant === pollutant)
      .slice()
      .sort((a, b) => a.MASE - b.MASE);
  }, [ext, sensor, pollutant]);

  const shillongH = useMemo(() => {
    return Array.from(new Set(direct.map((r) => r.h))).sort((a, b) => a - b);
  }, [direct]);

  const [shH, setShH] = useState(1);
  useEffect(() => {
    if (shillongH.length && !shillongH.includes(shH)) setShH(shillongH[0]);
  }, [shillongH, shH]);

  const shillongView = useMemo(() => {
    return direct
      .filter((r) => r.h === shH)
      .slice()
      .sort((a, b) => a.MASE - b.MASE);
  }, [direct, shH]);

  return (
    <div className="stack">
      <header>
        <div className="kicker">Extensions</div>
        <h2>Beyond the paper baseline</h2>
        <p className="lead">Filter variants, alternate decompositions, and a new station.</p>
      </header>

      <section className="glass panel stack" style={{ gap: 12 }}>
        <div>
          <h3>Filter comparison · Haar vs D4 vs LA8</h3>
          <p className="muted" style={{ margin: "4px 0 0" }}>
            Same Wave* pipeline; only the wavelet filter (pₘ, qₘ) changes. Lower MASE is better.
          </p>
        </div>
        <div className="toolbar-row">
          <label className="field">
            Pollutant
            <select value={pollutant} onChange={(e) => setPollutant(e.target.value)}>
              {pollutants.map((p) => (
                <option key={p}>{p}</option>
              ))}
            </select>
          </label>
          <label className="field">
            Method
            <select value={method} onChange={(e) => setMethod(e.target.value)}>
              {methods.map((m) => (
                <option key={m}>{m}</option>
              ))}
            </select>
          </label>
        </div>

        {filterView.length === 0 ? (
          <p className="takeaway">
            No filter scores for {sensor} · {pollutant} · {method}.
          </p>
        ) : (
          <>
            <Plot
              height={280}
              data={[
                {
                  x: filterView.map((r) => r.filter),
                  y: filterView.map((r) => r.MASE),
                  type: "bar",
                  marker: {
                    color: filterView.map((r) => FILTER_COLORS[r.filter] ?? COLORS.yhat),
                  },
                  text: filterView.map((r) => r.MASE.toFixed(3)),
                  textposition: "outside",
                },
              ]}
              layout={plotLayout({
                title: {
                  text: `MASE · ${sensor} · ${pollutant} · ${method}`,
                  font: { size: 13 },
                },
                yaxis: { title: "MASE" },
                showlegend: false,
                margin: { t: 40, r: 16, b: 40, l: 48 },
              })}
            />
            <p className="takeaway">
              Best here: <strong>{bestFilter.filter}</strong> (MASE {bestFilter.MASE.toFixed(3)}).
            </p>
          </>
        )}
      </section>

      <section className="glass panel stack" style={{ gap: 12 }}>
        <div>
          <h3>Fourier &amp; EMD substitutes</h3>
          <p className="muted" style={{ margin: "4px 0 0" }}>
            Alternate decompositions in place of MODWT, scored under the same learner where available.
          </p>
        </div>
        {decompView.length === 0 ? (
          <p className="takeaway">
            Unavailable for {sensor} · {pollutant}.
          </p>
        ) : (
          <Plot
            height={300}
            data={[
              {
                x: decompView.map((r) => `${r.filter}`),
                y: decompView.map((r) => r.MASE),
                type: "bar",
                marker: {
                  color: decompView.map((r) => FILTER_COLORS[r.filter] ?? "#5B7C99"),
                },
                text: decompView.map((r) => r.MASE.toFixed(2)),
                textposition: "outside",
              },
            ]}
            layout={plotLayout({
              title: { text: `Decomposition MASE · ${sensor} · ${pollutant}`, font: { size: 13 } },
              showlegend: false,
              margin: { t: 40, r: 16, b: 48, l: 48 },
            })}
          />
        )}
      </section>

      <section className="glass panel stack" style={{ gap: 12 }}>
        <div>
          <h3>Shillong · direct forecasts</h3>
          <p className="muted" style={{ margin: "4px 0 0" }}>
            New station with direct multi-horizon heads (1 h / 6 h / 24 h).
          </p>
        </div>
        <div className="toolbar-row">
          <label className="field">
            Horizon (h)
            <select value={shH} onChange={(e) => setShH(Number(e.target.value))}>
              {shillongH.map((h) => (
                <option key={h} value={h}>
                  {h}
                </option>
              ))}
            </select>
          </label>
        </div>
        {shillongView.length > 0 && (
          <Plot
            height={340}
            data={[
              {
                y: shillongView.map((r) => r.model),
                x: shillongView.map((r) => r.MASE),
                type: "bar",
                orientation: "h",
                marker: {
                  color: shillongView.map((_, i) => (i === 0 ? COLORS.bandLine : COLORS.yhat)),
                },
              },
            ]}
            layout={plotLayout({
              title: { text: `Shillong MASE · h = ${shH}`, font: { size: 13 } },
              margin: { t: 40, r: 16, b: 40, l: 140 },
              showlegend: false,
            })}
          />
        )}
        <p className="takeaway">
          Direct-horizon ranks are not merged with the CPCB / ID1 recursive comparison.
        </p>
      </section>

      <Detail title="What counts as an extension" open>
        <p>
          Longer wavelet filters, Fourier / EMD substitutes, a new station, or a different forecast
          protocol (direct heads). Each chart uses recorded scores for the selected controls.
        </p>
      </Detail>

      <p className="muted">
        <Link to="/credits">About →</Link>
      </p>
    </div>
  );
}
