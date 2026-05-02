(function () {
    const NS = "http://www.w3.org/2000/svg";

    function clamp(n, min, max) { return Math.max(min, Math.min(max, n)); }

    function tonePalette(tone) {

        const t = (tone || "").toLowerCase();
        if (t === "success") return ["#22c55e", "#16a34a", "#86efac", "#10b981", "#4ade80", "#14532d", "#34d399", "#bbf7d0"];
        if (t === "warning") return ["#f59e0b", "#d97706", "#fbbf24", "#f97316", "#fb923c", "#92400e", "#fdba74", "#ffedd5"];
        if (t === "danger") return ["#ef4444", "#dc2626", "#f87171", "#fb7185", "#f43f5e", "#7f1d1d", "#fecaca", "#ffe4e6"];


        if (t === "info") return ["#0ea5e9", "#0284c7", "#38bdf8", "#6366f1", "#8b5cf6", "#22d3ee", "#14b8a6", "#e0f2fe"];

        return ["#334155", "#64748b", "#94a3b8", "#0ea5e9", "#22c55e", "#f59e0b", "#8b5cf6", "#ef4444"];
    }

    function shade(hex, p) {
        const n = String(hex || "").replace("#", "");
        if (n.length !== 6) return hex;
        const r = parseInt(n.substring(0, 2), 16);
        const g = parseInt(n.substring(2, 4), 16);
        const b = parseInt(n.substring(4, 6), 16);
        const t = p < 0 ? 0 : 255;
        const a = Math.abs(p);
        const rr = Math.round((t - r) * a) + r;
        const gg = Math.round((t - g) * a) + g;
        const bb = Math.round((t - b) * a) + b;
        return "#" + [rr, gg, bb].map(x => x.toString(16).padStart(2, "0")).join("");
    }

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

    function makeSvg(tag, attrs) {
        const el = document.createElementNS(NS, tag);
        if (attrs) for (const k in attrs) el.setAttribute(k, attrs[k]);
        return el;
    }

    function polar(cx, cy, r, ang) {
        return { x: cx + r * Math.cos(ang), y: cy + r * Math.sin(ang) };
    }

    function arcPath(cx, cy, r, a0, a1) {
        const p0 = polar(cx, cy, r, a0);
        const p1 = polar(cx, cy, r, a1);
        const large = (a1 - a0) % (Math.PI * 2) > Math.PI ? 1 : 0;
        return `M ${cx} ${cy} L ${p0.x} ${p0.y} A ${r} ${r} 0 ${large} 1 ${p1.x} ${p1.y} Z`;
    }

    function arcRingPath(cx, cy, r0, r1, a0, a1) {
        const p0 = polar(cx, cy, r1, a0);
        const p1 = polar(cx, cy, r1, a1);
        const q0 = polar(cx, cy, r0, a1);
        const q1 = polar(cx, cy, r0, a0);
        const large = (a1 - a0) % (Math.PI * 2) > Math.PI ? 1 : 0;
        return [
            `M ${p0.x} ${p0.y}`,
            `A ${r1} ${r1} 0 ${large} 1 ${p1.x} ${p1.y}`,
            `L ${q0.x} ${q0.y}`,
            `A ${r0} ${r0} 0 ${large} 0 ${q1.x} ${q1.y}`,
            "Z"
        ].join(" ");
    }

    function renderOne(host) {
        const cfgId = host.getAttribute("data-config-id");
        const cfgNode = cfgId ? document.getElementById(cfgId) : null;
        if (!cfgNode) return;

        let cfg;
        try { cfg = JSON.parse(cfgNode.textContent || "{}"); } catch { return; }

        const dir = (cfg.dir || "rtl").toLowerCase();
        host.setAttribute("dir", dir);

        const size = clamp(Number(cfg.size ?? 280), 220, 520);
        const height = clamp(Number(cfg.height ?? 18), 0, 40);
        const innerHole = clamp(Number(cfg.innerHole ?? 0), 0, Math.floor(size * 0.35));
        const showLegend = !!cfg.showLegend;
        const showCenterTotal = !!cfg.showCenterTotal;
        const valueFormat = cfg.valueFormat || "0";
        const explodeOnHover = !!cfg.explodeOnHover;

        const slices = Array.isArray(cfg.slices) ? cfg.slices : [];
        const total = slices.reduce((s, x) => s + (Number(x.value) || 0), 0);

        const svgHost = host.querySelector(".smart-pie3d__svg");
        const legendHost = host.querySelector(".smart-pie3d__legend");
        const tip = host.querySelector(".smart-pie3d__tooltip");
        if (!svgHost || !tip) return;


        // ✅ Portal: طلّع tooltip خارج أي stacking context (حل مشكلة السايدبار نهائياً)
        if (!tip.dataset.portalized) {
            tip.dataset.portalized = "1";
            document.body.appendChild(tip);
            tip.style.position = "fixed";
            tip.style.zIndex = "2147483647";
        }


        // ✅ مهم: منع التولتيب من التقاط الماوس (هذا سبب شائع لبقاء التولتيب ظاهر)
        tip.style.pointerEvents = "none";

        svgHost.innerHTML = "";
        if (legendHost) legendHost.innerHTML = "";

        if (!slices.length || total <= 0) {
            svgHost.innerHTML = `<div style="padding:12px;border:1px solid rgba(226,232,240,.9);border-radius:16px;background:#fff;color:#64748b;font-weight:700;">لا توجد بيانات</div>`;
            return;
        }

        const palette = tonePalette(cfg.tone);

        // SVG sizing
        const W = size + 10;
        const H = size * 0.78 + height + 10; // منظور بسيط + سماكة
        const cx = W / 2;
        const cy = (size * 0.38) + 6;        // رفع المركز للأعلى لتظهر السماكة
        const rOuter = size * 0.38;
        const rInner = innerHole > 0 ? Math.min(innerHole, rOuter - 18) : 0;

        // ✅ إصلاح الخطأ: لا تضع height="auto" كـ attribute داخل SVG (غير صالح)
        const svg = makeSvg("svg", { viewBox: `0 0 ${W} ${H}`, width: "100%" });
        svg.style.height = "auto";
        svg.style.display = "block";
        svgHost.appendChild(svg);

        // ✅ دالة إخفاء موحدة للتولتيب
        function hideTip() {
            tip.classList.remove("is-show");
        }

        // ✅ إخفاء عام عند خروج الماوس من الرسم/الكارد (يضبط حالات كانت تبقى)
        svg.addEventListener("mouseleave", hideTip);
        host.addEventListener("mouseleave", hideTip);

        // ترتيب الرسم:
        // 1) الطبقة السفلية (السماكة) تُرسم فقط للجزء الأمامي (الزاوية بين 0..PI) ليوحي 3D
        // 2) الطبقة العلوية لكل شريحة فوقها

        let angle = -Math.PI / 2; // يبدأ من الأعلى
        const parts = [];

        for (let i = 0; i < slices.length; i++) {
            const v = Number(slices[i].value) || 0;
            const frac = v / total;
            const a0 = angle;
            const a1 = angle + frac * Math.PI * 2;
            angle = a1;

            const base = (slices[i].color && String(slices[i].color).trim()) ? slices[i].color : palette[i % palette.length];
            parts.push({
                i,
                key: slices[i].key || ("s" + i),
                label: String(slices[i].label || ""),
                value: v,
                frac,
                a0, a1,
                base,
                top: shade(base, 0.10),
                side: shade(base, -0.18),
                href: slices[i].href || "",
                hint: slices[i].hint || ""
            });
        }

        function isFront(a) {
            // y increases downward, front is where sin(angle) > 0
            return Math.sin(a) > 0;
        }

        const gAll = makeSvg("g");
        svg.appendChild(gAll);

        // Draw side/extrusion first (behind top faces)
        for (const p of parts) {
            const mid = (p.a0 + p.a1) / 2;
            if (!isFront(mid) || height <= 0) continue;

            const sidePath = makeSvg("path", {
                d: (rInner > 0)
                    ? arcRingPath(cx, cy + height, rInner, rOuter, p.a0, p.a1)
                    : arcPath(cx, cy + height, rOuter, p.a0, p.a1),
                fill: p.side,
                opacity: "0.98"
            });
            gAll.appendChild(sidePath);
        }

        // Top faces + interaction
        for (const p of parts) {
            const g = makeSvg("g", { "data-key": p.key, style: "cursor:" + (p.href ? "pointer" : "default") });
            gAll.appendChild(g);

            const topFace = makeSvg("path", {
                d: (rInner > 0)
                    ? arcRingPath(cx, cy, rInner, rOuter, p.a0, p.a1)
                    : arcPath(cx, cy, rOuter, p.a0, p.a1),
                fill: p.top,
                opacity: "1"
            });
            g.appendChild(topFace);

            const seam = makeSvg("path", {
                d: (rInner > 0)
                    ? arcRingPath(cx, cy, rInner, rOuter, p.a0, p.a1)
                    : arcPath(cx, cy, rOuter, p.a0, p.a1),
                fill: "none",
                stroke: "rgba(15,23,42,.06)",
                "stroke-width": "1"
            });
            g.appendChild(seam);

            // Center total text
            if (showCenterTotal && p.i === 0) {
                const t1 = makeSvg("text", { x: cx, y: cy + 6, "text-anchor": "middle", fill: "#0f172a", "font-size": "12", "font-weight": "900" });
                t1.textContent = "الإجمالي";
                svg.appendChild(t1);

                const t2 = makeSvg("text", { x: cx, y: cy + 28, "text-anchor": "middle", fill: "#0f172a", "font-size": "22", "font-weight": "900" });
                t2.textContent = fmtNumber(total, valueFormat);
                svg.appendChild(t2);
            }

            // Hover explode (move slice outward along bisector)
            const mid = (p.a0 + p.a1) / 2;
            const explode = 10;
            const dx = Math.cos(mid) * explode;
            const dy = Math.sin(mid) * explode * 0.65;

            //function showTip(ev) {
            //    const rect = host.getBoundingClientRect();
            //    const pct = (p.frac * 100);
            //    tip.querySelector(".smart-pie3d__tt-title").textContent = p.label;
            //    tip.querySelector(".smart-pie3d__tt-val").textContent =
            //        `${fmtNumber(p.value, valueFormat)} • ${pct.toFixed(1).replace(/\.0$/, "")}%`;
            //    tip.querySelector(".smart-pie3d__tt-hint").textContent = p.hint || "";

            //    // ✅ لأن tooltip صار position:fixed
            //    const offset = 14;
            //    let x = ev.clientX + offset;
            //    let y = ev.clientY + offset;

            //    // ✅ منع خروجه خارج الشاشة
            //    const pad = 12;
            //    const w = tip.offsetWidth || 260;
            //    const h = tip.offsetHeight || 120;

            //    if (x + w + pad > window.innerWidth) x = ev.clientX - w - offset;
            //    if (y + h + pad > window.innerHeight) y = ev.clientY - h - offset;

            //    tip.style.transform = `translate(${(ev.clientX - rect.left) + 12}px, ${(ev.clientY - rect.top) + 12}px)`;
            //    tip.classList.add("is-show");
            //}

            function showTip(ev) {
                const pct = (p.frac * 100);

                tip.querySelector(".smart-pie3d__tt-title").textContent = p.label;
                tip.querySelector(".smart-pie3d__tt-val").textContent =
                    `${fmtNumber(p.value, valueFormat)} • ${pct.toFixed(1).replace(/\.0$/, "")}%`;
                tip.querySelector(".smart-pie3d__tt-hint").textContent = p.hint || "";

                // ✅ لأن tooltip = position: fixed
                const offset = 14;
                let x = ev.clientX + offset;
                let y = ev.clientY + offset;

                // ✅ امنع خروجه خارج الشاشة
                const pad = 12;
                const w = tip.offsetWidth || 260;
                const h = tip.offsetHeight || 120;

                if (x + w + pad > window.innerWidth) x = ev.clientX - w - offset;
                if (y + h + pad > window.innerHeight) y = ev.clientY - h - offset;

                // ✅ استخدم x,y (ولا تستخدم rect هنا نهائياً)
                tip.style.transform = `translate(${x}px, ${y}px)`;
                tip.classList.add("is-show");
            }


            g.addEventListener("mousemove", (ev) => showTip(ev));


            g.addEventListener("mouseleave", () => {
                hideTip();
                if (explodeOnHover) g.setAttribute("transform", "");
            });

            g.addEventListener("mouseenter", (ev) => {
                if (explodeOnHover) g.setAttribute("transform", `translate(${dx} ${dy})`);
                showTip(ev);
            });

            if (p.href) {
                g.addEventListener("click", () => window.location.href = p.href);
            }
        }

        // Legend
        if (showLegend && legendHost) {
            for (const p of parts) {
                const item = document.createElement("div");
                item.className = "smart-pie3d__leg-item";
                item.style.cursor = p.href ? "pointer" : "default";

                item.innerHTML = `
          <div class="smart-pie3d__leg-left">
            <span class="smart-pie3d__dot" style="background:${p.top}"></span>
            <div class="smart-pie3d__leg-label" title="${p.label.replace(/"/g, '&quot;')}">${p.label}</div>
          </div>
          <div class="smart-pie3d__leg-right">
            <div class="smart-pie3d__leg-val">${fmtNumber(p.value, valueFormat)}</div>
            <div class="smart-pie3d__leg-pct">${(p.frac * 100).toFixed(1).replace(/\.0$/, "")}%</div>
          </div>
        `;

                item.addEventListener("mouseenter", () => {
                    const g = svg.querySelector(`g[data-key="${p.key}"]`);
                    if (g && explodeOnHover) {
                        const mid = (p.a0 + p.a1) / 2;
                        const explode = 10;
                        const dx = Math.cos(mid) * explode;
                        const dy = Math.sin(mid) * explode * 0.65;
                        g.setAttribute("transform", `translate(${dx} ${dy})`);
                    }
                });

                item.addEventListener("mouseleave", () => {
                    const g = svg.querySelector(`g[data-key="${p.key}"]`);
                    if (g && explodeOnHover) g.setAttribute("transform", "");

                    hideTip();
                });

                if (p.href) item.addEventListener("click", () => window.location.href = p.href);
                legendHost.appendChild(item);
            }
        }
    }

    function renderAll() {
        document.querySelectorAll(".smart-pie3d[data-config-id]").forEach(renderOne);
    }

    if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", renderAll);
    else renderAll();

    window.SmartCharts = window.SmartCharts || {};
    window.SmartCharts.renderPie3D = renderAll;
})();

