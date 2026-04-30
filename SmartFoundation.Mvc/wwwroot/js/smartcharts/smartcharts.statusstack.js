(function () {
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

    function defaultPalette() {
        // Occupied / Vacant / Maintenance / Blocked
        return ["#16a34a", "#0ea5e9", "#f59e0b", "#64748b"];
    }

    function ensureTooltip(host) {
        let tip = host.querySelector(".smart-sst__tooltip");
        if (tip) return tip;
        tip = document.createElement("div");
        tip.className = "smart-sst__tooltip";
        tip.innerHTML = `<div class="smart-sst__tt-title"></div><div class="smart-sst__tt-val"></div>`;
        host.appendChild(tip);
        return tip;
    }

    function renderOne(host) {
        const cfgId = host.getAttribute("data-config-id");
        const cfgNode = cfgId ? document.getElementById(cfgId) : null;
        if (!cfgNode) return;

        let cfg;
        try { cfg = JSON.parse(cfgNode.textContent || "{}"); } catch { return; }

        const dir = (cfg.dir || "rtl").toLowerCase();
        const items = Array.isArray(cfg.items) ? cfg.items : [];
        const valueFormat = cfg.valueFormat || "0";
        const showLegend = !!cfg.showLegend;

        host.innerHTML = "";
        host.setAttribute("dir", dir);

        if (items.length === 0) {
            host.innerHTML = `<div class="smart-sst__empty">لا توجد بيانات</div>`;
            return;
        }

        const palette = defaultPalette();

        const normalized = items.map((x, i) => ({
            key: String(x.key || ""),
            label: String(x.label || ""),
            value: Number(x.value) || 0,
            color: x.color || palette[i % palette.length],
            href: x.href ? String(x.href) : ""
        }));

        const total = normalized.reduce((s, x) => s + x.value, 0);
        const safeTotal = total > 0 ? total : 1;

        const tip = ensureTooltip(host);

        // Segmented bar
        const bar = document.createElement("div");
        bar.className = "smart-sst__bar";
        host.appendChild(bar);

        normalized.forEach((x) => {
            const pct = (x.value / safeTotal) * 100;
            const seg = document.createElement("div");
            seg.className = "smart-sst__seg" + (x.href ? " is-clickable" : "");
            seg.style.width = clamp(pct, 0, 100) + "%";
            seg.style.background = x.color;

            seg.addEventListener("mousemove", (e) => {
                tip.querySelector(".smart-sst__tt-title").textContent = x.label;
                tip.querySelector(".smart-sst__tt-val").textContent =
                    `${fmtNumber(x.value, valueFormat)} (${pct.toFixed(1)}%)`;

                const rect = host.getBoundingClientRect();
                tip.style.transform = `translate(${(e.clientX - rect.left) + 12}px, ${(e.clientY - rect.top) + 12}px)`;
                tip.classList.add("is-show");
            });
            seg.addEventListener("mouseleave", () => tip.classList.remove("is-show"));

            if (x.href) seg.addEventListener("click", () => window.location.href = x.href);

            bar.appendChild(seg);
        });

        if (!showLegend) return;

        // Legend cards
        const legend = document.createElement("div");
        legend.className = "smart-sst__legend";
        host.appendChild(legend);

        normalized.forEach((x) => {
            const pct = (x.value / safeTotal) * 100;

            const row = document.createElement("div");
            row.className = "smart-sst__item" + (x.href ? " is-clickable" : "");

            const left = document.createElement("div");
            left.className = "smart-sst__left";

            const dot = document.createElement("div");
            dot.className = "smart-sst__dot";
            dot.style.background = x.color;

            const label = document.createElement("div");
            label.className = "smart-sst__label";
            label.textContent = x.label;

            left.appendChild(dot);
            left.appendChild(label);

            const right = document.createElement("div");
            right.className = "smart-sst__right";

            const pctEl = document.createElement("div");
            pctEl.className = "smart-sst__pct";
            pctEl.textContent = pct.toFixed(1) + "%";

            const valEl = document.createElement("div");
            valEl.className = "smart-sst__val";
            valEl.textContent = fmtNumber(x.value, valueFormat);

            right.appendChild(pctEl);
            right.appendChild(valEl);

            row.appendChild(left);
            row.appendChild(right);

            if (x.href) row.addEventListener("click", () => window.location.href = x.href);

            legend.appendChild(row);
        });
    }

    function renderAll() {
        document.querySelectorAll(".smart-sst[data-config-id]").forEach(renderOne);
    }

    if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", renderAll);
    else renderAll();

    window.SmartCharts = window.SmartCharts || {};
    window.SmartCharts.renderStatusStack = renderAll;
})();
