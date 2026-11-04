"""Split / mask / feature-dimension computations for the Phase 0 proposal.

Usage: python3 -I split_audit.py <wide_csv> <out_dir>
"""
import sys, os, json
import numpy as np
import pandas as pd

WIDE, OUT = sys.argv[1], sys.argv[2]
w = pd.read_csv(WIDE, index_col=0, parse_dates=True)
P = ["PM2.5", "PM10", "NO2", "SO2", "O3", "CO"]
ALL = P + ["AT", "RH"]
n = len(w)
ts = w.index
W, LAG, HS = 2048, 24, [24, 168, 336, 744]

# ---------------------------------------------------------------- masks
fill_vec = w[ALL].iloc[0].values
is_fill = (np.abs(w[ALL].values - fill_vec) < 1e-9).all(axis=1)
same6 = np.r_[False, (w[P].values[1:] == w[P].values[:-1]).all(axis=1)]
# runs of all-6 identical values: run = the first hour + following identical hours
run_id = np.cumsum(~same6)
run_len = pd.Series(run_id).map(pd.Series(run_id).value_counts()).values
is_copy = same6 & ~is_fill  # hour equals previous hour on all six, not the constant fill
stuck_ge6 = is_copy & (run_len >= 6)
target_bad = is_fill | stuck_ge6
input_flag = is_fill | is_copy

# causal frac of flagged input hours in the trailing 24 h window ending at t (repo policy)
cs = np.r_[0, np.cumsum(input_flag.astype(int))]
frac24 = np.array([(cs[i + 1] - cs[max(0, i - 23)]) / (i - max(0, i - 23) + 1) for i in range(n)])
# hours into a flagged run so far (causal), for in_long_gap (> 72 h)
gap_sofar = np.zeros(n, int)
for i in range(n):
    gap_sofar[i] = (gap_sofar[i - 1] + 1 if i and input_flag[i] else (1 if input_flag[i] else 0))
in_long_gap = gap_sofar > 72
origin_ok = (frac24 <= 0.25) & ~in_long_gap          # evaluation origins (policy.yaml)
train_row_ok = frac24 <= 0.5                           # training rows (policy.yaml)

masks = pd.DataFrame({"row_1based": np.arange(1, n + 1),"timestamp": ts.strftime("%Y-%m-%d %H:%M"), "is_constant_fill": is_fill,
                      "is_all6_repeat_of_previous_hour": is_copy, "is_all6_stuck_run_ge6h": stuck_ge6,
                      "target_scorable": ~target_bad, "input_flagged": input_flag,
                      "frac_flagged_24h": frac24.round(4), "flagged_run_len_sofar": gap_sofar,
                      "eval_origin_allowed": origin_ok, "train_row_allowed": train_row_ok})
masks.to_csv(os.path.join(OUT, "proposed_quality_mask_cpcb.csv"), index=False)

# ---------------------------------------------------------------- decomposition / lag boundaries (0-based rows)
first_comp = W - 1               # valid_warmup: t >= W (1-based)
first_origin_b2 = first_comp + LAG - 1
first_origin_b1 = LAG - 1
info = dict(
    n_rows=n, start=str(ts[0]), end=str(ts[-1]),
    first_valid_component_ts=str(ts[first_comp]), first_valid_component_row_1based=first_comp + 1,
    first_b2_origin_ts=str(ts[first_origin_b2]), first_b2_origin_row_1based=first_origin_b2 + 1,
    first_b1_origin_ts=str(ts[first_origin_b1]),
    rows_lost_to_mra_warmup=int(first_comp), pct_lost_to_mra_warmup=round(100 * first_comp / n, 2),
    constant_fill_rows=int(is_fill.sum()), all6_repeat_rows=int(is_copy.sum()),
    all6_stuck_ge6h_rows=int(stuck_ge6.sum()), target_unscorable_rows=int(target_bad.sum()),
    target_unscorable_pct=round(100 * target_bad.mean(), 2), origins_disallowed=int((~origin_ok).sum()),
    rows_after_warmup=int(n - first_comp),
    target_unscorable_after_warmup=int(target_bad[first_comp:].sum()),
)


def block_counts(name, b0, b1, first_allowed_origin):
    """b0, b1 inclusive 0-based row bounds of a block. Origins and targets must lie in [b0, b1]."""
    out = []
    rule = train_row_ok if name == "train" else origin_ok
    for h in HS:
        o = np.arange(max(b0, first_allowed_origin), b1 - h + 1)
        o_ok = o[rule[o]]
        tgt_ok = o_ok[~target_bad[o_ok + h]]
        out.append(dict(block=name, horizon_h=h, block_start=str(ts[b0]), block_end=str(ts[b1]),
                        block_hours=int(b1 - b0 + 1), row_start_1based=int(b0 + 1), row_end_1based=int(b1 + 1),
                        origin_rule="frac_flagged_24h<=0.5" if name == "train" else "frac_flagged_24h<=0.25 & run<=72h",
                        origins_geometric=int(max(len(o), 0)), origins_after_origin_policy=int(len(o_ok)),
                        samples_scorable_target=int(len(tgt_ok)),
                        first_origin=str(ts[o[0]]) if len(o) else "", last_origin=str(ts[o[-1]]) if len(o) else "",
                        first_target=str(ts[o[0] + h]) if len(o) else "", last_target=str(ts[o[-1] + h]) if len(o) else "",
                        target_hours_in_block_scorable=int((~target_bad[b0:b1 + 1]).sum())))
    return out


def option(name, val_h, test_h):
    te0 = n - test_h
    va0 = te0 - val_h
    rows = []
    rows += block_counts("train", first_comp, va0 - 1, first_origin_b2)
    rows += block_counts("validation", va0, te0 - 1, va0)
    rows += block_counts("test", te0, n - 1, te0)
    df = pd.DataFrame(rows)
    df.insert(0, "option", name)
    return df


opts = pd.concat([
    option("S1_val1488_test1488", 1488, 1488),
    option("S2_val1104_test1488", 1104, 1488),
    option("S3_val1488_test2232", 1488, 2232),
    option("T1like_val336_test744", 336, 744),
], ignore_index=True)
opts.to_csv(os.path.join(OUT, "split_options_sample_counts.csv"), index=False)
rec = opts[opts.option == "S3_val1488_test2232"].drop(columns="option")
rec.to_csv(os.path.join(OUT, "split_proposal_S3_boundaries_and_counts.csv"), index=False)

# monthly scorable-target share
mm = pd.DataFrame({"month": ts.to_period("M").astype(str), "bad": target_bad, "fill": is_fill})
mon = mm.groupby("month").agg(hours=("bad", "size"), constant_fill=("fill", "sum"), unscorable=("bad", "sum"))
mon["pct_scorable"] = (100 * (1 - mon.unscorable / mon.hours)).round(1)
mon.reset_index().to_csv(os.path.join(OUT, "monthly_target_scorability_cpcb.csv"), index=False)

with open(os.path.join(OUT, "split_notes.json"), "w") as f:
    json.dump(info, f, indent=2)
pd.set_option("display.width", 250); pd.set_option("display.max_columns", 30)
print(json.dumps(info, indent=1))
print(mon)
print(opts[["option", "block", "horizon_h", "block_start", "block_end", "block_hours", "origins_geometric",
            "origins_after_origin_policy", "samples_scorable_target"]].to_string())
