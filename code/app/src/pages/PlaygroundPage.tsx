// Displays the playground page in the app.

import { useMemo, useState } from "react";
import { Link } from "react-router-dom";
import Detail from "../components/Detail";
import Katex, { EqBlock } from "../components/Katex";
import Plot from "../components/Plot";
import { energy, mra, reconstruct, maxAbsDiff, type FilterName } from "../lib/modwt";
import { COLORS, plotLayout } from "../lib/plotlyTheme";
import { dateAxisLayout, parseLabTime, trimFlatEdges } from "../lib/seriesView";
import { useData } from "../state/DataContext";

function makeSynthetic(n = 168): { t: string[]; y: number[] } {
  const t0 = Date.UTC(2023, 6, 1, 0, 0, 0);
  const t: string[] = [];
  const y: number[] = [];
  for (let i = 0; i < n; i++) {
    const d = new Date(t0 + i * 3600_000);
    const dd = String(d.getUTCDate()).padStart(2, "0");
    const mm = String(d.getUTCMonth() + 1).padStart(2, "0");
    const hh = String(d.getUTCHours()).padStart(2, "0");
    t.push(`${dd}-${mm}-${d.getUTCFullYear()} ${hh}:00`);
    const hours = i;
    const trend = 14 + 5 * (i / n);
    const daily = 3.5 * Math.sin((2 * Math.PI * hours) / 24);
    const slow = 2.2 * Math.sin((2 * Math.PI * hours) / 48 + 0.5);
    const spike = hours === 72 ? 8 : hours === 73 ? 3 : 0;
    const noise = 0.4 * Math.sin(hours * 0.41 + 1.2);
    y.push(trend + daily + slow + spike + noise);
  }
  return { t, y };
}

export default function PlaygroundPage() {
  const { series, sensor, pollutant } = useData();
  const [K, setK] = useState(5);
  const [filter, setFilter] = useState<FilterName>("haar");
  const [focus, setFocus] = useState<string>("Y");
  const [useSynthetic, setUseSynthetic] = useState(false);

  const trimmed = useMemo(() => {
    if (useSynthetic) {
      const syn = makeSynthetic(168);
      return { ...syn, trimmedLead: 0, trimmedTail: 0, source: "synthetic" as const };
    }
    const y = series?.y ?? [];
    const t = series?.t ?? [];
    if (!y.length) return null;
    const maxN = 24 * 14;
    const slice =
      y.length <= maxN
        ? { y, t }
        : { y: y.slice(-maxN), t: t.slice(-maxN) };
    const out = trimFlatEdges(slice.t, slice.y);
    return { ...out, source: "station" as const };
  }, [series, useSynthetic]);

  const xDates = useMemo(
    () => (trimmed ? trimmed.t.map(parseLabTime) : []),
    [trimmed]
  );

  const m = useMemo(() => {
    if (!trimmed?.y.length) return null;
    return mra(trimmed.y, K, filter);
  }, [trimmed, K, filter]);

  const en = useMemo(() => (m ? energy(m) : []), [m]);
  const recon = useMemo(() => (m ? reconstruct(m) : []), [m]);
  const reconErr = useMemo(
    () => (m && trimmed ? maxAbsDiff(trimmed.y, recon) : 0),
    [m, trimmed, recon]
  );

  const haarEnergy = useMemo(() => {
    if (!trimmed?.y.length) return [];
    return energy(mra(trimmed.y, K, "haar"));
  }, [trimmed, K]);

  const comps = useMemo(() => {
    if (!m || !trimmed) return [];
    return [
      { name: "Y", y: trimmed.y, color: COLORS.y },
      ...m.D.map((d, i) => ({
        name: `D${i + 1}`,
        y: d,
        color: COLORS.D[i % COLORS.D.length],
      })),
      { name: `S${K}`, y: m.S, color: COLORS.S },
    ];
  }, [m, trimmed, K]);

  const focusComp = comps.find((c) => c.name === focus) ?? comps[0];

  // Cumulative reconstruction: S_K + D_K + ... up to selected detail
  const buildUp = useMemo(() => {
    if (!m || !trimmed) return null;
    const partial = m.S.slice();
    const labels: string[] = [`S${K}`];
    for (let j = K - 1; j >= 0; j--) {
      for (let i = 0; i < partial.length; i++) partial[i] += m.D[j][i];
      labels.push(`+ D${j + 1}`);
    }
    return { y: partial, labels };
  }, [m, trimmed, K]);

  return (
    <div className="stack">
      <header>
        <div className="kicker">MODWT playground</div>
        <h2>What changes with K and filter?</h2>
        <p className="lead">
          Decompose {useSynthetic ? "a synthetic multi-scale signal" : `${sensor} · ${pollutant}`},
          watch energy shift, and rebuild Y from the bands.
        </p>
      </header>

      <div className="glass panel toolbar-row">
        <label className="field">
          Filter
          <select value={filter} onChange={(e) => setFilter(e.target.value as FilterName)}>
            <option value="haar">Haar</option>
            <option value="d4">D4</option>
            <option value="la8">LA8</option>
          </select>
        </label>
        <label className="field">
          K = {K}
          <input type="range" min={2} max={8} value={K} onChange={(e) => setK(Number(e.target.value))} />
        </label>
        <div className="pill-row" style={{ alignSelf: "end" }}>
          <button
            type="button"
            className={`pill${!useSynthetic ? " pill-active" : ""}`}
            onClick={() => setUseSynthetic(false)}
          >
            {sensor} · {pollutant}
          </button>
          <button
            type="button"
            className={`pill${useSynthetic ? " pill-active" : ""}`}
            onClick={() => setUseSynthetic(true)}
          >
            Synthetic demo
          </button>
        </div>
      </div>

      {trimmed && (trimmed.trimmedLead > 0 || trimmed.trimmedTail > 0) && (
        <p className="muted" style={{ fontSize: "0.85rem", margin: 0 }}>
          Constant plateaus hidden for readability
          {trimmed.trimmedLead > 0 ? ` · −${trimmed.trimmedLead} leading hours` : ""}
          {trimmed.trimmedTail > 0 ? ` · −${trimmed.trimmedTail} trailing hours` : ""}.
        </p>
      )}

      {!m && <p className="muted">Loading series…</p>}

      {/* Focus band chips */}
      {comps.length > 0 && (
        <div className="pill-row">
          {comps.map((c) => (
            <button
              key={c.name}
              type="button"
              className={`pill${focus === c.name ? " pill-active" : ""}`}
              onClick={() => setFocus(c.name)}
              style={{ borderColor: focus === c.name ? c.color : undefined }}
            >
              {c.name}
            </button>
          ))}
        </div>
      )}

      {/* Hero: focused band + Y overlay */}
      {focusComp && trimmed && (
        <Plot
          height={320}
          data={[
            {
              x: xDates,
              y: trimmed.y,
              type: "scatter",
              mode: "lines",
              name: "Y",
              line: { color: "rgba(26,51,88,0.28)", width: 1.3 },
              hovertemplate: `%{x|%d %b %H:%M}<br>Y: %{y:.3f}<extra></extra>`,
            },
            {
              x: xDates,
              y: focusComp.y,
              type: "scatter",
              mode: "lines",
              name: focusComp.name,
              line: { color: focusComp.color, width: 2 },
              hovertemplate: `%{x|%d %b %H:%M}<br>${focusComp.name}: %{y:.3f}<extra></extra>`,
            },
          ]}
          layout={plotLayout({
            title: {
              text: `Focus · ${focusComp.name} · ${filter.toUpperCase()} · K = ${K}`,
              font: { size: 13 },
            },
            xaxis: { ...dateAxisLayout, title: "Date" },
            yaxis: {
              title: focusComp.name.startsWith("D") ? "detail" : "level",
              zeroline: focusComp.name.startsWith("D"),
              zerolinecolor: "rgba(196,122,58,0.45)",
              gridcolor: "rgba(21,34,56,0.08)",
            },
            legend: { orientation: "h", y: 1.14 },
            margin: { t: 44, r: 14, b: 52, l: 52 },
          })}
        />
      )}

      {/* Compact band stack */}
      <div className="band-stack">
        {comps.map((c) => (
          <button
            key={c.name}
            type="button"
            className={`band-card glass band-card-btn${focus === c.name ? " is-focus" : ""}`}
            onClick={() => setFocus(c.name)}
          >
            <div className="band-label">{c.name}</div>
            <Plot
              height={120}
              data={[
                {
                  x: xDates,
                  y: c.y,
                  type: "scatter",
                  mode: "lines",
                  line: { color: c.color, width: 1.3 },
                  hovertemplate: `%{x|%d %b %H:%M}<br>${c.name}: %{y:.3f}<extra></extra>`,
                },
              ]}
              layout={plotLayout({
                margin: { t: 6, r: 10, b: 36, l: 40 },
                showlegend: false,
                title: undefined,
                xaxis: { ...dateAxisLayout, title: "" },
                yaxis: {
                  zeroline: c.name.startsWith("D"),
                  zerolinecolor: "rgba(196,122,58,0.35)",
                  gridcolor: "rgba(21,34,56,0.06)",
                },
              })}
            />
          </button>
        ))}
      </div>

      {m && trimmed && (
        <div className="row two">
          <Plot
            height={300}
            data={[
              {
                x: en.map((r) => r.component),
                y: en.map((r) => r.share),
                type: "bar",
                name: filter.toUpperCase(),
                marker: {
                  color: en.map((r) => (r.component.startsWith("S") ? COLORS.S : COLORS.bandLine)),
                },
                text: en.map((r) => `${(100 * r.share).toFixed(0)}%`),
                textposition: "outside",
              },
              ...(filter !== "haar"
                ? [
                    {
                      x: haarEnergy.map((r) => r.component),
                      y: haarEnergy.map((r) => r.share),
                      type: "scatter" as const,
                      mode: "lines+markers" as const,
                      name: "Haar ref",
                      line: { color: COLORS.y, width: 1.5, dash: "dot" as const },
                      marker: { size: 6 },
                    },
                  ]
                : []),
            ]}
            layout={plotLayout({
              title: { text: `Energy share · K = ${K}`, font: { size: 13 } },
              yaxis: { title: "Share", tickformat: ".0%", range: [0, 1.08] },
              legend: { orientation: "h", y: 1.14 },
              margin: { t: 44, r: 12, b: 44, l: 52 },
            })}
          />

          <Plot
            height={300}
            data={[
              {
                x: xDates,
                y: trimmed.y,
                type: "scatter",
                mode: "lines",
                name: "Y",
                line: { color: COLORS.y, width: 1.4 },
              },
              {
                x: xDates,
                y: recon,
                type: "scatter",
                mode: "lines",
                name: "Σ bands",
                line: { color: COLORS.yhat, width: 1.6, dash: "dash" },
              },
            ]}
            layout={plotLayout({
              title: {
                text: `Rebuild check · max|Y − Σ| = ${reconErr.toExponential(1)}`,
                font: { size: 13 },
              },
              xaxis: { ...dateAxisLayout, title: "Date" },
              yaxis: { title: "level", gridcolor: "rgba(21,34,56,0.08)" },
              legend: { orientation: "h", y: 1.14 },
              margin: { t: 44, r: 14, b: 52, l: 52 },
            })}
          />
        </div>
      )}

      {buildUp && trimmed && (
        <div className="glass panel">
          <h3>Additive rebuild</h3>
          <p className="muted" style={{ margin: "4px 0 10px", fontSize: "0.9rem" }}>
            Start from S_K, then add D_K … D₁. The dashed line is the full sum (should match Y).
          </p>
          <EqBlock>
            <Katex display tex="Y=\sum_{j=1}^{K}D_j+S_K" />
            <Katex display tex="E_C=\sum_t C_t^2,\quad \mathrm{share}(C)=E_C\big/\sum_{C'}E_{C'}" />
          </EqBlock>
          <Plot
            height={280}
            data={[
              {
                x: xDates,
                y: trimmed.y,
                type: "scatter",
                mode: "lines",
                name: "Y",
                line: { color: "rgba(26,51,88,0.35)", width: 1.2 },
              },
              {
                x: xDates,
                y: m!.S,
                type: "scatter",
                mode: "lines",
                name: `S${K}`,
                line: { color: COLORS.S, width: 1.5 },
              },
              {
                x: xDates,
                y: recon,
                type: "scatter",
                mode: "lines",
                name: "full sum",
                line: { color: COLORS.yhat, width: 1.7 },
              },
            ]}
            layout={plotLayout({
              xaxis: { ...dateAxisLayout, title: "Date" },
              yaxis: { title: "level", gridcolor: "rgba(21,34,56,0.08)" },
              legend: { orientation: "h", y: 1.14 },
              margin: { t: 28, r: 14, b: 52, l: 52 },
            })}
          />
        </div>
      )}

      <Detail title="How to use this page" open>
        <p>
          Pick a filter and K, then click a band chip (or a band card) to focus it against Y. Energy
          bars show where squared amplitude sits; if the filter is not Haar, a dotted Haar reference
          overlays the same K. The rebuild chart checks that summing all bands recovers Y.
        </p>
      </Detail>

      <Detail title="Choosing K">
        <p>
          Larger K peels more short-scale detail and leaves a smoother S_K. An energy elbow (smooth
          share still large, extra Dⱼ nearly empty) often sits near K ≈ 5 on hourly air-quality
          series.
        </p>
      </Detail>

      <p className="muted">
        Next: <Link to="/catboost">CatBoost on each band →</Link>
      </p>
    </div>
  );
}
