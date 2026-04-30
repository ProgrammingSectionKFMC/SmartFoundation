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

    function ensureTooltip(host) {
        let tip = host.querySelector(".smart-line__tooltip");
        if (tip) return tip;
        tip = document.createElement("div");
        tip.className = "smart-line__tooltip";
        tip.innerHTML = `<div class="smart-line__tt-title"></div>
                     <div class="smart-line__tt-val"></div>`;
        host.appendChild(tip);
        return tip;
    }

    function renderOne(host) {
        const cfgId = host.getAttribute("data-config-id");
        const cfgNode = cfgId ? document.getElementById(cfgId) : null;
        if (!cfgNode) return;

        let cfg;
        try { cfg = JSON.parse(cfgNode.textContent || "{}"); } catch { return; }

        const xLabels = Array.isArray(cfg.xLabels) ? cfg.xLabels : [];
        const series = Array.isArray(cfg.series) ? cfg.series : [];
        const dir = (cfg.dir || "rtl").toLowerCase();
        const showDots = !!cfg.showDots;
        const showGrid = !!cfg.showGrid;
        const fillArea = !!cfg.fillArea;
        const valueFormat = cfg.valueFormat || "0";
        const maxXTicks = clamp(Number(cfg.maxXTicks ?? 6), 2, 12);

        host.innerHTML = "";
        host.setAttribute("dir", dir);

        if (xLabels.length === 0 || series.length === 0 || !Array.isArray(series[0].data)) {
            const empty = document.createElement("div");
            empty.className = "smart-line__empty";
            empty.textContent = "لا توجد بيانات";
            host.appendChild(empty);
            return;
        }

        const data = series[0].data.map(n => Number(n) || 0);
        const n = Math.min(xLabels.length, data.length);
        if (n <= 1) {
            const empty = document.createElement("div");
            empty.className = "smart-line__empty";
            empty.textContent = "بيانات غير كافية";
            host.appendChild(empty);
            return;
        }

        // compute min/max
        let minV = Math.min(...data.slice(0, n));
        let maxV = Math.max(...data.slice(0, n));
        if (minV === maxV) { minV -= 1; maxV += 1; }

        // Layout
        const wrap = document.createElement("div");
        wrap.className = "smart-line__wrap";
        host.appendChild(wrap);

        const svg = document.createElementNS(NS, "svg");
        svg.setAttribute("class", "smart-line__svg");
        svg.setAttribute("viewBox", "0 0 600 240");
        wrap.appendChild(svg);

        const tip = ensureTooltip(host);

        const W = 600, H = 240;
        const padL = 48, padR = 18, padT = 14, padB = 40;
        const plotW = W - padL - padR;
        const plotH = H - padT - padB;

        function xAt(i) {
            const t = i / (n - 1);
            return padL + t * plotW;
        }
        function yAt(v) {
            const t = (v - minV) / (maxV - minV);
            return padT + (1 - t) * plotH;
        }

        // Grid + Y ticks (4 خطوط)
        if (showGrid) {
            for (let k = 0; k <= 4; k++) {
                const y = padT + (k / 4) * plotH;
                const line = document.createElementNS(NS, "line");
                line.setAttribute("x1", padL);
                line.setAttribute("x2", W - padR);
                line.setAttribute("y1", y);
                line.setAttribute("y2", y);
                line.setAttribute("class", "smart-line__grid");
                svg.appendChild(line);

                const val = maxV - (k / 4) * (maxV - minV);
                const t = document.createElementNS(NS, "text");
                t.setAttribute("x", padL - 10);
                t.setAttribute("y", y + 4);
                t.setAttribute("text-anchor", "end");
                t.setAttribute("class", "smart-line__ytext");
                t.textContent = fmtNumber(val, valueFormat);
                svg.appendChild(t);
            }
        }

        // X ticks
        const step = Math.ceil(n / maxXTicks);
        for (let i = 0; i < n; i += step) {
            const x = xAt(i);
            const t = document.createElementNS(NS, "text");
            t.setAttribute("x", x);
            t.setAttribute("y", H - 16);
            t.setAttribute("text-anchor", "middle");
            t.setAttribute("class", "smart-line__xtext");
            t.textContent = String(xLabels[i] ?? "");
            svg.appendChild(t);
        }

        // Path (line)
        let d = "";
        for (let i = 0; i < n; i++) {
            const x = xAt(i);
            const y = yAt(data[i]);
            d += (i === 0 ? `M ${x} ${y}` : ` L ${x} ${y}`);
        }

        // Area fill
        if (fillArea) {
            const dArea = `${d} L ${xAt(n - 1)} ${padT + plotH} L ${xAt(0)} ${padT + plotH} Z`;
            const area = document.createElementNS(NS, "path");
            area.setAttribute("d", dArea);
            area.setAttribute("class", "smart-line__area");
            svg.appendChild(area);
        }

        const path = document.createElementNS(NS, "path");
        path.setAttribute("d", d);
        path.setAttribute("class", "smart-line__path");
        svg.appendChild(path);

        // Dots + hover zones
        for (let i = 0; i < n; i++) {
            const x = xAt(i);
            const y = yAt(data[i]);

            // hover rect (عمود شفاف)
            const hit = document.createElementNS(NS, "rect");
            hit.setAttribute("x", x - (plotW / (n - 1)) / 2);
            hit.setAttribute("y", padT);
            hit.setAttribute("width", (plotW / (n - 1)));
            hit.setAttribute("height", plotH);
            hit.setAttribute("class", "smart-line__hit");
            hit.addEventListener("mousemove", (e) => {
                tip.querySelector(".smart-line__tt-title").textContent = String(xLabels[i] ?? "");
                tip.querySelector(".smart-line__tt-val").textContent = fmtNumber(data[i], valueFormat);

                const rect = host.getBoundingClientRect();
                tip.style.transform = `translate(${(e.clientX - rect.left) + 10}px, ${(e.clientY - rect.top) + 10}px)`;
                tip.classList.add("is-show");
            });
            hit.addEventListener("mouseleave", () => tip.classList.remove("is-show"));
            svg.appendChild(hit);

            if (showDots) {
                const c = document.createElementNS(NS, "circle");
                c.setAttribute("cx", x);
                c.setAttribute("cy", y);
                c.setAttribute("r", "3.2");
                c.setAttribute("class", "smart-line__dot");
                svg.appendChild(c);
            }
        }
    }

    function renderAll() {
        document.querySelectorAll(".smart-line[data-config-id]").forEach(renderOne);
    }

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", renderAll);
    } else {
        renderAll();
    }

    window.SmartCharts = window.SmartCharts || {};
    window.SmartCharts.renderLines = renderAll;
})();
