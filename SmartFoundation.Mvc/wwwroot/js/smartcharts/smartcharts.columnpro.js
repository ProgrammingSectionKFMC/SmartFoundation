(function () {
    const NS = "http://www.w3.org/2000/svg";

    function clamp(n, min, max) { return Math.max(min, Math.min(max, n)); }

    function fmtNumber(value, pattern) {
        if (!pattern) return String(value);
        const dot = pattern.indexOf(".");
        if (dot === -1) return String(Math.round(value));
        const decimals = pattern.length - dot - 1;
        const hasHash = pattern.includes("#");
        const fixed = Number(value).toFixed(decimals);
        return hasHash ? fixed.replace(/\.?0+$/, "") : fixed;
    }

    function toneBase(tone) {
        switch ((tone || "").toLowerCase()) {
            case "success": return "#22c55e";
            case "warning": return "#f59e0b";
            case "danger": return "#ef4444";
            case "info": return "#0ea5e9";
            default: return "#334155";
        }
    }

    // تفتيح/تغميق لون HEX
    function shade(hex, p) {
        const n = hex.replace("#", "");
        const r = parseInt(n.substring(0, 2), 16);
        const g = parseInt(n.substring(2, 4), 16);
        const b = parseInt(n.substring(4, 6), 16);
        const t = p < 0 ? 0 : 255;
        const a = Math.abs(p);
        const rr = Math.round((t - r) * a) + r;
        const gg = Math.round((t - g) * a) + g;
        const bb = Math.round((t - b) * a) + b;
        return "#" + [rr, gg, bb].map(x => x.toString(16).padStart(2, "0")).join("");
    }

    function makeSvg(tag, attrs) {
        const el = document.createElementNS(NS, tag);
        if (attrs) for (const k in attrs) el.setAttribute(k, attrs[k]);
        return el;
    }

    function ensureTooltip(host) {
        let tip = host.querySelector(".smart-colpro__tooltip");
        if (tip) return tip;
        tip = document.createElement("div");
        tip.className = "smart-colpro__tooltip";
        tip.innerHTML = `
      <div class="smart-colpro__tt-title"></div>
      <div class="smart-colpro__tt-val"></div>
      <div class="smart-colpro__tt-lines"></div>
    `;
        host.appendChild(tip);
        return tip;
    }

    function niceTicks(max) {
        if (max <= 0) return { max: 1, ticks: [0, .25, .5, .75, 1] };
        const pow = Math.pow(10, Math.floor(Math.log10(max)));
        const n = max / pow;
        const step = (n <= 2) ? 0.5 * pow : (n <= 5) ? 1 * pow : 2 * pow;
        const niceMax = Math.ceil(max / step) * step;
        const ticks = [];
        for (let i = 0; i <= 4; i++) ticks.push((i / 4) * niceMax);
        return { max: niceMax, ticks };
    }

    function estimatePadLeft(tickMax, valueFormat) {
        const s = fmtNumber(tickMax, valueFormat);
        // تقدير عرض النص (تقريبي) لتفادي تداخل أرقام المحور مع الرسم
        const approx = 8 * (s.length + 1);
        return clamp(approx, 54, 86);
    }

    function renderOne(host) {
        const cfgId = host.getAttribute("data-config-id");
        const cfgNode = cfgId ? document.getElementById(cfgId) : null;
        if (!cfgNode) return;

        let cfg;
        try { cfg = JSON.parse(cfgNode.textContent || "{}"); } catch { return; }

        const dir = (cfg.dir || "rtl").toLowerCase();
        const labels = Array.isArray(cfg.labels) ? cfg.labels : [];
        const series = Array.isArray(cfg.series) ? cfg.series : [];
        const hrefs = Array.isArray(cfg.hrefs) ? cfg.hrefs : [];

        const valueFormat = cfg.valueFormat || "0";
        const minBarWidth = clamp(Number(cfg.minBarWidth ?? 56), 44, 92);
        const H = clamp(Number(cfg.height ?? 280), 200, 460);
        const showValues = !!cfg.showValues;

        const tone = cfg.tone || "neutral";
        const base = toneBase(tone);

        host.innerHTML = "";
        host.setAttribute("dir", dir);

        const nCats = labels.length;
        if (nCats <= 0 || series.length <= 0) {
            const empty = document.createElement("div");
            empty.className = "smart-colpro__empty";
            empty.textContent = "لا توجد بيانات";
            host.appendChild(empty);
            return;
        }

        // Normalize series data lengths
        const sCount = series.length;
        const data = series.map(s => {
            const arr = Array.isArray(s.data) ? s.data : [];
            const out = [];
            for (let i = 0; i < nCats; i++) out.push(Number(arr[i]) || 0);
            return { name: String(s.name || "Series"), data: out };
        });

        // Find max across all series
        let rawMax = 0;
        for (const s of data) for (const v of s.data) rawMax = Math.max(rawMax, v);
        const tick = niceTicks(rawMax);

        // Layout
        //const padT = 16, padB = 54, padR = 18;
        //const padL = estimatePadLeft(tick.max, valueFormat);
        // Layout
        const isRTL = dir === "rtl";

        const padT = 16, padB = 54;
        const padAxis = estimatePadLeft(tick.max, valueFormat);

        // ✅ في RTL نخلي مساحة المحور يمين
        const padL = isRTL ? 18 : padAxis;
        const padR = isRTL ? padAxis : 18;


        // 3D depth in px (SVG coords)
        const depth = 10;               // سماكة 3D
        const topLift = 6;              // رفع الوجه العلوي
        const groupGap = 18;            // مسافة بين المجموعات (الأحياء)
        const innerGap = 10;            // مسافة بين أعمدة السلاسل داخل المجموعة

        // Decide widths
        // نحدد عرض المجموعة بناء على عدد السلاسل
        const barW = clamp(minBarWidth, 44, 92);
        const groupW = (sCount * barW) + ((sCount - 1) * innerGap);
        const plotWMin = nCats * groupW + (nCats - 1) * groupGap;

        const W = Math.max(640, padL + padR + plotWMin + 10);
        const plotW = W - padL - padR;
        const plotH = H - padT - padB;

        const scroller = document.createElement("div");
        scroller.className = "smart-colpro__scroller";
        host.appendChild(scroller);

        const canvas = document.createElement("div");
        canvas.className = "smart-colpro__canvas";
        canvas.style.width = `${W}px`;
        scroller.appendChild(canvas);

        const svg = makeSvg("svg", { class: "smart-colpro__svg", viewBox: `0 0 ${W} ${H}` });
        canvas.appendChild(svg);

        const tipEl = ensureTooltip(host);

        // Unique defs ids per chart (avoid collisions)
        const uid = (cfg.id || ("c" + Math.random().toString(16).slice(2)));
        const shadowId = `colpro_shadow_${uid}`;
        const gradIdBase = `colpro_grad_${uid}_`; // + i
        const clipId = `colpro_clip_${uid}`;

        // defs: shadow + clip
        const defs = makeSvg("defs");

        const f = makeSvg("filter", {
            id: shadowId,
            x: "-20%", y: "-20%", width: "140%", height: "160%"
        });
        f.appendChild(makeSvg("feDropShadow", {
            dx: "0", dy: "10", stdDeviation: "10",
            "flood-color": "#020617", "flood-opacity": "0.20"
        }));
        defs.appendChild(f);

        // clip for plot area (keep 3D parts inside)
        const clip = makeSvg("clipPath", { id: clipId });
        clip.appendChild(makeSvg("rect", { x: padL, y: padT, width: plotW, height: plotH + 2, rx: 10 }));
        defs.appendChild(clip);

        // gradients per series
        for (let si = 0; si < sCount; si++) {
            const g = makeSvg("linearGradient", { id: gradIdBase + si, x1: "0", y1: "0", x2: "0", y2: "1" });
            // base hue shift for multi-series (خفيف) بدون تغيير واضح لهوية اللون
            const base2 = (si === 0) ? base : shade(base, si * -0.10);
            g.appendChild(makeSvg("stop", { offset: "0%", "stop-color": shade(base2, 0.18), "stop-opacity": "1" }));
            g.appendChild(makeSvg("stop", { offset: "60%", "stop-color": base2, "stop-opacity": "1" }));
            g.appendChild(makeSvg("stop", { offset: "100%", "stop-color": shade(base2, -0.18), "stop-opacity": "1" }));
            defs.appendChild(g);
        }

        svg.appendChild(defs);

        // Grid + y labels
        for (let k = 0; k <= 4; k++) {
            const y = padT + (k / 4) * plotH;
            svg.appendChild(makeSvg("line", {
                x1: padL, x2: W - padR,
                y1: y, y2: y,
                stroke: "#e2e8f0", "stroke-width": "1"
            }));

            const val = tick.max - (k / 4) * tick.max;
            const t = makeSvg("text", {
                // ✅ في RTL الأرقام تكون يمين الرسم
                x: isRTL ? (W - padR + 12) : (padL - 12),
                y: y + 4,
                "text-anchor": isRTL ? "start" : "end",
                fill: "#64748b",
                "font-size": "11"
            });

            t.textContent = fmtNumber(val, valueFormat);
            svg.appendChild(t);
        }

        // Helpers
        function yAt(v) {
            const t = tick.max > 0 ? (v / tick.max) : 0;
            return padT + (1 - clamp(t, 0, 1)) * plotH;
        }

        function groupX(i) {
            // RTL/LTR كلاهما داخل SVG نفس الإحداثيات، بس النصوص بالاتجاه العام للصفحة
            return padL + i * (groupW + groupGap);
        }

        // Bars layer clipped
        const barsLayer = makeSvg("g", { "clip-path": `url(#${clipId})` });
        svg.appendChild(barsLayer);

        // Draw per category
        for (let ci = 0; ci < nCats; ci++) {
            const gx = groupX(ci);

            // X label centered for the group
            const label = makeSvg("text", {
                x: gx + groupW / 2,
                y: H - 18,
                "text-anchor": "middle",
                fill: "#475569",
                "font-size": "11"
            });

            // لو النص طويل ومزدحم: لفّ خفيف
            const txt = String(labels[ci] ?? "");
            label.textContent = txt;
            if (txt.length >= 8 && nCats >= 7) {
                label.setAttribute("transform", `rotate(-18 ${gx + groupW / 2} ${H - 18})`);
                label.setAttribute("text-anchor", "end");
            }
            svg.appendChild(label);

            // Per series in group
            for (let si = 0; si < sCount; si++) {
                const v = data[si].data[ci];
                const x = gx + si * (barW + innerGap);
                const y = yAt(v);
                const h = (padT + plotH) - y;

                // 3D colors
                const base2 = (si === 0) ? base : shade(base, si * -0.10);
                const topCol = shade(base2, 0.22);
                const sideCol = shade(base2, -0.18);

                // Group for this bar
                const g = makeSvg("g", {});
                barsLayer.appendChild(g);

                // Front face (gradient)
                const front = makeSvg("rect", {
                    x: x,
                    y: padT + plotH,
                    width: barW,
                    height: 0,
                    rx: 10,
                    fill: `url(#${gradIdBase + si})`,
                    opacity: "0.98"
                });
                g.appendChild(front);

                // Side face (polygon) - right side
                const side = makeSvg("path", {
                    d: "",
                    fill: sideCol,
                    opacity: "0.95"
                });
                g.appendChild(side);

                // Top face (polygon)
                const top = makeSvg("path", {
                    d: "",
                    fill: topCol,
                    opacity: "0.98"
                });
                g.appendChild(top);

                // Value text (optional)
                const valText = makeSvg("text", {
                    x: x + barW / 2,
                    y: y - 10,
                    "text-anchor": "middle",
                    fill: "#0f172a",
                    "font-size": "11",
                    "font-weight": "800",
                    opacity: showValues ? "1" : "0"
                });
                valText.textContent = fmtNumber(v, valueFormat);
                svg.appendChild(valText);

                // Hit area per bar
                const hit = makeSvg("rect", {
                    x: x,
                    y: padT,
                    width: barW,
                    height: plotH,
                    fill: "transparent",
                    cursor: (hrefs[ci] ? "pointer" : "default")
                });
                svg.appendChild(hit);

                function set3DPaths(currY, currH) {
                    const y0 = currY;
                    const y1 = currY + currH;

                    // front rect already handles y/height
                    // side: from (x+barW,y0) to (x+barW+depth,y0-topLift) to (x+barW+depth,y1-topLift) to (x+barW,y1)
                    const sx0 = x + barW, sx1 = x + barW + depth;
                    const sy0 = y0, sy0b = y0 - topLift;
                    const sy1 = y1, sy1b = y1 - topLift;

                    side.setAttribute("d",
                        `M ${sx0} ${sy0} L ${sx1} ${sy0b} L ${sx1} ${sy1b} L ${sx0} ${sy1} Z`
                    );

                    // top: (x,y0) (x+barW,y0) (x+barW+depth,y0-topLift) (x+depth,y0-topLift)
                    top.setAttribute("d",
                        `M ${x} ${sy0} L ${x + barW} ${sy0} L ${sx1} ${sy0b} L ${x + depth} ${sy0b} Z`
                    );
                }

                // Hover + tooltip
                hit.addEventListener("mousemove", (e) => {
                    front.setAttribute("filter", `url(#${shadowId})`);
                    front.setAttribute("opacity", "1");
                    side.setAttribute("opacity", "1");
                    top.setAttribute("opacity", "1");
                    if (!showValues) valText.setAttribute("opacity", "1");

                    const title = String(labels[ci] ?? "");
                    const total = data.reduce((sum, s) => sum + (Number(s.data[ci]) || 0), 0);

                    tipEl.querySelector(".smart-colpro__tt-title").textContent = title;
                    tipEl.querySelector(".smart-colpro__tt-val").textContent =
                        (sCount > 1)
                            ? (`الإجمالي: ${fmtNumber(total, valueFormat)}`)
                            : fmtNumber(v, valueFormat);

                    const lines = (sCount > 1)
                        ? data.map((s, idx) => `${s.name}: ${fmtNumber(s.data[ci], valueFormat)}`).join("\n")
                        : `${data[si].name}: ${fmtNumber(v, valueFormat)}`;

                    tipEl.querySelector(".smart-colpro__tt-lines").textContent = lines;

                    const rectHost = host.getBoundingClientRect();
                    tipEl.style.transform = `translate(${(e.clientX - rectHost.left) + 12}px, ${(e.clientY - rectHost.top) + 12}px)`;
                    tipEl.classList.add("is-show");
                });

                hit.addEventListener("mouseleave", () => {
                    front.removeAttribute("filter");
                    front.setAttribute("opacity", "0.98");
                    side.setAttribute("opacity", "0.95");
                    top.setAttribute("opacity", "0.98");
                    if (!showValues) valText.setAttribute("opacity", "0");
                    tipEl.classList.remove("is-show");
                });

                if (hrefs[ci]) {
                    hit.addEventListener("click", () => window.location.href = hrefs[ci]);
                }

                // Animate
                requestAnimationFrame(() => {
                    front.style.transition = "y 850ms cubic-bezier(.2,.8,.2,1), height 850ms cubic-bezier(.2,.8,.2,1)";
                    front.setAttribute("y", String(y));
                    front.setAttribute("height", String(h));
                    set3DPaths(y, h);

                    // update 3D after animation starts (simple)
                    setTimeout(() => set3DPaths(y, h), 30);
                });

                // Keep paths synced on transition end
                front.addEventListener("transitionend", () => set3DPaths(Number(front.getAttribute("y")), Number(front.getAttribute("height"))));
            }
        }
    }

    function renderAll() {
        document.querySelectorAll(".smart-colpro[data-config-id]").forEach(renderOne);
    }

    if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", renderAll);
    else renderAll();

    window.SmartCharts = window.SmartCharts || {};
    window.SmartCharts.renderColumnPro = renderAll;
})();
