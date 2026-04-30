// wwwroot/js/smartcharts.barh.js
(function () {
    function clamp(n, min, max) { return Math.max(min, Math.min(max, n)); }

    function fmtNumber(value, pattern) {
        if (value == null) return "";
        const v = Number(value) || 0;
        if (!pattern) return String(Math.round(v));
        const dot = pattern.indexOf(".");
        if (dot === -1) return String(Math.round(v));
        const decimals = pattern.length - dot - 1;
        const hasHash = pattern.includes("#");
        const fixed = v.toFixed(decimals);
        return hasHash ? fixed.replace(/\.?0+$/, "") : fixed;
    }

    function ellipsize(s, maxChars) {
        const t = String(s ?? "");
        if (!maxChars || t.length <= maxChars) return t;
        return t.slice(0, Math.max(0, maxChars - 1)) + "…";
    }

    function toneColor(tone) {
        switch ((tone || "").toLowerCase()) {
            case "success": return "#22c55e";
            case "warning": return "#f59e0b";
            case "danger": return "#ef4444";
            case "info": return "#0ea5e9";
            default: return "#334155";
        }
    }

    function ensureTooltip(host) {
        let tip = host.querySelector(".smart-barh2__tooltip");
        if (tip) return tip;
        tip = document.createElement("div");
        tip.className = "smart-barh2__tooltip";
        tip.innerHTML = `<div class="smart-barh2__tt-title"></div><div class="smart-barh2__tt-val"></div>`;
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
        const tone = (cfg.tone || "neutral").toLowerCase();
        const showValues = !!cfg.showValues;
        const valueFormat = cfg.valueFormat || "0";
        const labelMaxChars = Number(cfg.labelMaxChars || 22);

        const labels = Array.isArray(cfg.labels) ? cfg.labels : [];
        const values = Array.isArray(cfg.values) ? cfg.values : [];

        host.innerHTML = "";
        host.setAttribute("dir", dir);

        const n = Math.min(labels.length, values.length);
        if (n <= 0) {
            host.innerHTML = `<div class="smart-barh2__hint">لا توجد بيانات</div>`;
            return;
        }

        // Build items (keep original order) + totals
        const items = [];
        let total = 0;
        for (let i = 0; i < n; i++) {
            const v = Number(values[i]) || 0;
            total += v;
            items.push({ label: String(labels[i] ?? ""), value: v });
        }
        const max = Math.max(...items.map(x => x.value), 0) || 1;
        const safeTotal = total > 0 ? total : 1;

        const base = toneColor(tone);

        const wrap = document.createElement("div");
        wrap.className = "smart-barh2__wrap";
        host.appendChild(wrap);

        const meta = document.createElement("div");
        meta.className = "smart-barh2__meta";
        meta.innerHTML = `<div class="smart-barh2__hint">الإجمالي: ${fmtNumber(total, valueFormat)}</div>`;
        wrap.appendChild(meta);

        const tip = ensureTooltip(host);

        items.forEach((it) => {
            const pct = clamp((it.value / max) * 100, 0, 100);
            const share = (it.value / safeTotal) * 100;

            const row = document.createElement("div");
            row.className = "smart-barh2__row";

            const label = document.createElement("div");
            label.className = "smart-barh2__label";
            label.textContent = ellipsize(it.label, labelMaxChars);
            label.title = it.label;

            const track = document.createElement("div");
            track.className = "smart-barh2__track";

            const fill = document.createElement("div");
            fill.className = "smart-barh2__fill";
            fill.style.background = base; // ✅ لون ثابت بدون أي ظل/هالة

            track.appendChild(fill);

            const val = document.createElement("div");
            val.className = "smart-barh2__val";
            if (showValues) {
                val.innerHTML = `${fmtNumber(it.value, valueFormat)}<div class="smart-barh2__sub">${share.toFixed(1)}%</div>`;
            } else {
                val.innerHTML = `<div class="smart-barh2__sub">${share.toFixed(1)}%</div>`;
            }

            // Tooltip
            track.addEventListener("mousemove", (e) => {
                tip.querySelector(".smart-barh2__tt-title").textContent = it.label;
                tip.querySelector(".smart-barh2__tt-val").textContent =
                    `${fmtNumber(it.value, valueFormat)} — ${share.toFixed(1)}%`;

                const rect = host.getBoundingClientRect();
                tip.style.transform = `translate(${(e.clientX - rect.left) + 12}px, ${(e.clientY - rect.top) + 12}px)`;
                tip.classList.add("is-show");
            });
            track.addEventListener("mouseleave", () => tip.classList.remove("is-show"));

            row.appendChild(label);
            row.appendChild(track);
            row.appendChild(val);

            wrap.appendChild(row);

            // Animate
            requestAnimationFrame(() => {
                fill.style.transition = "width 900ms cubic-bezier(.2,.8,.2,1)";
                fill.style.width = pct + "%";
            });
        });
    }

    function renderAll() {
        document.querySelectorAll(".smart-barh2[data-config-id]").forEach(renderOne);
    }

    if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", renderAll);
    else renderAll();

    window.SmartCharts = window.SmartCharts || {};
    window.SmartCharts.renderBarHorizontal = renderAll;
})();
