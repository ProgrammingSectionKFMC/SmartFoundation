(function () {
    function clamp(n, min, max) { return Math.max(min, Math.min(max, n)); }

    function palette(i) {
        const p = ["#0ea5e9", "#f59e0b", "#22c55e", "#ef4444", "#8b5cf6", "#14b8a6", "#f97316", "#64748b"];
        return p[i % p.length];
    }

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
        let tip = host.querySelector(".smart-funnel__tooltip");
        if (tip) return tip;
        tip = document.createElement("div");
        tip.className = "smart-funnel__tooltip";
        tip.innerHTML = `<div class="smart-funnel__tt-title"></div>
                     <div class="smart-funnel__tt-val"></div>`;
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
        const stages = Array.isArray(cfg.stages) ? cfg.stages : [];
        const showPercent = !!cfg.showPercent;
        const showDelta = !!cfg.showDelta;
        const clickable = !!cfg.clickable;
        const valueFormat = cfg.valueFormat || "0";

        host.innerHTML = "";
        host.setAttribute("dir", dir);

        if (!stages.length) {
            const empty = document.createElement("div");
            empty.className = "smart-funnel__empty";
            empty.textContent = "لا توجد بيانات";
            host.appendChild(empty);
            return;
        }

        const values = stages.map(s => Number(s.value) || 0);
        const total = values.reduce((a, b) => a + b, 0);
        const max = Math.max(...values, 0);

        const tip = ensureTooltip(host);

        const wrap = document.createElement("div");
        wrap.className = "smart-funnel__wrap";
        host.appendChild(wrap);

        for (let i = 0; i < stages.length; i++) {
            const s = stages[i];
            const v = Number(s.value) || 0;
            const pct = total > 0 ? (v / total) * 100 : 0;
            const width = max > 0 ? (v / max) * 100 : 0;

            const prev = i > 0 ? (Number(stages[i - 1].value) || 0) : null;
            const delta = (prev === null || prev === 0) ? null : ((v - prev) / prev) * 100;

            let deltaDir = "flat";
            let deltaText = "";
            if (delta !== null) {
                if (delta > 0.05) deltaDir = "up";
                else if (delta < -0.05) deltaDir = "down";
                deltaText = `${delta > 0 ? "+" : ""}${delta.toFixed(1)}%`;
            }

            const stage = document.createElement("div");
            stage.className = "smart-funnel__stage" + (clickable && (s.href || s.onClickJs) ? " smart-funnel__click" : "");

            const left = document.createElement("div");
            left.className = "smart-funnel__left";

            const topline = document.createElement("div");
            topline.className = "smart-funnel__topline";

            const label = document.createElement("div");
            label.className = "smart-funnel__label";
            label.textContent = (s.label || "");

            const meta = document.createElement("div");
            meta.className = "smart-funnel__meta";
            if (showPercent) {
                const p = document.createElement("span");
                p.textContent = (total > 0) ? `${pct.toFixed(1)}%` : "0%";
                meta.appendChild(p);
            }
            if (showDelta && delta !== null) {
                const d = document.createElement("span");
                d.textContent = `مقارنةً بالسابق: ${deltaText}`;
                meta.appendChild(d);
            }

            topline.appendChild(label);
            topline.appendChild(meta);

            const bar = document.createElement("div");
            bar.className = "smart-funnel__bar";

            const fill = document.createElement("div");
            fill.className = "smart-funnel__fill";
            fill.style.background = s.color || palette(i);
            fill.style.width = "0%";
            bar.appendChild(fill);

            left.appendChild(topline);
            left.appendChild(bar);

            const right = document.createElement("div");
            right.className = "smart-funnel__right";

            const val = document.createElement("div");
            val.className = "smart-funnel__value";
            val.textContent = fmtNumber(v, valueFormat);

            right.appendChild(val);

            if (showDelta && delta !== null) {
                const pill = document.createElement("div");
                pill.className = "smart-funnel__delta";
                pill.setAttribute("data-dir", deltaDir);
                pill.textContent = deltaText;
                right.appendChild(pill);
            }

            stage.appendChild(left);
            stage.appendChild(right);
            wrap.appendChild(stage);

            // tooltip
            stage.addEventListener("mousemove", (e) => {
                const title = (s.label || "");
                const valText = `${fmtNumber(v, valueFormat)}${showPercent ? ` • ${pct.toFixed(1)}%` : ""}`;

                tip.querySelector(".smart-funnel__tt-title").textContent = title;
                tip.querySelector(".smart-funnel__tt-val").textContent = valText;

                const rect = host.getBoundingClientRect();
                tip.style.transform = `translate(${(e.clientX - rect.left) + 10}px, ${(e.clientY - rect.top) + 10}px)`;
                tip.classList.add("is-show");
            });
            stage.addEventListener("mouseleave", () => tip.classList.remove("is-show"));

            // click
            if (clickable && (s.href || s.onClickJs)) {
                stage.addEventListener("click", () => {
                    if (s.onClickJs) {
                        try { (new Function(s.onClickJs))(); } catch { }
                        return;
                    }
                    if (s.href) window.location.href = s.href;
                });
            }

            // animate
            requestAnimationFrame(() => {
                fill.style.width = `${clamp(width, 0, 100).toFixed(2)}%`;
            });
        }
    }

    function renderAll() {
        document.querySelectorAll(".smart-funnel[data-config-id]").forEach(renderOne);
    }

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", renderAll);
    } else {
        renderAll();
    }

    window.SmartCharts = window.SmartCharts || {};
    window.SmartCharts.renderFunnels = renderAll;
})();
