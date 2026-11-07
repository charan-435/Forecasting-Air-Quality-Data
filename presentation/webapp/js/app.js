(function () {
  const $ = (sel) => document.querySelector(sel);
  const $$ = (sel) => [...document.querySelectorAll(sel)];

  const METHOD_LABEL = {
    snaive: "snaive",
    sarima: "SARIMA",
    xgb: "XGB",
    lgb: "LGB",
    catboost: "CatBoost",
    wavesarima: "WaveSARIMA",
    wavexgb: "WaveXGB",
    wavelgb: "WaveLGB",
    wavecatboost: "WaveCatBoost",
  };
  const METHOD_ORDER = [
    "snaive", "sarima", "xgb", "lgb", "catboost",
    "wavesarima", "wavexgb", "wavelgb", "wavecatboost",
  ];
  const METHOD_COLOR = {
    snaive: "#7A8B9A",
    sarima: "#5B7C99",
    xgb: "#C4A35A",
    lgb: "#3D6B4F",
    catboost: "#6B4C9A",
    wavesarima: "#8AA6C1",
    wavexgb: "#D4B96A",
    wavelgb: "#2E6B4F",
    wavecatboost: "#A64B2A",
  };

  const DATASETS = [
    {
      id: "CPCB",
      name: "CPCB",
      blurb: "CPCB station used in the paper.",
      pollutants: ["PM2.5", "PM10", "NO2", "O3", "CO", "SO2"],
      horizons: ["1d", "7d", "14d", "31d"],
      note: "Also used for the pipeline film (PM2.5, 7d).",
    },
    {
      id: "ID1",
      name: "ID1",
      blurb: "Second station from the paper.",
      pollutants: ["PM2.5", "PM10", "NO2", "O3", "CO", "SO2"],
      horizons: ["1d", "7d", "14d", "31d"],
      note: "MASE and MAE can rank methods differently because the seasonal scale differs.",
    },
    {
      id: "SHILLONG",
      name: "Shillong",
      blurb: "Our Shillong series (not in paper Table 1).",
      pollutants: ["PM2.5", "PM10", "NO2", "O3"],
      horizons: ["1d", "7d", "14d", "31d"],
      note: "Some methods missing in a few cells. Separate from the A0-C3 architecture runs.",
    },
  ];

  const cssVar = (n) => getComputedStyle(document.documentElement).getPropertyValue(n).trim();
  const isLight = () => document.documentElement.getAttribute("data-theme") !== "dark";

  function metric(b, s) {
    return `<div class="metric"><b>${b}</b><span>${s}</span></div>`;
  }

  function fitCanvas(canvas) {
    const host = canvas.parentElement;
    const r = host.getBoundingClientRect();
    const dpr = Math.min(devicePixelRatio || 1, 2);
    const W = Math.max(1, r.width);
    const H = Math.max(1, r.height);
    canvas.width = W * dpr;
    canvas.height = H * dpr;
    const ctx = canvas.getContext("2d");
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    return { ctx, W, H };
  }

  function drawGrid(ctx, x0, x1, y0, y1, lo, hi, muted) {
    ctx.strokeStyle = muted;
    ctx.globalAlpha = 0.28;
    ctx.lineWidth = 1;
    for (let i = 0; i <= 4; i++) {
      const y = y0 + ((y1 - y0) * i) / 4;
      ctx.beginPath();
      ctx.moveTo(x0, y);
      ctx.lineTo(x1, y);
      ctx.stroke();
      const v = hi - ((hi - lo) * i) / 4;
      ctx.globalAlpha = 0.9;
      ctx.fillStyle = muted;
      ctx.font = '10px "App Mono", Consolas, monospace';
      ctx.textAlign = "right";
      ctx.fillText(Number.isFinite(v) ? v.toFixed(1) : "", x0 - 6, y + 3);
      ctx.globalAlpha = 0.28;
    }
    ctx.globalAlpha = 1;
    ctx.textAlign = "left";
  }

  let film = null;
  let uploadState = null;

  function showPage(name) {
    $$(".page").forEach((p) => p.classList.toggle("on", p.dataset.page === name));
    $$(".nav-list button").forEach((t) => t.classList.toggle("on", t.dataset.page === name));
    location.hash = name;
    requestAnimationFrame(() => {
      if (name === "film" && film) film.redraw();
      if (name === "explore") drawExplore();
      if (name === "scores") {
        const s = $("#scoreSensor");
        if (s) renderScores(s.value, $("#scorePol").value, $("#scoreHn").value);
      }
      if (name === "upload" && uploadState) drawUploadChart();
    });
  }

  $$(".nav-list button").forEach((t) =>
    t.addEventListener("click", () => showPage(t.dataset.page))
  );
  $$("[data-go]").forEach((b) =>
    b.addEventListener("click", () => showPage(b.dataset.go))
  );
  $("#themeBtn").addEventListener("click", () => {
    const cur = document.documentElement.getAttribute("data-theme") || "light";
    document.documentElement.setAttribute("data-theme", cur === "dark" ? "light" : "dark");
    requestAnimationFrame(() => {
      if (film) film.redraw();
      drawExplore();
      if (uploadState) drawUploadChart();
      const s = $("#scoreSensor");
      if (s && $(".page.on")?.dataset.page === "scores") {
        renderScores(s.value, $("#scorePol").value, $("#scoreHn").value);
      }
    });
  });

  function fillHome() {
    const scores = window.SCORES || [];
    const pick = (sensor, method) =>
      scores.find(
        (r) =>
          r.sensor === sensor &&
          r.pollutant === "PM2.5" &&
          r.horizon === "1d" &&
          r.method === method
      );
    const wc = pick("CPCB", "wavecatboost");
    const sn = pick("CPCB", "snaive");
    const id1 = pick("ID1", "wavecatboost");
    const clip = window.CLIP;
    $("#homeMetrics").innerHTML = [
      metric(wc ? wc.MASE.toFixed(3) : "—", "CPCB WaveCatBoost, 1d MASE"),
      metric(sn ? sn.MASE.toFixed(3) : "—", "CPCB snaive, 1d MASE"),
      metric(id1 ? id1.MASE.toFixed(3) : "—", "ID1 WaveCatBoost, 1d MASE"),
      metric(
        clip ? `${(100 * clip.metrics.coverage).toFixed(0)}%` : "—",
        "7d PI coverage"
      ),
    ].join("");
  }

  function initDatasets() {
    const host = $("#dsCards");
    host.innerHTML = DATASETS.map(
      (d) => `<div class="ds-card" data-id="${d.id}">
        <div class="name">${d.name}</div>
        <div class="meta">${d.pollutants.length} pollutants · ${d.horizons.join("/")}</div>
      </div>`
    ).join("");
    host.querySelectorAll(".ds-card").forEach((el) => {
      el.addEventListener("click", () => {
        host.querySelectorAll(".ds-card").forEach((c) => c.classList.remove("on"));
        el.classList.add("on");
        showDataset(el.dataset.id);
      });
    });
    host.querySelector(".ds-card")?.click();
  }

  function showDataset(id) {
    const d = DATASETS.find((x) => x.id === id);
    const scores = (window.SCORES || []).filter((r) => r.sensor === id);
    const pols = [...new Set(scores.map((r) => r.pollutant))].sort();
    const nRows = scores.length;
    const wc1 = scores.find(
      (r) => r.pollutant === "PM2.5" && r.horizon === "1d" && r.method === "wavecatboost"
    );
    $("#dsDetail").innerHTML = `
      <h2>${d.name}</h2>
      <p class="lead mt-0">${d.blurb}</p>
      <div class="metrics four" style="margin-top:var(--s3)">
        ${metric(String(nRows), "score rows")}
        ${metric(pols.join(", ") || "—", "pollutants scored")}
        ${metric(wc1 ? wc1.MASE.toFixed(3) : "—", "WaveCatBoost PM₂.₅ 1d MASE")}
        ${metric(d.horizons.join(" · "), "horizons")}
      </div>
      <div class="callout"><strong>Note.</strong> ${d.note}</div>
      <div class="actions">
        <button class="btn secondary" type="button" data-jump-scores="${id}">Open in scores</button>
      </div>`;
    $("#dsDetail").querySelector("[data-jump-scores]")?.addEventListener("click", () => {
      $("#scoreSensor").value = id;
      showPage("scores");
      renderScores(id, $("#scorePol").value, $("#scoreHn").value);
    });
  }

  function initFilm() {
    const canvas = $("#filmCanvas");
    if (!canvas || !window.CLIP || !window.createFilm) return;
    const title = $("#filmTitle");
    const body = $("#filmBody");
    const scrub = $("#filmScrub");
    const timeEl = $("#filmTime");
    const playBtn = $("#filmPlay");

    film = createFilm(canvas, {
      onTick: ({ t, dur, stage }) => {
        title.textContent = stage.title;
        body.textContent = stage.body;
        scrub.value = Math.round((1000 * t) / dur);
        const m = Math.floor(t / 60),
          s = Math.floor(t % 60);
        timeEl.textContent = `${m}:${String(s).padStart(2, "0")}`;
      },
      onPlayChange: (playing) => {
        playBtn.textContent = playing ? "Pause" : "Play";
      },
    });
    playBtn.onclick = () => {
      if (film.playing) film.pause();
      else film.start(film.t >= film.DUR - 0.05 ? 0 : film.t);
    };
    $("#filmReplay").onclick = () => film.start(0);
    scrub.addEventListener("input", () => film.seek((+scrub.value / 1000) * film.DUR));
    $$(".spd").forEach((ch) => {
      ch.onclick = () => {
        $$(".spd").forEach((c) => c.classList.remove("on"));
        ch.classList.add("on");
        film.setSpeed(+ch.dataset.spd);
      };
    });
  }

  function drawExplore() {
    const canvas = $("#exploreCanvas");
    if (!canvas || !window.CLIP) return;
    if (!$('.page[data-page="explore"]').classList.contains("on")) return;

    const showWc = $("#showWc").checked;
    const showSn = $("#showSn").checked;
    const showPi = $("#showPi").checked;
    const showAct = $("#showAct").checked;

    const Y = Float64Array.from(CLIP.test.y);
    const YH = Float64Array.from(CLIP.test.yhat_wavecatboost);
    const SN = Float64Array.from(CLIP.test.yhat_snaive);
    const LO = Float64Array.from(CLIP.test.lower);
    const HI = Float64Array.from(CLIP.test.upper);
    const N = Y.length;
    const M = CLIP.metrics;

    const { ctx, W, H } = fitCanvas(canvas);
    ctx.clearRect(0, 0, W, H);

    const ink = cssVar("--ink");
    const muted = cssVar("--muted");
    const rust = cssVar("--rust");
    const navy = cssVar("--navy");
    const snCol = cssVar("--sn") || "#5B7C99";
    const light = isLight();
    const seriesCol = light ? navy : "#9ec5ff";

    let lo = Infinity,
      hi = -Infinity;
    const consider = [];
    if (showAct) consider.push(Y);
    if (showWc) consider.push(YH);
    if (showSn) consider.push(SN);
    if (showPi) {
      consider.push(LO);
      consider.push(HI);
    }
    if (!consider.length) consider.push(Y);
    for (const arr of consider)
      for (const v of arr) {
        if (v < lo) lo = v;
        if (v > hi) hi = v;
      }
    const pad = (hi - lo) * 0.06 || 1;
    lo -= pad;
    hi += pad;

    const x0 = 56,
      x1 = W - 16,
      y0 = 32,
      y1 = H - 36;
    const mx = (i) => x0 + ((x1 - x0) * i) / (N - 1);
    const my = (v) => y1 - ((v - lo) / (hi - lo)) * (y1 - y0);

    drawGrid(ctx, x0, x1, y0, y1, lo, hi, muted);

    function line(arr, col, w, a = 1) {
      ctx.beginPath();
      for (let i = 0; i < N; i++) {
        const x = mx(i),
          y = my(arr[i]);
        if (i) ctx.lineTo(x, y);
        else ctx.moveTo(x, y);
      }
      ctx.strokeStyle = col;
      ctx.globalAlpha = a;
      ctx.lineWidth = w;
      ctx.lineJoin = "round";
      ctx.lineCap = "round";
      ctx.stroke();
      ctx.globalAlpha = 1;
    }

    if (showPi) {
      ctx.beginPath();
      for (let i = 0; i < N; i++) {
        const x = mx(i),
          y = my(HI[i]);
        if (i) ctx.lineTo(x, y);
        else ctx.moveTo(x, y);
      }
      for (let i = N - 1; i >= 0; i--) ctx.lineTo(mx(i), my(LO[i]));
      ctx.closePath();
      ctx.fillStyle = light ? "rgba(166,75,42,.12)" : "rgba(166,75,42,.22)";
      ctx.fill();
    }
    if (showAct) line(Y, seriesCol, 2.2);
    if (showSn) line(SN, snCol, 2, 0.95);
    if (showWc) line(YH, rust, 2.6);

    ctx.fillStyle = ink;
    ctx.font = '600 13px "App Sans", Segoe UI, sans-serif';
    ctx.fillText("CPCB PM2.5, 7-day recursive test", x0, 18);
    ctx.fillStyle = muted;
    ctx.font = '10px "App Mono", Consolas, monospace';
    ctx.fillText(`n = ${N} hours`, x0, H - 12);

    $("#exploreMeta").innerHTML = [
      metric(M.mase_wavecatboost.toFixed(3), "WaveCatBoost MASE"),
      metric(M.mae_wavecatboost.toFixed(2), "WaveCatBoost MAE"),
      metric(M.mase_snaive.toFixed(3), "snaive MASE"),
      metric(`${(100 * M.coverage).toFixed(1)}%`, "residual PI coverage"),
    ].join("");
  }

  ["showWc", "showSn", "showPi", "showAct"].forEach((id) => {
    const el = document.getElementById(id);
    if (el) el.addEventListener("change", drawExplore);
  });

  function unique(arr) {
    return [...new Set(arr)];
  }

  function initScores() {
    const scores = window.SCORES || [];
    const sensors = unique(scores.map((r) => r.sensor)).sort();
    const pols = unique(scores.map((r) => r.pollutant)).sort();
    const hns = ["1d", "7d", "14d", "31d"];
    const sSel = $("#scoreSensor"),
      pSel = $("#scorePol"),
      hSel = $("#scoreHn");
    sSel.innerHTML = sensors.map((s) => `<option>${s}</option>`).join("");
    pSel.innerHTML = pols.map((p) => `<option>${p}</option>`).join("");
    hSel.innerHTML = hns.map((h) => `<option>${h}</option>`).join("");
    sSel.value = "CPCB";
    pSel.value = "PM2.5";
    hSel.value = "1d";
    const render = () => renderScores(sSel.value, pSel.value, hSel.value);
    [sSel, pSel, hSel].forEach((el) => el.addEventListener("change", render));
    render();
    renderPaperCmp();
  }

  function renderScores(sensor, pollutant, horizon) {
    const rows = (window.SCORES || []).filter(
      (r) => r.sensor === sensor && r.pollutant === pollutant && r.horizon === horizon
    );
    const byMethod = Object.fromEntries(rows.map((r) => [r.method, r]));
    const methods = METHOD_ORDER.filter((m) => byMethod[m]);
    let best = Infinity;
    methods.forEach((m) => {
      best = Math.min(best, byMethod[m].MASE);
    });

    const tbody = methods
      .map((m) => {
        const r = byMethod[m];
        const isBest = Math.abs(r.MASE - best) < 1e-9;
        return `<tr>
          <td>${METHOD_LABEL[m] || m}</td>
          <td class="${isBest ? "best" : ""}">${r.MASE.toFixed(3)}</td>
          <td>${r.MAE.toFixed(2)}</td>
          <td>${r.RMSE.toFixed(2)}</td>
        </tr>`;
      })
      .join("");
    $("#scoreTable").innerHTML = `
      <thead><tr><th>Method</th><th>MASE</th><th>MAE</th><th>RMSE</th></tr></thead>
      <tbody>${tbody || "<tr><td colspan=4>No rows for this filter</td></tr>"}</tbody>`;

    const legend = $("#scoreLegend");
    if (legend) {
      legend.innerHTML = methods
        .map(
          (m) =>
            `<span><i style="background:${METHOD_COLOR[m] || "#888"}"></i>${METHOD_LABEL[m] || m}</span>`
        )
        .join("");
    }

    const canvas = $("#scoreBars");
    if (!canvas) return;
    const { ctx, W, H } = fitCanvas(canvas);
    ctx.clearRect(0, 0, W, H);
    const muted = cssVar("--muted");
    const ink = cssVar("--ink");
    if (!methods.length) return;

    const maxV = Math.max(...methods.map((m) => byMethod[m].MASE), 0.01);
    const pad = { l: 48, r: 48, t: 28, b: 56 };
    const bw = (W - pad.l - pad.r) / methods.length;

    ctx.fillStyle = ink;
    ctx.font = '600 13px "App Sans", Segoe UI';
    ctx.fillText(`${sensor} ${pollutant} ${horizon} MASE`, pad.l, 16);

    methods.forEach((m, i) => {
      const v = byMethod[m].MASE;
      const h = ((H - pad.t - pad.b) * v) / maxV;
      const x = pad.l + i * bw + bw * 0.18;
      const y = H - pad.b - h;
      const isBest = Math.abs(v - best) < 1e-9;
      ctx.fillStyle = METHOD_COLOR[m] || "#888";
      ctx.globalAlpha = isBest ? 1 : 0.85;
      ctx.fillRect(x, y, bw * 0.64, Math.max(2, h));
      ctx.globalAlpha = 1;

      ctx.fillStyle = ink;
      ctx.font = '600 11px "App Mono", Consolas, monospace';
      ctx.textAlign = "center";
      ctx.fillText(v.toFixed(2), x + bw * 0.32, y - 6);

      ctx.fillStyle = muted;
      ctx.font = '11px "App Sans", Segoe UI';
      const label = METHOD_LABEL[m] || m;
      ctx.save();
      ctx.translate(pad.l + i * bw + bw / 2, H - 14);
      if (methods.length > 6) {
        ctx.rotate(-0.35);
        ctx.textAlign = "right";
        ctx.fillText(label, 4, 0);
      } else {
        ctx.textAlign = "center";
        ctx.fillText(label, 0, 0);
      }
      ctx.restore();
    });
    ctx.textAlign = "left";
  }

  function renderPaperCmp() {
    const cmp = window.PAPER_CMP || [];
    const focus = cmp.filter((r) => r.pollutant === "PM2.5");
    const rows = focus
      .map((r) => {
        const pw = +r.paper_wave,
          ow = +r.ours_wave;
        return `<tr>
          <td>${r.sensor}</td><td>${r.horizon}</td>
          <td>${pw.toFixed(2)}</td><td>${ow.toFixed(2)}</td>
          <td class="mono">${ow < pw ? "ours lower*" : "paper lower*"}</td>
        </tr>`;
      })
      .join("");
    $("#paperTable").innerHTML = `
      <thead><tr><th>Sensor</th><th>h</th><th>Paper Wave</th><th>Ours Wave</th><th>Note</th></tr></thead>
      <tbody>${rows}</tbody>`;
  }

  function initUpload() {
    const zone = $("#dropzone");
    const input = $("#fileInput");
    $("#pickFile").onclick = () => input.click();
    input.addEventListener("change", () => {
      if (input.files?.[0]) loadFile(input.files[0]);
    });
    ["dragenter", "dragover"].forEach((ev) =>
      zone.addEventListener(ev, (e) => {
        e.preventDefault();
        zone.classList.add("drag");
      })
    );
    ["dragleave", "drop"].forEach((ev) =>
      zone.addEventListener(ev, (e) => {
        e.preventDefault();
        zone.classList.remove("drag");
      })
    );
    zone.addEventListener("drop", (e) => {
      const f = e.dataTransfer.files?.[0];
      if (f) loadFile(f);
    });
    $("#runSnaive").onclick = runSnaive;
    $("#uploadCol").addEventListener("change", () => {
      if (uploadState) {
        uploadState.col = $("#uploadCol").value;
        drawUploadChart();
      }
    });
  }

  function loadFile(file) {
    const reader = new FileReader();
    reader.onload = () => {
      try {
        const parsed = CSVTOOLS.parseCsv(String(reader.result));
        const timeCol = CSVTOOLS.findTimeCol(parsed.headers);
        const cols = CSVTOOLS.numericCols(parsed.headers, parsed.rows, timeCol);
        if (!cols.length) throw new Error("No numeric pollutant columns found.");
        uploadState = {
          name: file.name,
          headers: parsed.headers,
          rows: parsed.rows,
          timeCol,
          cols,
          col: cols.includes("PM2.5") ? "PM2.5" : cols[0],
          last: null,
        };
        $("#uploadCol").innerHTML = cols.map((c) => `<option>${c}</option>`).join("");
        $("#uploadCol").value = uploadState.col;
        $("#uploadTitle").textContent = file.name;
        $("#uploadResult").hidden = false;
        $("#uploadMetrics").innerHTML = [
          metric(String(parsed.rows.length), "rows"),
          metric(timeCol, "time column"),
          metric(String(cols.length), "numeric series"),
          metric("ready", "status"),
        ].join("");
        requestAnimationFrame(drawUploadChart);
      } catch (err) {
        alert(err.message || String(err));
      }
    };
    reader.readAsText(file);
  }

  function runSnaive() {
    if (!uploadState) return;
    const col = $("#uploadCol").value;
    const h = +$("#uploadH").value;
    const S = +$("#uploadS").value;
    uploadState.col = col;
    const pts = CSVTOOLS.seriesFrom(uploadState.rows, uploadState.timeCol, col);
    const y = pts.map((p) => p.y);
    try {
      const { train, test, yhat } = CSVTOOLS.seasonalNaive(y, h, S);
      const mae = CSVTOOLS.mae(test, yhat);
      const rmse = CSVTOOLS.rmse(test, yhat);
      const mase = CSVTOOLS.mase(test, yhat, train, S);
      uploadState.last = { train, test, yhat, mae, rmse, mase, h, S, col };
      $("#uploadMetrics").innerHTML = [
        metric(mase.toFixed(3), "snaive MASE"),
        metric(mae.toFixed(3), "MAE"),
        metric(rmse.toFixed(3), "RMSE"),
        metric(`${h}h / S=${S}`, "holdout / season"),
      ].join("");
      drawUploadChart();
    } catch (err) {
      alert(err.message || String(err));
    }
  }

  function drawUploadChart() {
    const canvas = $("#uploadChart");
    if (!canvas || !uploadState) return;
    const col = uploadState.col || $("#uploadCol").value;
    const pts = CSVTOOLS.seriesFrom(uploadState.rows, uploadState.timeCol, col);
    const y = pts.map((p) => p.y);
    const last = uploadState.last;

    const { ctx, W, H } = fitCanvas(canvas);
    ctx.clearRect(0, 0, W, H);

    const ink = cssVar("--ink");
    const muted = cssVar("--muted");
    const rust = cssVar("--rust");
    const navy = cssVar("--navy");
    const light = isLight();

    let series = y;
    let yhat = null;
    let split = null;
    if (last && last.col === col) {
      series = [...last.train, ...last.test];
      yhat = last.yhat;
      split = last.train.length;
    }

    let lo = Math.min(...series),
      hi = Math.max(...series);
    if (yhat) {
      lo = Math.min(lo, ...yhat);
      hi = Math.max(hi, ...yhat);
    }
    const padY = (hi - lo) * 0.08 || 1;
    lo -= padY;
    hi += padY;

    const x0 = 56,
      x1 = W - 14,
      y0 = 28,
      y1 = H - 32;
    const N = series.length;
    const mx = (i) => x0 + ((x1 - x0) * i) / Math.max(1, N - 1);
    const my = (v) => y1 - ((v - lo) / (hi - lo)) * (y1 - y0);

    drawGrid(ctx, x0, x1, y0, y1, lo, hi, muted);

    function stroke(arr, from, colStroke, w) {
      ctx.beginPath();
      for (let i = 0; i < arr.length; i++) {
        const x = mx(from + i),
          yy = my(arr[i]);
        if (i) ctx.lineTo(x, yy);
        else ctx.moveTo(x, yy);
      }
      ctx.strokeStyle = colStroke;
      ctx.lineWidth = w;
      ctx.lineJoin = "round";
      ctx.stroke();
    }

    stroke(series, 0, light ? navy : "#9ec5ff", 2);
    if (yhat && split != null) {
      ctx.beginPath();
      ctx.moveTo(mx(split), y0);
      ctx.lineTo(mx(split), y1);
      ctx.strokeStyle = muted;
      ctx.setLineDash([4, 4]);
      ctx.lineWidth = 1;
      ctx.stroke();
      ctx.setLineDash([]);
      stroke(Array.from(yhat), split, rust, 2.4);
    }

    ctx.fillStyle = ink;
    ctx.font = '600 13px "App Sans", Segoe UI';
    ctx.fillText(`${uploadState.name} / ${col}`, x0, 16);
    ctx.fillStyle = muted;
    ctx.font = '10px "App Mono", Consolas';
    ctx.fillText(
      yhat ? "dashed line = forecast origin" : "full series; run snaive for holdout",
      x0,
      H - 10
    );
  }

  function observeCharts() {
    if (typeof ResizeObserver === "undefined") return;
    const map = [
      ["#exploreHost", () => drawExplore()],
      ["#scoreBarsHost", () => {
        const s = $("#scoreSensor");
        if (s) renderScores(s.value, $("#scorePol").value, $("#scoreHn").value);
      }],
      ["#uploadChartWrap", () => {
        if (uploadState) drawUploadChart();
      }],
    ];
    map.forEach(([sel, fn]) => {
      const el = $(sel);
      if (el) {
        const ro = new ResizeObserver(() => {
          if ($(".page.on")?.contains(el) || el.offsetParent !== null) fn();
        });
        ro.observe(el);
      }
    });
  }

  fillHome();
  initDatasets();
  initFilm();
  initScores();
  initUpload();
  observeCharts();

  const pages = [
    "home", "datasets", "upload", "film", "explore", "scores", "methods", "share",
  ];
  const start = (location.hash || "#home").replace("#", "") || "home";
  showPage(pages.includes(start) ? start : "home");
})();
