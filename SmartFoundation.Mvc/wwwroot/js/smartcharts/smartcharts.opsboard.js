(function () {

    function clamp(n, min, max) { return Math.max(min, Math.min(max, n)); }

    function parseNumeric(text) {
        if (!text) return null;
        const raw = String(text).trim();
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
            const eased = 1 - Math.pow(1 - t, 3);
            const v = from + (end - from) * eased;
            el.textContent = formatWithSuffix(v, suffix);
            if (t < 1) requestAnimationFrame(tick);
        }
        requestAnimationFrame(tick);
    }

    function makeEl(tag, cls) {
        const el = document.createElement(tag);
        if (cls) el.className = cls;
        return el;
    }

    function iconHtml(fa) {
        return fa ? `<i class="${fa}"></i>` : `<i class="fa-regular fa-chart-bar"></i>`;
    }

    function renderOne(host) {
        const cfgId = host.getAttribute("data-config-id");
        const cfgNode = cfgId ? document.getElementById(cfgId) : null;
        if (!cfgNode) return;

        let cfg;
        try { cfg = JSON.parse(cfgNode.textContent || "{}"); } catch { return; }

        const dir = (cfg.dir || "rtl").toLowerCase();
        const animate = !!cfg.animate;
        const compact = !!cfg.compact;
        const cols = clamp(parseInt(cfg.columns || 2, 10), 1, 3);

        host.innerHTML = "";
        host.setAttribute("dir", dir);
        host.setAttribute("data-compact", compact ? "true" : "false");

        const wrap = makeEl("div", "smart-opsboard__wrap");
        wrap.setAttribute("data-cols", String(cols));
        host.appendChild(wrap);

        const sections = Array.isArray(cfg.sections) ? cfg.sections : [];
        for (const s of sections) {
            const sec = makeEl("div", "smart-opsboard__section");
            if (s.href) sec.style.cursor = "pointer";

            const head = makeEl("div", "smart-opsboard__shead");

            const sleft = makeEl("div", "smart-opsboard__sleft");
            sleft.innerHTML = `
        <div class="smart-opsboard__sicon">${iconHtml(s.icon)}</div>
        <div class="min-w-0">
          <div class="smart-opsboard__stitle" title="${s.title || ""}">${s.title || ""}</div>
          ${s.subtitle ? `<div class="smart-opsboard__ssub" title="${s.subtitle}">${s.subtitle}</div>` : ""}
        </div>
      `;

            const badge = makeEl("div", "smart-opsboard__badge");
            badge.style.display = s.badge ? "inline-flex" : "none";
            badge.textContent = s.badge || "";

            head.appendChild(sleft);
            head.appendChild(badge);
            sec.appendChild(head);

            // KPIs
            const kpis = makeEl("div", "smart-opsboard__kpis");
            const klist = Array.isArray(s.kpis) ? s.kpis : [];
            for (const k of klist) {
                const kpi = makeEl("div", "smart-opsboard__kpi");
                if (k.href) kpi.style.cursor = "pointer";

                const progress = (typeof k.progress === "number") ? clamp(k.progress, 0, 100) : null;

                kpi.innerHTML = `
          <div class="smart-opsboard__kpiTop">
            <div class="smart-opsboard__kpiMeta">
              <div class="smart-opsboard__kpiIcon">${iconHtml(k.icon)}</div>
              <div class="min-w-0">
                <div class="smart-opsboard__kpiLabel" title="${k.label || ""}">${k.label || ""}</div>
                ${k.hint ? `<div class="smart-opsboard__kpiHint" title="${k.hint}">${k.hint}</div>` : ""}
              </div>
            </div>
            <div class="text-end">
              <div class="smart-opsboard__kpiValue">${k.value || ""}</div>
              ${k.unit ? `<div class="smart-opsboard__kpiUnit">${k.unit}</div>` : ""}
              ${k.delta ? `<div class="smart-opsboard__kpiDelta" data-positive="${k.deltaPositive === true ? "true" : k.deltaPositive === false ? "false" : "null"}">${k.delta}</div>` : ""}
            </div>
          </div>
          ${progress === null ? "" : `
            <div class="smart-opsboard__bar" aria-label="progress">
              <div class="smart-opsboard__barFill" style="width:${progress}%"></div>
            </div>
          `}
        `;

                kpis.appendChild(kpi);

                if (k.href) {
                    kpi.addEventListener("click", (ev) => { ev.stopPropagation(); window.location.href = k.href; });
                }
            }
            if (klist.length) sec.appendChild(kpis);

            // Events
            const events = makeEl("div", "smart-opsboard__events");
            const elist = Array.isArray(s.events) ? s.events : [];
            for (const e of elist) {
                const row = makeEl("div", "smart-opsboard__event");
                if (e.href) row.style.cursor = "pointer";

                row.innerHTML = `
          <div class="smart-opsboard__eventLeft">
            <div class="smart-opsboard__eventIcon">${iconHtml(e.icon)}</div>
            <div class="min-w-0">
              <div class="smart-opsboard__eventTitle" title="${e.title || ""}">${e.title || ""}</div>
              ${e.subtitle ? `<div class="smart-opsboard__eventSub" title="${e.subtitle}">${e.subtitle}</div>` : ""}
            </div>
          </div>
          <div class="smart-opsboard__eventRight">
            ${e.time ? `<div class="smart-opsboard__time">${e.time}</div>` : ""}
            ${e.status ? `<div class="smart-opsboard__pill" data-tone="${(e.statusTone || "neutral")}">${e.status}</div>` : ""}
            ${e.priority ? `<div class="smart-opsboard__pill" data-tone="${(e.priorityTone || "neutral")}">${e.priority}</div>` : ""}
          </div>
        `;

                events.appendChild(row);

                if (e.href) row.addEventListener("click", (ev) => { ev.stopPropagation(); window.location.href = e.href; });
            }
            if (elist.length) sec.appendChild(events);

            wrap.appendChild(sec);

            if (s.href) {
                sec.addEventListener("click", () => window.location.href = s.href);
            }
        }

        if (animate) {
            host.querySelectorAll(".smart-opsboard__kpiValue").forEach(animateNumber);
        }

        // trigger bars animation (already transitions)
        host.querySelectorAll(".smart-opsboard__barFill").forEach(el => {
            const w = el.style.width;
            el.style.width = "0%";
            requestAnimationFrame(() => { el.style.width = w; });
        });
    }

    function renderAll() {
        document.querySelectorAll(".smart-opsboard[data-config-id]").forEach(renderOne);
    }

    if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", renderAll);
    else renderAll();

    window.SmartCharts = window.SmartCharts || {};
    window.SmartCharts.renderOpsBoard = renderAll;

})();
