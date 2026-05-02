(function () {
    function parseNumeric(text) {
        if (!text) return null;
        const raw = String(text).trim();

        // دعم K/M/B (اختياري)
        const m = raw.match(/^([\d,.\s]+)\s*([KMB])?$/i);
        if (!m) return null;

        const num = parseFloat(m[1].replace(/,/g, "").replace(/\s/g, ""));
        if (Number.isNaN(num)) return null;

        const suf = (m[2] || "").toUpperCase();
        const mul = suf === "K" ? 1e3 : suf === "M" ? 1e6 : suf === "B" ? 1e9 : 1;
        return { value: num * mul, suffix: suf, original: raw };
    }

    function formatWithSuffix(v, suffix) {
        if (!suffix) return Math.round(v).toString();
        const div = suffix === "K" ? 1e3 : suffix === "M" ? 1e6 : 1e9;
        const out = v / div;
        // رقم واحد عشري لو يحتاج
        const s = out >= 10 ? out.toFixed(0) : out.toFixed(1).replace(/\.0$/, "");
        return s + suffix;
    }

    function animateNumber(el) {
        const parsed = parseNumeric(el.textContent);
        if (!parsed) return;

        const end = parsed.value;
        const suffix = parsed.suffix;

        const dur = 650;
        const start = performance.now();
        const from = 0;

        function tick(now) {
            const t = Math.min(1, (now - start) / dur);
            // easeOutCubic
            const eased = 1 - Math.pow(1 - t, 3);
            const v = from + (end - from) * eased;
            el.textContent = formatWithSuffix(v, suffix);

            if (t < 1) requestAnimationFrame(tick);
        }
        requestAnimationFrame(tick);
    }

    function renderOne(host) {
        const val = host.querySelector(".smart-kpi__value");
        if (val) animateNumber(val);
    }

    function renderAll() {
        document.querySelectorAll(".smart-kpi").forEach(renderOne);
    }

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", renderAll);
    } else {
        renderAll();
    }

    window.SmartCharts = window.SmartCharts || {};
    window.SmartCharts.renderKpis = renderAll;
})();
