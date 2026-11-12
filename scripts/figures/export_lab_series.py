"""Export hourly series JSON for WaveCatBoost Lab (all pollutants).

Run from repo root:
  python scripts/figures/export_lab_series.py
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "lab" / "public" / "data"
N_KEEP = 24 * 21
POLLUTANTS = ["PM2.5", "PM10", "NO2", "O3", "CO", "SO2"]

UNITS = {
    "PM2.5": "µg/m³ (as recorded; verify station docs)",
    "PM10": "µg/m³ (as recorded; verify station docs)",
    "NO2": "µg/m³ (as recorded; verify station docs)",
    "O3": "µg/m³ (as recorded; verify station docs)",
    "SO2": "µg/m³ (as recorded; verify station docs)",
    "CO": "as recorded (verify station docs; often mg/m³ or µg/m³)",
}


def safe_name(sensor: str, pollutant: str) -> str:
    return f"series_{sensor}_{pollutant.replace('.', '_')}.json"


def pack(sensor: str, pollutant: str, times: list[str], y: list[float]) -> dict:
    n = len(y)
    i0 = max(0, n - N_KEEP)
    yy = y[i0:]
    tt = times[i0:]
    finite = [v for v in yy if v is not None and math.isfinite(v)]
    return {
        "sensor": sensor,
        "pollutant": pollutant,
        "n_full": n,
        "t0": tt[0] if tt else "",
        "t1": tt[-1] if tt else "",
        "freq": "hourly",
        "units": UNITS.get(pollutant, "as recorded"),
        "t": tt,
        "y": [None if v is None or not math.isfinite(v) else round(float(v), 4) for v in yy],
        "stats": {
            "mean": round(sum(finite) / len(finite), 3) if finite else None,
            "sd": round(float(pd.Series(finite).std(ddof=1)), 3) if len(finite) > 1 else None,
            "min": round(min(finite), 3) if finite else None,
            "max": round(max(finite), 3) if finite else None,
        },
    }


def normalize_cols(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    if "Ozone" in df.columns and "O3" not in df.columns:
        df = df.rename(columns={"Ozone": "O3"})
    if "Datetime" not in df.columns:
        # ID1 sometimes has Datetime after an index col
        for c in df.columns:
            if "date" in c.lower() or "time" in c.lower():
                df = df.rename(columns={c: "Datetime"})
                break
    return df


def series_from_csv(path: Path, sensor: str) -> dict[str, dict]:
    df = pd.read_csv(path)
    df = normalize_cols(df)
    if "Datetime" not in df.columns:
        raise SystemExit(f"{path}: no Datetime column ({list(df.columns)})")
    times = df["Datetime"].astype(str).tolist()
    out: dict[str, dict] = {}
    for pol in POLLUTANTS:
        if pol not in df.columns:
            continue
        y = pd.to_numeric(df[pol], errors="coerce")
        # light interpolate for teaching plots (not scored bake-off features)
        y = y.interpolate(limit_direction="both")
        out[pol] = pack(sensor, pol, times, y.tolist())
        print(f"packed {sensor} {pol} n={out[pol]['n_full']}")
    return out


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    sources = {
        "CPCB": ROOT / "data" / "raw" / "CPCB.csv",
        "ID1": ROOT / "data" / "raw" / "ID1.csv",
        "SHILLONG": ROOT / "data" / "processed" / "SHILLONG.csv",
    }

    datasets: dict[str, dict] = {}
    for sensor, path in sources.items():
        if not path.exists():
            print(f"skip missing {path}")
            continue
        series = series_from_csv(path, sensor)
        if not series:
            continue
        for pol, payload in series.items():
            fname = safe_name(sensor, pol)
            (OUT / fname).write_text(json.dumps(payload, indent=2), encoding="utf-8")
        pols = [p for p in POLLUTANTS if p in series]
        datasets[sensor] = {
            "sensor": sensor,
            "default_pollutant": "PM2.5" if "PM2.5" in series else pols[0],
            "pollutants": pols,
            "series": {
                pol: {
                    "sensor": sensor,
                    "pollutant": pol,
                    "n_full": series[pol]["n_full"],
                    "t0": series[pol]["t0"],
                    "t1": series[pol]["t1"],
                    "freq": series[pol]["freq"],
                    "units": series[pol]["units"],
                    "stats": series[pol]["stats"],
                    "file": safe_name(sensor, pol),
                }
                for pol in pols
            },
        }

    # Merge into existing manifest if present; else write a stub.
    man_path = OUT / "manifest.json"
    if man_path.exists():
        manifest = json.loads(man_path.read_text(encoding="utf-8"))
    else:
        manifest = {
            "app": "WaveCatBoost Lab",
            "paper": "https://ieeexplore.ieee.org/document/10806566",
            "paper_code": "https://github.com/jborah2/WaveCatBoost-Time-Series-Model",
            "links": {
                "cpcb": "https://cpcb.nic.in/",
                "caaqms": "https://airquality.cpcb.gov.in/ccr/#/caaqm-dashboard-all/caaqm-landing",
            },
            "scores_file": "scores.json",
            "conformal_file": "conformal.json",
            "eda_decisions_file": "eda_decisions.json",
            "modwt_fixture_file": "modwt_haar_fixture.json",
            "notes": {
                "id1": "ID1 is a station series from the paper release — not a separate pollution board.",
                "scores": "results/paper/scores.csv are our recursive bake-off scores, not paper Table 1 rolling 1-step.",
            },
        }
    manifest["datasets"] = datasets
    manifest["notes"] = {
        **manifest.get("notes", {}),
        "series": "Hourly windows (last ~21 days) for PM2.5/PM10/NO2/O3/CO/SO2 from raw/processed CSVs. CPCB Ozone renamed to O3.",
    }
    man_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"Wrote {man_path} with {len(datasets)} sensors")


if __name__ == "__main__":
    main()
