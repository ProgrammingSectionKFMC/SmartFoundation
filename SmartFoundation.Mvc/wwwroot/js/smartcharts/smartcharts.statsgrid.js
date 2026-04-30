(function () {
    function parseNumeric(text) {
        if (!text) return null;
        const raw = String(text).trim();

        // يدعم 1,633 / 57731 / 21K / 12.3M
        const m = raw.match(/^([\d,.\s]+)\s*([KMB])?$/i);
        if (!m) return null;

        const num = parseFloat(m[1].replace(/,/g, "").replace(/\s/g, ""));
        if (Number.isNaN(num)) return null;

        const suf = (m[2] || "").toUpperCase();
        const mul = suf === "K" ? 1e3 : suf === "M" ? 1e6 : suf === "B" ? 1e9 : 1;
        return { value: num * mul, suffix: suf };
    }

    function formatWithSuffix(v, suffix) {
        if (!suffix) return Math.round(v).toLocaleString();
        const div = suffix === "K" ? 1e3 : suffix === "M" ? 1e6 : 1e9;
        const out = v / div;
        const s = out >= 10 ? out.toFixed(0) : out.toFixed(1).replace(/\.0$/, "");
        return s + suffix;
    }

    function animateNumber(el) {
        const parsed = parseNumeric(el.textContent);
        if (!parsed) return;

        const end = parsed.value;
        const suffix = parsed.suffix;

        const dur = 750;
        const start = performance.now();
        const from = 0;

        function tick(now) {
            const t = Math.min(1, (now - start) / dur);
            const eased = 1 - Math.pow(1 - t, 3); // easeOutCubic
            const v = from + (end - from) * eased;
            el.textContent = formatWithSuffix(v, suffix);
            if (t < 1) requestAnimationFrame(tick);
        }
        requestAnimationFrame(tick);
    }

    function renderOne(host) {
        const cfgId = host.getAttribute("data-config-id");
        const cfgNode = cfgId ? document.getElementById(cfgId) : null;
        if (!cfgNode) return;

        let cfg;
        try { cfg = JSON.parse(cfgNode.textContent || "{}"); } catch { return; }

        const dir = (cfg.dir || "rtl").toLowerCase();
        const groups = Array.isArray(cfg.groups) ? cfg.groups : [];
        const animate = !!cfg.animate;

        host.innerHTML = "";
        host.setAttribute("dir", dir);

        const wrap = document.createElement("div");
        wrap.className = "smart-statsgrid__wrap";
        host.appendChild(wrap);

        for (const g of groups) {
            const group = document.createElement("div");
            group.className = "smart-statsgrid__group";

            const head = document.createElement("div");
            head.className = "smart-statsgrid__ghead";

            const left = document.createElement("div");
            left.innerHTML = `
        <div class="smart-statsgrid__gtitle">${g.title || ""}</div>
        ${g.subtitle ? `<div class="smart-statsgrid__gsub">${g.subtitle}</div>` : ""}
      `;

            const badge = document.createElement("div");
            badge.className = "smart-statsgrid__badge";
            badge.style.display = g.badge ? "inline-flex" : "none";
            badge.textContent = g.badge || "";

            head.appendChild(left);
            head.appendChild(badge);

            const items = document.createElement("div");
            items.className = "smart-statsgrid__items";

            const list = Array.isArray(g.items) ? g.items : [];
            for (const it of list) {
                const row = document.createElement("div");
                row.className = "smart-statsgrid__item";
                if (it.href) row.style.cursor = "pointer";

                const l = document.createElement("div");
                l.className = "smart-statsgrid__left";
                l.innerHTML = `
          <div class="smart-statsgrid__icon">${it.icon ? `<i class="${it.icon}"></i>` : `<i class="fa-regular fa-chart-bar"></i>`}</div>
          <div class="smart-statsgrid__meta">
            <div class="smart-statsgrid__label" title="${it.label || ""}">${it.label || ""}</div>
            ${it.hint ? `<div class="smart-statsgrid__hint" title="${it.hint}">${it.hint}</div>` : ""}
          </div>
        `;

                const r = document.createElement("div");
                r.className = "smart-statsgrid__right";
                r.innerHTML = `
          <div class="smart-statsgrid__value">${it.value || ""}</div>
          ${it.unit ? `<div class="smart-statsgrid__unit">${it.unit}</div>` : ""}
          ${it.delta ? `<div class="smart-statsgrid__delta" data-positive="${it.deltaPositive === true ? "true" : it.deltaPositive === false ? "false" : "null"}">${it.delta}</div>` : ""}
        `;

                row.appendChild(l);
                row.appendChild(r);
                items.appendChild(row);

                if (it.href) row.addEventListener("click", () => window.location.href = it.href);
            }

            group.appendChild(head);
            group.appendChild(items);
            wrap.appendChild(group);
        }

        if (animate) {
            host.querySelectorAll(".smart-statsgrid__value").forEach(animateNumber);
        }
    }

    function renderAll() {
        document.querySelectorAll(".smart-statsgrid[data-config-id]").forEach(renderOne);
    }

    if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", renderAll);
    else renderAll();

    window.SmartCharts = window.SmartCharts || {};
    window.SmartCharts.renderStatsGrid = renderAll;
})();
