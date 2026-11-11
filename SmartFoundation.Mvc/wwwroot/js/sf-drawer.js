
/*
 * SmartFoundation - SmartDrawer
 * Independent, reusable drawer controller.
 * No dependency on SmartTable, SmartForm or Alpine.
 */
(function () {
    "use strict";

    if (window.SmartDrawer) return;

    const openDrawers = new Set();
    const previousFocus = new WeakMap();
    const closeTimers = new WeakMap();

    let originalOverflow = null;

    const focusableSelector = [
        'a[href]',
        'button:not([disabled])',
        'input:not([disabled])',
        'select:not([disabled])',
        'textarea:not([disabled])',
        '[tabindex]:not([tabindex="-1"])'
    ].join(",");

    function resolveDrawer(target) {
        if (typeof target === "string") {
            const id = target.replace(/^#/, "");
            const element = document.getElementById(id);

            return element?.matches("[data-sf-drawer]")
                ? element
                : null;
        }

        return target?.matches?.("[data-sf-drawer]")
            ? target
            : null;
    }

    function currentDrawer() {
        return Array.from(openDrawers).pop() || null;
    }

    function syncBodyScroll() {
        const needsLock = Array.from(openDrawers).some(
            drawer => drawer.dataset.lockScroll !== "false"
        );

        if (needsLock && originalOverflow === null) {
            originalOverflow = document.body.style.overflow;
            document.body.style.overflow = "hidden";
        }

        if (!needsLock && originalOverflow !== null) {
            document.body.style.overflow = originalOverflow;
            originalOverflow = null;
        }
    }

    function getFocusable(panel) {
        return Array.from(
            panel.querySelectorAll(focusableSelector)
        ).filter(element =>
            element.getClientRects().length > 0 &&
            window.getComputedStyle(element).visibility !== "hidden"
        );
    }

    function open(target, context = null) {
        const drawer = resolveDrawer(target);

        if (!drawer) {
            console.warn("SmartDrawer: drawer not found.");
            return false;
        }

        if (openDrawers.has(drawer)) return true;

        const panel = drawer.querySelector(".sf-drawer-panel");
        if (!panel) return false;

        const pendingTimer = closeTimers.get(drawer);
        if (pendingTimer) {
            clearTimeout(pendingTimer);
            closeTimers.delete(drawer);
        }

        // One drawer at a time in the first version.
        const active = currentDrawer();
        if (active && active !== drawer) {
            close(active, false);
        }

        previousFocus.set(drawer, document.activeElement);

        drawer.hidden = false;
        openDrawers.add(drawer);
        syncBodyScroll();

        requestAnimationFrame(() => {
            if (!openDrawers.has(drawer)) return;

            drawer.classList.add("is-open");
            panel.focus({ preventScroll: true });
        });

drawer.dispatchEvent(new CustomEvent("sf-drawer:open", {
    bubbles: true,
    detail: {
        id: drawer.id,
        context: context
    }
}));


        return true;
    }

    function close(target, restoreFocus = true) {
        const drawer = target
            ? resolveDrawer(target)
            : currentDrawer();

        if (!drawer || !openDrawers.has(drawer)) {
            return false;
        }

        openDrawers.delete(drawer);
        drawer.classList.remove("is-open");
        syncBodyScroll();

        const pendingTimer = closeTimers.get(drawer);
        if (pendingTimer) clearTimeout(pendingTimer);

        const timer = setTimeout(() => {
            if (!openDrawers.has(drawer)) {
                drawer.hidden = true;
            }
            closeTimers.delete(drawer);
        }, 280);

        closeTimers.set(drawer, timer);

        if (restoreFocus) {
            const element = previousFocus.get(drawer);

            if (element?.isConnected &&
                typeof element.focus === "function") {
                element.focus({ preventScroll: true });
            }
        }

        previousFocus.delete(drawer);

        drawer.dispatchEvent(new CustomEvent("sf-drawer:close", {
            bubbles: true,
            detail: { id: drawer.id }
        }));

        return true;
    }

    function closeAll() {
        Array.from(openDrawers).reverse().forEach(drawer => {
            close(drawer);
        });
    }

    function isOpen(target) {
        const drawer = resolveDrawer(target);
        return !!drawer && openDrawers.has(drawer);
    }

    // Close buttons and backdrop.
    document.addEventListener("click", event => {
        const target = event.target;
        if (!(target instanceof Element)) return;

        const closeButton = target.closest(
            "[data-sf-drawer-close]"
        );

        if (closeButton) {
            const drawer = closeButton.closest(
                "[data-sf-drawer]"
            );

            if (drawer && openDrawers.has(drawer)) {
                event.preventDefault();
                close(drawer);
            }
            return;
        }

        const backdrop = target.closest(
            "[data-sf-drawer-backdrop]"
        );

        if (backdrop) {
            const drawer = backdrop.closest(
                "[data-sf-drawer]"
            );

            if (
                drawer &&
                openDrawers.has(drawer) &&
                drawer.dataset.closeOnBackdrop !== "false"
            ) {
                close(drawer);
            }
        }
    });

    // Escape and keyboard focus containment.
    document.addEventListener("keydown", event => {
        const drawer = currentDrawer();
        if (!drawer) return;

        // Modal opened from inside a SmartDrawer.
        // Its content is teleported to document.body.
        const activeModal = document.querySelector(
            ".sf-modal-backdrop--drawer .sf-modal"
        );

        if (activeModal) {

            // Close the Modal first, without closing the Drawer.
            if (event.key === "Escape") {
                event.preventDefault();
                event.stopImmediatePropagation();

                activeModal
                    .querySelector(".sf-modal-close")
                    ?.click();

                return;
            }

            // Keep keyboard navigation inside the active Modal.
            if (event.key === "Tab") {
                const elements = getFocusable(activeModal);

                if (!elements.length) {
                    event.preventDefault();
                    activeModal.setAttribute("tabindex", "-1");
                    activeModal.focus({ preventScroll: true });
                    return;
                }

                const first = elements[0];
                const last = elements[elements.length - 1];
                const active = document.activeElement;

                if (!activeModal.contains(active)) {
                    event.preventDefault();
                    (event.shiftKey ? last : first).focus();
                } else if (event.shiftKey && active === first) {
                    event.preventDefault();
                    last.focus();
                } else if (!event.shiftKey && active === last) {
                    event.preventDefault();
                    first.focus();
                }

                return;
            }
        }

        if (event.key === "Escape") {
            if (drawer.dataset.closeOnEscape !== "false") {
                event.preventDefault();
                event.stopPropagation();
                close(drawer);
            }
            return;
        }

        if (event.key !== "Tab") return;

        const panel = drawer.querySelector(".sf-drawer-panel");
        if (!panel) return;

        const elements = getFocusable(panel);

        if (!elements.length) {
            event.preventDefault();
            panel.focus();
            return;
        }

        const first = elements[0];
        const last = elements[elements.length - 1];
        const active = document.activeElement;

        if (!panel.contains(active)) {
            event.preventDefault();
            (event.shiftKey ? last : first).focus();
        } else if (event.shiftKey && active === first) {
            event.preventDefault();
            last.focus();
        } else if (!event.shiftKey && active === last) {
            event.preventDefault();
            first.focus();
        }
    }, true);

    // Remote content: open a drawer and load server-rendered HTML into its body.
    // Lives here (not in page views) because pages loaded through the sidebar
    // are swapped in via innerHTML, where inline <script> tags never run.
    let remoteLoadId = 0;

    function escapeHtml(value) {
        return String(value).replace(/[&<>"']/g, c => ({
            "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
        }[c]));
    }

    function stateHtml(icon, text) {
        return '<div class="sf-drawer-state"><i class="' + icon +
            '" aria-hidden="true"></i><span>' + escapeHtml(text) + "</span></div>";
    }

    async function openRemote(target, url, label = "") {
        const drawer = resolveDrawer(target);

        // Same-origin relative URLs only.
        if (!drawer || !/^\/(?!\/)/.test(url)) return false;
        if (!open(drawer, { url })) return false;

        const body = drawer.querySelector(".sf-drawer-body");
        const title = drawer.querySelector(".sf-drawer-title");

        if (title) {
            title.dataset.defaultText ??= title.textContent.trim();
            title.textContent = label
                ? title.dataset.defaultText + " " + label
                : title.dataset.defaultText;
        }

        if (!body) return true;

        const loadId = ++remoteLoadId;
        body.innerHTML = stateHtml("fa-solid fa-spinner fa-spin", "جاري التحميل...");
        body.scrollTop = 0;

        try {
            const response = await fetch(url, {
                credentials: "same-origin",
                headers: { "X-Requested-With": "XMLHttpRequest" }
            });
            if (loadId !== remoteLoadId) return true;

            if (response.status === 401) {
                window.location.reload();
                return true;
            }

            if (!response.ok) {
                const messages = {
                    403: "ليس لديك صلاحية لعرض هذه البيانات",
                    404: "لم يتم العثور على البيانات المطلوبة"
                };
                body.innerHTML = stateHtml(
                    "fa-solid fa-triangle-exclamation",
                    messages[response.status] || "تعذر تحميل البيانات");
                return true;
            }

            body.innerHTML = await response.text();
        } catch (error) {
            if (loadId !== remoteLoadId) return true;
            console.error("SmartDrawer remote load failed:", error);
            body.innerHTML = stateHtml("fa-solid fa-triangle-exclamation", "تعذر تحميل البيانات");
        }

        return true;
    }

    // Links shaped as  #sf-drawer:<drawerId>:<relative url>  open a remote drawer.
    // Works for SmartTable LinkTemplate cells and for links inside drawer content.
    document.addEventListener("click", event => {
        const target = event.target;
        if (!(target instanceof Element)) return;

        const link = target.closest('a[href^="#sf-drawer:"]');
        if (!link) return;

        const match = /^#sf-drawer:([\w-]+):(.+)$/.exec(link.getAttribute("href"));
        if (!match) return;

        event.preventDefault();
        openRemote(match[1], match[2], link.textContent.trim());
    }, true);

    // Public API for all SmartFoundation pages.
    window.SmartDrawer = Object.freeze({
        open,
        openRemote,
        close,
        closeAll,
        isOpen
    });

})();


