(function () {
    const NS = "http://www.w3.org/2000/svg";
    function clamp(n, min, max) { return Math.max(min, Math.min(max, n)); }

    function fmtNumber(value, pattern) {
        if (!pattern) return String(Math.round(value));
        const dot = pattern.indexOf(".");
        if (dot === -1) return String(Math.round(value));
        const decimals = pattern.length - dot - 1;
        const hasHash = pattern.includes("#");
        const fixed = Number(value).toFixed(decimals);
        return hasHash ? fixed.replace(/\.?0+$/, "") : fixed;
    }

    function makeSvg(tag, attrs) {
        const el = document.createElementNS(NS, tag);
        if (attrs) for (const k in attrs) el.setAttribute(k, attrs[k]);
        return el;
    }

    function toneNeutral(tone) {
        switch ((tone || "").toLowerCase()) {
            case "info": return "#0ea5e9";
            case "success": return "#22c55e";
            case "warning": return "#f59e0b";
            case "danger": return "#ef4444";
            default: return "#334155";
        }
    }

    function ensureTooltip(host) {
        let tip = host.querySelector(".smart-wf__tooltip");
        if (tip) return tip;
        tip = document.createElement("div");
        tip.className = "smart-wf__tooltip";
        tip.innerHTML = `<div class="smart-wf__tt-title"></div><div class="smart-wf__tt-val"></div><div class="smart-wf__tt-sub"></div>`;
        host.appendChild(tip);
        return tip;
    }

    function niceTicks(minV, maxV) {
        const span = maxV - minV;
        const safe = span <= 0 ? 1 : span;
        const pow = Math.pow(10, Math.floor(Math.log10(safe)));
        const n = safe / pow;
        const step = (n <= 2) ? 0.5 * pow : (n <= 5) ? 1 * pow : 2 * pow;
        const niceMin = Math.floor(minV / step) * step;
        const niceMax = Math.ceil(maxV / step) * step;
        const ticks = [];
        for (let i = 0; i <= 4; i++) ticks.push(niceMin + (i / 4) * (niceMax - niceMin));
        return { min: niceMin, max: niceMax, ticks };
    }

    function estimatePadLeft(tickMaxAbs, valueFormat) {
        const s = fmtNumber(tickMaxAbs, valueFormat);
        const approx = 8 * (s.length + 2);
        return clamp(approx, 54, 96);
    }

    function renderOne(host) {
        const cfgId = host.getAttribute("data-config-id");
        const cfgNode = cfgId ? document.getElementById(cfgId) : null;
        if (!cfgNode) return;

        let cfg;
        try { cfg = JSON.parse(cfgNode.textContent || "{}"); } catch { return; }

        const dir = (cfg.dir || "rtl").toLowerCase();
        const tone = cfg.tone || "neutral";
        const valueFormat = cfg.valueFormat || "0";
        const H = clamp(Number(cfg.height ?? 280), 200, 440);
        const minBarWidth = clamp(Number(cfg.minBarWidth ?? 72), 56, 120);
        const showValues = !!cfg.showValues;

        const stepsRaw = Array.isArray(cfg.steps) ? cfg.steps : [];
        host.innerHTML = "";
        host.setAttribute("dir", dir);

        if (!stepsRaw.length) return;

        // colors
        const base = toneNeutral(tone);
        const posCol = "#16a34a";
        const negCol = "#ef4444";
        const totalCol = base;

        // compute running totals
        const steps = stepsRaw.map(s => ({
            label: String(s.label ?? ""),
            value: Number(s.value) || 0,
            isTotal: !!s.isTotal,
            color: s.color ? String(s.color) : null,
            href: s.href ? String(s.href) : ""
        }));

        const points = []; // {start,end,delta,isTotal}
        let run = 0;
        for (const st of steps) {
            if (st.isTotal) {
                points.push({ start: 0, end: st.value, delta: st.value, isTotal: true });
                run = st.value;
            } else {
                const start = run;
                const end = run + st.value;
                points.push({ start, end, delta: st.value, isTotal: false });
                run = end;
            }
        }

        // range
        let minV = 0, maxV = 0;
        for (const p of points) {
            minV = Math.min(minV, p.start, p.end);
            maxV = Math.max(maxV, p.start, p.end);
        }
        const ticks = niceTicks(minV, maxV);
        const padT = 16, padB = 54, padR = 18;
        const padL = estimatePadLeft(Math.max(Math.abs(ticks.min), Math.abs(ticks.max)), valueFormat);
        const plotH = H - padT - padB;

        const gap = 18;
        const W = Math.max(640, padL + padR + steps.length * minBarWidth + (steps.length - 1) * gap + 20);
        const plotW = W - padL - padR;

        const scroller = document.createElement("div");
        scroller.className = "smart-wf__scroller";
        host.appendChild(scroller);

        const canvas = document.createElement("div");
        canvas.className = "smart-wf__canvas";
        canvas.style.width = `${W}px`;
        scroller.appendChild(canvas);

        const svg = makeSvg("svg", { class: "smart-wf__svg", viewBox: `0 0 ${W} ${H}` });
        canvas.appendChild(svg);

        const tip = ensureTooltip(host);

        // defs shadow
        const uid = (cfg.id || ("wf" + Math.random().toString(16).slice(2)));
        const shadowId = `wf_shadow_${uid}`;
        const defs = makeSvg("defs");
        const f = makeSvg("filter", { id: shadowId, x: "-20%", y: "-20%", width: "140%", height: "160%" });
        f.appendChild(makeSvg("feDropShadow", {
            dx: "0", dy: "10", stdDeviation: "10",
            "flood-color": "#020617", "flood-opacity": "0.18"
        }));
        defs.appendChild(f);
        svg.appendChild(defs);

        function yAt(v) {
            const t = (v - ticks.min) / (ticks.max - ticks.min || 1);
            return padT + (1 - clamp(t, 0, 1)) * plotH;
        }

        // grid + y labels
        for (let k = 0; k <= 4; k++) {
            const y = padT + (k / 4) * plotH;
            svg.appendChild(makeSvg("line", { x1: padL, x2: W - padR, y1: y, y2: y, stroke: "#e2e8f0", "stroke-width": "1" }));
            const val = ticks.max - (k / 4) * (ticks.max - ticks.min);
            const t = makeSvg("text", { x: padL - 10, y: y + 4, "text-anchor": "end", fill: "#64748b", "font-size": "11" });
            t.textContent = fmtNumber(val, valueFormat);
            svg.appendChild(t);
        }

        // zero line
        const yZero = yAt(0);
        svg.appendChild(makeSvg("line", { x1: padL, x2: W - padR, y1: yZero, y2: yZero, stroke: "#cbd5e1", "stroke-width": "1.5" }));

        // bars
        const barW = Math.max(44, Math.min(minBarWidth, (plotW - gap * (steps.length - 1)) / steps.length));
        const r = 10;

        function xAt(i) { return padL + i * (barW + gap); }

        for (let i = 0; i < steps.length; i++) {
            const st = steps[i];
            const p = points[i];

            const x = xAt(i);
            const y1 = yAt(p.start);
            const y2 = yAt(p.end);
            const top = Math.min(y1, y2);
            const bot = Math.max(y1, y2);
            const h = Math.max(6, bot - top);

            const color =
                st.color ? st.color :
                    p.isTotal ? totalCol :
                        (p.delta >= 0 ? posCol : negCol);

            // connector from previous end
            if (i > 0) {
                const prevEndY = yAt(points[i - 1].end);
                const cx1 = xAt(i - 1) + barW;
                const cx2 = xAt(i);
                svg.appendChild(makeSvg("line", { x1: cx1, x2: cx2, y1: prevEndY, y2: prevEndY, stroke: "#94a3b8", "stroke-width": "2", "stroke-dasharray": "3 3" }));
            }

            const rect = makeSvg("rect", {
                x, y: bot, width: barW, height: 0,
                rx: r, fill: color, opacity: "0.96"
            });
            svg.appendChild(rect);

            // label
            const lab = makeSvg("text", {
                x: x + barW / 2,
                y: H - 18,
                "text-anchor": "middle",
                fill: "#475569",
                "font-size": "11"
            });
            lab.textContent = st.label;
            svg.appendChild(lab);

            // value text
            const valText = makeSvg("text", {
                x: x + barW / 2,
                y: top - 8,
                "text-anchor": "middle",
                fill: "#0f172a",
                "font-size": "11",
                "font-weight": "900",
                opacity: showValues ? "1" : "0"
            });
            valText.textContent = p.isTotal ? fmtNumber(p.end, valueFormat) : ((p.delta >= 0 ? "+" : "") + fmtNumber(p.delta, valueFormat));
            svg.appendChild(valText);

            // hit
            const hit = makeSvg("rect", {
                x, y: padT,
                width: barW, height: plotH,
                fill: "transparent",
                cursor: st.href ? "pointer" : "default"
            });
            svg.appendChild(hit);

            hit.addEventListener("mousemove", (e) => {
                rect.setAttribute("filter", `url(#${shadowId})`);
                rect.setAttribute("opacity", "1");
                if (!showValues) valText.setAttribute("opacity", "1");

                tip.querySelector(".smart-wf__tt-title").textContent = st.label;
                const deltaTxt = p.isTotal ? `الإجمالي: ${fmtNumber(p.end, valueFormat)}` : `التغير: ${(p.delta >= 0 ? "+" : "")}${fmtNumber(p.delta, valueFormat)}`;
                tip.querySelector(".smart-wf__tt-val").textContent = deltaTxt;
                tip.querySelector(".smart-wf__tt-sub").textContent = `الرصيد بعد الخطوة: ${fmtNumber(p.end, valueFormat)}`;

                const rectHost = host.getBoundingClientRect();
                tip.style.transform = `translate(${(e.clientX - rectHost.left) + 12}px, ${(e.clientY - rectHost.top) + 12}px)`;
                tip.classList.add("is-show");
            });

            hit.addEventListener("mouseleave", () => {
                rect.removeAttribute("filter");
                rect.setAttribute("opacity", "0.96");
                if (!showValues) valText.setAttribute("opacity", "0");
                tip.classList.remove("is-show");
            });

            if (st.href) hit.addEventListener("click", () => window.location.href = st.href);

            // animate
            requestAnimationFrame(() => {
                rect.style.transition = "y 850ms cubic-bezier(.2,.8,.2,1), height 850ms cubic-bezier(.2,.8,.2,1)";
                rect.setAttribute("y", String(top));
                rect.setAttribute("height", String(h));
            });
        }
    }

    function renderAll() {
        document.querySelectorAll(".smart-wf[data-config-id]").forEach(renderOne);
    }

    if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", renderAll);
    else renderAll();

    window.SmartCharts = window.SmartCharts || {};
    window.SmartCharts.renderWaterfall = renderAll;
})();
