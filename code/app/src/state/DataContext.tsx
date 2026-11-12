import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import { loadJson } from "../lib/paths";
import type { Conformal, EdaDecision, Manifest, ScoreRow, Series } from "../lib/types";

type DataState = {
  ready: boolean;
  error: string | null;
  manifest: Manifest | null;
  sensor: string;
  setSensor: (s: string) => void;
  pollutant: string;
  setPollutant: (p: string) => void;
  pollutants: string[];
  series: Series | null;
  seriesMeta: Manifest["datasets"][string]["series"][string] | null;
  scores: ScoreRow[];
  conformal: Conformal | null;
  eda: EdaDecision[];
};

const Ctx = createContext<DataState | null>(null);

function cacheKey(sensor: string, pollutant: string) {
  return `${sensor}::${pollutant}`;
}

export function DataProvider({ children }: { children: ReactNode }) {
  const [manifest, setManifest] = useState<Manifest | null>(null);
  const [sensor, setSensor] = useState("CPCB");
  const [pollutant, setPollutant] = useState("PM2.5");
  // Reuse downloaded series when the reader switches back to a station.
  const [seriesCache, setSeriesCache] = useState<Record<string, Series>>({});
  const [scores, setScores] = useState<ScoreRow[]>([]);
  const [conformal, setConformal] = useState<Conformal | null>(null);
  const [eda, setEda] = useState<EdaDecision[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    // A late response must not update state after a selection change or unmount.
    let cancelled = false;
    (async () => {
      try {
        const m = await loadJson<Manifest>("data/manifest.json");
        const sc = await loadJson<ScoreRow[]>("data/scores.json");
        const cf = await loadJson<Conformal>("data/conformal.json");
        const ed = await loadJson<EdaDecision[]>("data/eda_decisions.json");
        if (cancelled) return;
        setManifest(m);
        setScores(Array.isArray(sc) ? sc : []);
        setConformal(cf);
        setEda(Array.isArray(ed) ? ed : []);
        const keys = Object.keys(m.datasets || {});
        const first = keys.includes("CPCB") ? "CPCB" : keys[0];
        if (first) {
          setSensor(first);
          const def = m.datasets[first]?.default_pollutant ?? m.datasets[first]?.pollutants?.[0];
          if (def) setPollutant(def);
        }
        setReady(true);
      } catch (e) {
        if (!cancelled) setError(e instanceof Error ? e.message : String(e));
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  // Keep pollutant valid when sensor changes
  useEffect(() => {
    const ds = manifest?.datasets[sensor];
    if (!ds) return;
    if (!ds.pollutants.includes(pollutant)) {
      setPollutant(ds.default_pollutant || ds.pollutants[0]);
    }
  }, [manifest, sensor, pollutant]);

  useEffect(() => {
    const meta = manifest?.datasets[sensor]?.series?.[pollutant];
    if (!meta) return;
    const key = cacheKey(sensor, pollutant);
    if (seriesCache[key]) return;
    let cancelled = false;
    loadJson<Series>(`data/${meta.file}`)
      .then((s) => {
        if (!cancelled) {
          setSeriesCache((prev) => (prev[key] ? prev : { ...prev, [key]: s }));
        }
      })
      .catch((e) => {
        if (!cancelled) setError(e instanceof Error ? e.message : String(e));
      });
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [manifest, sensor, pollutant]);

  const setSensorSafe = useCallback((s: string) => setSensor(s), []);
  const setPollutantSafe = useCallback((p: string) => setPollutant(p), []);

  const pollutants = manifest?.datasets[sensor]?.pollutants ?? [];
  const seriesMeta = manifest?.datasets[sensor]?.series?.[pollutant] ?? null;

  const value = useMemo<DataState>(
    () => ({
      ready,
      error,
      manifest,
      sensor,
      setSensor: setSensorSafe,
      pollutant,
      setPollutant: setPollutantSafe,
      pollutants,
      series: seriesCache[cacheKey(sensor, pollutant)] ?? null,
      seriesMeta,
      scores,
      conformal,
      eda,
    }),
    [
      ready,
      error,
      manifest,
      sensor,
      setSensorSafe,
      pollutant,
      setPollutantSafe,
      pollutants,
      seriesCache,
      seriesMeta,
      scores,
      conformal,
      eda,
    ]
  );

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useData() {
  const v = useContext(Ctx);
  if (!v) throw new Error("useData outside provider");
  return v;
}
