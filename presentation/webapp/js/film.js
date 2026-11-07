(function (global) {
  function createFilm(canvas, opts = {}) {
    const CLIP = global.CLIP;
    if (!CLIP) throw new Error("CLIP missing");
    const Y = Float64Array.from(CLIP.test.y);
    const YH = Float64Array.from(CLIP.test.yhat_wavecatboost);
    const SN = Float64Array.from(CLIP.test.yhat_snaive);
    const LO = Float64Array.from(CLIP.test.lower);
    const HI = Float64Array.from(CLIP.test.upper);
    const M = CLIP.metrics;
    const N = Y.length;
    const DUR = 78;

    function mavg(a, w) {
      const o = new Float64Array(a.length);
      for (let i = 0; i < a.length; i++) {
        let s = 0, c = 0;
        for (let k = -w; k <= w; k++) {
          const j = i + k;
          if (j >= 0 && j < a.length) { s += a[j]; c++; }
        }
        o[i] = s / c;
      }
      return o;
    }
    const S5 = mavg(Y, 16);
    let rem = Float64Array.from(Y, (v, i) => v - S5[i]);
    const D5 = mavg(rem, 8); rem = Float64Array.from(rem, (v, i) => v - D5[i]);
    const D4 = mavg(rem, 4); rem = Float64Array.from(rem, (v, i) => v - D4[i]);
    const D3 = mavg(rem, 2); rem = Float64Array.from(rem, (v, i) => v - D3[i]);
    const D2 = mavg(rem, 1); rem = Float64Array.from(rem, (v, i) => v - D2[i]);
    const bands = [rem, D2, D3, D4, D5, S5];
    const SHORT = ["D₁", "D₂", "D₃", "D₄", "D₅", "S₅"];
    const BAND = ["#A64B2A", "#C4A35A", "#2E6B4F", "#5B7C99", "#6B4C9A", "#1F3A5F"];

    const STAGES = [
      { t0: 0, t1: 11, id: 0, title: "1. series", body: "CPCB PM2.5, 7-day test window from our forecast cache." },
      { t0: 11, t1: 24, id: 1, title: "2. Haar bands", body: "Split into D1..D5 detail bands and smooth S5." },
      { t0: 24, t1: 36, id: 2, title: "3. CatBoost", body: "One CatBoost model per band, lag window p = 24." },
      { t0: 36, t1: 48, id: 3, title: "4. reconstruct", body: `Sum band forecasts. WaveCatBoost MASE ${M.mase_wavecatboost.toFixed(2)}` },
      { t0: 48, t1: 60, id: 4, title: "5. vs snaive", body: `snaive MASE ${M.mase_snaive.toFixed(2)}, WaveCatBoost ${M.mase_wavecatboost.toFixed(2)}` },
      { t0: 60, t1: 72, id: 5, title: "6. residual PI", body: `95% PI, coverage ${(100 * M.coverage).toFixed(0)}%, mean width ${M.width.toFixed(1)}` },
      { t0: 72, t1: 78, id: 5, title: "WaveCatBoost", body: "decompose, forecast each band, sum back" },
    ];

    const ctx = canvas.getContext("2d");
    let W = 0, H = 0, dpr = 1;
    let playing = false, speed = 1, t0 = 0, raf = 0, lastT = 0;
    const onTick = opts.onTick || (() => {});

    const lerp = (a, b, t) => a + (b - a) * t;
    const clamp = (x, a, b) => Math.max(a, Math.min(b, x));
    const ease = (t) => (t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2);
    const smooth = (t, a, b) => ease(clamp((t - a) / (b - a), 0, 1));
    const yScale = (arr) => {
      let lo = Infinity, hi = -Infinity;
      for (const v of arr) { if (v < lo) lo = v; if (v > hi) hi = v; }
      return { lo: lo - 1, hi: hi + 1 };
    };
    const YS = yScale([...Y, ...YH, ...SN, ...LO, ...HI]);
    const css = (name) => getComputedStyle(document.documentElement).getPropertyValue(name).trim();

    function resize() {
      const host = canvas.parentElement;
      const r = host.getBoundingClientRect();
      dpr = Math.min(devicePixelRatio || 1, 2);
      W = Math.max(1, r.width);
      H = Math.max(1, r.height);
      canvas.width = W * dpr;
      canvas.height = H * dpr;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    }

    function mx(i, x0, x1) { return lerp(x0, x1, i / (N - 1)); }
    function my(v, y0, y1, sc = YS) { return lerp(y1, y0, (v - sc.lo) / (sc.hi - sc.lo)); }

    function drawAxes(x0, x1, y0, y1, sc, inkMuted) {
      ctx.strokeStyle = inkMuted;
      ctx.globalAlpha = 0.35;
      ctx.lineWidth = 1;
      for (let i = 0; i <= 4; i++) {
        const y = y0 + ((y1 - y0) * i) / 4;
        ctx.beginPath();
        ctx.moveTo(x0, y);
        ctx.lineTo(x1, y);
        ctx.stroke();
        const v = sc.hi - ((sc.hi - sc.lo) * i) / 4;
        ctx.globalAlpha = 0.85;
        ctx.fillStyle = inkMuted;
        ctx.font = '10px "App Mono", Consolas, monospace';
        ctx.textAlign = "right";
        ctx.fillText(v.toFixed(0), x0 - 6, y + 3);
        ctx.globalAlpha = 0.35;
      }
      ctx.globalAlpha = 1;
      ctx.textAlign = "left";
    }

    function strokeSeries(arr, x0, x1, y0, y1, nDraw, sc, col, w, a = 1) {
      const m = Math.max(2, Math.floor(nDraw));
      ctx.beginPath();
      for (let i = 0; i < m; i++) {
        const x = mx(i, x0, x1), y = my(arr[i], y0, y1, sc);
        if (i) ctx.lineTo(x, y); else ctx.moveTo(x, y);
      }
      ctx.strokeStyle = col; ctx.globalAlpha = a; ctx.lineWidth = w;
      ctx.lineJoin = "round"; ctx.lineCap = "round"; ctx.stroke(); ctx.globalAlpha = 1;
    }

    function stageAt(t) {
      return STAGES.find((s) => t >= s.t0 && t < s.t1) || STAGES.at(-1);
    }

    function draw(t) {
      lastT = t;
      const st = stageAt(t);
      onTick({ t, dur: DUR, stage: st, metrics: M });
      ctx.clearRect(0, 0, W, H);
      const ink = css("--ink");
      const muted = css("--muted");
      const rust = css("--rust");
      const navy = css("--navy");
      const light = document.documentElement.getAttribute("data-theme") !== "dark";
      const seriesCol = light ? navy : "#9ec5ff";
      const x0 = 52, x1 = W - 18, y0 = 28, y1 = H - 28;

      const a0 = 1 - smooth(t, 10, 11.8);
      const a1 = smooth(t, 10.5, 12.5) * (1 - smooth(t, 22.5, 24.2));
      const a2 = smooth(t, 23.5, 25.5) * (1 - smooth(t, 34.5, 36.2));
      const a3 = smooth(t, 35.5, 37.5) * (1 - smooth(t, 46.5, 48.2));
      const a4 = smooth(t, 47.5, 49.5) * (1 - smooth(t, 58.5, 60.2));
      const a5 = smooth(t, 59.5, 61.5) * (1 - smooth(t, 70.5, 72.2));
      const aEnd = smooth(t, 71.5, 74);

      if (a1 < 0.2 && a2 < 0.2 && aEnd < 0.4) {
        drawAxes(x0, x1, y0, y1, YS, muted);
      }

      if (a0 > 0.01 && t < 13) {
        ctx.globalAlpha = a0;
        const p = smooth(t, 0.2, 8.5);
        const nDraw = 2 + Math.floor((N - 1) * p);
        strokeSeries(Y, x0, x1, y0, y1, nDraw, YS, seriesCol, 2.3, 1);
        ctx.fillStyle = ink; ctx.font = "600 13px Segoe UI";
        ctx.fillText("Yₜ  CPCB PM₂.₅", x0, 14);
        ctx.globalAlpha = 1;
      }
      if (a1 > 0.01) {
        const peel = smooth(t, 11.5, 18);
        const rows = 6, top = 16, bot = H - 20, rh = (bot - top) / rows;
        for (let b = 0; b < rows; b++) {
          const yy0 = lerp(y0, top + b * rh + 2, peel);
          const yy1 = lerp(y1, top + (b + 1) * rh - 4, peel);
          const scB = yScale(bands[b]);
          const local = Float64Array.from(Y, (v, i) => v * (1 - peel) + bands[b][i] * peel);
          const scL = { lo: YS.lo * (1 - peel) + (scB.lo - 0.5) * peel, hi: YS.hi * (1 - peel) + (scB.hi + 0.5) * peel };
          ctx.globalAlpha = a1 * (0.4 + 0.6 * smooth(t, 12 + b * 0.3, 14 + b * 0.3));
          strokeSeries(local, x0 + 40, x1, yy0, yy1, N, scL, BAND[b], 1.5, 1);
          ctx.fillStyle = BAND[b]; ctx.font = "600 11px ui-monospace, Consolas, monospace";
          ctx.fillText(SHORT[b], x0, (yy0 + yy1) / 2 + 3);
        }
        ctx.globalAlpha = 1;
      }
      if (a2 > 0.01) {
        ctx.globalAlpha = a2;
        const rows = 6, top = 14, bot = H - 16, rh = (bot - top) / rows;
        for (let b = 0; b < rows; b++) {
          const yy0 = top + b * rh + 2, yy1 = top + (b + 1) * rh - 4, mid = (yy0 + yy1) / 2;
          const sc = yScale(bands[b]);
          strokeSeries(bands[b], x0 + 36, W * 0.38, yy0, yy1, N, sc, BAND[b], 1.25, 0.95);
          ctx.fillStyle = BAND[b]; ctx.font = "600 11px ui-monospace, Consolas, monospace";
          ctx.fillText(SHORT[b], x0, mid + 3);
          const bx = W * 0.58, by = mid - 14, bw = W * 0.36, bh = 28;
          ctx.strokeStyle = BAND[b]; ctx.fillStyle = light ? "rgba(31,58,95,.05)" : "rgba(255,255,255,.05)";
          const rr = 8;
          ctx.beginPath();
          ctx.moveTo(bx + rr, by);
          ctx.arcTo(bx + bw, by, bx + bw, by + bh, rr);
          ctx.arcTo(bx + bw, by + bh, bx, by + bh, rr);
          ctx.arcTo(bx, by + bh, bx, by, rr);
          ctx.arcTo(bx, by, bx + bw, by, rr);
          ctx.closePath();
          ctx.fill(); ctx.stroke();
          ctx.fillStyle = ink; ctx.font = "600 12px Segoe UI";
          ctx.fillText("CatBoost", bx + 12, mid + 1);
        }
        ctx.globalAlpha = 1;
      }
      if (a3 > 0.01) {
        ctx.globalAlpha = a3;
        strokeSeries(Y, x0, x1, y0, y1, N, YS, seriesCol, 1.5, 0.55);
        strokeSeries(YH, x0, x1, y0, y1, N, YS, rust, 2.4, 1);
        ctx.fillStyle = ink; ctx.font = "600 13px Segoe UI";
        ctx.fillText("actual vs WaveCatBoost Ŷ", x0, 14);
        ctx.globalAlpha = 1;
      }
      if (a4 > 0.01) {
        ctx.globalAlpha = a4;
        const split = smooth(t, 49, 52);
        const L1 = lerp(x1, (x0 + x1) / 2 - 6, split);
        const R0 = lerp(x0, (x0 + x1) / 2 + 6, split);
        strokeSeries(Y, x0, L1, y0, y1, N, YS, seriesCol, 1.2, 0.4);
        strokeSeries(SN, x0, L1, y0, y1, N, YS, "#5B7C99", 2, 1);
        strokeSeries(Y, R0, x1, y0, y1, N, YS, seriesCol, 1.2, 0.4);
        strokeSeries(YH, R0, x1, y0, y1, N, YS, rust, 2, 1);
        ctx.fillStyle = ink; ctx.font = "700 12px Segoe UI";
        ctx.fillText("snaive", x0, 14);
        ctx.fillText("WaveCatBoost", R0, 14);
        ctx.fillStyle = "#5B7C99"; ctx.font = "600 11px ui-monospace, Consolas, monospace";
        ctx.fillText(`MASE ${M.mase_snaive.toFixed(2)}`, x0, 30);
        ctx.fillStyle = rust; ctx.fillText(`MASE ${M.mase_wavecatboost.toFixed(2)}`, R0, 30);
        ctx.globalAlpha = 1;
      }
      if (a5 > 0.01) {
        ctx.globalAlpha = a5;
        const p = smooth(t, 61, 66);
        ctx.beginPath();
        for (let i = 0; i < N; i++) {
          const up = YH[i] + (HI[i] - YH[i]) * p;
          const x = mx(i, x0, x1), y = my(up, y0, y1);
          if (i) ctx.lineTo(x, y); else ctx.moveTo(x, y);
        }
        for (let i = N - 1; i >= 0; i--) {
          const lo = YH[i] + (LO[i] - YH[i]) * p;
          ctx.lineTo(mx(i, x0, x1), my(lo, y0, y1));
        }
        ctx.closePath();
        ctx.fillStyle = light ? "rgba(166,75,42,.16)" : "rgba(166,75,42,.28)";
        ctx.fill();
        strokeSeries(Y, x0, x1, y0, y1, N, YS, seriesCol, 1.4, 0.5);
        strokeSeries(YH, x0, x1, y0, y1, N, YS, rust, 2.3, 1);
        ctx.fillStyle = ink; ctx.font = "600 13px Segoe UI";
        ctx.fillText("95% residual PI", x0, 14);
        ctx.globalAlpha = 1;
      }
      if (aEnd > 0.01) {
        ctx.globalAlpha = aEnd; ctx.textAlign = "center";
        ctx.fillStyle = ink; ctx.font = "800 32px Segoe UI";
        ctx.fillText("WaveCatBoost", W / 2, H * 0.42);
        ctx.fillStyle = muted; ctx.font = "14px Segoe UI";
        ctx.fillText("ATSA Group 8", W / 2, H * 0.52);
        ctx.textAlign = "left"; ctx.globalAlpha = 1;
      }
    }

    function frame(now) {
      if (!playing) return;
      const t = Math.min(DUR, ((now - t0) / 1000) * speed);
      draw(t);
      if (t < DUR) raf = requestAnimationFrame(frame);
      else { playing = false; if (opts.onPlayChange) opts.onPlayChange(false); }
    }

    function start(from = 0) {
      cancelAnimationFrame(raf);
      playing = true;
      if (opts.onPlayChange) opts.onPlayChange(true);
      t0 = performance.now() - (from * 1000) / speed;
      raf = requestAnimationFrame(frame);
    }
    function pause() {
      playing = false;
      cancelAnimationFrame(raf);
      if (opts.onPlayChange) opts.onPlayChange(false);
    }
    function seek(t) {
      lastT = clamp(t, 0, DUR);
      if (playing) t0 = performance.now() - (lastT * 1000) / speed;
      draw(lastT);
    }
    function setSpeed(s) {
      const prev = lastT;
      speed = s;
      if (playing) start(prev);
    }

    resize();
    addEventListener("resize", () => { resize(); draw(lastT); });
    if (typeof ResizeObserver !== "undefined") {
      const ro = new ResizeObserver(() => { resize(); draw(lastT); });
      ro.observe(canvas.parentElement);
    }
    draw(0);

    return {
      DUR, start, pause, seek, setSpeed, resize,
      get t() { return lastT; },
      get playing() { return playing; },
      redraw: () => { resize(); draw(lastT); },
    };
  }

  global.createFilm = createFilm;
})(window);
