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
        const end = parsed.value, suffix = parsed.suffix;

        const dur = 750, start = performance.now(), from = 0;
        function tick(now) {
            const t = Math.min(1, (now - start) / dur);
            const eased = 1 - Math.pow(1 - t, 3);
            const v = from + (end - from) * eased;
            el.textContent = formatWithSuffix(v, suffix);
            if (t < 1) requestAnimationFrame(tick);
        }
        requestAnimationFrame(tick);
    }

    function iconHtml(fa) {
        return fa ? `<i class="${fa}"></i>` : `<i class="fa-regular fa-chart-bar"></i>`;
    }

    function pillHtml(text, tone) {
        if (!text) return "";
        return `<div class="smart-execwatch__pill" data-tone="${tone || "neutral"}">${text}</div>`;
    }


    function renderOne(host) {
        const cfgId = host.getAttribute("data-config-id");
        const cfgNode = cfgId ? document.getElementById(cfgId) : null;
        if (!cfgNode) return;

        let cfg;
        try { cfg = JSON.parse(cfgNode.textContent || "{}"); } catch { return; }

        const dir = (cfg.dir || "rtl").toLowerCase();
        const animate = !!cfg.animate;

        host.innerHTML = "";
        host.setAttribute("dir", dir);

        // Root layout
        const layout = document.createElement("div");
        layout.className = "smart-execwatch__layout";
        host.appendChild(layout);

        // =========================
        // TOP: RISKS + SLA FULL WIDTH
        // =========================
        const topPanel = document.createElement("div");
        topPanel.className = "smart-execwatch__panel smart-execwatch__panel--full";
        layout.appendChild(topPanel);

        const rTitle = document.createElement("div");
        rTitle.className = "smart-execwatch__sectionTitle";
        rTitle.innerHTML = `<div>
      <div class="smart-execwatch__title">الإنذارات الرقابية</div>
      <div class="smart-execwatch__sub">مخاطر تحتاج قرار سريع</div>
    </div>`;
        topPanel.appendChild(rTitle);

        const risks = Array.isArray(cfg.risks) ? cfg.risks : [];
        for (const r of risks) {
            const item = document.createElement("div");
            item.className = "smart-execwatch__riskItem";
            item.setAttribute("data-tone", (r.tone || "danger"));
            if (r.href) item.style.cursor = "pointer";

            item.innerHTML = `
          <div class="min-w-0">
            <div class="smart-execwatch__riskTitle" title="${r.title || ""}">${r.title || ""}</div>
            ${r.desc ? `<div class="smart-execwatch__riskDesc" title="${r.desc}">${r.desc}</div>` : ""}
          </div>
          ${r.time ? `<div class="smart-execwatch__riskTime">${r.time}</div>` : ""}
        `;

            topPanel.appendChild(item);
            if (r.href) item.addEventListener("click", () => window.location.href = r.href);
        }

        const sla = cfg.sla || {};
        const slaBox = document.createElement("div");
        slaBox.className = "smart-execwatch__slaBox";
        slaBox.style.marginTop = "14px";
        if (sla.href) slaBox.style.cursor = "pointer";

        slaBox.innerHTML = `
      <div class="smart-execwatch__slaRow">
        <div>
          <div class="smart-execwatch__slaLabel">${sla.label || "SLA"}</div>
          ${sla.hint ? `<div class="smart-execwatch__slaHint">${sla.hint}</div>` : ""}
          <div class="smart-execwatch__pill" data-tone="${sla.tone || "info"}">مستوى الخدمة</div>
        </div>
        <div class="smart-execwatch__slaValue">
          <span class="smart-execwatch__slaNum">${sla.value || "—"}</span>
          <span style="font-size:12px;color:#64748b;font-weight:900;margin-inline-start:6px">${sla.unit || "%"}</span>
        </div>
      </div>
    `;
        topPanel.appendChild(slaBox);
        if (sla.href) slaBox.addEventListener("click", () => window.location.href = sla.href);

        // =========================
        // BOTTOM: PIPELINE + WORKSHOPS FULL WIDTH
        // =========================
        const mainPanel = document.createElement("div");
        mainPanel.className = "smart-execwatch__panel smart-execwatch__panel--full";
        layout.appendChild(mainPanel);

        // Pipeline
        const pTitle = document.createElement("div");
        pTitle.className = "smart-execwatch__sectionTitle";
        pTitle.innerHTML = `<div>
      <div class="smart-execwatch__title">سير الأعمال للطلبات</div>
      <div class="smart-execwatch__sub">مراحل الطلبات + متوسط زمن + المتأخر</div>
    </div>`;
        mainPanel.appendChild(pTitle);

        const pipe = document.createElement("div");
        pipe.className = "smart-execwatch__pipeline";
        mainPanel.appendChild(pipe);

        const stages = Array.isArray(cfg.stages) ? cfg.stages : [];
        for (const s of stages) {
            const st = document.createElement("div");
            st.className = "smart-execwatch__stage";
            if (s.href) st.style.cursor = "pointer";

            const percent = typeof s.percent === "number" ? clamp(s.percent, 0, 100) : 0;

            st.innerHTML = `
          <div class="smart-execwatch__stageTop">
            <div class="smart-execwatch__stageLabel">${s.label || ""}</div>
            <div class="smart-execwatch__stageMeta">
              <div class="smart-execwatch__mini">العدد: <span class="smart-execwatch__num">${(s.count ?? 0)}</span></div>
              <div class="smart-execwatch__mini">متوسط: <span>${(s.avgHours ?? 0)}</span> س</div>
              <div class="smart-execwatch__mini">متأخر: <span>${(s.overdue ?? 0)}</span></div>
            </div>
          </div>
          <div class="smart-execwatch__bar">
            <div class="smart-execwatch__barFill" data-tone="${s.tone || "info"}" style="width:${percent}%"></div>
          </div>
        `;

            pipe.appendChild(st);
            if (s.href) st.addEventListener("click", () => window.location.href = s.href);
        }

        // Workshops
        const wTitle = document.createElement("div");
        wTitle.className = "smart-execwatch__sectionTitle";
        wTitle.style.marginTop = "14px";
        wTitle.innerHTML = `<div>
      <div class="smart-execwatch__title">مراقبة الورش</div>
      <div class="smart-execwatch__sub">ضغط العمل/إنتاجية/تأخير/تحت الاجراء</div>
    </div>`;
        mainPanel.appendChild(wTitle);

        const wWrap = document.createElement("div");
        wWrap.className = "smart-execwatch__workshops";
        mainPanel.appendChild(wWrap);

        const workshops = Array.isArray(cfg.workshops) ? cfg.workshops : [];
        for (const w of workshops) {
            const box = document.createElement("div");
            box.className = "smart-execwatch__workshop";
            if (w.href) box.style.cursor = "pointer";

            box.innerHTML = `
          <div class="smart-execwatch__wTop">
            <div class="smart-execwatch__wLeft">
              <div class="smart-execwatch__wIcon">${iconHtml(w.icon)}</div>
              <div class="smart-execwatch__wName" title="${w.name || ""}">${w.name || ""}</div>
            </div>
            <div class="smart-execwatch__pill" data-tone="${w.tone || "neutral"}">ضغط العمل ${w.load ?? 0}%</div>
          </div>

          <div class="smart-execwatch__wStats">
            <div class="smart-execwatch__stat"><div class="smart-execwatch__statLabel">الطاقة</div><div class="smart-execwatch__statValue">${w.capacity ?? 0}</div></div>
            <div class="smart-execwatch__stat"><div class="smart-execwatch__statLabel">الإنتاجية</div><div class="smart-execwatch__statValue">${w.productivity ?? 0}%</div></div>
            <div class="smart-execwatch__stat"><div class="smart-execwatch__statLabel">تحت الاجراء</div><div class="smart-execwatch__statValue">${w.backlog ?? 0}</div></div>
            <div class="smart-execwatch__stat"><div class="smart-execwatch__statLabel">متأخر</div><div class="smart-execwatch__statValue">${w.delayed ?? 0}</div></div>
          </div>
        `;

            wWrap.appendChild(box);
            if (w.href) box.addEventListener("click", () => window.location.href = w.href);
        }

        // Animate numbers
        if (animate) {
            host.querySelectorAll(".smart-execwatch__slaNum").forEach(animateNumber);
            host.querySelectorAll(".smart-execwatch__num").forEach(animateNumber);
        }

        // Bars transition
        host.querySelectorAll(".smart-execwatch__barFill").forEach(el => {
            const w = el.style.width;
            el.style.width = "0%";
            requestAnimationFrame(() => { el.style.width = w; });
        });
    }

    //function renderOne(host) {
    //    const cfgId = host.getAttribute("data-config-id");
    //    const cfgNode = cfgId ? document.getElementById(cfgId) : null;
    //    if (!cfgNode) return;

    //    let cfg;
    //    try { cfg = JSON.parse(cfgNode.textContent || "{}"); } catch { return; }

    //    const dir = (cfg.dir || "rtl").toLowerCase();
    //    const animate = !!cfg.animate;

    //    host.innerHTML = "";
    //    host.setAttribute("dir", dir);

    //    // Root grid
    //    const grid = document.createElement("div");
    //    grid.className = "smart-execwatch__grid";
    //    host.appendChild(grid);

    //    // LEFT PANEL (KPIs + Pipeline + Workshops)
    //    const left = document.createElement("div");
    //    left.className = "smart-execwatch__panel";
    //    grid.appendChild(left);

    //    // KPIs
    //    const kpis = Array.isArray(cfg.kpis) ? cfg.kpis : [];
    //    const kTitle = document.createElement("div");
    //    kTitle.className = "smart-execwatch__sectionTitle";
    //    kTitle.innerHTML = `<div>
    //  <div class="smart-execwatch__title">مؤشرات المدراء</div>
    //  <div class="smart-execwatch__sub">ملخص رقابي سريع للأداء والمخاطر</div>
    //</div>`;
    //    left.appendChild(kTitle);

    //    const kWrap = document.createElement("div");
    //    kWrap.className = "smart-execwatch__kpis";
    //    left.appendChild(kWrap);

    //    for (const k of kpis) {
    //        const row = document.createElement("div");
    //        row.className = "smart-execwatch__kpi";
    //        if (k.href) row.style.cursor = "pointer";

    //        row.innerHTML = `
    //    <div class="smart-execwatch__kpiLeft">
    //      <div class="smart-execwatch__kpiIcon">${iconHtml(k.icon)}</div>
    //      <div class="min-w-0">
    //        <div class="smart-execwatch__kpiLabel" title="${k.label || ""}">${k.label || ""}</div>
    //        ${k.hint ? `<div class="smart-execwatch__kpiHint" title="${k.hint}">${k.hint}</div>` : ""}
    //      </div>
    //    </div>
    //    <div class="smart-execwatch__kpiRight">
    //      <div class="smart-execwatch__kpiValue">${k.value || ""}</div>
    //      ${k.unit ? `<div class="smart-execwatch__kpiUnit">${k.unit}</div>` : ""}
    //      ${k.delta ? pillHtml(k.delta, (k.deltaPositive === true ? "success" : k.deltaPositive === false ? "danger" : (k.tone || "info"))) : ""}
    //    </div>
    //  `;

    //        kWrap.appendChild(row);
    //        if (k.href) row.addEventListener("click", () => window.location.href = k.href);
    //    }

    //    // Pipeline
    //    const pTitle = document.createElement("div");
    //    pTitle.className = "smart-execwatch__sectionTitle";
    //    pTitle.style.marginTop = "14px";
    //    pTitle.innerHTML = `<div>
    //  <div class="smart-execwatch__title">سير الأعمال للطلبات</div>
    //  <div class="smart-execwatch__sub">مراحل الطلبات + متوسط زمن + المتأخر</div>
    //</div>`;
    //    left.appendChild(pTitle);

    //    const pipe = document.createElement("div");
    //    pipe.className = "smart-execwatch__pipeline";
    //    left.appendChild(pipe);

    //    const stages = Array.isArray(cfg.stages) ? cfg.stages : [];
    //    for (const s of stages) {
    //        const st = document.createElement("div");
    //        st.className = "smart-execwatch__stage";
    //        if (s.href) st.style.cursor = "pointer";

    //        const percent = typeof s.percent === "number" ? clamp(s.percent, 0, 100) : 0;

    //        st.innerHTML = `
    //    <div class="smart-execwatch__stageTop">
    //      <div class="smart-execwatch__stageLabel">${s.label || ""}</div>
    //      <div class="smart-execwatch__stageMeta">
    //        <div class="smart-execwatch__mini">العدد: <span class="smart-execwatch__num">${(s.count ?? 0)}</span></div>
    //        <div class="smart-execwatch__mini">متوسط: <span>${(s.avgHours ?? 0)}</span> س</div>
    //        <div class="smart-execwatch__mini">متأخر: <span>${(s.overdue ?? 0)}</span></div>
    //      </div>
    //    </div>
    //    <div class="smart-execwatch__bar">
    //      <div class="smart-execwatch__barFill" data-tone="${s.tone || "info"}" style="width:${percent}%"></div>
    //    </div>
    //  `;

    //        pipe.appendChild(st);
    //        if (s.href) st.addEventListener("click", () => window.location.href = s.href);
    //    }

    //    // Workshops
    //    const wTitle = document.createElement("div");
    //    wTitle.className = "smart-execwatch__sectionTitle";
    //    wTitle.style.marginTop = "14px";
    //    wTitle.innerHTML = `<div>
    //  <div class="smart-execwatch__title">مراقبة الورش</div>
    //  <div class="smart-execwatch__sub">حمولة/إنتاجية/تأخير/تحت الاجراء</div>
    //</div>`;
    //    left.appendChild(wTitle);

    //    const wWrap = document.createElement("div");
    //    wWrap.className = "smart-execwatch__workshops";
    //    left.appendChild(wWrap);

    //    const workshops = Array.isArray(cfg.workshops) ? cfg.workshops : [];
    //    for (const w of workshops) {
    //        const box = document.createElement("div");
    //        box.className = "smart-execwatch__workshop";
    //        if (w.href) box.style.cursor = "pointer";

    //        box.innerHTML = `
    //    <div class="smart-execwatch__wTop">
    //      <div class="smart-execwatch__wLeft">
    //        <div class="smart-execwatch__wIcon">${iconHtml(w.icon)}</div>
    //        <div class="smart-execwatch__wName" title="${w.name || ""}">${w.name || ""}</div>
    //      </div>
    //      <div class="smart-execwatch__pill" data-tone="${w.tone || "neutral"}">حمولة ${w.load ?? 0}%</div>
    //    </div>

    //    <div class="smart-execwatch__wStats">
    //      <div class="smart-execwatch__stat"><div class="smart-execwatch__statLabel">الطاقة</div><div class="smart-execwatch__statValue">${w.capacity ?? 0}</div></div>
    //      <div class="smart-execwatch__stat"><div class="smart-execwatch__statLabel">الإنتاجية</div><div class="smart-execwatch__statValue">${w.productivity ?? 0}%</div></div>
    //      <div class="smart-execwatch__stat"><div class="smart-execwatch__statLabel">تحت الاجراء</div><div class="smart-execwatch__statValue">${w.backlog ?? 0}</div></div>
    //      <div class="smart-execwatch__stat"><div class="smart-execwatch__statLabel">متأخر</div><div class="smart-execwatch__statValue">${w.delayed ?? 0}</div></div>
    //    </div>
    //  `;

    //        wWrap.appendChild(box);
    //        if (w.href) box.addEventListener("click", () => window.location.href = w.href);
    //    }

    //    // RIGHT STACK (Risks + SLA)
    //    const right = document.createElement("div");
    //    right.className = "smart-execwatch__rightStack";
    //    grid.appendChild(right);

    //    const riskPanel = document.createElement("div");
    //    riskPanel.className = "smart-execwatch__panel";
    //    right.appendChild(riskPanel);

    //    const rTitle = document.createElement("div");
    //    rTitle.className = "smart-execwatch__sectionTitle";
    //    rTitle.innerHTML = `<div>
    //  <div class="smart-execwatch__title">الإنذارات الرقابية</div>
    //  <div class="smart-execwatch__sub">مخاطر تحتاج قرار سريع</div>
    //</div>`;
    //    riskPanel.appendChild(rTitle);

    //    const risks = Array.isArray(cfg.risks) ? cfg.risks : [];
    //    for (const r of risks) {
    //        const item = document.createElement("div");
    //        item.className = "smart-execwatch__riskItem";
    //        item.setAttribute("data-tone", (r.tone || "danger"));
    //        if (r.href) item.style.cursor = "pointer";

    //        item.innerHTML = `
    //    <div class="min-w-0">
    //      <div class="smart-execwatch__riskTitle" title="${r.title || ""}">${r.title || ""}</div>
    //      ${r.desc ? `<div class="smart-execwatch__riskDesc" title="${r.desc}">${r.desc}</div>` : ""}
    //    </div>
    //    ${r.time ? `<div class="smart-execwatch__riskTime">${r.time}</div>` : ""}
    //  `;

    //        riskPanel.appendChild(item);
    //        if (r.href) item.addEventListener("click", () => window.location.href = r.href);
    //    }

    //    const sla = cfg.sla || {};
    //    const slaBox = document.createElement("div");
    //    slaBox.className = "smart-execwatch__slaBox";
    //    if (sla.href) slaBox.style.cursor = "pointer";

    //    slaBox.innerHTML = `
    //  <div class="smart-execwatch__slaRow">
    //    <div>
    //      <div class="smart-execwatch__slaLabel">${sla.label || "SLA"}</div>
    //      ${sla.hint ? `<div class="smart-execwatch__slaHint">${sla.hint}</div>` : ""}
    //      <div class="smart-execwatch__pill" data-tone="${sla.tone || "info"}">مستوى الخدمة</div>
    //    </div>
    //    <div class="smart-execwatch__slaValue">
    //      <span class="smart-execwatch__slaNum">${sla.value || "—"}</span>
    //      <span style="font-size:12px;color:#64748b;font-weight:900;margin-inline-start:6px">${sla.unit || "%"}</span>
    //    </div>
    //  </div>
    //`;
    //    right.appendChild(slaBox);
    //    if (sla.href) slaBox.addEventListener("click", () => window.location.href = sla.href);

    //    // Animate numbers
    //    if (animate) {
    //        host.querySelectorAll(".smart-execwatch__kpiValue").forEach(animateNumber);
    //        host.querySelectorAll(".smart-execwatch__slaNum").forEach(animateNumber);
    //        host.querySelectorAll(".smart-execwatch__num").forEach(animateNumber);
    //    }

    //    // Bars transition
    //    host.querySelectorAll(".smart-execwatch__barFill").forEach(el => {
    //        const w = el.style.width;
    //        el.style.width = "0%";
    //        requestAnimationFrame(() => { el.style.width = w; });
    //    });
    //}

    function renderAll() {
        document.querySelectorAll(".smart-execwatch[data-config-id]").forEach(renderOne);
    }

    if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", renderAll);
    else renderAll();

    window.SmartCharts = window.SmartCharts || {};
    window.SmartCharts.renderExecWatch = renderAll;

})();
