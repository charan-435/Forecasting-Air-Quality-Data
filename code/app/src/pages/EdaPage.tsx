// Displays the eda page in the app.

import { useMemo } from "react";
import { Link } from "react-router-dom";
import Detail from "../components/Detail";
import Katex, { EqBlock } from "../components/Katex";
import Plot from "../components/Plot";
import { energy, mra } from "../lib/modwt";
import { asset } from "../lib/paths";
import { COLORS, plotLayout } from "../lib/plotlyTheme";
import { acf, hourOfDayMeans, pacf } from "../lib/stats";
import { useData } from "../state/DataContext";

/** Recorded CPCB PM2.5 design-board figures (static evidence from the paper pipeline). */
const DESIGN_FIGS = [
  {
    src: "data/eda/diag_2x2_cpcb_pm25.png",
    title: "Series · ACF · PACF overview",
    why: "Four-panel summary of the design series: raw level, seasonal structure, and ACF/PACF side by side. Use this board to see persistence and the daily cycle in one glance before tuning lags.",
  },
  {
    src: "data/eda/boxes_cpcb_pm25.png",
    title: "Hour-of-day vs day-of-week boxes",
    why: "Boxplots of concentration by clock hour and by weekday. The hour-of-day spread is much larger than the day-of-week spread, which is why the seasonal period is S = 24 rather than S = 168.",
  },
  {
    src: "data/eda/acf_pacf_cpcb_pm25.png",
    title: "ACF and PACF (design board)",
    why: "Recorded ACF/PACF for CPCB PM2.5. Lag-1 and lag-24 dominate the ACF; the PACF stays outside the noise band for many hours, motivating lag windows around p = 24–48.",
  },
  {
    src: "data/eda/eda_snaive_resid_acf_cpcb_pm25.png",
    title: "Seasonal-naive residual ACF",
    why: "After subtracting Yₜ₋₂₄, residual autocorrelation at lag 1 remains high. A pure seasonal baseline is not enough—flexible learners (trees / Wave*) are needed for leftover dynamics.",
  },
  {
    src: "data/eda/eda_energy_cpcb_pm25.png",
    title: "Haar MRA energy",
    why: "Energy shares for detail bands D₁…D₅ and smooth S₅. Most squared amplitude sits in S₅, but detail bands are nonzero—so MODWT keeps both the smooth and the details for separate forecasting.",
  },
  {
    src: "data/eda/mra_d1d4_s4_cpcb_pm25.png",
    title: "MRA detail and smooth bands",
    why: "Time traces of selected Dⱼ and S_K. Each detail band emphasises a different time scale; the smooth carries the slow trend that CatBoost will also model.",
  },
  {
    src: "data/eda/eda_design_board_cpcb_pm25.png",
    title: "Full EDA design board",
    why: "Composite board that collected the key plots used when locking S, p, and K for the CPCB PM2.5 reference run.",
  },
  {
    src: "data/eda/eda_to_pipeline_cpcb_pm25.png",
    title: "EDA → pipeline map",
    why: "Summary graphic linking each diagnostic finding to a concrete modeling choice (seasonality, lags, MODWT, trees).",
  },
];

const PIPELINE = [
  {
    observed: "Hour-of-day swing is larger than day-of-week swing on the design series.",
    motivated: "Seasonal period S = 24 for seasonal-naive baselines and MASE.",
    tex: "S=24\\quad(\\text{hours in one day})",
    note: "Weekly seasonality (S = 168) is weaker here, so the daily cycle is the natural scale.",
  },
  {
    observed: "Autocorrelation is near one at lag 1 and still strong at lag 24.",
    motivated: "Lag features must capture persistence and the daily cycle.",
    tex: "\\hat\\rho(1)\\approx 1,\\quad \\hat\\rho(24)\\text{ elevated}",
    note: "A model that ignores lag 24 will miss the traffic / boundary-layer rhythm.",
  },
  {
    observed: "Partial autocorrelation decays slowly across many hours.",
    motivated: "Tune lag window p on validation MASE (commonly p = 24, try p = 48).",
    tex: "\\mathbf{x}_t=(Y_{t-1},\\ldots,Y_{t-p})",
    note: "PACF suggests how far linear dependence reaches; trees still benefit from a long enough window.",
  },
  {
    observed: "Seasonal-naive residuals keep high ACF(1) and large residual scale.",
    motivated: "Need flexible learners (gradient trees) beyond a pure seasonal baseline.",
    tex: "e_t=Y_t-Y_{t-S},\\quad \\mathrm{ACF}_e(1)\\text{ still large}",
    note: "Leftover serial correlation is exactly what CatBoost / Wave* target.",
  },
  {
    observed: "Haar energy is dominated by the smooth, with smaller nonzero detail bands.",
    motivated: "MODWT split → one forecast per Dⱼ and S_K → sum.",
    tex: "Y_t=\\sum_{j=1}^{K}D_{j,t}+S_{K,t}",
    note: "Detail filters pₘ and scaling filters qₘ build Dⱼ and Sⱼ; Haar is the default filter pair.",
  },
];

export default function EdaPage() {
  const { series, sensor, pollutant } = useData();

  const y = series?.y ?? [];
  const t = series?.t ?? [];
  const maxLag = 48;

  const acfRows = useMemo(() => acf(y, maxLag), [y]);
  const pacfRows = useMemo(() => pacf(y, maxLag), [y]);
  const hourly = useMemo(() => hourOfDayMeans(t, y), [t, y]);
  const mraBands = useMemo(() => {
    if (y.length < 64) return null;
    return mra(y, 4, "haar");
  }, [y]);
  const en = useMemo(() => (mraBands ? energy(mraBands) : []), [mraBands]);

  const conf = useMemo(() => {
    const n = y.filter(Number.isFinite).length;
    if (n < 10) return 0;
    return 1.96 / Math.sqrt(n);
  }, [y]);

  const live = useMemo(() => {
    const r1 = acfRows.find((d) => d.lag === 1)?.r;
    const r24 = acfRows.find((d) => d.lag === 24)?.r;
    const hourAmp =
      hourly.length > 0
        ? Math.max(...hourly.map((d) => d.mean).filter(Number.isFinite)) -
          Math.min(...hourly.map((d) => d.mean).filter(Number.isFinite))
        : NaN;
    const detailShare = en.filter((r) => r.component.startsWith("D")).reduce((a, r) => a + r.share, 0);
    const smoothShare = en.find((r) => r.component.startsWith("S"))?.share;
    return { r1, r24, hourAmp, detailShare, smoothShare };
  }, [acfRows, hourly, en]);

  return (
    <div className="stack">
      <header>
        <div className="kicker">EDA & preprocessing</div>
        <h2>Observation → decision</h2>
        <p className="lead">
          Diagnostics for <strong>{sensor}</strong> · <strong>{pollutant}</strong> that motivate
          seasonality, lag windows, MODWT, and tree models. Open each section for the plot and the
          reasoning.
        </p>
      </header>

      {/* 1. Findings → pipeline */}
      <div className="glass panel">
        <h3>Findings → pipeline</h3>
        <p className="muted" style={{ margin: "6px 0 14px", fontSize: "0.9rem" }}>
          Design logic first established on CPCB PM2.5, then reused as defaults elsewhere. Live
          numbers below refresh with the series you selected.
        </p>
        {PIPELINE.map((row, i) => (
          <div className="decision-rich" key={i}>
            <div className="decision-rich-cols">
              <div>
                <div className="decision-label">Observed</div>
                <p>{row.observed}</p>
              </div>
              <div className="arrow">→</div>
              <div>
                <div className="decision-label">Pipeline choice</div>
                <p>
                  <strong>{row.motivated}</strong>
                </p>
              </div>
            </div>
            <EqBlock>
              <Katex display tex={row.tex} />
            </EqBlock>
            <p className="muted" style={{ margin: "6px 0 0", fontSize: "0.88rem" }}>
              {row.note}
            </p>
          </div>
        ))}
        {Number.isFinite(live.r1) && (
          <p className="takeaway" style={{ marginTop: 12 }}>
            On this window: ρ̂(1) = {live.r1!.toFixed(2)}
            {Number.isFinite(live.r24) ? `, ρ̂(24) = ${live.r24!.toFixed(2)}` : ""}
            {Number.isFinite(live.hourAmp) ? `, hour-of-day range ≈ ${live.hourAmp!.toFixed(2)}` : ""}
            {Number.isFinite(live.smoothShare)
              ? `, Haar smooth share ≈ ${(100 * live.smoothShare!).toFixed(0)}%`
              : ""}
            .
          </p>
        )}
      </div>

      {/* Design-board photos (CPCB PM2.5 evidence) */}
      <div className="glass panel">
        <h3>Design-board figures</h3>
        <p className="muted" style={{ margin: "6px 0 12px", fontSize: "0.9rem" }}>
          Recorded CPCB PM2.5 panels from the original design pass. Open any figure for the full image
          and explanation. Live interactive diagnostics for your current selection follow below.
        </p>
        <div className="eda-fig-grid">
          {DESIGN_FIGS.map((f) => (
            <figure key={f.src} className="eda-fig-card">
              <img src={asset(f.src)} alt={f.title} loading="lazy" />
              <figcaption>
                <strong>{f.title}</strong>
              </figcaption>
            </figure>
          ))}
        </div>
      </div>

      {DESIGN_FIGS.map((f, i) => (
        <Detail key={f.src} title={f.title} open={i === 0}>
          <p>{f.why}</p>
          <img
            className="eda-fig-full"
            src={asset(f.src)}
            alt={f.title}
            loading="lazy"
          />
        </Detail>
      ))}

      {/* Live interactive diagnostics */}
      <h3 className="eda-live-h">Live diagnostics · {sensor} · {pollutant}</h3>
      <p className="muted" style={{ margin: "-4px 0 8px", fontSize: "0.9rem" }}>
        These charts recompute from the series selected in the top bar (not frozen CPCB-only screenshots).
      </p>

      <Detail title="Autocorrelation (ACF)" open>
        <p>
          The sample ACF at lag k measures linear dependence between Yₜ and Yₜ₋ₖ. Dotted lines are
          approximate white-noise bounds ±1.96/√n.
        </p>
        <EqBlock>
          <Katex display tex="\hat\rho(k)=\dfrac{\sum_{t=k+1}^{n}(Y_t-\bar Y)(Y_{t-k}-\bar Y)}{\sum_{t=1}^{n}(Y_t-\bar Y)^2}" />
        </EqBlock>
        <Plot
          height={300}
          data={[
            {
              x: acfRows.map((d) => d.lag),
              y: acfRows.map((d) => d.r),
              type: "bar",
              marker: { color: COLORS.yhat },
              name: "ACF",
            },
            {
              x: [0, maxLag],
              y: [conf, conf],
              type: "scatter",
              mode: "lines",
              line: { color: COLORS.bandLine, width: 1, dash: "dot" },
              name: "+1.96/√n",
              hoverinfo: "skip",
            },
            {
              x: [0, maxLag],
              y: [-conf, -conf],
              type: "scatter",
              mode: "lines",
              line: { color: COLORS.bandLine, width: 1, dash: "dot" },
              showlegend: false,
              hoverinfo: "skip",
            },
          ]}
          layout={plotLayout({
            xaxis: { title: "Lag (hours)" },
            yaxis: { title: "ρ̂(k)", range: [-1, 1] },
            margin: { t: 16, r: 12, b: 44, l: 48 },
          })}
        />
        <p className="muted" style={{ fontSize: "0.88rem", marginTop: 8 }}>
          Strong lag-1 and lag-24 bars justify persistence features and a daily seasonal scale.
        </p>
      </Detail>

      <Detail title="Partial autocorrelation (PACF)">
        <p>
          PACF at lag k is the correlation between Yₜ and Yₜ₋ₖ after removing the linear effect of
          intermediate lags. It helps size the lag window p for supervised features.
        </p>
        <EqBlock>
          <Katex display tex="\mathbf{x}_t=(Y_{t-1},\ldots,Y_{t-p})" />
        </EqBlock>
        <Plot
          height={300}
          data={[
            {
              x: pacfRows.filter((d) => d.lag > 0).map((d) => d.lag),
              y: pacfRows.filter((d) => d.lag > 0).map((d) => d.phi),
              type: "bar",
              marker: { color: COLORS.y },
              name: "PACF",
            },
            {
              x: [1, maxLag],
              y: [conf, conf],
              type: "scatter",
              mode: "lines",
              line: { color: COLORS.bandLine, width: 1, dash: "dot" },
              name: "+1.96/√n",
              hoverinfo: "skip",
            },
            {
              x: [1, maxLag],
              y: [-conf, -conf],
              type: "scatter",
              mode: "lines",
              line: { color: COLORS.bandLine, width: 1, dash: "dot" },
              showlegend: false,
              hoverinfo: "skip",
            },
          ]}
          layout={plotLayout({
            xaxis: { title: "Lag (hours)" },
            yaxis: { title: "ϕ̂ₖₖ", range: [-1, 1] },
            margin: { t: 16, r: 12, b: 44, l: 48 },
          })}
        />
      </Detail>

      <Detail title="Diurnal profile (hour of day)">
        <p>
          Mean level by clock hour reveals the daily amplitude. When this range exceeds the
          day-of-week contrast, the seasonal period for snaive / MASE is chosen as S = 24.
        </p>
        <Plot
          height={280}
          data={[
            {
              x: hourly.map((d) => d.hour),
              y: hourly.map((d) => d.mean),
              type: "bar",
              marker: { color: COLORS.yhat },
            },
          ]}
          layout={plotLayout({
            xaxis: { title: "Hour of day", dtick: 3 },
            yaxis: { title: pollutant },
            showlegend: false,
            margin: { t: 16, r: 12, b: 44, l: 48 },
          })}
        />
      </Detail>

      <Detail title="Haar energy share">
        <p>
          After MODWT / MRA with K levels, each component’s energy is its sum of squares. Shares show
          how much squared amplitude sits in details versus the smooth.
        </p>
        <EqBlock>
          <Katex display tex="E_C=\sum_t C_t^2,\quad C\in\{D_1,\ldots,D_K,S_K\}" />
          <Katex display tex="\mathrm{share}(C)=\dfrac{E_C}{\sum_{C'} E_{C'}}" />
        </EqBlock>
        {en.length > 0 && (
          <Plot
            height={280}
            data={[
              {
                x: en.map((r) => r.component),
                y: en.map((r) => r.share),
                type: "bar",
                marker: {
                  color: en.map((r) => (r.component.startsWith("S") ? COLORS.S : COLORS.bandLine)),
                },
                text: en.map((r) => `${(100 * r.share).toFixed(0)}%`),
                textposition: "outside",
              },
            ]}
            layout={plotLayout({
              yaxis: { title: "Share", tickformat: ".0%", range: [0, 1.05] },
              showlegend: false,
              margin: { t: 16, r: 12, b: 44, l: 52 },
            })}
          />
        )}
        <p className="muted" style={{ fontSize: "0.88rem", marginTop: 8 }}>
          A dominant S_K does not mean details are useless—short-scale Dⱼ still carry events that
          Wave* models separately.
        </p>
      </Detail>

      <Detail title="MRA bands (Haar, K = 4)">
        <p>
          Detail series Dⱼ and smooth S_K from the same window. Band j roughly corresponds to time
          scales near 2ʲ hours on hourly data.
        </p>
        {mraBands && (
          <div className="band-stack">
            {mraBands.D.map((d, i) => (
              <div key={i} className="band-card glass">
                <div className="band-label">D{i + 1}</div>
                <Plot
                  height={110}
                  data={[
                    {
                      y: d,
                      type: "scatter",
                      mode: "lines",
                      line: { color: COLORS.D[i % COLORS.D.length], width: 1.1 },
                    },
                  ]}
                  layout={plotLayout({
                    margin: { t: 4, r: 10, b: 20, l: 40 },
                    showlegend: false,
                    title: undefined,
                  })}
                />
              </div>
            ))}
            <div className="band-card glass">
              <div className="band-label">S4</div>
              <Plot
                height={110}
                data={[
                  {
                    y: mraBands.S,
                    type: "scatter",
                    mode: "lines",
                    line: { color: COLORS.S, width: 1.1 },
                  },
                ]}
                layout={plotLayout({
                  margin: { t: 4, r: 10, b: 20, l: 40 },
                  showlegend: false,
                  title: undefined,
                })}
              />
            </div>
          </div>
        )}
      </Detail>

      {/* 3. Preprocessing */}
      <div className="glass panel">
        <h3>Missing values, imputation, and min–max scaling</h3>
        <p className="muted" style={{ margin: "8px 0 0", fontSize: "0.92rem" }}>
          Before MODWT or trees, each pollutant column is cleaned on a regular hourly grid.
        </p>

        <h4 className="eda-subh">1 · Detect impossible / missing values</h4>
        <p style={{ fontSize: "0.92rem" }}>
          Negatives and absurd spikes (beyond pollutant-specific physical caps) are set to missing.
          Ordinary gaps from sensor downtime are already NA in the raw tables.
        </p>
        <EqBlock>
          <Katex display tex="Y_t^{\mathrm{raw}}\leftarrow \mathrm{NA}\quad\text{if }Y_t<0\text{ or }Y_t>\mathrm{cap}" />
        </EqBlock>

        <h4 className="eda-subh">2 · Impute to a continuous hourly series</h4>
        <p style={{ fontSize: "0.92rem" }}>
          Short gaps are filled with a seasonal interpolant at period S = 24 when possible; if that
          fails, linear interpolation in time is used. The goal is a complete series for filtering and
          lag construction—not to invent new pollution events.
        </p>
        <EqBlock>
          <Katex display tex="Y_t^{\mathrm{fill}}=\mathrm{Impute}\bigl(Y_t^{\mathrm{raw}};\,S=24\bigr)" />
        </EqBlock>

        <h4 className="eda-subh">3 · Train-only min–max normalisation</h4>
        <p style={{ fontSize: "0.92rem" }}>
          When models expect a bounded scale, min and max are estimated on the training segment only,
          then applied to validation / test. Inversion restores µg/m³ (or the native unit) after
          forecasting.
        </p>
        <EqBlock>
          <Katex display tex="Z_t=\dfrac{Y_t-\min_{\mathrm{train}}Y}{\max_{\mathrm{train}}Y-\min_{\mathrm{train}}Y}" />
          <Katex display tex="\hat Y_t=Z_t\,(\max_{\mathrm{train}}Y-\min_{\mathrm{train}}Y)+\min_{\mathrm{train}}Y" />
        </EqBlock>
        <p className="muted" style={{ fontSize: "0.88rem", marginTop: 8 }}>
          Test hours never enter the min/max fit, the imputation used for scored features, or the
          hyperparameter grid.
        </p>
      </div>

      {/* 4. Strong closing */}
      <div className="glass panel">
        <h3>How EDA locks the WaveCatBoost recipe</h3>
        <ol className="eda-close-list">
          <li>
            <strong>S = 24</strong> from the diurnal profile → seasonal-naive scale inside MASE and
            any seasonal baseline.
          </li>
          <li>
            <strong>Lags p ≈ 24–48</strong> from ACF / PACF → supervised feature window for each
            component model.
          </li>
          <li>
            <strong>Leftover dynamics</strong> after seasonal-naive → gradient-boosted trees instead of
            a pure seasonal forecast.
          </li>
          <li>
            <strong>Energy in S_K and Dⱼ</strong> → MODWT with filters (pₘ, qₘ); forecast each Dⱼ and
            S_K; reconstruct{" "}
            <Katex tex="\hat Y=\sum_j\hat Y_{D_j}+\hat Y_{S_K}" />.
          </li>
          <li>
            <strong>Clean hourly grid</strong> via NA handling, imputation, and train-only min–max →
            stable inputs to every step above.
          </li>
        </ol>
        <p className="takeaway" style={{ marginTop: 14 }}>
          Next: walk the MODWT recursion and the K = 4 decomposition tree.{" "}
          <Link to="/modwt">MODWT →</Link>
        </p>
      </div>
    </div>
  );
}
