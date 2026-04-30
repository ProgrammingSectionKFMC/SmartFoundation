/* File: wwwroot/js/smartcharts.healthkpiy.js */
(function () {
    const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
    const fmt = (n) => (n === null || n === undefined || n === "") ? "—" : ("" + Math.round(Number(n)));

    //  فقط لو الوحدة % داخل (منجز/مستهدف/متبقي)
    const isPctUnit = (u) => (String(u || "").trim() === "%");
    const fmtChipVal = (n, unit) => {
        const v = fmt(n);
        if (v === "—") return v;
        return isPctUnit(unit) ? (v + "%") : v;
    };

    function calcPct(actual, target) {
        if (actual === null || actual === undefined) return null;
        if (target === null || target === undefined) return null;
        const t = Number(target);
        if (!isFinite(t) || t <= 0) return 0;
        return clamp((Number(actual) / t) * 100, 0, 100);
    }

    function sumNullable(arr) {
        let hasAny = false;
        let s = 0;
        for (const v of arr) {
            if (v === null || v === undefined) continue;
            hasAny = true;
            s += Number(v);
        }
        return hasAny ? s : null;
    }

    function el(tag, cls, html) {
        const n = document.createElement(tag);
        if (cls) n.className = cls;
        if (html !== undefined) n.innerHTML = html;
        return n;
    }

    function getCfg(host) {
        const id = host.getAttribute("data-config-id");
        const node = document.getElementById(id);
        if (!node) return null;
        try { return JSON.parse(node.textContent || "{}"); } catch { return null; }
    }

    function ensureTooltip(host) {
        const tip = host.querySelector(".hkpa-tip");
        const tTitle = tip.querySelector(".hkpa-tip__title");
        const tBody = tip.querySelector(".hkpa-tip__body");

        function show(anchor, title, body) {
            tTitle.textContent = title || "";
            tBody.innerHTML = body || "";
            tip.setAttribute("aria-hidden", "false");
            tip.classList.add("is-on");

            const r = anchor.getBoundingClientRect();
            const pad = 12;
            const w = tip.offsetWidth || 320;
            const h = tip.offsetHeight || 120;

            let left = r.left + (r.width / 2) - (w / 2);
            left = Math.max(pad, Math.min(left, window.innerWidth - w - pad));

            let top = r.top - h - 10;
            if (top < pad) top = r.bottom + 10;

            tip.style.left = left + "px";
            tip.style.top = top + "px";
        }

        function hide() {
            tip.setAttribute("aria-hidden", "true");
            tip.classList.remove("is-on");
        }

        host.addEventListener("mouseover", (e) => {
            const a = e.target.closest("[data-tip-title]");
            if (!a) return;
            show(a, a.getAttribute("data-tip-title"), a.getAttribute("data-tip-body"));
        });

        host.addEventListener("mouseout", (e) => {
            if (e.target.closest("[data-tip-title]")) hide();
        });

        return { show, hide };
    }

    // =========================
    // View switch
    // =========================
    function initViewSwitch(host) {
        const key = "hkpa_view_" + (host.id || "");
        const btns = Array.from(host.querySelectorAll(".hkpa-viewbtn"));
        if (!btns.length) return;

        const saved = localStorage.getItem(key);
        const initial = saved || "matrix";
        host.setAttribute("data-view", initial);

        btns.forEach(b => {
            b.classList.toggle("is-on", b.getAttribute("data-view") === initial);
            b.addEventListener("click", () => {
                const v = b.getAttribute("data-view");
                host.setAttribute("data-view", v);
                localStorage.setItem(key, v);
                btns.forEach(x => x.classList.toggle("is-on", x === b));
            });
        });
    }

    // =========================
    // ✅ Tooltip builders
    // =========================
    function buildSummaryTip(k, overallActual, overallTarget) {
        return (
            `<div class="hkpa-tiprow"><div class="hkpa-tipk">المنجز</div><div class="hkpa-tipv">${fmt(overallActual)} ${k.unit || ""}</div></div>
             <div class="hkpa-tiprow"><div class="hkpa-tipk">الهدف</div><div class="hkpa-tipv">${fmt(overallTarget)} ${k.unit || ""}</div></div>`
        );
    }

    function buildFullTipFromYears(k, yearsSorted) {
        let body = "";
        for (const y of yearsSorted) {
            const target = (y.target !== undefined) ? y.target : null;
            const actual = (y.actual !== undefined) ? y.actual : null;
            const remain = (target === null || actual === null) ? null : Math.max(0, Number(target) - Number(actual));
            const pct = calcPct(actual, target);
            const pctText = (pct === null) ? "—" : (Math.round(pct) + "%");

            const desc = (y.title || "—") + (y.subtitle ? (" • " + y.subtitle) : "");

            body +=
                `<div class="hkpa-tiprow"><div class="hkpa-tipk">السنة</div><div class="hkpa-tipv">${y.year}</div></div>
                 <div class="hkpa-tiprow"><div class="hkpa-tipk">وصف</div><div class="hkpa-tipv">${desc}</div></div>
                 <div class="hkpa-tiprow"><div class="hkpa-tipk">هدف</div><div class="hkpa-tipv">${fmt(target)} ${k.unit || ""}</div></div>
                 <div class="hkpa-tiprow"><div class="hkpa-tipk">منجز</div><div class="hkpa-tipv">${fmt(actual)} ${k.unit || ""}</div></div>
                 <div class="hkpa-tiprow"><div class="hkpa-tipk">متبقي</div><div class="hkpa-tipv">${fmt(remain)} ${k.unit || ""}</div></div>
                 <div class="hkpa-tiprow"><div class="hkpa-tipk">النسبة</div><div class="hkpa-tipv">${pctText}</div></div>`;

            body += `<div class="hkpa-tiprow" style="border-top:1px solid rgba(226,232,240,.95); padding-top:6px; margin-top:4px"></div>`;
        }
        return body;
    }

    // =========================
    // Indicator chips (top row)
    // =========================
    function renderIndicatorChip(host, k, overallActual, overallTarget, overallPct) {
        const pctText = (overallPct === null) ? "—" : (Math.round(overallPct) + "%");
        const chip = el("a", "hkpa-ind", "");
        chip.href = k.href || "#";
        chip.setAttribute("role", "button");

        chip.innerHTML = `
      <div class="hkpa-ind__head">
        <span class="hkpa-emoji">${k.emoji || "🎯"}</span>
        <div class="hkpa-ind__ttl">
          <div class="hkpa-ind__t">${k.title || ""}</div>
          <div class="hkpa-ind__s">${k.subtitle || ""}</div>
        </div>
        <div class="hkpa-ind__pct">${pctText}</div>
      </div>
      <div class="hkpa-ind__meta">
        <span class="hkpa-ind__num">${fmt(overallActual)} / ${fmt(overallTarget)} ${k.unit || ""}</span>
      </div>
    `;

        const topTipMode = (host.getAttribute("data-top-tip") || "").toLowerCase();
        const wantFull = topTipMode === "full";

        if (wantFull) {
            const ys = (k.years || []).slice().sort((a, b) => (a.year || 0) - (b.year || 0));
            chip.setAttribute("data-tip-title", k.title || "تفاصيل المؤشر");
            chip.setAttribute("data-tip-body", buildFullTipFromYears(k, ys));
        } else {
            chip.setAttribute("data-tip-title", "ملخص المؤشر");
            chip.setAttribute("data-tip-body", buildSummaryTip(k, overallActual, overallTarget));
        }

        return chip;
    }

    // =========================
    // Detail view
    // =========================
    function renderYearPanel(year, items) {
        const panel = el("div", "hkpa-yearpanel", "");
        panel.innerHTML = `
      <div class="hkpa-yearpanel__head">
        <div class="hkpa-yearpanel__y">${year}</div>
        <div class="hkpa-yearpanel__hint">تفاصيل 7 مؤشرات</div>
      </div>
      <div class="hkpa-yearpanel__grid"></div>
    `;
        const grid = panel.querySelector(".hkpa-yearpanel__grid");
        for (const it of items) grid.appendChild(it);
        return panel;
    }

    function renderYearItem(k, y) {
        const target = (y && y.target !== undefined) ? y.target : null;
        const actual = (y && y.actual !== undefined) ? y.actual : null;
        const remain = (target === null || actual === null) ? null : Math.max(0, Number(target) - Number(actual));

        const pct = calcPct(actual, target);
        const pctText = (pct === null) ? "—" : (Math.round(pct) + "%");

        const item = el("div", "hkpa-item", "");
        item.innerHTML = `
      <div class="hkpa-item__top">
        <div class="hkpa-item__id">
          <span class="hkpa-emoji">${k.emoji || "🎯"}</span>
          <div class="hkpa-item__t">
            <div class="hkpa-item__name">${k.title || ""}</div>
            <div class="hkpa-item__desc">${(y && (y.title || y.subtitle)) ? ((y.title || "") + (y.subtitle ? (" • " + y.subtitle) : "")) : "—"}</div>
          </div>
        </div>

        <div class="hkpa-ring" data-pct="${pct === null ? "" : Math.round(pct)}">
          <svg viewBox="0 0 36 36" class="hkpa-ring__svg" aria-hidden="true">
            <path class="hkpa-ring__bg" d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"></path>
            <path class="hkpa-ring__fg" d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"></path>
          </svg>
          <div class="hkpa-ring__txt">${pctText}</div>
        </div>
      </div>

      <div class="hkpa-item__nums">
        <div class="hkpa-num hkpa-num--target">
          <div class="hkpa-num__k">هدف</div>
          <div class="hkpa-num__v">${fmt(target)}</div>
        </div>
        <div class="hkpa-num hkpa-num--actual">
          <div class="hkpa-num__k">منجز</div>
          <div class="hkpa-num__v">${fmt(actual)}</div>
        </div>
        <div class="hkpa-num hkpa-num--remain">
          <div class="hkpa-num__k">متبقي</div>
          <div class="hkpa-num__v">${fmt(remain)}</div>
        </div>
      </div>
    `;

        const pctStroke = (pct === null) ? 0 : clamp(Math.round(pct), 0, 100);
        item.querySelector(".hkpa-ring__fg")
            .setAttribute("stroke-dasharray", pctStroke.toFixed(0) + ", 100");

        const tipBody =
            `<div class="hkpa-tiprow"><div class="hkpa-tipk">السنة</div><div class="hkpa-tipv">${y ? y.year : "—"}</div></div>
       <div class="hkpa-tiprow"><div class="hkpa-tipk">منجز</div><div class="hkpa-tipv">${fmt(actual)} ${k.unit || ""}</div></div>
       <div class="hkpa-tiprow"><div class="hkpa-tipk">هدف</div><div class="hkpa-tipv">${fmt(target)} ${k.unit || ""}</div></div>
       <div class="hkpa-tiprow"><div class="hkpa-tipk">متبقي</div><div class="hkpa-tipv">${fmt(remain)} ${k.unit || ""}</div></div>`;

        item.setAttribute("data-tip-title", k.title || "تفاصيل المؤشر");
        item.setAttribute("data-tip-body", tipBody);

        return item;
    }

    // =========================
    // ✅ Matrix compact view
    // =========================
    function renderMatrix(host, cfg, years) {
        const wrap = host.querySelector(".hkpa-matrix");
        if (!wrap) return;
        wrap.innerHTML = "";

        const indicators = (cfg.indicators || []);
        if (!indicators.length) return;

        const head = el("div", "hkpa-mx__head", "");
        head.appendChild(el("div", "hkpa-mx__hcell", "المؤشر"));
        years.forEach(y => head.appendChild(el("div", "hkpa-mx__hcell", "" + y)));
        wrap.appendChild(head);

        indicators.forEach(k => {
            const row = el("div", "hkpa-mx__row", "");

            const kpiCell = el("div", "hkpa-mx__kpi", "");
            kpiCell.innerHTML = `
        <span class="hkpa-emoji">${k.emoji || "🎯"}</span>
        <div class="hkpa-mx__kpiT">
          <div class="hkpa-mx__kpiName">${k.title || ""}</div>
          <div class="hkpa-mx__kpiSub">${k.subtitle || ""}</div>
        </div>
      `;
            row.appendChild(kpiCell);

            years.forEach(yr => {
                const y = (k.years || []).find(a => a.year === yr) || { year: yr, target: null, actual: null, title: "—", subtitle: "—" };

                const target = (y.target !== undefined) ? y.target : null;
                const actual = (y.actual !== undefined) ? y.actual : null;
                const remain = (target === null || actual === null) ? null : Math.max(0, Number(target) - Number(actual));

                const pct = calcPct(actual, target);
                const pctText = (pct === null) ? "—" : (Math.round(pct) + "%");

                // ✅ هنا الإصلاح: لو الوحدة % نلحقها للقيم داخل chips فقط
                const aText = fmtChipVal(actual, k.unit);
                const tText = fmtChipVal(target, k.unit);
                const rText = fmtChipVal(remain, k.unit);

                const pill = el("div", "hkpa-mx__pill", "");
                pill.innerHTML = `
          <div class="hkpa-mx__mini">
            <div class="hkpa-ring" style="width:44px;height:44px">
              <svg viewBox="0 0 36 36" class="hkpa-ring__svg" aria-hidden="true" style="width:44px;height:44px">
                <path class="hkpa-ring__bg" d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"></path>
                <path class="hkpa-ring__fg" d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"></path>
              </svg>
              <div class="hkpa-ring__txt" style="font-size:11px">${pctText}</div>
            </div>

            <div>
              <div class="hkpa-mx__nums">
                <span class="hkpa-mx__n hkpa-mx__n--actual"><b class="hkpa-mx__lbl">منجز</b><i class="hkpa-mx__val">${aText}</i></span>
                <span class="hkpa-mx__n hkpa-mx__n--target"><b class="hkpa-mx__lbl">مستهدف</b><i class="hkpa-mx__val">${tText}</i></span>
                <span class="hkpa-mx__n hkpa-mx__n--remain"><b class="hkpa-mx__lbl">متبقي</b><i class="hkpa-mx__val">${rText}</i></span>
              </div>
            </div>
          </div>
        `;

                const isEmpty =
                    (actual === null || Number(actual) === 0) &&
                    (pct === null || Number(pct) === 0);
                pill.setAttribute("data-empty", isEmpty ? "1" : "0");

                const pctStroke = (pct === null) ? 0 : clamp(Math.round(pct), 0, 100);
                pill.querySelector(".hkpa-ring__fg")
                    .setAttribute("stroke-dasharray", pctStroke.toFixed(0) + ", 100");

                const tipBody =
                    `<div class="hkpa-tiprow"><div class="hkpa-tipk">السنة</div><div class="hkpa-tipv">${yr}</div></div>
           <div class="hkpa-tiprow"><div class="hkpa-tipk">وصف</div><div class="hkpa-tipv">${(y.title || "—")}${y.subtitle ? (" • " + y.subtitle) : ""}</div></div>
           <div class="hkpa-tiprow"><div class="hkpa-tipk">هدف</div><div class="hkpa-tipv">${fmt(target)} ${k.unit || ""}</div></div>
           <div class="hkpa-tiprow"><div class="hkpa-tipk">منجز</div><div class="hkpa-tipv">${fmt(actual)} ${k.unit || ""}</div></div>
           <div class="hkpa-tiprow"><div class="hkpa-tipk">متبقي</div><div class="hkpa-tipv">${fmt(remain)} ${k.unit || ""}</div></div>`;

                pill.setAttribute("data-tip-title", k.title || "تفاصيل المؤشر");
                pill.setAttribute("data-tip-body", tipBody);

                const cell = el("div", "hkpa-mx__cell", "");
                cell.appendChild(pill);
                row.appendChild(cell);
            });

            wrap.appendChild(row);
        });
    }

    function render(host, cfg) {
        const indicatorsWrap = host.querySelector(".hkpa-indicators");
        const yearsWrap = host.querySelector(".hkpa-years");

        indicatorsWrap.innerHTML = "";
        yearsWrap.innerHTML = "";

        const indicators = (cfg.indicators || []);
        if (!indicators.length) return;

        const allYears = new Set();
        for (const k of indicators) for (const y of (k.years || [])) allYears.add(y.year);
        const years = Array.from(allYears).sort((a, b) => a - b);

        for (const k of indicators) {
            const ys = (k.years || []);
            const sumActual = sumNullable(ys.map(x => x.actual));
            const sumTarget = sumNullable(ys.map(x => x.target));
            const overallTarget = (k.planGoal !== null && k.planGoal !== undefined) ? k.planGoal : sumTarget;
            const overallPct = calcPct(sumActual, overallTarget);

            indicatorsWrap.appendChild(renderIndicatorChip(host, k, sumActual, overallTarget, overallPct));
        }

        renderMatrix(host, cfg, years);

        for (const yr of years) {
            const items = indicators.map(k => {
                const y = (k.years || []).find(a => a.year === yr) || { year: yr, target: null, actual: null, title: "—", subtitle: "—" };
                return renderYearItem(k, y);
            });
            yearsWrap.appendChild(renderYearPanel(yr, items));
        }

        ensureTooltip(host);
        initViewSwitch(host);
    }

    function bootOne(host) {
        const cfg = getCfg(host);
        if (!cfg) return;
        render(host, cfg);
    }

    function bootAll() {
        document.querySelectorAll(".smart-healthkpiannual[data-config-id]").forEach(bootOne);
    }

    window.SmartCharts = window.SmartCharts || {};
    window.SmartCharts.renderHealthKpiAnnual = bootAll;

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", bootAll);
    } else {
        bootAll();
    }
})();
