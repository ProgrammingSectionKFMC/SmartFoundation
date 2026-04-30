(function () {
    const NS = "http://www.w3.org/2000/svg";

    function clamp(n, min, max) { return Math.max(min, Math.min(max, n)); }

    function fmtNumber(value, pattern) {
        // pattern مثل "0" أو "0.0" أو "0.##"
        // تطبيق بسيط: نشتق عدد المنازل من pattern
        if (!pattern) return String(value);
        const dot = pattern.indexOf(".");
        if (dot === -1) return String(Math.round(value));
        const decimals = pattern.length - dot - 1;
        // لو فيه # ما نجبرها
        const hasHash = pattern.includes("#");
        const fixed = Number(value).toFixed(decimals);
        if (!hasHash) return fixed;
        // إزالة أصفار النهاية
        return fixed.replace(/\.?0+$/, "");
    }

    function polarToCartesian(cx, cy, r, angleDeg) {
        const rad = (angleDeg - 90) * Math.PI / 180;
        return { x: cx + r * Math.cos(rad), y: cy + r * Math.sin(rad) };
    }

    function arcPath(cx, cy, rOuter, rInner, startAngle, endAngle) {
        const startOuter = polarToCartesian(cx, cy, rOuter, endAngle);
        const endOuter = polarToCartesian(cx, cy, rOuter, startAngle);
        const startInner = polarToCartesian(cx, cy, rInner, startAngle);
        const endInner = polarToCartesian(cx, cy, rInner, endAngle);

        const largeArc = (endAngle - startAngle) > 180 ? 1 : 0;

        // Donut slice using two arcs
        return [
            `M ${startOuter.x} ${startOuter.y}`,
            `A ${rOuter} ${rOuter} 0 ${largeArc} 0 ${endOuter.x} ${endOuter.y}`,
            `L ${startInner.x} ${startInner.y}`,
            `A ${rInner} ${rInner} 0 ${largeArc} 1 ${endInner.x} ${endInner.y}`,
            "Z"
        ].join(" ");
    }

    function ensureTooltip(host) {
        let tip = host.querySelector(".smart-donut__tooltip");
        if (tip) return tip;

        tip = document.createElement("div");
        tip.className = "smart-donut__tooltip";
        tip.innerHTML = `<div class="smart-donut__tooltip-title"></div>
                     <div class="smart-donut__tooltip-val"></div>`;
        host.appendChild(tip);
        return tip;
    }

    function palette(i) {
        // ألوان افتراضية معقولة (بدون مكتبات)
        const p = [
            "#0ea5e9", "#22c55e", "#f59e0b", "#ef4444", "#8b5cf6",
            "#14b8a6", "#f97316", "#64748b", "#e11d48", "#84cc16"
        ];
        return p[i % p.length];
    }

    function renderOne(host) {
        const cfgId = host.getAttribute("data-config-id");
        const cfgNode = cfgId ? document.getElementById(cfgId) : null;
        if (!cfgNode) return;

        let cfg;
        try { cfg = JSON.parse(cfgNode.textContent || "{}"); } catch { return; }

        const slices = Array.isArray(cfg.slices) ? cfg.slices : [];
        const total = slices.reduce((a, s) => a + (Number(s.value) || 0), 0);
        const dir = (cfg.dir || "rtl").toLowerCase();
        const mode = (cfg.mode || "donut").toLowerCase();
        const thickness = clamp(Number(cfg.thickness ?? 0.28), 0.05, 0.49);
        const showLegend = !!cfg.showLegend;
        const showCenterText = !!cfg.showCenterText;
        const valueFormat = cfg.valueFormat || "0";

        host.innerHTML = "";
        host.setAttribute("dir", dir);

        // Empty state
        if (!total || total <= 0 || slices.length === 0) {
            const empty = document.createElement("div");
            empty.className = "smart-donut__empty";
            empty.textContent = "لا توجد بيانات";
            host.appendChild(empty);
            return;
        }

        // Layout container
        const wrap = document.createElement("div");
        wrap.className = "smart-donut__wrap";
        host.appendChild(wrap);

        // Chart area
        const chart = document.createElement("div");
        chart.className = "smart-donut__chart";
        wrap.appendChild(chart);

        // SVG
        const size = 220; // ثابت وبسيط، CSS يخليه responsive
        const cx = size / 2;
        const cy = size / 2;
        const rOuter = 90;
        const rInner = mode === "pie" ? 0 : Math.max(1, rOuter * (1 - thickness));

        const svg = document.createElementNS(NS, "svg");
        svg.setAttribute("viewBox", `0 0 ${size} ${size}`);
        svg.setAttribute("class", "smart-donut__svg");
        chart.appendChild(svg);

        // Center text
        const center = document.createElement("div");
        center.className = "smart-donut__center";
        chart.appendChild(center);

        if (showCenterText) {
            center.innerHTML = `
        <div class="smart-donut__center-total">${fmtNumber(total, valueFormat)}</div>
        <div class="smart-donut__center-label">الإجمالي</div>
      `;
        } else {
            center.style.display = "none";
        }

        const tip = ensureTooltip(host);

        // Draw slices
        let angle = 0;
        slices.forEach((s, idx) => {
            const v = Number(s.value) || 0;
            if (v <= 0) return;

            const frac = v / total;
            const delta = frac * 360;

            // Avoid 360deg exact (SVG edge case)
            const start = angle;
            const end = Math.min(angle + delta, 359.999);

            const path = document.createElementNS(NS, "path");
            path.setAttribute("d", arcPath(cx, cy, rOuter, rInner, start, end));

            const color = s.color || palette(idx);
            path.setAttribute("fill", color);
            path.setAttribute("class", "smart-donut__slice");

            const label = (s.label || "").toString();
            const displayValue = (s.displayValue && String(s.displayValue).trim().length)
                ? String(s.displayValue)
                : fmtNumber(v, valueFormat);

            const pct = (frac * 100);
            const pctText = (pct < 0.1) ? "<0.1%" : `${pct.toFixed(1)}%`;

            path.addEventListener("mousemove", (e) => {
                tip.querySelector(".smart-donut__tooltip-title").textContent = label;
                tip.querySelector(".smart-donut__tooltip-val").textContent = `${displayValue} • ${pctText}`;

                const rect = host.getBoundingClientRect();
                const x = e.clientX - rect.left;
                const y = e.clientY - rect.top;

                tip.style.transform = `translate(${x + 10}px, ${y + 10}px)`;
                tip.classList.add("is-show");
            });

            path.addEventListener("mouseleave", () => {
                tip.classList.remove("is-show");
            });

            svg.appendChild(path);
            angle += delta;
        });

        // Legend
        if (showLegend) {
            const legend = document.createElement("div");
            legend.className = "smart-donut__legend";
            wrap.appendChild(legend);

            slices.forEach((s, idx) => {
                const v = Number(s.value) || 0;
                if (v <= 0) return;

                const color = s.color || palette(idx);
                const frac = v / total;
                const pct = frac * 100;
                const pctText = (pct < 0.1) ? "<0.1%" : `${pct.toFixed(1)}%`;

                const row = document.createElement("div");
                row.className = "smart-donut__legend-row";
                row.innerHTML = `
          <span class="smart-donut__dot" style="background:${color}"></span>
          <span class="smart-donut__legend-label"></span>
          <span class="smart-donut__legend-meta">${pctText}</span>
        `;
                row.querySelector(".smart-donut__legend-label").textContent = (s.label || "");
                legend.appendChild(row);
            });
        }
    }

    function renderAll() {
        document.querySelectorAll(".smart-donut[data-config-id]").forEach(renderOne);
    }

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", renderAll);
    } else {
        renderAll();
    }

    // لو عندك تحديثات AJAX/Partial reload تقدر تنادي:
    window.SmartCharts = window.SmartCharts || {};
    window.SmartCharts.renderDonuts = renderAll;
})();
