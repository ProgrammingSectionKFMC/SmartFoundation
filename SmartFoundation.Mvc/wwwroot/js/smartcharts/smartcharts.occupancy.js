(function () {

    function renderOne(host) {
        const cfgId = host.getAttribute("data-config-id");
        const cfgNode = document.getElementById(cfgId);
        if (!cfgNode) return;

        const cfg = JSON.parse(cfgNode.textContent || "{}");
        const statuses = cfg.statuses || [];
        const total = statuses.reduce((a, s) => a + (s.units || 0), 0);

        host.innerHTML = "";
        host.setAttribute("dir", cfg.dir || "rtl");

        const list = document.createElement("div");
        list.className = "smart-occupancy__list";
        host.appendChild(list);

        statuses.forEach(s => {
            const pct = total > 0 ? (s.units / total) * 100 : 0;

            const row = document.createElement("div");
            row.className = "smart-occupancy__row" + (s.href ? " smart-occupancy__click" : "");

            const label = document.createElement("div");
            label.className = "smart-occupancy__label";
            label.textContent = s.label;

            const track = document.createElement("div");
            track.className = "smart-occupancy__track";

            const fill = document.createElement("div");
            fill.className = "smart-occupancy__fill";
            fill.style.background = s.color || "#64748b";
            fill.style.width = "0%";
            track.appendChild(fill);

            const val = document.createElement("div");
            val.className = "smart-occupancy__value";
            val.textContent = `${s.units} وحدة${cfg.showPercent ? ` • ${pct.toFixed(1)}%` : ""}`;

            row.appendChild(label);
            row.appendChild(track);
            row.appendChild(val);
            list.appendChild(row);

            requestAnimationFrame(() => {
                fill.style.width = `${pct.toFixed(2)}%`;
            });

            if (s.href) {
                row.addEventListener("click", () => window.location.href = s.href);
            }
        });
    }

    function renderAll() {
        document.querySelectorAll(".smart-occupancy[data-config-id]").forEach(renderOne);
    }

    document.readyState === "loading"
        ? document.addEventListener("DOMContentLoaded", renderAll)
        : renderAll();

    window.SmartCharts = window.SmartCharts || {};
    window.SmartCharts.renderOccupancy = renderAll;

})();
