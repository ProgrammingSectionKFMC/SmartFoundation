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

    function palette(i) {
        const p = ["#0ea5e9", "#22c55e", "#f59e0b", "#ef4444", "#8b5cf6", "#14b8a6", "#f97316", "#64748b"];
        return p[i % p.length];
    }

    function makeSvg(tag, attrs) {
        const el = document.createElementNS(NS, tag);
        if (attrs) for (const k in attrs) el.setAttribute(k, attrs[k]);
        return el;
    }

    function ensureTooltip(host) {
        let tip = host.querySelector(".smart-rings__tooltip");
        if (tip) return tip;
        tip = document.createElement("div");
        tip.className = "smart-rings__tooltip";
        tip.innerHTML = `<div class="smart-rings__tt-title"></div>
                     <div class="smart-rings__tt-val"></div>`;
        host.appendChild(tip);
        return tip;
    }

    function polar(cx, cy, r, ang) {
        const rad = (ang - 90) * Math.PI / 180;
        return { x: cx + r * Math.cos(rad), y: cy + r * Math.sin(rad) };
    }

    function arcPath(cx, cy, r, startAng, endAng) {
        const start = polar(cx, cy, r, endAng);
        const end = polar(cx, cy, r, startAng);
        const large = (endAng - startAng) > 180 ? 1 : 0;
        return `M ${start.x} ${start.y} A ${r} ${r} 0 ${large} 0 ${end.x} ${end.y}`;
    }

    function renderOne(host) {
        const cfgId = host.getAttribute("data-config-id");
        const cfgNode = cfgId ? document.getElementById(cfgId) : null;
        if (!cfgNode) return;

        let cfg;
        try { cfg = JSON.parse(cfgNode.textContent || "{}"); } catch { return; }

        const dir = (cfg.dir || "rtl").toLowerCase();
        const size = clamp(Number(cfg.size ?? 260), 160, 380);
        const thickness = clamp(Number(cfg.thickness ?? 10), 6, 18);
        const gap = clamp(Number(cfg.gap ?? 8), 0, 16);
        const showLegend = !!cfg.showLegend;
        const valueFormat = cfg.valueFormat || "0";
        const rings = Array.isArray(cfg.rings) ? cfg.rings : [];

        host.innerHTML = "";
        host.setAttribute("dir", dir);
        host.style.setProperty("--rings-size", `${size}px`);

        if (!rings.length) {
            const empty = document.createElement("div");
            empty.className = "smart-rings__empty";
            empty.textContent = "لا توجد بيانات";
            host.appendChild(empty);
            return;
        }

        const tip = ensureTooltip(host);

        const wrap = document.createElement("div");
        wrap.className = "smart-rings__wrap";
        host.appendChild(wrap);

        const chart = document.createElement("div");
        chart.className = "smart-rings__chart";
        wrap.appendChild(chart);

        const legend = document.createElement("div");
        legend.className = "smart-rings__legend";
        if (showLegend) wrap.appendChild(legend);

        const svg = makeSvg("svg", { class: "smart-rings__svg", viewBox: `0 0 ${size} ${size}` });
        chart.appendChild(svg);

        const cx = size / 2, cy = size / 2;
        const startR = (size / 2) - 10; // outer radius
        const startAngle = 210;       // stylistic
        const sweep = 300;            // 300deg ring

        // center info: اختر أهم حلقة (الأعلى قيمة نسبة)
        let best = rings[0];
        let bestPct = -1;

        rings.forEach((r, i) => {
            const max = Number(r.max ?? 100) || 100;
            const val = Number(r.value ?? 0) || 0;
            const pct = max > 0 ? (val / max) * 100 : 0;
            if (pct > bestPct) { bestPct = pct; best = r; }
        });

        const center = document.createElement("div");
        center.className = "smart-rings__center";
        center.innerHTML = `
      <div class="smart-rings__center-title">الاجمالي</div>
      <div class="smart-rings__center-big">2221</div>
      
    `;

        //<div class="smart-rings__center-big">${best.valueText ? best.valueText : (bestPct.toFixed(0) + "%")}</div>
        chart.appendChild(center);

        // draw rings
        rings.forEach((r, i) => {
            const color = r.color || palette(i);
            const max = Number(r.max ?? 100) || 100;
            const val = Number(r.value ?? 0) || 0;
            const pct = clamp(max > 0 ? (val / max) : 0, 0, 1);

            const radius = startR - i * (thickness + gap);

            // background
            const bg = makeSvg("path", {
                d: arcPath(cx, cy, radius, startAngle, startAngle + sweep),
                fill: "none",
                stroke: "#e2e8f0",
                "stroke-width": String(thickness),
                "stroke-linecap": "round"
            });
            svg.appendChild(bg);

            // foreground
            const endAng = startAngle + sweep * pct;
            const fg = makeSvg("path", {
                d: arcPath(cx, cy, radius, startAngle, endAng),
                fill: "none",
                stroke: color,
                "stroke-width": String(thickness),
                "stroke-linecap": "round",
                opacity: "0.95"
            });
            fg.style.strokeDasharray = "999";
            fg.style.strokeDashoffset = "999";
            svg.appendChild(fg);

            // animate
            requestAnimationFrame(() => {
                fg.style.transition = "stroke-dashoffset 850ms cubic-bezier(.2,.8,.2,1)";
                fg.style.strokeDashoffset = "0";
            });

            // hover hit arc (wider)
            const hit = makeSvg("path", {
                d: arcPath(cx, cy, radius, startAngle, startAngle + sweep),
                fill: "none",
                stroke: "transparent",
                "stroke-width": String(thickness + 14),
                "stroke-linecap": "round",
                cursor: (r.href ? "pointer" : "default")
            });
            svg.appendChild(hit);

            const label = String(r.label || "");
            const valText = r.valueText ? String(r.valueText)
                : `${fmtNumber(val, valueFormat)} / ${fmtNumber(max, valueFormat)} • ${(pct * 100).toFixed(0)}%`;

            hit.addEventListener("mousemove", (e) => {
                tip.querySelector(".smart-rings__tt-title").textContent = label;
                tip.querySelector(".smart-rings__tt-val").textContent = valText;

                const rect = host.getBoundingClientRect();
                tip.style.transform = `translate(${(e.clientX - rect.left) + 10}px, ${(e.clientY - rect.top) + 10}px)`;
                tip.classList.add("is-show");

                fg.setAttribute("opacity", "1");
            });
            hit.addEventListener("mouseleave", () => {
                tip.classList.remove("is-show");
                fg.setAttribute("opacity", "0.95");
            });
            if (r.href) {
                hit.addEventListener("click", () => window.location.href = r.href);
            }

            // legend
            if (showLegend) {
                const item = document.createElement("div");
                item.className = "smart-rings__item" + (r.href ? " is-click" : "");
                item.innerHTML = `
          <div class="smart-rings__left">
            <div class="smart-rings__name">
              <span class="smart-rings__dot" style="background:${color}"></span>
              <span>${label}</span>
            </div>
            <div class="smart-rings__sub">${(pct * 100)}% من الحد</div>
          </div>
          <div class="smart-rings__right">${r.valueText ? r.valueText : fmtNumber(val, valueFormat)}</div>
        `;
                if (r.href) item.addEventListener("click", () => window.location.href = r.href);
                legend.appendChild(item);
            }
        });
    }

    function renderAll() {
        document.querySelectorAll(".smart-rings[data-config-id]").forEach(renderOne);
    }

    if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", renderAll);
    else renderAll();

    window.SmartCharts = window.SmartCharts || {};
    window.SmartCharts.renderRadialRings = renderAll;
})();
