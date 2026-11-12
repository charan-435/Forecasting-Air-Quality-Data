"""Draw comparison figures from saved results; no models are fitted.

Run from anywhere:
    python code/figures/make_comparison_figures.py --rscript "path/to/Rscript.exe"

Python needs numpy, pandas and matplotlib. R uses base packages only.
"""
from pathlib import Path
import argparse
import os
import shutil
import subprocess
import tempfile
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rscript', default=shutil.which('Rscript'), help='Rscript executable; required when R is not on PATH')
    args = parser.parse_args()
    if not args.rscript:
        parser.error('Rscript was not found. Pass --rscript with its full path.')
    root = Path(__file__).resolve().parents[2]
    out = Path(os.environ.get('ATS_FIGURE_DIR', root / 'results' / 'figures')) / 'comparison'
    figs = out
    figs.mkdir(parents=True, exist_ok=True)
    # Read saved R arrays through a small base-R exporter, without loading models.
    conf = {}
    # Keep temporary CSVs beside the outputs so R and Python share a writable path.
    with tempfile.TemporaryDirectory(prefix='.asset-tmp-', dir=out) as temporary:
        subprocess.run([args.rscript, str(root / 'code/figures/export_conformal_cache.R'), str(root / 'results/paper/conformal.rds'), temporary], check=True, cwd=root)
        for sensor in ['CPCB', 'ID1', 'SHILLONG']:
            data = pd.read_csv(Path(temporary) / f'{sensor}.csv').to_dict('list')
            data.update(pd.read_csv(Path(temporary) / f'{sensor}_meta.csv').iloc[0].to_dict())
            data['kappa'] = int(data['kappa'])
            conf[sensor] = data
    plt.rcParams.update({'font.family': 'serif', 'font.size': 9, 'axes.spines.top': False, 'axes.spines.right': False, 'pdf.fonttype': 42})
    # Each bar compares a saved score for the same sensor, pollutant and horizon.
    colors = ['#435889', '#8a9fc3', '#c1c9d9']
    filters = ['haar', 'd4', 'la8']
    labels = ['Haar', 'D4', 'LA8']
    scores = pd.read_csv(root / 'results/extensions/filter_scores.csv')
    scores.to_csv(out / 'filter_scores.csv', index=False)
    fig, axes = plt.subplots(1, 2, figsize=(6.65, 2.25), sharey=True)
    for ax, sensor in zip(axes, ['CPCB', 'ID1']):
        for j, filt in enumerate(filters):
            a = scores[(scores.sensor == sensor) & (scores.pollutant == 'PM2.5') & (scores['filter'] == filt)].set_index('method')
            vals = [a.loc[m, 'MASE'] for m in ['wavelgb', 'wavecatboost']]
            bars = ax.bar(np.arange(2) + (j - 1) * 0.24, vals, width=0.23, color=colors[j], label=labels[j])
            ax.bar_label(bars, labels=[f'{v:.3f}' for v in vals], fontsize=7, padding=2)
        ax.set_xticks([0, 1], ['WaveLGB', 'WaveCatBoost'])
        ax.set_title(sensor, fontsize=10)
        ax.set_ylim(0, 1.43)
        ax.grid(axis='y', alpha=0.17)
        ax.set_axisbelow(True)
    axes[0].set_ylabel('MASE (lower is better)')
    fig.legend(*axes[0].get_legend_handles_labels(), ncol=3, frameon=False, loc='upper center', bbox_to_anchor=(0.53, 1.04))
    fig.tight_layout(rect=[0, 0, 1, 0.92], pad=0.5)
    fig.savefig(figs / 'filter_pm25_bars.pdf')
    plt.close(fig)
    pols = ['PM2.5', 'PM10', 'NO2', 'O3', 'CO', 'SO2']
    fig, axes = plt.subplots(1, 2, figsize=(6.65, 2.25))
    for ax, sensor in zip(axes, ['CPCB', 'ID1']):
        for j, filt in enumerate(filters):
            a = scores[(scores.sensor == sensor) & (scores.method == 'wavecatboost') & (scores['filter'] == filt)].set_index('pollutant')
            ax.bar(np.arange(6) + (j - 1) * 0.24, [a.loc[p, 'MASE'] for p in pols], width=0.23, color=colors[j], label=labels[j])
        ax.set_xticks(np.arange(6), ['PM2.5', 'PM10', 'NO2', 'O3', 'CO', 'SO2'], fontsize=7)
        ax.set_title(sensor, fontsize=10)
        ax.set_ylim(0, 6.9 if sensor == 'CPCB' else 1.55)
        ax.grid(axis='y', alpha=0.17)
        ax.set_axisbelow(True)
    axes[0].set_ylabel('MASE (lower is better)')
    fig.legend(*axes[0].get_legend_handles_labels(), ncol=3, frameon=False, loc='upper center', bbox_to_anchor=(0.53, 1.04))
    fig.tight_layout(rect=[0, 0, 1, 0.92], pad=0.5)
    fig.savefig(figs / 'filter_pollutant_bars.pdf')
    plt.close(fig)
    # Recompute coverage and width from the bounds instead of trusting a label.
    diagnostics = []
    fig, axes = plt.subplots(3, 1, figsize=(6.65, 4.0), sharex=True)
    for ax, sensor in zip(axes, ['CPCB', 'ID1', 'SHILLONG']):
        a = conf[sensor]
        y = np.array(a['y_test'])
        yh = np.array(a['yhat'])
        lo = np.array(a['lower'])
        hi = np.array(a['upper'])
        x = np.arange(len(y))
        coverage = np.mean((y >= lo) & (y <= hi))
        width = np.mean(hi - lo)
        mae = np.mean(abs(y - yh))
        rmse = np.sqrt(np.mean((y - yh) ** 2))
        assert abs(coverage - a['coverage_test']) < 1e-10
        assert abs(width - a['width']) < 1e-08
        diagnostics.append({'sensor': sensor, 'kappa': a['kappa'], 'coverage_cal': a['coverage_cal'], 'coverage_test': coverage, 'width': width, 'MAE': mae, 'RMSE': rmse})
        ax.fill_between(x, lo, hi, color='#b7c5da', alpha=0.6, label='Recorded 95% nominal interval')
        ax.plot(x, y, color='#242424', lw=0.8, label='Observed')
        ax.plot(x, yh, color='#ab552f', lw=0.8, label='WaveCatBoost')
        ax.set_ylabel('PM2.5', fontsize=8)
        ax.text(0.01, 0.94, f'{sensor} | coverage {coverage * 100:.1f}% | mean width {width:.2f}', transform=ax.transAxes, va='top', fontsize=8)
        ax.grid(axis='y', alpha=0.15)
    axes[-1].set_xlabel('Hour within the retained 7-day test window')
    axes[-1].set_xticks([0, 24, 48, 72, 96, 120, 144, 167])
    fig.legend(*axes[0].get_legend_handles_labels(), ncol=3, frameon=False, loc='upper center', bbox_to_anchor=(0.53, 1.015), fontsize=8)
    fig.tight_layout(rect=[0, 0, 1, 0.965], pad=0.5, h_pad=0.5)
    fig.savefig(figs / 'conformal_recorded.pdf')
    plt.close(fig)
    pd.DataFrame(diagnostics).to_csv(out / 'conformal_metrics.csv', index=False)
    # Validation chose the settings; the test score is the final comparison.
    metrics = pd.read_csv(root / 'results/preprocessed_experiment/comparisons/metrics_pollutant_level.csv')
    fig, ax = plt.subplots(figsize=(3.3, 2.15))
    for model, color in [('B0', '#315f9a'), ('A1', '#aa5a32'), ('B1', '#648d5b'), ('B2', '#8866a4'), ('B3', '#708080')]:
        values = metrics[(metrics.dataset == 'clean') & (metrics.model == model)].set_index('block')
        ax.plot([0, 1], [values.loc['val', 'MAE'], values.loc['test', 'MAE']], marker='o', label=model, color=color, linewidth=1.5)
    ax.set_xticks([0, 1], ['Validation (selection)', 'Test (final)'])
    ax.set_ylabel('MAE (PM2.5 units)')
    ax.set_xlim(-0.3, 1.55)
    ax.grid(axis='y', alpha=0.18)
    ax.legend(loc='center right', frameon=False)
    fig.tight_layout(pad=0.6)
    fig.savefig(figs / 'validation_test.pdf')
    plt.close(fig)
    print('Updated filter, metric and conformal figures in', figs)
if __name__ == '__main__':
    main()
