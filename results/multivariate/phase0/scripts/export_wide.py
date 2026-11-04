"""Export CPCB value_filled_causal from store/clean to a wide CSV used by the
other Phase 0 scripts.  Usage: python3 export_wide.py <repo_root> <out_csv>"""
import sys
import pandas as pd
import pyarrow.parquet as pq

repo, out = sys.argv[1], sys.argv[2]
st = pq.read_table(f"{repo}/store/clean/series.parquet").to_pandas()
st = st[st.station == "CPCB"].copy()
st["ts"] = pd.to_datetime(st.timestamp, utc=True).dt.tz_convert("Asia/Kolkata").dt.strftime("%Y-%m-%d %H:%M")
st.pivot(index="ts", columns="variable", values="value_filled_causal").sort_index().to_csv(out)
