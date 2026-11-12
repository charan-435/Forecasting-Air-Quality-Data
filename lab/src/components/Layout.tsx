import { NavLink, Outlet, useLocation } from "react-router-dom";
import Logo from "./Logo";
import PageTransition from "./PageTransition";
import { useData } from "../state/DataContext";

const LINKS = [
  { to: "/", label: "Start", end: true },
  { to: "/data", label: "Data" },
  { to: "/eda", label: "EDA" },
  { to: "/modwt", label: "MODWT" },
  { to: "/playground", label: "Playground" },
  { to: "/catboost", label: "CatBoost" },
  { to: "/results", label: "Results" },
  { to: "/conformal", label: "Conformal" },
  { to: "/extensions", label: "Extensions" },
  { to: "/credits", label: "About" },
];

export default function Layout() {
  const { sensor, setSensor, pollutant, setPollutant, pollutants, manifest, ready, error } =
    useData();
  const loc = useLocation();
  const isStart = loc.pathname === "/";
  const isAbout = loc.pathname === "/credits";
  const showContext = !isStart && !isAbout;
  const sensors = manifest ? Object.keys(manifest.datasets) : [];

  return (
    <div className={`app-shell${isStart ? " app-shell--home" : ""}`}>
      <header className="topnav">
        <NavLink to="/" className="brand" end>
          <Logo size={30} />
          WaveCatBoost
        </NavLink>
        <nav className="nav-links" aria-label="Learning path">
          {LINKS.map((l) => (
            <NavLink
              key={l.to}
              to={l.to}
              end={l.end}
              className={({ isActive }) => (isActive ? "active" : undefined)}
            >
              {l.label}
            </NavLink>
          ))}
        </nav>
      </header>

      {showContext && (
        <div className="context-bar">
          <label className="field">
            Dataset
            <select value={sensor} onChange={(e) => setSensor(e.target.value)} disabled={!ready}>
              {sensors.map((s) => (
                <option key={s} value={s}>
                  {s}
                </option>
              ))}
            </select>
          </label>
          <label className="field">
            Pollutant
            <select
              value={pollutant}
              onChange={(e) => setPollutant(e.target.value)}
              disabled={!ready || pollutants.length === 0}
            >
              {pollutants.map((p) => (
                <option key={p} value={p}>
                  {p}
                </option>
              ))}
            </select>
          </label>
        </div>
      )}

      <main className={`page${isStart ? " page--home" : ""}`}>
        {error && (
          <div className="glass panel" style={{ marginBottom: 14, borderColor: "rgba(196,122,58,0.4)" }}>
            <strong>Data load issue.</strong> <span className="muted">{error}</span>
          </div>
        )}
        <PageTransition>
          <Outlet />
        </PageTransition>
      </main>
    </div>
  );
}
