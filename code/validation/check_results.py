"""Check saved experiment values and the app bundle without retraining models.

Run from any directory: python code/validation/check_results.py
"""
from pathlib import Path
import csv
import json
import math

ROOT = Path(__file__).resolve().parents[2]
METRICS = ("MASE", "MAE", "RMSE")
KEY_COLUMNS = ("sensor", "pollutant", "horizon", "method")


def read_csv(relative_path):
    with (ROOT / relative_path).open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def read_json(relative_path):
    return json.loads((ROOT / relative_path).read_text(encoding="utf-8-sig"))


def score_key(row):
    return tuple(row[column] for column in KEY_COLUMNS)


def check_equal(actual, expected, label):
    if not math.isclose(float(actual), float(expected), abs_tol=1e-9, rel_tol=0):
        raise AssertionError(f"{label}: {actual} != {expected}")


def main():
    rows = read_csv("results/paper/scores.csv")
    scores = {score_key(row): row for row in rows}
    assert len(scores) == len(rows), "Duplicate experiment keys in scores.csv"
    comparisons = 0

    # The app must display the saved values, not rounded or simulated replacements.
    app_rows = read_json("code/app/public/data/scores.json")
    assert {score_key(row) for row in app_rows} == set(scores)
    for row in app_rows:
        key = score_key(row)
        for metric in METRICS:
            check_equal(row[metric], scores[key][metric], f"App {key} {metric}")
            comparisons += 1

    # A second format is useful for inspection, but must mirror the same run.
    for row in read_csv("results/paper/mase_wide.csv"):
        for method, value in row.items():
            if method in KEY_COLUMNS or value in ("", "NA"):
                continue
            key = (row["sensor"], row["pollutant"], row["horizon"], method)
            check_equal(value, scores[key]["MASE"], f"Wide MASE {key}")
            comparisons += 1

    # Resolve every dataset choice before a reader hits a missing asset in the UI.
    app_data = ROOT / "code/app/public/data"
    manifest = read_json("code/app/public/data/manifest.json")
    series_count = 0
    for dataset in manifest["datasets"].values():
        for pollutant, metadata in dataset["series"].items():
            path = app_data / metadata["file"]
            assert path.is_file(), f"Missing series file: {path}"
            series = json.loads(path.read_text(encoding="utf-8-sig"))
            assert len(series["t"]) == len(series["y"]) > 0
            assert series["pollutant"] == pollutant
            series_count += 1

    # docs/ intentionally has no editable sources, intermediate figures or archives.
    documents = ROOT / "docs"
    expected = {"report.pdf", "presentation.pdf", "research_paper.pdf"}
    assert {path.name for path in documents.iterdir()} == expected
    for name in expected:
        with (documents / name).open("rb") as handle:
            assert handle.read(5) == b"%PDF-", f"Invalid PDF header: {name}"

    print(f"PASS: {comparisons} recorded numeric comparisons; {series_count} app series; 3 final PDFs.")


if __name__ == "__main__":
    main()
