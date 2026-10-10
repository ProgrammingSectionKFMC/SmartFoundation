
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

    // Public API for all SmartFoundation pages.
    window.SmartDrawer = Object.freeze({
        open,
        close,
        closeAll,
        isOpen
    });

})();
