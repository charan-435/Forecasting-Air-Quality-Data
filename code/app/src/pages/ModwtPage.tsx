import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import Detail from "../components/Detail";
import Katex, { EqBlock } from "../components/Katex";
import Plot from "../components/Plot";
import Sparkline from "../components/Sparkline";
import { haarStep, mra, reconstruct, maxAbsDiff } from "../lib/modwt";
import { COLORS, plotLayout } from "../lib/plotlyTheme";
import { useData } from "../state/DataContext";

type Frame = {
  id: string;
  label: string;
  kind: "X" | "W" | "V";
  j: number;
  s: number | null;
  y: number[];
  overlay?: number[];
  overlayName?: string;
  blurb: string;
};

const TREE_STEPS = [
  { k: 0, title: "S₀ = Yₜ", note: "Start from the observed series. Every later band is filtered from the previous smooth." },
  { k: 1, title: "Split S₀ → D₁, S₁", note: "Wavelet taps pₘ peel short-scale change into D₁; scaling taps qₘ average into S₁." },
  { k: 2, title: "Split S₁ → D₂, S₂", note: "Only S₁ is split again. D₂ sees a coarser dilation (s = 2)." },
  { k: 3, title: "Split S₂ → D₃, S₃", note: "Scale doubles again (s = 4). Intermediate smooths are dashed — they will be split further." },
  { k: 4, title: "Split S₃ → D₄, S₄", note: "Final level. Reconstruct: Y = D₁ + D₂ + D₃ + D₄ + S₄." },
];

/** Multi-scale teaching signal: trend + daily + slow cycle + spike + noise. */
function makeSynthetic(n = 192): number[] {
  return Array.from({ length: n }, (_, i) => {
    const t = i / n;
    const hours = i; // treat index as hour
    const trend = 12 + 6 * t;
    const daily = 3.2 * Math.sin((2 * Math.PI * hours) / 24);
    const slow = 2.4 * Math.sin((2 * Math.PI * hours) / 48 + 0.4);
    const burst = 1.1 * Math.sin((2 * Math.PI * hours) / 8) * Math.exp(-((hours - 140) ** 2) / 400);
    const spike = hours === 96 ? 9 : hours === 97 ? 4 : 0;
    const noise = 0.35 * Math.sin(2 * Math.PI * hours * 0.37 + 1.7);
    return trend + daily + slow + burst + spike + noise;
  });
}

export default function ModwtPage() {
  const { series, sensor, pollutant } = useData();
  const [step, setStep] = useState(0);
  const [playing, setPlaying] = useState(false);
  const [useReal, setUseReal] = useState(false);
  const [treeStep, setTreeStep] = useState(0);
  const [treePlaying, setTreePlaying] = useState(false);

  const teach = useMemo(() => makeSynthetic(192), []);

  const y = useMemo(() => {
    if (useReal && series?.y?.length) {
      const raw = series.y;
      return raw.length > 192 ? raw.slice(-192) : raw.slice();
    }
    return teach;
  }, [useReal, series, teach]);

  const frames = useMemo<Frame[]>(() => {
    const out: Frame[] = [
      {
        id: "S0",
        label: "S₀ = Y",
        kind: "X",
        j: 0,
        s: null,
        y: y.slice(),
        blurb: "Observed series (trend + daily cycle + slow wave + local burst + spike). Each MODWT level filters the previous smooth.",
      },
    ];
    let V = y.slice();
    for (let j = 1; j <= 4; j++) {
      const s = haarStep(V, j);
      out.push({
        id: `D${j}`,
        label: `D${j}`,
        kind: "W",
        j,
        s: s.s,
        y: s.W,
        overlay: V.slice(),
        overlayName: `S${j - 1}`,
        blurb: `Detail at dilation s = ${s.s}. Haar p = (½, −½) highlights change; the spike / burst light up here.`,
      });
      out.push({
        id: `S${j}`,
        label: `S${j}`,
        kind: "V",
        j,
        s: s.s,
        y: s.V,
        overlay: V.slice(),
        overlayName: `S${j - 1}`,
        blurb: `Smooth at dilation s = ${s.s}. Haar q = (½, ½) averages neighbours; sharp events are attenuated.`,
      });
      V = s.V;
    }
    return out;
  }, [y]);

  /** Precompute Haar pyramid pieces for tree sparklines (same y as scrubber). */
  const treeSeries = useMemo(() => {
    const Slevels: number[][] = [y.slice()];
    const Dlevels: number[][] = [];
    let V = y.slice();
    for (let j = 1; j <= 4; j++) {
      const s = haarStep(V, j);
      Dlevels.push(s.W);
      Slevels.push(s.V);
      V = s.V;
    }
    return { Slevels, Dlevels };
  }, [y]);

  useEffect(() => {
    setStep(0);
    setPlaying(false);
  }, [useReal, y]);

  useEffect(() => {
    if (!playing) return;
    const id = window.setInterval(() => {
      setStep((s) => {
        if (s + 1 >= frames.length) {
          setPlaying(false);
          return s;
        }
        return s + 1;
      });
    }, 900);
    return () => clearInterval(id);
  }, [playing, frames.length]);

  useEffect(() => {
    if (!treePlaying) return;
    const id = window.setInterval(() => {
      setTreeStep((s) => {
        if (s + 1 >= TREE_STEPS.length) {
          setTreePlaying(false);
          return s;
        }
        return s + 1;
      });
    }, 1200);
    return () => clearInterval(id);
  }, [treePlaying]);

  const fr = frames[Math.min(step, frames.length - 1)];
  const mraRec = useMemo(() => mra(y, 4, "haar"), [y]);
  const reconErr = useMemo(() => maxAbsDiff(y, reconstruct(mraRec)), [y, mraRec]);
  const eqActive = fr.kind === "W" ? "D" : fr.kind === "V" ? "S" : "Y";

  const eventIdx = useMemo(() => {
    if (useReal) return -1;
    return 96; // synthetic spike hour
  }, [useReal]);

  const traces = useMemo(() => {
    const x = y.map((_, i) => i);
    const t: object[] = [];
    if (fr.overlay) {
      t.push({
        x,
        y: fr.overlay,
        type: "scatter",
        mode: "lines",
        name: fr.overlayName,
        line: { color: "rgba(26,51,88,0.3)", width: 1.5 },
      });
    }
    t.push({
      x,
      y: fr.y,
      type: "scatter",
      mode: "lines",
      name: fr.label,
      line: { color: fr.kind === "W" ? COLORS.bandLine : COLORS.y, width: 2.2 },
    });
    if (eventIdx >= 0 && eventIdx < y.length) {
      t.push({
        x: [eventIdx],
        y: [fr.y[eventIdx]],
        type: "scatter",
        mode: "markers",
        name: "spike",
        marker: { size: 9, color: "#c47a3a", symbol: "diamond" },
      });
    }
    return t;
  }, [fr, y, eventIdx]);

  const k = treeStep;

  return (
    <div className="stack">
      <header>
        <div className="kicker">MODWT</div>
        <h2>How is a component formed?</h2>
        <p className="lead">
          Maximal overlap DWT keeps every time index. Detail filters pₘ build Dⱼ; scaling filters qₘ
          build Sⱼ.
        </p>
      </header>

      <div className="glass panel">
        <h3>General recursion</h3>
        <p className="muted" style={{ margin: "4px 0 10px", fontSize: "0.9rem" }}>
          Wavelet taps pₘ extract change (Σ pₘ = 0). Scaling taps qₘ extract averages (Σ qₘ = 1).
          Initialize S₀,ₜ = Yₜ.
        </p>
        <EqBlock>
          <Katex display tex="D_{j,t}=\sum_{m}p_m\,S_{j-1,(t-2^{j-1}m)\bmod N}" />
          <Katex display tex="S_{j,t}=\sum_{m}q_m\,S_{j-1,(t-2^{j-1}m)\bmod N}" />
          <Katex display tex="Y_t=\sum_{j=1}^{K}D_{j,t}+S_{K,t}" />
        </EqBlock>
      </div>

      <div className="glass panel">
        <h3>Haar filters (used here)</h3>
        <p className="muted" style={{ margin: "4px 0 10px", fontSize: "0.9rem" }}>
          This Lab uses Haar. Longer filters (D4, LA8) change only (pₘ, qₘ).
        </p>
        <EqBlock>
          <Katex display tex="p=\bigl(\tfrac12,-\tfrac12\bigr),\qquad q=\bigl(\tfrac12,\tfrac12\bigr)" />
          <Katex display tex="D_{j,t}=\tfrac12\bigl(S_{j-1,t}-S_{j-1,t-s}\bigr),\quad s=2^{j-1}" />
          <Katex display tex="S_{j,t}=\tfrac12\bigl(S_{j-1,t}+S_{j-1,t-s}\bigr)" />
        </EqBlock>
      </div>

      {/* Richer decomposition tree with sparklines */}
      <div className="glass panel modwt-tree-panel">
        <div className="modwt-stage-top">
          <div>
            <h3>Decomposition tree (K = 4)</h3>
            <p className="muted" style={{ margin: "4px 0 0", fontSize: "0.9rem" }}>
              {TREE_STEPS[k].note}
            </p>
          </div>
          <div className="pill-row">
            <button type="button" className="btn" onClick={() => setTreePlaying((p) => !p)}>
              {treePlaying ? "Pause" : "Play tree"}
            </button>
            <button
              type="button"
              className="btn ghost"
              onClick={() => {
                setTreePlaying(false);
                setTreeStep((s) => Math.min(s + 1, TREE_STEPS.length - 1));
              }}
            >
              Next
            </button>
            <button
              type="button"
              className="btn ghost"
              onClick={() => {
                setTreePlaying(false);
                setTreeStep(0);
              }}
            >
              Reset
            </button>
          </div>
        </div>

        <div className="modwt-tree modwt-tree--rich" aria-label="MODWT decomposition tree">
          <div className={`modwt-tree-node root wide${k >= 0 ? " on" : ""}`}>
            <div className="modwt-tree-node-head">
              <span>Yₜ ≡ S₀</span>
              <small>observed</small>
            </div>
            <Sparkline y={treeSeries.Slevels[0]} color={COLORS.y} width={120} height={32} />
          </div>

          {[1, 2, 3, 4].map((level) => (
            <div key={level} className={`modwt-tree-level${k >= level ? " on" : ""}`}>
              <div className="modwt-tree-connector" aria-hidden>
                <span className="modwt-tree-fork" />
              </div>
              <div className="modwt-tree-branch">
                <div className={`modwt-tree-node detail wide${k >= level ? " on" : ""}`}>
                  <div className="modwt-tree-node-head">
                    <span>D{level}</span>
                    <small>
                      pₘ · s = {1 << (level - 1)}
                    </small>
                  </div>
                  <Sparkline
                    y={treeSeries.Dlevels[level - 1]}
                    color="#c47a3a"
                    width={110}
                    height={30}
                    zeroLine
                  />
                </div>
                <div
                  className={`modwt-tree-node smooth wide${k >= level ? " on" : ""}${
                    level < 4 && k > level ? " split" : ""
                  }`}
                >
                  <div className="modwt-tree-node-head">
                    <span>S{level}</span>
                    <small>qₘ{level < 4 ? " · split next" : " · residual"}</small>
                  </div>
                  <Sparkline
                    y={treeSeries.Slevels[level]}
                    color={COLORS.y}
                    width={110}
                    height={30}
                  />
                </div>
              </div>
            </div>
          ))}
        </div>

        <div className="modwt-tree-legend">
          <span>
            <i className="swatch detail" /> Detail Dⱼ (change)
          </span>
          <span>
            <i className="swatch smooth" /> Smooth Sⱼ (average)
          </span>
          <span>Dashed border = intermediate smooth that will be split again</span>
        </div>
        <p className="takeaway" style={{ marginTop: 12 }}>
          Only the smooth is split at each level. After K = 4:{" "}
          <Katex tex="Y=D_1+D_2+D_3+D_4+S_4" />.
        </p>
      </div>

      {/* Signal scrubber */}
      <div className="modwt-stage glass panel">
        <div className="modwt-stage-top">
          <div className="modwt-now">
            <div className="modwt-now-kicker">
              Step {step + 1} / {frames.length}
              {fr.s != null && (
                <span className="badge recorded" style={{ marginLeft: 8 }}>
                  s = {fr.s}
                </span>
              )}
              {!useReal && (
                <span className="badge recorded" style={{ marginLeft: 8 }}>
                  synthetic · n = {y.length}
                </span>
              )}
            </div>
            <h3 className="modwt-now-title">{fr.label}</h3>
            <p className="modwt-now-blurb">{fr.blurb}</p>
          </div>
          <div className="modwt-controls">
            <div className="pill-row">
              <button type="button" className="btn" onClick={() => setPlaying((p) => !p)}>
                {playing ? "Pause" : "Play"}
              </button>
              <button
                type="button"
                className="btn ghost"
                onClick={() => {
                  setPlaying(false);
                  setStep((s) => Math.min(s + 1, frames.length - 1));
                }}
              >
                Next
              </button>
              <button
                type="button"
                className="btn ghost"
                onClick={() => {
                  setStep(0);
                  setPlaying(false);
                }}
              >
                Reset
              </button>
            </div>
            <div className="pill-row" style={{ marginTop: 8 }}>
              <button
                type="button"
                className={`pill${!useReal ? " pill-active" : ""}`}
                onClick={() => setUseReal(false)}
              >
                Synthetic
              </button>
              <button
                type="button"
                className={`pill${useReal ? " pill-active" : ""}`}
                onClick={() => setUseReal(true)}
                disabled={!series?.y?.length}
              >
                {sensor} · {pollutant}
              </button>
            </div>
          </div>
        </div>

        {!useReal && (
          <p className="muted" style={{ fontSize: "0.85rem", margin: 0 }}>
            Synthetic mix: slow trend + 24-step daily sine + 48-step envelope + local burst + diamond
            spike at t = 96 + light high-frequency ripple — so Dⱼ and Sⱼ separate visibly.
          </p>
        )}

        <ol className="modwt-chips" aria-label="Pyramid steps">
          {frames.map((f, i) => (
            <li key={f.id}>
              <button
                type="button"
                className={`modwt-chip${i === step ? " is-active" : ""}${f.kind === "W" ? " is-w" : " is-v"}`}
                onClick={() => {
                  setPlaying(false);
                  setStep(i);
                }}
              >
                {f.label}
              </button>
              {i < frames.length - 1 && <span className="modwt-chip-arrow" aria-hidden />}
            </li>
          ))}
        </ol>

        <input
          type="range"
          min={0}
          max={frames.length - 1}
          value={step}
          onChange={(e) => {
            setPlaying(false);
            setStep(Number(e.target.value));
          }}
          className="modwt-scrub"
          aria-label="Scrub pyramid"
        />

        <div className="row two" style={{ marginTop: 4 }}>
          <div>
            <div className={`modwt-eq${eqActive === "Y" ? " is-on" : ""}`}>
              <Katex display tex="S_{0,t}=Y_t" />
            </div>
            <div className={`modwt-eq${eqActive === "D" ? " is-on" : ""}`}>
              <Katex display tex="D_{j,t}=\sum_m p_m S_{j-1,t-2^{j-1}m}" />
            </div>
            <div className={`modwt-eq${eqActive === "S" ? " is-on" : ""}`}>
              <Katex display tex="S_{j,t}=\sum_m q_m S_{j-1,t-2^{j-1}m}" />
            </div>
          </div>
          <Plot
            height={360}
            data={traces}
            layout={plotLayout({
              showlegend: true,
              legend: { orientation: "h", y: 1.18 },
              margin: { t: 36, r: 14, b: 44, l: 52 },
              yaxis: {
                title: fr.kind === "W" ? "detail" : "level",
                zeroline: fr.kind === "W",
                zerolinecolor: "rgba(196,122,58,0.5)",
                zerolinewidth: 1,
                gridcolor: "rgba(21,34,56,0.08)",
              },
              xaxis: {
                title: "t (index)",
                gridcolor: "rgba(21,34,56,0.08)",
                nticks: 8,
              },
            })}
          />
        </div>
        <p className="muted" style={{ fontSize: "0.85rem", margin: "8px 0 0" }}>
          Additive reconstruction error: {reconErr.toExponential(2)}.{" "}
          <Link to="/playground">Playground →</Link>
        </p>
      </div>

      <Detail title="Dⱼ versus forecasting components">
        <p>
          The recursion produces detail and smooth series Dⱼ, Sⱼ. Additive MRA satisfies Y = Σⱼ Dⱼ +
          S_K. WaveCatBoost fits one model per component, then sums the forecasts.
        </p>
      </Detail>
    </div>
  );
}
