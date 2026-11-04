"""Phase 0 data availability audit (read-only on the repo).

Usage: python3 -I data_audit.py <repo_root> <out_dir>
"""
import sys, os, json
import numpy as np
import pandas as pd
import pyarrow.parquet as pq

REPO, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)

POLS = ["PM2.5", "PM10", "NO2", "SO2", "O3", "CO"]
MET = ["AT", "RH"]
# config/preprocess.yaml bounds (canonical units; CO in mg/m3)
BOUNDS = {"PM2.5": (0, 1000), "PM10": (0, 2000), "NO2": (0, 1000), "SO2": (0, 1000),
          "O3": (0, 1000), "CO": (0, 50), "AT": (-10, 50), "RH": (0, 100)}
STUCK_H = 6


def runs(mask):
    """Lengths of True runs."""
    m = np.asarray(mask, bool)
    if not m.any():
        return np.array([], int)
    d = np.diff(np.r_[0, m.astype(int), 0])
    s, e = np.where(d == 1)[0], np.where(d == -1)[0]
    return e - s


def const_runs(x):
    """Lengths of runs of identical consecutive finite values (run length counted in hours)."""
    x = np.asarray(x, float)
    same = np.r_[False, (x[1:] == x[:-1]) & np.isfinite(x[1:]) & np.isfinite(x[:-1])]
    # a run of k identical values -> k-1 consecutive True in `same`
    r = runs(same)
    return r + 1


def linear_runs(x, tol=1e-6):
    """Runs (>=3 points) where the first difference is constant and nonzero: linear interpolation signature."""
    x = np.asarray(x, float)
    d1 = np.diff(x)
    d2 = np.diff(d1)
    lin = np.r_[False, False, (np.abs(d2) <= tol * np.maximum(1, np.abs(x[2:]))) & (np.abs(d1[1:]) > tol)]
    r = runs(lin)
    return r + 2


def series_stats(t, x, var, station, source, unit, scale_note=""):
    t = pd.DatetimeIndex(t)
    x = np.asarray(x, float)
    n = len(x)
    order_ok = bool(t.is_monotonic_increasing)
    dup = int(t.duplicated(keep=False).sum())
    dt = np.diff(t.values).astype("timedelta64[m]").astype(float)
    freq = float(np.median(dt)) if len(dt) else np.nan
    span_h = (t.max() - t.min()) / pd.Timedelta(hours=1)
    expected = int(round(span_h)) + 1
    grid_missing = expected - (n - (dup - int(t.duplicated().sum()) if dup else 0)) if freq == 60 else np.nan
    na = int(np.isnan(x).sum())
    inf = int(np.isinf(x).sum())
    neg = int((x < 0).sum())
    zero = int((x == 0).sum())
    lo, hi = BOUNDS.get(var, (-np.inf, np.inf))
    oob = int(((x < lo) | (x > hi)).sum())
    cr = const_runs(x)
    lr = linear_runs(x)
    return dict(
        station=station, variable=var, source=source, unit=unit,
        start=str(t.min()), end=str(t.max()), n_rows=n,
        median_step_min=freq, n_irregular_steps=int((dt != 60).sum()) if freq == 60 else int((dt != freq).sum()),
        expected_hourly_rows=expected, missing_timestamps=int(grid_missing) if grid_missing == grid_missing else None,
        duplicate_timestamp_rows=dup, monotonic=order_ok,
        na_values=na, inf_values=inf, negative=neg, zeros=zero,
        out_of_bounds=oob, bounds=f"[{lo}, {hi}]",
        pct_missing=round(100 * (na + inf) / n, 3) if n else None,
        n_const_runs_ge6h=int((cr >= STUCK_H).sum()), hours_in_const_runs_ge6h=int(cr[cr >= STUCK_H].sum()),
        max_const_run_h=int(cr.max()) if len(cr) else 0,
        n_linear_runs_ge6h=int((lr >= 6).sum()), hours_in_linear_runs_ge6h=int(lr[lr >= 6].sum()),
        max_linear_run_h=int(lr.max()) if len(lr) else 0,
        min=float(np.nanmin(x)) if n - na else None, median=float(np.nanmedian(x)) if n - na else None,
        max=float(np.nanmax(x)) if n - na else None, note=scale_note,
    )


rows = []
notes = {}

# ---------------------------------------------------------------- CPCB.csv (raw, reference)
cp = pd.read_csv(os.path.join(REPO, "data/raw/CPCB.csv"), dtype={"Datetime": str})
cp = cp.rename(columns={"Ozone": "O3"})
cp["t"] = pd.to_datetime(cp["Datetime"], format="%d-%m-%Y %H:%M")
first, last = cp.iloc[0], cp.iloc[-1]
vals = [c for c in cp.columns if c not in ("Datetime", "t")]
cloned = bool(np.allclose(first[vals].astype(float).values, last[vals].astype(float).values))
notes["cpcb_raw_rows"] = len(cp)
notes["cpcb_last_row_clones_first"] = cloned
notes["cpcb_last_ts"] = str(cp["t"].iloc[-1])
notes["cpcb_second_last_ts"] = str(cp["t"].iloc[-2])
for v in POLS + MET:
    unit = "ug/m3"
    if v == "AT": unit = "degC"
    if v == "RH": unit = "pct"
    x = cp[v].astype(float).values
    xb = x / 1000 if v == "CO" else x  # bounds are in mg/m3 for CO
    r = series_stats(cp["t"], xb, v, "CPCB", "data/raw/CPCB.csv", unit,
                     "CO converted ug/m3->mg/m3 for bounds check only" if v == "CO" else "")
    if v == "CO":
        for k in ("min", "median", "max"):
            r[k] = r[k] * 1000 if r[k] is not None else None
        r["unit"] = "ug/m3 (raw file)"
    rows.append(r)

# ---------------------------------------------------------------- clean store (what the pipeline reads)
st = pq.read_table(os.path.join(REPO, "store/clean/series.parquet")).to_pandas()
st["timestamp"] = pd.to_datetime(st["timestamp"], utc=True).dt.tz_convert("Asia/Kolkata")
store_rows = []
for (stn, v), g in st.groupby(["station", "variable"]):
    g = g.sort_values("timestamp")
    t_naive = g["timestamp"].dt.tz_localize(None)
    unit = {"CO": "mg/m3", "AT": "degC", "RH": "pct"}.get(v, "ug/m3")
    if stn == "ID1" and v == "CO":
        unit = "mg/m3 (config label; magnitudes look like ug/m3/1000 inconsistent - see notes)"
    r = series_stats(t_naive, g["value_filled_causal"].values, v, stn,
                     "store/clean/series.parquet:value_filled_causal", unit)
    r["n_is_masked"] = int(g["is_masked"].sum())
    r["n_is_scorable"] = int(g["is_scorable"].sum())
    r["n_fill_method_nonNA"] = int(g["fill_method"].notna().sum())
    r["raw_equals_filled"] = bool(np.allclose(g["value_hourly_raw"].values, g["value_filled_causal"].values, equal_nan=True))
    store_rows.append(r)
store_df = pd.DataFrame(store_rows)

# ---------------------------------------------------------------- consistency raw CSV vs store (CPCB)
s_cp = st[st.station == "CPCB"].pivot(index="timestamp", columns="variable", values="value_filled_causal")
s_cp.index = s_cp.index.tz_localize(None)
raw_cp = cp.set_index("t")[POLS + MET].astype(float)
raw_cp_c = raw_cp.copy(); raw_cp_c["CO"] = raw_cp_c["CO"] / 1000
common_idx = s_cp.index.intersection(raw_cp_c.index)
diff = (s_cp.loc[common_idx, POLS + MET] - raw_cp_c.loc[common_idx, POLS + MET]).abs().max()
notes["store_vs_raw_maxabs_diff_CPCB"] = {k: float(v) for k, v in diff.items()}
notes["store_cpcb_rows"] = int(len(s_cp))
notes["store_cpcb_start"] = str(s_cp.index.min()); notes["store_cpcb_end"] = str(s_cp.index.max())
notes["raw_rows_not_in_store"] = [str(t) for t in raw_cp_c.index.difference(s_cp.index)]

# ---------------------------------------------------------------- other CPCB-sourced stations (15-min CAAQMS)
def caaqms(path, sid, name):
    t = pq.read_table(os.path.join(REPO, path)).to_pandas()
    t.columns = [c.replace("µ", "u") for c in t.columns]
    t = t[t["Station ID"] == sid].copy()
    ts = pd.to_datetime(t["Timestamp"])
    if ts.dt.tz is not None:
        ts = ts.dt.tz_convert("UTC").dt.tz_localize(None)
    t["ts"] = ts
    out = []
    colmap = {"PM2.5": "PM2.5", "PM10": "PM10", "NO2": "NO2", "SO2": "SO2", "O3": "Ozone", "CO": "CO"}
    for v, pre in colmap.items():
        c = [k for k in t.columns if k.startswith(pre)]
        if not c:
            continue
        x = pd.to_numeric(t[c[0]], errors="coerce").values
        r = dict(station=name, station_id=sid, variable=v, source=path, column=c[0],
                 start=str(t.ts.min()), end=str(t.ts.max()), n_rows_15min=len(t),
                 median_step_min=float(np.median(np.diff(np.sort(t.ts.values)).astype("timedelta64[m]").astype(float))),
                 duplicate_ts=int(t.ts.duplicated(keep=False).sum()),
                 na_15min=int(np.isnan(x).sum()), pct_na_15min=round(100 * np.isnan(x).mean(), 2),
                 negative=int((x < 0).sum()))
        # hourly coverage with >=3/4 slots valid (config min_subhour_coverage 0.75)
        hh = pd.Series(np.isfinite(x), index=t.ts.values).groupby(pd.DatetimeIndex(t.ts.values).floor("h")).sum()
        full = pd.date_range(t.ts.min().floor("h"), t.ts.max().floor("h"), freq="h")
        hh = hh.reindex(full, fill_value=0)
        r["hours_total"] = len(full)
        r["hours_with_ge3_of_4_valid"] = int((hh >= 3).sum())
        r["pct_hours_usable"] = round(100 * (hh >= 3).mean(), 2)
        out.append(r)
    return out

other = []
other += caaqms("data/raw/delhi/cpcb_delhi_2023.parquet", "site_117", "ITO (Delhi)")
other += caaqms("data/raw/delhi/cpcb_delhi_2023.parquet", "site_124", "RK_Puram (Delhi)")
other += caaqms("data/raw/shillong/shillong_15min_2023.parquet", "site_5131", "Lumpyngngad (Shillong)")
other += caaqms("data/raw/shillong/shillong_15min_2023.parquet", "site_5593", "JN_Stadium (Shillong)")
other_df = pd.DataFrame(other)

# ---------------------------------------------------------------- common intersection (CPCB store)
wide = pq.read_table(os.path.join(REPO, "store/clean/wide_CPCB.parquet")).to_pandas()
wide["timestamp"] = pd.to_datetime(wide["timestamp"], utc=True).dt.tz_convert("Asia/Kolkata").dt.tz_localize(None)
wide = wide.sort_values("timestamp").set_index("timestamp")
n_union = len(wide)
fin = np.isfinite(wide[POLS].values)
all_fin = fin.all(axis=1)
inter = []
for v in POLS:
    f = np.isfinite(wide[v].values)
    inter.append(dict(variable=v, n_finite=int(f.sum()), first_finite=str(wide.index[f].min()),
                      last_finite=str(wide.index[f].max()), n_missing_on_union_grid=int((~f).sum()),
                      n_missing_after_alignment=int((~f & all_fin).sum()),
                      pct_missing_after_alignment=0.0))
inter_df = pd.DataFrame(inter)
notes["union_grid_rows"] = n_union
notes["common_all6_rows"] = int(all_fin.sum())
notes["common_pct_retained"] = round(100 * all_fin.mean(), 3)
notes["union_grid_regular_hourly"] = bool((np.diff(wide.index.values).astype("timedelta64[m]").astype(int) == 60).all())

# also rows retained for subsets (if a pollutant had to be dropped)
sub = []
from itertools import combinations
for k in range(2, 7):
    for c in combinations(POLS, k):
        if "PM2.5" not in c:
            continue
        m = np.isfinite(wide[list(c)].values).all(axis=1)
        sub.append(dict(pollutants="+".join(c), k=k, n_common=int(m.sum())))
sub_df = pd.DataFrame(sub)

# ---------------------------------------------------------------- data-quality signatures in CPCB (raw)
# hours where ALL pollutants are simultaneously in a constant run (row-level duplicate of previous hour)
rowdup = np.r_[False, (raw_cp[POLS].values[1:] == raw_cp[POLS].values[:-1]).all(axis=1)]
rd = runs(rowdup) + 1
notes["cpcb_rows_identical_to_previous_hour_all6"] = int(rowdup.sum())
notes["cpcb_row_frozen_runs_ge6h"] = int((rd >= 6).sum())
notes["cpcb_row_frozen_hours_in_runs_ge6h"] = int(rd[rd >= 6].sum())
notes["cpcb_row_frozen_max_run_h"] = int(rd.max()) if len(rd) else 0
# where are frozen runs? list runs >= 24h
d = np.diff(np.r_[0, rowdup.astype(int), 0]); s_, e_ = np.where(d == 1)[0], np.where(d == -1)[0]
frozen = [dict(start=str(raw_cp.index[max(a - 1, 0)]), end=str(raw_cp.index[b - 1]), hours=int(b - a + 1))
          for a, b in zip(s_, e_) if b - a + 1 >= 24]
pd.DataFrame(frozen).to_csv(os.path.join(OUT, "cpcb_frozen_blocks_ge24h.csv"), index=False)
notes["cpcb_frozen_blocks_ge24h"] = len(frozen)
# the value of the first row repeated elsewhere?
fr = raw_cp[POLS].values[0]
same_as_first = (np.abs(raw_cp[POLS].values - fr) < 1e-9).all(axis=1)
notes["cpcb_rows_equal_to_first_row"] = int(same_as_first.sum())
notes["cpcb_rows_equal_to_first_row_ts_sample"] = [str(t) for t in raw_cp.index[same_as_first][:10]]

# per-month missing/constant share for PM2.5 etc on the store grid
mon = []
for v in POLS:
    x = raw_cp[v].values
    same = np.r_[False, x[1:] == x[:-1]]
    dfm = pd.DataFrame({"m": raw_cp.index.to_period("M").astype(str), "same": same})
    for m, g in dfm.groupby("m"):
        mon.append(dict(variable=v, month=m, n=len(g), pct_identical_to_prev_hour=round(100 * g.same.mean(), 1)))
pd.DataFrame(mon).pivot(index="month", columns="variable", values="pct_identical_to_prev_hour").reset_index() \
    .to_csv(os.path.join(OUT, "cpcb_monthly_pct_identical_to_previous_hour.csv"), index=False)

# ---------------------------------------------------------------- write
avail = pd.DataFrame(rows)
avail.to_csv(os.path.join(OUT, "pollutant_availability_cpcb_raw.csv"), index=False)
store_df.to_csv(os.path.join(OUT, "pollutant_availability_clean_store.csv"), index=False)
other_df.to_csv(os.path.join(OUT, "pollutant_availability_other_cpcb_stations.csv"), index=False)


with open(os.path.join(OUT, "data_audit_notes.json"), "w") as f:
    json.dump(notes, f, indent=2, default=str)
pd.set_option("display.width", 250); pd.set_option("display.max_columns", 40)
print(avail.drop(columns=["source", "bounds", "note"]).to_string())
print(store_df[["station", "variable", "start", "end", "n_rows", "missing_timestamps", "na_values", "out_of_bounds", "n_is_masked", "raw_equals_filled", "max_const_run_h"]].to_string())
print(other_df.to_string())
print(inter_df.to_string())
print(json.dumps(notes, indent=1, default=str))
