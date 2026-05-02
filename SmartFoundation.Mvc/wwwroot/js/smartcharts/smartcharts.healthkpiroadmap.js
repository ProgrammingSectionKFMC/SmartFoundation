(function () {

    function renderOne(host) {
        if (!host) return;

        const hasProgress = host.getAttribute("data-has-progress") === "1";
        const animate = host.getAttribute("data-animate") !== "0";

        if (hasProgress) {
            const pct = Number(host.getAttribute("data-pct") || "0") || 0;
            const fill = host.querySelector(".smart-healthkpi__bar-fill");
            if (fill) {
                if (!animate) fill.style.width = Math.max(0, Math.min(100, pct)) + "%";
                else {
                    fill.style.width = "0%";
                    requestAnimationFrame(() => {
                        fill.style.transition = "width .75s ease";
                        fill.style.width = Math.max(0, Math.min(100, pct)) + "%";
                    });
                }
            }
        }

        // Click
        host.querySelectorAll(".smart-healthkpi__node[data-href]").forEach(node => {
            const href = (node.getAttribute("data-href") || "").trim();
            if (!href) return;
            node.addEventListener("click", () => window.location.href = href);
        });
    }

    function renderAll() {
        document.querySelectorAll(".smart-healthkpi").forEach(renderOne);
    }

    if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", renderAll);
    else renderAll();

    window.SmartCharts = window.SmartCharts || {};
    window.SmartCharts.renderHealthKpiRoadmap = renderAll;

})();
