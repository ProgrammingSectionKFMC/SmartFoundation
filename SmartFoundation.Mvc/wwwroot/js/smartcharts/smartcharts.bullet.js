(function () {
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

    function palette(i) {
        const p = ["#0ea5e9", "#22c55e", "#f59e0b", "#ef4444", "#8b5cf6", "#14b8a6", "#f97316", "#64748b"];
        return p[i % p.length];
    }

    function renderOne(host) {
        const cfgId = host.getAttribute("data-config-id");
        const cfgNode = cfgId ? document.getElementById(cfgId) : null;
        if (!cfgNode) return;

        let cfg;
        try { cfg = JSON.parse(cfgNode.textContent || "{}"); } catch { return; }

        host.innerHTML = "";
        host.setAttribute("dir", cfg.dir || "rtl");

        const items = Array.isArray(cfg.items) ? cfg.items : [];
        if (!items.length) {
            const empty = document.createElement("div");
            empty.className = "smart-bullet__empty";
            empty.textContent = "لا توجد بيانات";
            host.appendChild(empty);
            return;
        }

        const list = document.createElement("div");
        list.className = "smart-bullet__list";
        host.appendChild(list);

        items.forEach((b, i) => {
            const max = Number(b.max ?? 100) || 100;
            const actual = clamp(Number(b.actual ?? 0) || 0, 0, max);
            const target = clamp(Number(b.target ?? 0) || 0, 0, max);

            const okFrom = clamp(Number(b.okFrom ?? (max * 0.6)), 0, max);
            const goodFrom = clamp(Number(b.goodFrom ?? (max * 0.85)), okFrom, max);

            const pActual = max > 0 ? (actual / max) * 100 : 0;
            const pTarget = max > 0 ? (target / max) * 100 : 0;

            const unit = (b.unit && String(b.unit).trim().length) ? String(b.unit) : "";
            const color = b.color || palette(i);

            const row = document.createElement("div");
            row.className = "smart-bullet__row" + (b.href ? " is-click" : "");

            const top = document.createElement("div");
            top.className = "smart-bullet__top";

            const label = document.createElement("div");
            label.className = "smart-bullet__label";
            label.textContent = String(b.label || "");

            const nums = document.createElement("div");
            nums.className = "smart-bullet__nums";
            nums.textContent = `الحالي: ${fmtNumber(actual, cfg.valueFormat)}${unit} • الهدف: ${fmtNumber(target, cfg.valueFormat)}${unit}`;

            top.appendChild(label);
            top.appendChild(nums);

            const track = document.createElement("div");
            track.className = "smart-bullet__track";

            const ranges = document.createElement("div");
            ranges.className = "smart-bullet__ranges";

            const r1 = document.createElement("div");
            r1.className = "smart-bullet__r-poor";
            r1.style.width = `${(okFrom / max) * 100}%`;

            const r2 = document.createElement("div");
            r2.className = "smart-bullet__r-ok";
            r2.style.width = `${((goodFrom - okFrom) / max) * 100}%`;

            const r3 = document.createElement("div");
            r3.className = "smart-bullet__r-good";
            r3.style.width = `${((max - goodFrom) / max) * 100}%`;

            ranges.appendChild(r1);
            ranges.appendChild(r2);
            ranges.appendChild(r3);
            track.appendChild(ranges);

            const actualEl = document.createElement("div");
            actualEl.className = "smart-bullet__actual";
            actualEl.style.background = color;
            actualEl.style.width = "0%";
            track.appendChild(actualEl);

            const targetEl = document.createElement("div");
            targetEl.className = "smart-bullet__target";
            targetEl.style.left = `${pTarget}%`;
            track.appendChild(targetEl);

            row.appendChild(top);
            row.appendChild(track);

            if (cfg.showLegend) {
                const legend = document.createElement("div");
                legend.className = "smart-bullet__legend";
                legend.innerHTML = `
          <span class="smart-bullet__pill"><span class="smart-bullet__dot" style="background:${color}"></span>Actual</span>
          <span class="smart-bullet__pill"><span class="smart-bullet__dot" style="background:#0f172a"></span>Target</span>
          <span class="smart-bullet__pill"><span class="smart-bullet__dot" style="background:rgba(239,68,68,0.35)"></span>ضعيف</span>
          <span class="smart-bullet__pill"><span class="smart-bullet__dot" style="background:rgba(245,158,11,0.35)"></span>جيد</span>
          <span class="smart-bullet__pill"><span class="smart-bullet__dot" style="background:rgba(34,197,94,0.35)"></span>ممتاز</span>
        `;
                row.appendChild(legend);
            }

            list.appendChild(row);

            requestAnimationFrame(() => {
                actualEl.style.width = `${clamp(pActual, 0, 100).toFixed(2)}%`;
            });

            if (b.href) {
                row.addEventListener("click", () => window.location.href = b.href);
            }
        });
    }

    function renderAll() {
        document.querySelectorAll(".smart-bullet[data-config-id]").forEach(renderOne);
    }

    if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", renderAll);
    else renderAll();

    window.SmartCharts = window.SmartCharts || {};
    window.SmartCharts.renderBullets = renderAll;
})();
