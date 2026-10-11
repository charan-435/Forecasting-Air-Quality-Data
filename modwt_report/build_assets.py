"""Compute worked examples and figures for the MODWT explainer (modwt_explained.tex)."""

from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

ROOT = Path(__file__).parent
FIGS = ROOT / "figs"
TABLES = ROOT / "tables"
FIGS.mkdir(exist_ok=True)
TABLES.mkdir(exist_ok=True)

SQRT2 = np.sqrt(2.0)
HAAR_H = np.array([1 / SQRT2, -1 / SQRT2])  # DWT wavelet filter
HAAR_G = np.array([1 / SQRT2, 1 / SQRT2])   # DWT scaling filter


def modwt(x, J, h=HAAR_H, g=HAAR_G):
    """Circular MODWT via the pyramid algorithm (Percival & Walden, 2000)."""
    x = np.asarray(x, dtype=float)
    N = len(x)
    ht, gt = h / SQRT2, g / SQRT2
    V = x.copy()
    Ws, Vs = [], []
    for j in range(1, J + 1):
        step = 2 ** (j - 1)
        W_j = np.zeros(N)
        V_j = np.zeros(N)
        for t in range(N):
            for l in range(len(ht)):
                idx = (t - step * l) % N
                W_j[t] += ht[l] * V[idx]
                V_j[t] += gt[l] * V[idx]
        Ws.append(W_j)
        Vs.append(V_j)
        V = V_j
    return Ws, Vs


def imodwt(Ws, V_J, h=HAAR_H, g=HAAR_G):
    """Inverse circular MODWT."""
    ht, gt = h / SQRT2, g / SQRT2
    N = len(V_J)
    V = V_J.copy()
    for j in range(len(Ws), 0, -1):
        step = 2 ** (j - 1)
        prev = np.zeros(N)
        for t in range(N):
            for l in range(len(ht)):
                idx = (t + step * l) % N
                prev[t] += ht[l] * Ws[j - 1][idx] + gt[l] * V[idx]
        V = prev
    return V


def mra(x, J):
    """Multiresolution analysis: details D_1..D_J and smooth S_J."""
    Ws, Vs = modwt(x, J)
    zeros = [np.zeros_like(w) for w in Ws]
    D = []
    for j in range(J):
        Wz = list(zeros)
        Wz[j] = Ws[j]
        D.append(imodwt(Wz, np.zeros_like(Vs[-1])))
    S = imodwt(zeros, Vs[-1])
    return D, S


def fmt(v, d=4):
    s = f"{v:.{d}f}".rstrip("0").rstrip(".")
    if s in ("-0", ""):
        s = "0"
    return f"${s}$" if s.startswith("-") else s


def write_table(name, header, rows, align=None):
    align = align or "c" * len(header)
    lines = [rf"\begin{{tabular}}{{{align}}}", r"\toprule", " & ".join(header) + r" \\", r"\midrule"]
    for r in rows:
        lines.append(" & ".join(r) + r" \\")
    lines += [r"\bottomrule", r"\end{tabular}"]
    (TABLES / f"{name}.tex").write_text("\n".join(lines), encoding="utf-8")


# ---------------------------------------------------------------- toy example
X = np.array([20, 22, 25, 24, 28, 30, 27, 26], dtype=float)
N, J = len(X), 3
Ws, Vs = modwt(X, J)

rows = []
for t in range(N):
    prev = X[(t - 1) % N]
    prev_s = fmt(prev) + (r"$^{\ast}$" if t == 0 else "")
    rows.append([str(t), fmt(X[t]), prev_s, fmt(Ws[0][t]), fmt(Vs[0][t]), fmt(Ws[0][t] + Vs[0][t])])
write_table("toy_level1",
            [r"$t$", r"$X_t$", r"$X_{t-1}$", r"$W_{1,t}=\frac{X_t-X_{t-1}}{2}$",
             r"$V_{1,t}=\frac{X_t+X_{t-1}}{2}$", r"$W_{1,t}+V_{1,t}$"], rows)

rows = []
for t in range(N):
    prev = Vs[0][(t - 2) % N]
    star = r"$^{\ast}$" if t < 2 else ""
    rows.append([str(t), fmt(Vs[0][t]), fmt(prev) + star, fmt(Ws[1][t]), fmt(Vs[1][t])])
write_table("toy_level2",
            [r"$t$", r"$V_{1,t}$", r"$V_{1,t-2}$", r"$W_{2,t}=\frac{V_{1,t}-V_{1,t-2}}{2}$",
             r"$V_{2,t}=\frac{V_{1,t}+V_{1,t-2}}{2}$"], rows)

rows = []
for t in range(N):
    prev = Vs[1][(t - 4) % N]
    star = r"$^{\ast}$" if t < 4 else ""
    rows.append([str(t), fmt(Vs[1][t]), fmt(prev) + star, fmt(Ws[2][t]), fmt(Vs[2][t])])
write_table("toy_level3",
            [r"$t$", r"$V_{2,t}$", r"$V_{2,t-4}$", r"$W_{3,t}=\frac{V_{2,t}-V_{2,t-4}}{2}$",
             r"$V_{3,t}=\frac{V_{2,t}+V_{2,t-4}}{2}$"], rows)

rows = []
for t in range(N):
    total = Ws[0][t] + Ws[1][t] + Ws[2][t] + Vs[2][t]
    rows.append([str(t), fmt(X[t]), fmt(Ws[0][t]), fmt(Ws[1][t]), fmt(Ws[2][t]), fmt(Vs[2][t]), fmt(total)])
write_table("toy_all",
            [r"$t$", r"$X_t$", r"$W_{1,t}$", r"$W_{2,t}$", r"$W_{3,t}$", r"$V_{3,t}$",
             r"$W_1{+}W_2{+}W_3{+}V_3$"], rows)

X_rec = imodwt(Ws, Vs[-1])
assert np.allclose(X_rec, X)

D, S = mra(X, J)
rows = []
for t in range(N):
    total = D[0][t] + D[1][t] + D[2][t] + S[t]
    rows.append([str(t), fmt(X[t]), fmt(D[0][t]), fmt(D[1][t]), fmt(D[2][t]), fmt(S[t]), fmt(total)])
write_table("toy_mra",
            [r"$t$", r"$X_t$", r"$D_{1,t}$", r"$D_{2,t}$", r"$D_{3,t}$", r"$S_{3,t}$",
             r"$D_1{+}D_2{+}D_3{+}S_3$"], rows)
assert np.allclose(sum(D) + S, X)

energy_X = float(np.sum(X ** 2))
e_W = [float(np.sum(w ** 2)) for w in Ws]
e_V = float(np.sum(Vs[-1] ** 2))
rows = [[r"$\lVert X\rVert^2$", fmt(energy_X)]]
rows += [[rf"$\lVert W_{j + 1}\rVert^2$", fmt(e)] for j, e in enumerate(e_W)]
rows += [[r"$\lVert V_3\rVert^2$", fmt(e_V)],
         [r"$\sum_j \lVert W_j\rVert^2 + \lVert V_3\rVert^2$", fmt(sum(e_W) + e_V)]]
write_table("toy_energy", ["Quantity", "Value"], rows, "lr")
assert np.isclose(energy_X, sum(e_W) + e_V)

# DWT vs MODWT under a circular shift
def dwt_level1(x):
    return (x[1::2] - x[0::2]) / SQRT2

Xs = np.roll(X, 1)
dw, dws = dwt_level1(X), dwt_level1(Xs)
mw, mws = modwt(X, 1)[0][0], modwt(Xs, 1)[0][0]
write_table("shift_dwt",
            [r"$k$", r"$W_{1,k}$ of $X$", r"$W_{1,k}$ of $X'$"],
            [[str(k), fmt(dw[k]), fmt(dws[k])] for k in range(len(dw))])
write_table("shift_modwt",
            [r"$t$", r"$W_{1,t}$ of $X$", r"$W_{1,t}$ of $X'$"],
            [[str(t), fmt(mw[t]), fmt(mws[t])] for t in range(N)])
assert np.allclose(mws, np.roll(mw, 1))

# Leakage: MRA detail at t=6 computed from data up to t=6 vs. from the full series
D_trunc, _ = mra(X[:7], J)
rows = [[rf"$D_{{{j + 1},6}}$", fmt(D[j][6]), fmt(D_trunc[j][6])] for j in range(J)]
W_trunc, _ = modwt(X[:7], J)
rows += [[rf"$W_{{{j + 1},6}}$", fmt(Ws[j][6]), fmt(W_trunc[j][6])] for j in range(J)]
write_table("leakage",
            ["Value at $t=6$", r"using $X_0,\dots,X_7$ (full)", r"using $X_0,\dots,X_6$ only"],
            rows, "lcc")

# ------------------------------------------------------------- figures
plt.rcParams.update({"font.size": 9, "axes.spines.top": False, "axes.spines.right": False})

# Equivalent Haar MODWT filters
fig, axes = plt.subplots(2, 3, figsize=(7.2, 3.4), sharey=True)
for j in range(1, 4):
    L = 2 ** j
    h_j = np.r_[np.full(L // 2, 1 / L), np.full(L // 2, -1 / L)]
    g_j = np.full(L, 1 / L)
    for row, (filt, name, col) in enumerate([(h_j, r"\tilde h", "C3"), (g_j, r"\tilde g", "C0")]):
        ax = axes[row, j - 1]
        ax.stem(np.arange(L), filt, linefmt=col, markerfmt=col + "o", basefmt="k-")
        ax.set_title(rf"${name}_{{{j},l}}$  (length {L})")
        ax.set_xticks(range(L))
        ax.axhline(0, color="k", lw=0.5)
        if j == 1:
            ax.set_ylabel("weight")
for ax in axes[1]:
    ax.set_xlabel(r"lag $l$ (applied to $X_{t-l}$)")
fig.tight_layout()
fig.savefig(FIGS / "haar_filters.pdf")
plt.close(fig)

# Squared gain functions of Haar MODWT filters
f = np.linspace(0, 0.5, 2000)
fig, ax = plt.subplots(figsize=(7.2, 3.0))
J_show = 5
for j in range(1, J_show + 1):
    gain = np.sin(np.pi * f * 2 ** (j - 1)) ** 2
    for k in range(1, j):
        gain *= np.cos(np.pi * f * 2 ** (k - 1)) ** 2
    ax.plot(f, gain, label=rf"$W_{j}$: nominal band $[1/2^{{{j + 1}}}, 1/2^{{{j}}}]$")
    ax.axvspan(1 / 2 ** (j + 1), 1 / 2 ** j, color=f"C{j - 1}", alpha=0.06)
smooth = np.ones_like(f)
for k in range(1, J_show + 1):
    smooth *= np.cos(np.pi * f * 2 ** (k - 1)) ** 2
ax.plot(f, smooth, "k--", label=rf"$V_{J_show}$ (low-pass)")
ax.set_xlabel("frequency $f$ (cycles per time step)")
ax.set_ylabel("squared gain")
ax.set_xlim(0, 0.5)
ax.legend(fontsize=7, frameon=False, loc="upper right")
fig.tight_layout()
fig.savefig(FIGS / "haar_gain.pdf")
plt.close(fig)

# Synthetic hourly PM2.5-like series
rng = np.random.default_rng(7)
hours = 24 * 32
t = np.arange(hours)
trend = 45 + 0.012 * t
daily = 9 * np.sin(2 * np.pi * (t - 6) / 24) + 3.5 * np.sin(2 * np.pi * t / 12)
weekly = 5 * np.sin(2 * np.pi * t / 168)
noise = rng.normal(0, 2.5, hours)
spikes = np.zeros(hours)
for c, a in [(150, 30), (410, 22), (600, 26)]:
    spikes += a * np.exp(-0.5 * ((t - c) / 1.5) ** 2)
pm = trend + daily + weekly + noise + spikes

J_syn = 6
D_syn, S_syn = mra(pm, J_syn)
assert np.allclose(sum(D_syn) + S_syn, pm)

bands = [f"periods {2 ** j}–{2 ** (j + 1)} h" for j in range(1, J_syn + 1)]
fig, axes = plt.subplots(J_syn + 2, 1, figsize=(7.2, 9.2), sharex=True)
axes[0].plot(t, pm, color="k", lw=0.7)
axes[0].set_ylabel(r"$X_t$", rotation=0, labelpad=18)
axes[0].set_title("Synthetic hourly PM$_{2.5}$ (µg/m³) and its MODWT multiresolution analysis (Haar, $J=6$)")
for j in range(J_syn):
    axes[j + 1].plot(t, D_syn[j], color=f"C{j}", lw=0.7)
    axes[j + 1].set_ylabel(rf"$D_{j + 1}$", rotation=0, labelpad=18)
    axes[j + 1].text(1.0, 1.0, bands[j], transform=axes[j + 1].transAxes, ha="right", va="bottom", fontsize=7)
axes[-1].plot(t, S_syn, color="k", lw=1)
axes[-1].set_ylabel(r"$S_6$", rotation=0, labelpad=18)
axes[-1].text(1.0, 1.0, "periods > 128 h", transform=axes[-1].transAxes, ha="right", va="bottom", fontsize=7)
axes[-1].set_xlabel("hour")
fig.tight_layout()
fig.savefig(FIGS / "synthetic_mra.pdf")
plt.close(fig)

# Energy (variance) per level for the synthetic series
Ws_syn, Vs_syn = modwt(pm, J_syn)
var_W = np.array([np.mean(w ** 2) for w in Ws_syn])
fig, ax = plt.subplots(figsize=(7.2, 2.6))
labels = [rf"$W_{j}$" + f"\n{2 ** j}–{2 ** (j + 1)} h" for j in range(1, J_syn + 1)]
ax.bar(labels, var_W / var_W.sum() * 100, color=[f"C{j}" for j in range(J_syn)])
ax.set_ylabel("% of wavelet variance")
ax.set_title("Where the variability lives: wavelet variance by level")
fig.tight_layout()
fig.savefig(FIGS / "synthetic_energy.pdf")
plt.close(fig)

# Shift invariance on the synthetic series
seg = pm[:192]
seg_shift = np.roll(seg, 3)
mw2 = modwt(seg, 2)[0][1]
mw2s = modwt(seg_shift, 2)[0][1]
fig, axes = plt.subplots(1, 2, figsize=(7.2, 2.5))
axes[0].plot(mw2, lw=0.8, label="original")
axes[0].plot(mw2s, lw=0.8, ls="--", label="input shifted by 3 h")
axes[0].set_title("MODWT $W_2$: same pattern, shifted")
axes[0].legend(fontsize=7, frameon=False)
d2 = lambda x: (x[2::4] + x[3::4] - x[0::4] - x[1::4]) / 2
axes[1].plot(d2(seg), "o-", ms=2.5, lw=0.8, label="original")
axes[1].plot(d2(seg_shift), "s--", ms=2.5, lw=0.8, label="input shifted by 3 h")
axes[1].set_title("DWT level-2 coefficients: pattern changes")
axes[1].legend(fontsize=7, frameon=False)
for ax in axes:
    ax.set_xlabel("index")
fig.tight_layout()
fig.savefig(FIGS / "shift_invariance.pdf")
plt.close(fig)

print("assets written to", ROOT)
