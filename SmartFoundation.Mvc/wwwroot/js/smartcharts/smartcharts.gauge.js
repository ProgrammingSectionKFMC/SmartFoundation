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

    function polarToCartesian(cx, cy, r, angleDeg) {
        const rad = (angleDeg - 90) * Math.PI / 180;
        return { x: cx + r * Math.cos(rad), y: cy + r * Math.sin(rad) };
    }

    function arcPath(cx, cy, r, startAngle, endAngle) {
        const start = polarToCartesian(cx, cy, r, endAngle);
        const end = polarToCartesian(cx, cy, r, startAngle);
        const largeArc = (endAngle - startAngle) > 180 ? 1 : 0;
        return `M ${start.x} ${start.y} A ${r} ${r} 0 ${largeArc} 0 ${end.x} ${end.y}`;
    }

    function colorFor(valuePct, warnFromPct, goodFromPct) {
        if (valuePct >= goodFromPct) return "#22c55e"; // green
        if (valuePct >= warnFromPct) return "#f59e0b"; // amber
        return "#ef4444"; // red
    }

    function renderOne(host) {
        const cfgId = host.getAttribute("data-config-id");
        const cfgNode = cfgId ? document.getElementById(cfgId) : null;
        if (!cfgNode) return;

        let cfg;
        try { cfg = JSON.parse(cfgNode.textContent || "{}"); } catch { return; }

        const dir = (cfg.dir || "rtl").toLowerCase();
        const min = Number(cfg.min ?? 0);
        const max = Number(cfg.max ?? 100);
        const value = Number(cfg.value ?? 0);

        const label = (cfg.label || "").toString();
        const unit = (cfg.unit || "%").toString();

        const valueFormat = cfg.valueFormat || "0";
        const valueText = (cfg.valueText && String(cfg.valueText).trim().length) ? String(cfg.valueText) : null;

        const goodFrom = Number(cfg.goodFrom ?? 90);
        const warnFrom = Number(cfg.warnFrom ?? 75);
        const showThresholds = !!cfg.showThresholds;

        host.innerHTML = "";
        host.setAttribute("dir", dir);

        if (!Number.isFinite(min) || !Number.isFinite(max) || max <= min) {
            const empty = document.createElement("div");
            empty.className = "smart-gauge__empty";
            empty.textContent = "بيانات غير صحيحة";
            host.appendChild(empty);
            return;
        }

        const pct = clamp(((value - min) / (max - min)) * 100, 0, 100);
        const stroke = colorFor(pct, warnFrom, goodFrom);

        // layout
        const wrap = document.createElement("div");
        wrap.className = "smart-gauge__wrap";
        host.appendChild(wrap);

        const chart = document.createElement("div");
        chart.className = "smart-gauge__chart";
        wrap.appendChild(chart);

        const info = document.createElement("div");
        info.className = "smart-gauge__info";
        wrap.appendChild(info);

        // SVG half-circle gauge
        const size = 240;
        const cx = size / 2;
        const cy = size / 2;
        const r = 90;

        const svg = document.createElementNS(NS, "svg");
        svg.setAttribute("class", "smart-gauge__svg");
        svg.setAttribute("viewBox", `0 0 ${size} ${size}`);
        chart.appendChild(svg);

        // background arc (180deg)
        const bg = document.createElementNS(NS, "path");
        bg.setAttribute("d", arcPath(cx, cy, r, 180, 360));
        bg.setAttribute("fill", "none");
        bg.setAttribute("stroke", "#e2e8f0");
        bg.setAttribute("stroke-width", "14");
        bg.setAttribute("stroke-linecap", "round");
        svg.appendChild(bg);

        // value arc
        const endAngle = 180 + (pct / 100) * 180;
        const fg = document.createElementNS(NS, "path");
        fg.setAttribute("d", arcPath(cx, cy, r, 180, endAngle));
        fg.setAttribute("fill", "none");
        fg.setAttribute("stroke", stroke);
        fg.setAttribute("stroke-width", "14");
        fg.setAttribute("stroke-linecap", "round");
        fg.setAttribute("style", "stroke-dasharray: 999; stroke-dashoffset: 999;");
        svg.appendChild(fg);

        // animate arc
        requestAnimationFrame(() => {
            fg.style.transition = "stroke-dashoffset 800ms cubic-bezier(.2,.8,.2,1)";
            fg.style.strokeDashoffset = "0";
        });

        // center text
        const center = document.createElement("div");
        center.className = "smart-gauge__center";
        chart.appendChild(center);

        const vEl = document.createElement("div");
        vEl.className = "smart-gauge__value";
        vEl.textContent = valueText ? valueText : `${fmtNumber(pct, "0.0").replace(/\.0$/, "")}${unit}`;
        center.appendChild(vEl);

        const lEl = document.createElement("div");
        lEl.className = "smart-gauge__label";
        lEl.textContent = label || "SLA";
        center.appendChild(lEl);

        // info text
        const head = document.createElement("div");
        head.className = "smart-gauge__headline";
        head.textContent = label || "الالتزام بالـ SLA";
        info.appendChild(head);

        const sub = document.createElement("div");
        sub.className = "smart-gauge__sub";
        sub.textContent = `القيمة الحالية: ${fmtNumber(value, valueFormat)} من ${fmtNumber(max, valueFormat)} (الهدف: ${fmtNumber(goodFrom, "0")}${unit}+).`;
        info.appendChild(sub);

        if (showThresholds) {
            const th = document.createElement("div");
            th.className = "smart-gauge__thresholds";

            const mk = (c, t) => {
                const row = document.createElement("div");
                row.className = "smart-gauge__pill";
                row.innerHTML = `<span class="smart-gauge__dot" style="background:${c}"></span><span>${t}</span>`;
                return row;
            };

            th.appendChild(mk("#22c55e", `جيد: ${goodFrom}${unit}+`));
            th.appendChild(mk("#f59e0b", `تحذير: ${warnFrom}${unit}+`));
            th.appendChild(mk("#ef4444", `خارج SLA: أقل من ${warnFrom}${unit}`));
            info.appendChild(th);
        }
    }

    function renderAll() {
        document.querySelectorAll(".smart-gauge[data-config-id]").forEach(renderOne);
    }

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", renderAll);
    } else {
        renderAll();
    }

    window.SmartCharts = window.SmartCharts || {};
    window.SmartCharts.renderGauges = renderAll;
})();
