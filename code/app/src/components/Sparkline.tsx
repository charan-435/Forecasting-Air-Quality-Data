/** Tiny SVG sparkline for MODWT tree nodes. */
export default function Sparkline({
  y,
  color = "#1a3358",
  width = 88,
  height = 28,
  zeroLine = false,
}: {
  y: number[];
  color?: string;
  width?: number;
  height?: number;
  zeroLine?: boolean;
}) {
  if (!y.length) return null;
  const finite = y.map((v) => (Number.isFinite(v) ? v : 0));
  let lo = Math.min(...finite);
  let hi = Math.max(...finite);
  if (hi - lo < 1e-9) {
    lo -= 1;
    hi += 1;
  }
  if (zeroLine) {
    lo = Math.min(lo, 0);
    hi = Math.max(hi, 0);
  }
  const pad = 2;
  const w = width - pad * 2;
  const h = height - pad * 2;
  const pts = finite.map((v, i) => {
    const x = pad + (i / Math.max(1, finite.length - 1)) * w;
    const yy = pad + h - ((v - lo) / (hi - lo)) * h;
    return `${x.toFixed(1)},${yy.toFixed(1)}`;
  });
  const zeroY =
    zeroLine && hi !== lo ? pad + h - ((0 - lo) / (hi - lo)) * h : null;

  return (
    <svg
      className="sparkline"
      width={width}
      height={height}
      viewBox={`0 0 ${width} ${height}`}
      aria-hidden
    >
      {zeroY != null && (
        <line
          x1={pad}
          x2={width - pad}
          y1={zeroY}
          y2={zeroY}
          stroke="rgba(196,122,58,0.45)"
          strokeWidth="1"
          strokeDasharray="2 2"
        />
      )}
      <polyline
        fill="none"
        stroke={color}
        strokeWidth="1.5"
        strokeLinejoin="round"
        strokeLinecap="round"
        points={pts.join(" ")}
      />
    </svg>
  );
}
