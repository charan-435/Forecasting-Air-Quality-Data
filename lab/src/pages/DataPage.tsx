import { useMemo } from "react";
import { Link } from "react-router-dom";
import Detail from "../components/Detail";
import Plot from "../components/Plot";
import { COLORS, plotLayout } from "../lib/plotlyTheme";
import { useData } from "../state/DataContext";

const STATION_COPY: Record<string, { title: string; body: string }> = {
  CPCB: {
    title: "Central Pollution Control Board (paper release)",
    body: "Hourly concentrations from the CPCB monitoring network used in the WaveCatBoost paper. This station is the primary reference for seasonality choices (daily period S = 24), lag structure, and decomposition depth. Design decisions for MODWT and tree models were first read off CPCB PM2.5 and then checked across pollutants.",
  },
  ID1: {
    title: "Second paper-release station",
    body: "An independent site published with the same paper data release as CPCB—not a separate regulatory board. The schema matches CPCB (hourly pollutants), which lets the same recursive multi-step comparison protocol be repeated on a second geographic footprint.",
  },
  SHILLONG: {
    title: "CAAQMS extension station",
    body: "An extension site built from Continuous Ambient Air Quality Monitoring System extracts. Native samples are 15-minute; they are aggregated to hourly means before forecasting. Shillong is scored under a direct multi-horizon protocol and should not be ranked against the CPCB / ID1 recursive results.",
  },
};

/** Parse Lab timestamps (DD-MM-YYYY HH:mm or ISO-like) into Date for Plotly. */
function parseLabTime(s: string): Date {
  const m = /^(\d{2})-(\d{2})-(\d{4})[ T](\d{2}):(\d{2})/.exec(s);
  if (m) {
    return new Date(`${m[3]}-${m[2]}-${m[1]}T${m[4]}:${m[5]}:00`);
  }
  const d = new Date(s.replace(" ", "T"));
  return Number.isFinite(d.getTime()) ? d : new Date(NaN);
}

/**
 * Drop long leading/trailing constant plateaus (imputed gaps / stuck sensors)
 * so the chart shows the informative variation.
 */
function trimFlatEdges(t: string[], y: number[], minFlat = 12) {
  const n = y.length;
  if (n < minFlat + 8) return { t, y, trimmedLead: 0, trimmedTail: 0 };

  const nearlyEq = (a: number, b: number) =>
    Number.isFinite(a) && Number.isFinite(b) && Math.abs(a - b) <= 1e-6;

  let lo = 0;
  while (lo + 1 < n && nearlyEq(y[lo + 1], y[lo])) lo++;
  let lead = lo + 1 >= minFlat ? lo + 1 : 0;

  let hi = n - 1;
  while (hi - 1 >= lead && nearlyEq(y[hi - 1], y[hi])) hi--;
  let tailCut = n - 1 - hi >= minFlat ? n - 1 - hi : 0;
  const hiExcl = n - tailCut;

  if (hiExcl - lead < 24) {
    // keep a usable window from the end if trim is too aggressive
    lead = Math.max(0, n - 24 * 7);
    tailCut = 0;
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

function statsOf(y: number[]) {
  const v = y.filter(Number.isFinite);
  if (!v.length) return null;
  const mean = v.reduce((a, b) => a + b, 0) / v.length;
  const sd = Math.sqrt(v.reduce((a, b) => a + (b - mean) ** 2, 0) / Math.max(1, v.length - 1));
  return {
    mean: +mean.toFixed(3),
    sd: +sd.toFixed(3),
    min: +Math.min(...v).toFixed(3),
    max: +Math.max(...v).toFixed(3),
    n: v.length,
  };
}

export default function DataPage() {
  const { series, seriesMeta, sensor, setSensor, pollutant, setPollutant, pollutants, manifest } =
    useData();
  const meta = seriesMeta;
  const station = STATION_COPY[sensor] ?? {
    title: sensor,
    body: "Selected monitoring station.",
  };

  const view = useMemo(() => {
    if (!series?.y?.length) return null;
    const trimmed = trimFlatEdges(series.t, series.y);
    const x = trimmed.t.map(parseLabTime);
    const st = statsOf(trimmed.y);
    return { ...trimmed, x, st };
  }, [series]);

  return (
    <div className="stack">
      <header>
        <div className="kicker">Data</div>
        <h2>What are we forecasting?</h2>
        <p className="lead">
          Hourly concentrations of major urban air pollutants. Choose a monitoring station and a
          target species; every later lesson—EDA, MODWT, models, and scores—follows this selection.
        </p>
      </header>

      <div className="pill-row">
        {manifest &&
          Object.keys(manifest.datasets).map((s) => (
            <button
              key={s}
              type="button"
              className={`pill${s === sensor ? " pill-active" : ""}`}
              onClick={() => setSensor(s)}
            >
              {s}
            </button>
          ))}
      </div>

      <div className="pill-row">
        {pollutants.map((p) => (
          <button
            key={p}
            type="button"
            className={`pill${p === pollutant ? " pill-active" : ""}`}
            onClick={() => setPollutant(p)}
          >
            {p}
          </button>
        ))}
      </div>

      <div className="row two">
        <div className="glass panel">
          <h3>
            {sensor} · {pollutant}
          </h3>
          <p style={{ margin: "8px 0 0", fontSize: "0.95rem" }}>{station.title}</p>
          <p className="muted" style={{ margin: "8px 0 0", fontSize: "0.9rem" }}>
            {station.body}
          </p>
          {meta && view?.st && (
            <ul className="muted" style={{ margin: "12px 0 0", paddingLeft: 18 }}>
              <li>
                Full archive length: <strong>{meta.n_full.toLocaleString()}</strong> hourly samples
              </li>
              <li>
                Chart span: {view.t[0]} → {view.t[view.t.length - 1]} ({view.st.n} hours shown)
              </li>
              <li>Sampling rate: hourly · Units: {meta.units.replace(/ \(as recorded.*/, "")}</li>
              <li>
                Window stats — mean {view.st.mean}, sd {view.st.sd}, min {view.st.min}, max{" "}
                {view.st.max}
              </li>
            </ul>
          )}
          <div className="pill-row" style={{ marginTop: 14 }}>
            {manifest?.links?.cpcb && (
              <a className="pill" href={manifest.links.cpcb} target="_blank" rel="noreferrer">
                CPCB portal
              </a>
            )}
            {manifest?.links?.caaqms && (
              <a className="pill" href={manifest.links.caaqms} target="_blank" rel="noreferrer">
                CAAQMS
              </a>
            )}
            {manifest?.paper_code && (
              <a className="pill" href={manifest.paper_code} target="_blank" rel="noreferrer">
                Paper code &amp; data
              </a>
            )}
          </div>
        </div>

        <div className="glass panel">
          <h3>Why this matters</h3>
          <p className="muted" style={{ margin: "8px 0 0", fontSize: "0.92rem" }}>
            Air-quality series mix slow meteorology, daily traffic cycles, and sharp pollution events.
            A single global model often blurs those scales. WaveCatBoost first separates the series
            into MODWT detail and smooth components, forecasts each component, then reconstructs the
            target—so the Lab starts by locking the station and pollutant you will decompose.
          </p>
          <p className="muted" style={{ margin: "10px 0 0", fontSize: "0.92rem" }}>
            CPCB and ID1 share the paper’s recursive multi-step comparison. Shillong is an extension
            with direct horizons; keep those score tables separate when you report results.
          </p>
        </div>
      </div>

      {view && (
        <>
          <Plot
            height={360}
            data={[
              {
                x: view.x,
                y: view.y,
                type: "scatter",
                mode: "lines",
                line: { color: COLORS.y, width: 1.4 },
                name: pollutant,
                hovertemplate: `%{x|%d %b %Y %H:%M}<br>${pollutant}: %{y:.3f}<extra></extra>`,
              },
            ]}
            layout={plotLayout({
              title: { text: `${sensor} · ${pollutant}`, font: { size: 13 } },
              yaxis: {
                title: pollutant === "CO" ? "concentration" : "µg/m³",
                gridcolor: "rgba(21,34,56,0.08)",
                zeroline: false,
              },
              xaxis: {
                type: "date",
                title: "Date",
                tickformat: "%d %b",
                nticks: 8,
                tickangle: 0,
                automargin: true,
                gridcolor: "rgba(21,34,56,0.08)",
                zeroline: false,
              },
              margin: { t: 40, r: 16, b: 56, l: 56 },
              showlegend: false,
            })}
          />
          {(view.trimmedLead > 0 || view.trimmedTail > 0) && (
            <p className="muted" style={{ fontSize: "0.85rem", margin: "-4px 0 0" }}>
              Long constant plateaus (stuck readings or filled gaps) are hidden from this chart so the
              varying segment is readable
              {view.trimmedLead > 0 ? ` · removed ${view.trimmedLead} leading hours` : ""}
              {view.trimmedTail > 0 ? ` · removed ${view.trimmedTail} trailing hours` : ""}.
            </p>
          )}
        </>
      )}

      <Detail title="How these series are prepared" open>
        <p>
          CPCB and ID1 arrive as hourly tables in the paper release. Impossible negatives and extreme
          sensor faults are clipped to missing, then gaps are filled with a seasonal / linear
          interpolant so the modeling pipeline sees a continuous hourly grid. Ozone on CPCB is aligned
          to the label O₃ used in the score tables.
        </p>
        <p>
          Shillong originates as 15-minute CAAQMS extracts. Those stamps are aggregated to hourly
          means (and aligned to the same pollutant names) before any MODWT or tree model is fit. That
          aggregation reduces high-frequency instrument noise but preserves the diurnal cycle that
          drives S = 24.
        </p>
        <p>
          Evaluation uses a chronological split: the final h hours are the test block; a validation
          slice is taken from the end of the remaining fit window for early stopping and hyperparameter
          choice. Scalers and scored decompositions are fit without looking into the test block.
        </p>
      </Detail>

      <Detail title="What the chart shows">
        <p>
          The figure is a recent excerpt of the selected series—not the entire multi-year archive
          (full length is listed in the metadata). When a long stretch is perfectly flat, it usually
          reflects a filled outage or a stuck sensor; those plateaus are omitted from the plot so
          day-to-day variation remains visible. Hover a point for the exact timestamp and value; use
          the Plotly toolbar to zoom.
        </p>
        <p>
          Pollutant coverage includes PM2.5, PM10, NO₂, O₃, CO, and SO₂ wherever the station file
          provides a column. Switching the pills above (or the top bar) reloads the series for every
          downstream page.
        </p>
      </Detail>

      <Detail title="From data to WaveCatBoost">
        <p>
          Once a series is fixed, EDA checks daily seasonality and lag structure; MODWT splits the
          signal into detail bands Dⱼ and a smooth S_K; CatBoost (or related learners) forecasts each
          band; the sum reconstructs Ŷ; conformal prediction wraps an interval around that point
          forecast. Keeping station and pollutant consistent is what makes those steps comparable.
        </p>
      </Detail>

      <p className="takeaway">
        Next: interactive ACF, PACF, and energy on this series. <Link to="/eda">EDA →</Link>
      </p>
    </div>
  );
}
