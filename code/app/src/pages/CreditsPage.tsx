// Displays the credits page in the app.

import { useData } from "../state/DataContext";

const TEAM = [
  { name: "Kumar Utkarsh", url: "https://github.com/Kumarutkarsh9470" },
  { name: "M Charan Sree Teja", url: "https://github.com/charan-435" },
  { name: "P Sai Deva Charan 🐐", url: "https://github.com/Charanponaganti" },
  { name: "D Lalit Santosh", url: "https://github.com/lalitdeshmane10-cloud" },
];

export default function CreditsPage() {
  const { manifest } = useData();
  const paper = manifest?.paper ?? "https://ieeexplore.ieee.org/document/10806566";

  return (
    <div className="stack">
      <header>
        <div className="kicker">About</div>
        <h2>Team & credits</h2>
        <p className="lead">Interactive companion for the WaveCatBoost methodology.</p>
      </header>

      <div className="glass panel">
        <h3>Built by</h3>
        <div className="team" style={{ marginTop: 10 }}>
          {TEAM.map((t) => (
            <a key={t.url} href={t.url} target="_blank" rel="noreferrer">
              {t.name}
              <div className="gh">{t.url.replace("https://", "")}</div>
            </a>
          ))}
        </div>
      </div>

      <div className="glass panel">
        <h3>Paper</h3>
        <p style={{ margin: "8px 0" }}>
          J. Borah et al., WaveCatBoost for probabilistic forecasting of multidimensional
          feature-temporal data, <em>IEEE Sensors Letters</em>, 2025.
        </p>
        <a href={paper} target="_blank" rel="noreferrer">
          {paper}
        </a>
        {manifest?.paper_code && (
          <p className="muted" style={{ marginTop: 10 }}>
            Author code:{" "}
            <a href={manifest.paper_code} target="_blank" rel="noreferrer">
              jborah2/WaveCatBoost-Time-Series-Model
            </a>
          </p>
        )}
      </div>
    </div>
  );
}
