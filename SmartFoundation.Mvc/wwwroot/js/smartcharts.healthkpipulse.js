(function () {
    window.SmartCharts = window.SmartCharts || {};

    function fmtNumber(v, fmt) {
        // fmt هنا بسيط (0) من الكنترول — نخليه رقم صحيح افتراضياً
        try {
            const n = Number(v || 0);
            return Math.round(n).toLocaleString('en-US');
        } catch {
            return String(v ?? 0);
        }
    }

    function setText(root, selector, text) {
        const el = root.querySelector(selector);
        if (el) el.textContent = text;
    }

    function donut(svg, pct) {
        const fg = svg.querySelector('.smart-healthkpipulse__donutFg');
        if (!fg) return;

        const r = 46;
        const c = 2 * Math.PI * r;
        const p = Math.max(0, Math.min(100, Number(pct || 0))) / 100;
        const dash = (c * p);
        const gap = c - dash;

        fg.style.strokeDasharray = `${dash} ${gap}`;
    }

    SmartCharts.renderHealthKpiPulse = function (hostId) {
        const root = document.getElementById(hostId);
        if (!root) return;

        const cfgEl = document.getElementById(hostId + "_cfg");
        if (!cfgEl) return;

        let cfg = null;
        try { cfg = JSON.parse(cfgEl.textContent || "{}"); } catch { cfg = {}; }

        const goal = Number(cfg.goal || 0);
        const actual = Number(cfg.actual || 0);
        const planned = Number(cfg.plannedToDate || 0);
        const remaining = Math.max(0, goal - actual);

        // Numbers
        root.querySelectorAll('[data-num="goal"]').forEach(x => x.textContent = fmtNumber(goal, cfg.fmt));
        root.querySelectorAll('[data-num="actual"]').forEach(x => x.textContent = fmtNumber(actual, cfg.fmt));
        root.querySelectorAll('[data-num="planned"]').forEach(x => x.textContent = fmtNumber(planned, cfg.fmt));
        root.querySelectorAll('[data-num="remaining"]').forEach(x => x.textContent = fmtNumber(remaining, cfg.fmt));

        // Percentages
        const pctActual = goal <= 0 ? 0 : (actual / goal) * 100;
        const pctPlan = goal <= 0 ? 0 : (planned / goal) * 100;

        const pctAEl = root.querySelector('[data-pct="actual"]');
        if (pctAEl) pctAEl.textContent = `${Math.round(pctActual)}%`;

        const pctPEl = root.querySelector('[data-pct="plan"]');
        if (pctPEl) pctPEl.textContent = `${Math.round(pctPlan)}%`;

        // Donut
        const svg = root.querySelector('.smart-healthkpipulse__donut');
        if (svg) donut(svg, pctActual);

        // Animate (optional)
        if (cfg.animate && svg) {
            const fg = svg.querySelector('.smart-healthkpipulse__donutFg');
            if (fg) {
                fg.style.transition = 'none';
                fg.style.strokeDasharray = `0 999`;
                requestAnimationFrame(() => {
                    fg.style.transition = 'stroke-dasharray .9s ease';
                    donut(svg, pctActual);
                });
            }
        }
    };
})();
