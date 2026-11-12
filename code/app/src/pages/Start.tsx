import { Link } from "react-router-dom";
import Logo from "../components/Logo";
import { useData } from "../state/DataContext";

const PILLS = [
  { to: "/data", label: "Datasets", tip: "Boards & series" },
  { to: "/eda", label: "EDA", tip: "Findings → choices" },
  { to: "/modwt", label: "MODWT", tip: "How bands form" },
  { to: "/catboost", label: "CatBoost", tip: "Per-band trees" },
];

const PIPE = [
  { to: "/data", label: "Observed series", short: "y(t)", hint: "Hourly readings" },
  { to: "/modwt", label: "MODWT bands", short: "Dⱼ · S", hint: "Multi-scale split" },
  { to: "/catboost", label: "Per-band trees", short: "CatBoost", hint: "One model each" },
  { to: "/results", label: "Reconstructed ŷ", short: "Σ bands", hint: "Sum forecasts" },
  { to: "/conformal", label: "Interval", short: "PI", hint: "Coverage band" },
];

export default function Start() {
  const { manifest } = useData();
  const paper = manifest?.paper ?? "https://ieeexplore.ieee.org/document/10806566";
  const code = manifest?.paper_code ?? "https://github.com/jborah2/WaveCatBoost-Time-Series-Model";

  return (
    <section className="hero" aria-label="Start">
      <div className="hero-bg" aria-hidden />
      <div className="hero-inner hero-inner--split">
        <div className="hero-copy">
          <div className="kicker">WaveCatBoost Lab</div>
          <div className="hero-brand">
            <Logo size={56} />
            <h1>WaveCatBoost</h1>
          </div>
          <p className="lead" style={{ fontSize: "1.15rem", maxWidth: "36ch" }}>
            From noisy air-quality readings to forecasts you can inspect.
          </p>
          <p className="muted" style={{ margin: 0, maxWidth: "48ch" }}>
            Multi-scale air forecasts — MODWT decomposition, per-band CatBoost, and conformal
            intervals.
          </p>

          <div className="pill-row" style={{ marginTop: 8 }}>
            {PILLS.map((p) => (
              <Link key={p.to} className="pill" to={p.to}>
                <span className="ico" aria-hidden>
                  ◆
                </span>
                <span>
                  {p.label}
                  <div className="muted" style={{ fontSize: "0.75rem", fontWeight: 400 }}>
                    {p.tip}
                  </div>
                </span>
              </Link>
            ))}
          </div>

          <div className="actions">
            <Link className="btn" to="/data">
              Start exploring
            </Link>
            <a className="btn ghost" href={paper} target="_blank" rel="noreferrer">
              Read the paper
            </a>
            <a className="btn ghost" href={code} target="_blank" rel="noreferrer">
              Paper code
            </a>
          </div>
        </div>

        <aside className="hero-pipe" aria-label="WaveCatBoost pipeline">
          <div className="hero-pipe-label">Pipeline</div>
          <ol className="hero-pipe-flow">
            {PIPE.map((s, i) => (
              <li key={s.to} className="hero-pipe-item" style={{ ["--i" as string]: i }}>
                <Link className="hero-pipe-node" to={s.to}>
                  <span className="hero-pipe-idx" aria-hidden>
                    {i + 1}
                  </span>
                  <span className="hero-pipe-text">
                    <span className="hero-pipe-title">{s.label}</span>
                    <span className="hero-pipe-meta">
                      <span className="mono">{s.short}</span>
                      <span className="muted"> · {s.hint}</span>
                    </span>
                  </span>
                </Link>
                {i < PIPE.length - 1 && (
                  <div className="hero-pipe-connector" aria-hidden>
                    <span className="hero-pipe-dot" />
                    <span className="hero-pipe-line" />
                    <span className="hero-pipe-chevron">↓</span>
                  </div>
                )}
              </li>
            ))}
          </ol>
          <svg className="hero-pipe-wave" viewBox="0 0 320 80" aria-hidden>
            <path
              className="hero-pipe-wave-path"
              d="M0 40 C40 10, 80 70, 120 40 S200 10, 240 40 S300 70, 320 40"
              fill="none"
              stroke="currentColor"
              strokeWidth="1.5"
            />
            <path
              className="hero-pipe-wave-path hero-pipe-wave-path--delay"
              d="M0 52 C50 30, 90 74, 140 52 S220 28, 270 52 S310 70, 320 52"
              fill="none"
              stroke="currentColor"
              strokeWidth="1.2"
              opacity="0.45"
            />
          </svg>
        </aside>
      </div>
    </section>
  );
}
