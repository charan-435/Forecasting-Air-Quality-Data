// Defines shared chart styling.

export const plotLayout = (extra: Record<string, unknown> = {}) => ({
  margin: { t: 36, r: 18, b: 40, l: 48 },
  paper_bgcolor: "rgba(0,0,0,0)",
  plot_bgcolor: "rgba(255,255,255,0.35)",
  font: { family: "Source Sans 3, Segoe UI, sans-serif", size: 11, color: "#152238" },
  xaxis: { gridcolor: "rgba(21,34,56,0.08)", zeroline: false },
  yaxis: { gridcolor: "rgba(21,34,56,0.08)", zeroline: false },
  legend: { orientation: "h", y: 1.12 },
  hovermode: "x unified" as const,
  ...extra,
});

export const plotConfig = {
  responsive: true,
  displaylogo: false,
  modeBarButtonsToRemove: ["lasso2d", "select2d"] as const,
};

export const COLORS = {
  y: "#1a3358",
  yhat: "#2f7a7a",
  band: "rgba(196,122,58,0.25)",
  bandLine: "rgba(196,122,58,0.55)",
  D: ["#c47a3a", "#2f7a7a", "#1a3358", "#6b8f71", "#8a5a12", "#4a6d8c", "#a65b3a", "#3d6b8a"],
  S: "#1a3358",
};
