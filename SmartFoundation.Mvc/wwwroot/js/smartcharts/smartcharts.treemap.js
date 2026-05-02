(function () {

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

    function sumNode(node) {
        if (!node) return 0;
        const kids = Array.isArray(node.children) ? node.children : [];
        if (!kids.length) return Number(node.value) || 0;
        return kids.reduce((a, c) => a + sumNode(c), 0);
    }

    // Squarified-ish simple layout (good enough dashboard)
    function layoutRows(items, x, y, w, h) {
        const out = [];
        const total = items.reduce((a, it) => a + it._sum, 0) || 1;
        let offset = 0;

        // choose orientation by aspect ratio
        const horizontal = w >= h;

        items.forEach(it => {
            const frac = it._sum / total;
            if (horizontal) {
                const ww = w * frac;
                out.push({ node: it, x: x + offset, y, w: ww, h });
                offset += ww;
            } else {
                const hh = h * frac;
                out.push({ node: it, x, y: y + offset, w, h: hh });
                offset += hh;
            }
        });

        return out;
    }

    function ensureTooltip(host) {
        let tip = host.querySelector(".smart-treemap__tooltip");
        if (tip) return tip;
        tip = document.createElement("div");
        tip.className = "smart-treemap__tooltip";
        tip.innerHTML = `<div class="smart-treemap__tt-title"></div>
                     <div class="smart-treemap__tt-val"></div>`;
        host.appendChild(tip);
        return tip;
    }

    function renderLevel(host, cfg, levelNode, path) {
        host.innerHTML = "";
        host.setAttribute("dir", cfg.dir || "rtl");

        if (!levelNode) {
            const empty = document.createElement("div");
            empty.className = "smart-treemap__empty";
            empty.textContent = "لا توجد بيانات";
            host.appendChild(empty);
            return;
        }

        const tip = ensureTooltip(host);

        // breadcrumbs
        const crumbs = document.createElement("div");
        crumbs.className = "smart-treemap__crumbs";
        host.appendChild(crumbs);

        const rootCrumb = document.createElement("div");
        rootCrumb.className = "smart-treemap__crumb";
        rootCrumb.textContent = "الكل";
        rootCrumb.addEventListener("click", () => renderLevel(host, cfg, cfg.root, [cfg.root]));
        crumbs.appendChild(rootCrumb);

        for (let i = 1; i < path.length; i++) {
            const c = document.createElement("div");
            c.className = "smart-treemap__crumb";
            c.textContent = path[i].label || "";
            const targetIndex = i;
            c.addEventListener("click", () => {
                const subPath = path.slice(0, targetIndex + 1);
                renderLevel(host, cfg, subPath[subPath.length - 1], subPath);
            });
            crumbs.appendChild(c);
        }

        const wrap = document.createElement("div");
        wrap.className = "smart-treemap__wrap";
        wrap.style.height = `${cfg.height}px`;
        host.appendChild(wrap);

        const children = Array.isArray(levelNode.children) ? levelNode.children : [];
        if (!children.length) {
            // leaf: show single tile
            const tile = document.createElement("div");
            tile.className = "smart-treemap__tile";
            tile.style.left = "0px";
            tile.style.top = "0px";
            tile.style.width = "100%";
            tile.style.height = "100%";
            tile.style.background = levelNode.color || palette(0);

            const val = sumNode(levelNode);
            tile.innerHTML = `
        <div class="smart-treemap__label">
          <div class="smart-treemap__name">${levelNode.label || ""}</div>
          <div class="smart-treemap__value">${fmtNumber(val, cfg.valueFormat)}</div>
        </div>
      `;
            wrap.appendChild(tile);
            return;
        }

        // compute sums + sort descending
        const items = children.map((c, i) => ({ ...c, _sum: sumNode(c), _i: i }));
        items.sort((a, b) => (b._sum - a._sum));

        const rects = layoutRows(items, 0, 0, wrap.clientWidth || wrap.getBoundingClientRect().width || 800, cfg.height);

        rects.forEach((r, idx) => {
            const node = r.node;
            const w = Math.max(1, r.w);
            const h = Math.max(1, r.h);

            const tile = document.createElement("div");
            tile.className = "smart-treemap__tile";
            tile.style.left = `${r.x}px`;
            tile.style.top = `${r.y}px`;
            tile.style.width = `${w}px`;
            tile.style.height = `${h}px`;
            tile.style.background = node.color || palette(idx);

            const val = node._sum;
            const canLabel = (w >= cfg.minTile * 3 && h >= cfg.minTile * 2);

            if (canLabel) {
                tile.innerHTML = `
          <div class="smart-treemap__label">
            <div class="smart-treemap__name">${node.label || ""}</div>
            <div class="smart-treemap__value">${fmtNumber(val, cfg.valueFormat)}</div>
          </div>
        `;
            }

            // tooltip
            tile.addEventListener("mousemove", (e) => {
                tip.querySelector(".smart-treemap__tt-title").textContent = String(node.label || "");
                tip.querySelector(".smart-treemap__tt-val").textContent = fmtNumber(val, cfg.valueFormat);

                const rectHost = host.getBoundingClientRect();
                tip.style.transform = `translate(${(e.clientX - rectHost.left) + 10}px, ${(e.clientY - rectHost.top) + 10}px)`;
                tip.classList.add("is-show");
            });
            tile.addEventListener("mouseleave", () => tip.classList.remove("is-show"));

            // click: if has children => drilldown, else href
            const hasKids = Array.isArray(node.children) && node.children.length;
            if (hasKids) {
                tile.classList.add("is-click");
                tile.addEventListener("click", () => {
                    const nextPath = path.concat([node]);
                    renderLevel(host, cfg, node, nextPath);
                });
            } else if (node.href) {
                tile.classList.add("is-click");
                tile.addEventListener("click", () => window.location.href = node.href);
            }

            wrap.appendChild(tile);
        });
    }

    function renderOne(host) {
        const cfgId = host.getAttribute("data-config-id");
        const cfgNode = cfgId ? document.getElementById(cfgId) : null;
        if (!cfgNode) return;

        let cfg;
        try { cfg = JSON.parse(cfgNode.textContent || "{}"); } catch { return; }

        if (!cfg.root) {
            host.innerHTML = `<div class="smart-treemap__empty">لا توجد بيانات</div>`;
            return;
        }

        renderLevel(host, cfg, cfg.root, [cfg.root]);
    }

    function renderAll() {
        document.querySelectorAll(".smart-treemap[data-config-id]").forEach(renderOne);
    }

    if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", renderAll);
    else renderAll();

    window.SmartCharts = window.SmartCharts || {};
    window.SmartCharts.renderTreemaps = renderAll;

})();
