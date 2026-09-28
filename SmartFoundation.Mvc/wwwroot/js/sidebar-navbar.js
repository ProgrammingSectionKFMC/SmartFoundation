(function () {
    "use strict";

    if (window.__sfSidebarNavbarInitialized) {
        return;
    }

    window.__sfSidebarNavbarInitialized = true;

    const SIDEBAR_STATES = {
        PINNED: "sidebar-pinned",
        COLLAPSED: "sidebar-collapsed",
        MOBILE_OPEN: "with-sidebar-open"
    };

    function runWhenReady(callback) {
        if (document.readyState === "loading") {
            document.addEventListener("DOMContentLoaded", callback, { once: true });
            return;
        }

        callback();
    }

    function applyInitialSidebarState() {
        const body = document.body;
        if (!body || window.innerWidth < 1024) {
            return;
        }

        const savedSidebarState = localStorage.getItem("sidebarState");
        if (savedSidebarState === SIDEBAR_STATES.COLLAPSED) {
            body.classList.add(SIDEBAR_STATES.COLLAPSED);
            body.classList.remove(SIDEBAR_STATES.PINNED, SIDEBAR_STATES.MOBILE_OPEN);
            return;
        }

        body.classList.add(SIDEBAR_STATES.PINNED);
        body.classList.remove(SIDEBAR_STATES.COLLAPSED, SIDEBAR_STATES.MOBILE_OPEN);
    }

    function getSidebarMenuData() {
        const source = document.getElementById("sidebar-menu-data");
        if (!source) {
            return [];
        }

        try {
            return JSON.parse(source.textContent || "[]");
        } catch {
            return [];
        }
    }

    function normalizePath(path) {
        if (!path) {
            return "/";
        }

        let normalized = path.split("?")[0].trim().toLowerCase();

        if (normalized !== "/" && normalized.endsWith("/")) {
            normalized = normalized.slice(0, -1);
        }

        if (normalized === "" || normalized === "/home" || normalized === "/home/index") {
            return "/home";
        }

        return normalized;
    }

    function cleanMenuLink(link) {
        if (!link || typeof link !== "string") {
            return "";
        }

        let cleaned = link.trim();

        while (cleaned.startsWith("../")) {
            cleaned = cleaned.substring(3);
        }

        if (cleaned.startsWith("/")) {
            cleaned = cleaned.substring(1);
        }

        if (cleaned.toLowerCase().endsWith(".aspx")) {
            cleaned = cleaned.substring(0, cleaned.length - 5);
        }

        return cleaned;
    }

    function escapeHtml(text) {
        const div = document.createElement("div");
        div.textContent = text ?? "";
        return div.innerHTML;
    }

    function normalizeArabicText(text) {
        return (text || "")
            .toString()
            .trim()
            .toLowerCase()
            .replace(/[أإآا]/g, "ا")
            .replace(/ة/g, "ه")
            .replace(/ى/g, "ي")
            .replace(/ؤ/g, "و")
            .replace(/ئ/g, "ي")
            .replace(/\s+/g, " ");
    }

    function getMenuDisplayName(item) {
        return (item?.MenuName_A || item?.MenuNameForView || "").toString().trim();
    }

    function highlightMatch(text, query) {
        const safeText = text || "";
        const safeQuery = (query || "").trim();
        if (!safeQuery) {
            return escapeHtml(safeText);
        }

        const normalizedText = normalizeArabicText(safeText);
        const normalizedQuery = normalizeArabicText(safeQuery);
        const startIndex = normalizedText.indexOf(normalizedQuery);

        if (startIndex === -1) {
            return escapeHtml(safeText);
        }

        const start = safeText.slice(0, startIndex);
        const middle = safeText.slice(startIndex, startIndex + safeQuery.length);
        const end = safeText.slice(startIndex + safeQuery.length);

        return `${escapeHtml(start)}<mark class="sidebar-search-match">${escapeHtml(middle)}</mark>${escapeHtml(end)}`;
    }

    function getItemLink(item) {
        const rawController = item?.MPLink ?? item?.mpLink ?? "";
        const rawAction = item?.MenuLink ?? item?.menuLink ?? "";

        const controller = cleanMenuLink(rawController);
        const action = cleanMenuLink(rawAction);

        const hasChildren = Array.isArray(item?.Children) && item.Children.length > 0;
        const hasAnyLinkInfo = controller !== "" || action !== "";

        if (!hasAnyLinkInfo || hasChildren) {
            return "#";
        }

        if (controller && action) {
            return `/${controller}/${action}`;
        }

        if (action) {
            return `/${action}`;
        }

        if (controller) {
            return `/${controller}`;
        }

        return "#";
    }

    function isCurrentMenuItem(item) {
        const itemLink = getItemLink(item);
        return itemLink !== "#" && normalizePath(itemLink) === normalizePath(window.location.pathname);
    }

    function itemOrDescendantIsActive(item) {
        if (!item) {
            return false;
        }

        if (isCurrentMenuItem(item)) {
            return true;
        }

        const children = Array.isArray(item.Children) ? item.Children : [];
        return children.some(child => itemOrDescendantIsActive(child));
    }

    function filterMenuTree(items, query) {
        if (!Array.isArray(items)) {
            return [];
        }

        const normalizedQuery = normalizeArabicText(query);
        if (!normalizedQuery) {
            return items;
        }

        const result = [];

        for (const item of items) {
            const children = Array.isArray(item.Children) ? item.Children : [];
            const filteredChildren = filterMenuTree(children, query);

            const itemName = getMenuDisplayName(item);
            const isSelfMatch = normalizeArabicText(itemName).includes(normalizedQuery);
            const isActiveSelf = isCurrentMenuItem(item);
            const hasActiveDescendant = children.some(child => itemOrDescendantIsActive(child));
            const hadChildrenOriginally = children.length > 0;

            if (isSelfMatch || filteredChildren.length > 0 || isActiveSelf || hasActiveDescendant) {
                let finalChildren;

                if (isSelfMatch) {
                    finalChildren = children;
                } else {
                    finalChildren = children
                        .filter(child => {
                            const childFiltered = filteredChildren.some(x => x.MPID === child.MPID);
                            const childActivePath = itemOrDescendantIsActive(child);
                            return childFiltered || childActivePath;
                        })
                        .map(child => {
                            const existingFiltered = filteredChildren.find(x => x.MPID === child.MPID);
                            return existingFiltered || child;
                        });
                }

                result.push({
                    ...item,
                    __matched: isSelfMatch,
                    __forceOpen: hadChildrenOriginally || finalChildren.length > 0 || hasActiveDescendant,
                    __hadChildrenOriginally: hadChildrenOriginally,
                    Children: finalChildren
                });
            }
        }

        return result;
    }

    function hasActiveChildRecursive(item) {
        if (!Array.isArray(item.Children)) {
            return false;
        }

        for (const child of item.Children) {
            const itemLink = getItemLink(child);
            const isActive = itemLink !== "#" && normalizePath(window.location.pathname) === normalizePath(itemLink);

            if (isActive || hasActiveChildRecursive(child)) {
                return true;
            }
        }

        return false;
    }

    function buildMenuItem(item, level) {
        const paddingClass = level > 1 ? " ps-10" : "";
        const baseClasses = "flex items-center w-full p-2 rounded-md transition duration-75 group hover:bg-slate-700 hover:text-slate-50 text-slate-200";
        const linkClasses = level === 1 ? baseClasses : baseClasses + paddingClass;

        const rawMenuName = getMenuDisplayName(item);
        const currentSearchValue = document.getElementById("sidebar-menu-search")?.value || "";
        const menuName = currentSearchValue
            ? highlightMatch(rawMenuName, currentSearchValue)
            : escapeHtml(rawMenuName);

        const itemLink = getItemLink(item);
        const hasChildren = (Array.isArray(item.Children) && item.Children.length > 0) || item.__hadChildrenOriginally === true;
        const isClickableLink = itemLink !== "#" && !hasChildren;
        const isActive = isClickableLink && normalizePath(window.location.pathname) === normalizePath(itemLink);
        const activeClass = isActive ? " bg-slate-700 text-slate-50" : "";

        const iconHtml = item.MPIcon && item.MPIcon.trim() !== ""
            ? `<i class="${escapeHtml(item.MPIcon)} me-3 h-5 w-5 text-slate-400 transition-colors duration-200 group-hover:text-slate-50"></i>`
            : "";

        let html = "";

        if (hasChildren) {
            const collapseId = `dropdown-${item.MPID}`;
            const isSearching = !!(document.getElementById("sidebar-menu-search")?.value || "").trim();
            const shouldBeOpen = isSearching || hasActiveChildRecursive(item) || item.__forceOpen === true;
            const childListClasses = shouldBeOpen ? "py-2 space-y-0" : "hidden py-2 space-y-0";
            const expandedAttr = shouldBeOpen ? "true" : "false";
            const safeChildren = Array.isArray(item.Children) ? item.Children : [];

            html += `
            <button type="button"
                    class="${linkClasses}${activeClass} sidebar-menu-toggle"
                    data-menu-toggle="${collapseId}"
                    aria-controls="${collapseId}"
                    aria-expanded="${expandedAttr}">
                ${iconHtml}
                <span class="flex-1 text-right leading-snug break-words whitespace-normal">
                    ${menuName}
                </span>
                <svg class="menu-chevron h-4 w-4 text-slate-400 transition-transform duration-200 group-hover:text-slate-50"
                     fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd"
                          d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z"
                          clip-rule="evenodd"></path>
                </svg>
            </button>
            <ul id="${collapseId}" class="${childListClasses}">`;

            safeChildren.forEach((child, index) => {
                html += `<li>${index === 0 ? "" : '<div class="menu-sep sm"></div>'}${buildMenuItem(child, level + 1)}</li>`;
            });

            html += "</ul>";
            return html;
        }

        if (isClickableLink) {
            return `
                    <a href="${escapeHtml(itemLink)}"
                       class="${linkClasses}${activeClass} sidebar-link"
                       data-url="${escapeHtml(itemLink)}">
                        ${iconHtml}
                        <span class="flex-1 leading-snug break-words whitespace-normal">
                            ${menuName}
                        </span>
                    </a>`;
        }

        return `
                    <div class="${linkClasses}${activeClass}">
                        ${iconHtml}
                        <span class="flex-1 leading-snug break-words whitespace-normal">
                            ${menuName}
                        </span>
                    </div>`;
    }

    function removeDuplicateMenuItems(items) {
        const seen = new Set();

        return items.filter(item => {
            if (seen.has(item.MPID)) {
                return false;
            }

            seen.add(item.MPID);
            return true;
        });
    }

    function buildMenuItems(items) {
        const safeItems = Array.isArray(items) ? items : [];
        const rootItems = safeItems
            .filter(x => x.Levels === 1)
            .sort((a, b) => (a.MPSerial || 0) - (b.MPSerial || 0));

        let html = "";
        rootItems.forEach(item => {
            html += `<li><div class="menu-sep"></div>${buildMenuItem(item, 1)}</li>`;
        });

        return html;
    }

    function setActiveSidebar(url) {
        const path = normalizePath(url || window.location.pathname);

        document.querySelectorAll("a.sidebar-link").forEach(anchor => {
            anchor.classList.remove("bg-slate-700", "text-slate-50");

            const itemUrl = normalizePath(anchor.getAttribute("data-url") || "");
            if (itemUrl === path) {
                anchor.classList.add("bg-slate-700", "text-slate-50");
            }
        });
    }

    function renderSidebarMenu(menuData, searchTerm = "") {
        const host = document.getElementById("menu-container");
        const emptyBox = document.getElementById("sidebar-search-empty");
        if (!host || !Array.isArray(menuData)) {
            return;
        }

        const uniqueMenuData = removeDuplicateMenuItems(menuData);
        const finalItems = searchTerm?.trim()
            ? filterMenuTree(uniqueMenuData, searchTerm)
            : uniqueMenuData;

        host.innerHTML = buildMenuItems(finalItems);

        const hasResults = Array.isArray(finalItems) && finalItems.length > 0;
        emptyBox?.classList.toggle("hidden", hasResults || !searchTerm?.trim());

        setActiveSidebar(window.location.pathname + window.location.search);
    }

    function loadPageIntoMainContent(url) {
        const main = document.getElementById("main-content");

        if (!main) {
            if (typeof window.hideMainLoading === "function") {
                window.hideMainLoading();
            }

            window.location.href = url;
            return;
        }

        fetch(url, { headers: { "X-Requested-With": "XMLHttpRequest" } })
            .then(response => response.text())
            .then(html => {
                const parser = new DOMParser();
                const doc = parser.parseFromString(html, "text/html");
                const newMain = doc.getElementById("main-content");

                if (!newMain) {
                    if (typeof window.hideMainLoading === "function") {
                        window.hideMainLoading();
                    }

                    document.body.style.pointerEvents = "auto";
                    window.location.href = url;
                    return;
                }

                main.innerHTML = newMain.innerHTML;

                const currentBreadcrumb = document.querySelector("#page-header .sf-bc-text");
                const newBreadcrumb = doc.querySelector("#page-header .sf-bc-text");
                if (currentBreadcrumb && newBreadcrumb) {
                    currentBreadcrumb.innerHTML = newBreadcrumb.innerHTML;
                }

                if (typeof window.initFlowbite === "function") {
                    window.initFlowbite();
                }

                window.history.pushState({}, "", url);

                const titleEl = doc.querySelector("title");
                if (titleEl?.textContent) {
                    document.title = titleEl.textContent;
                }

                setActiveSidebar(url);

                if (typeof window.hideMainLoading === "function") {
                    window.hideMainLoading();
                }

                document.body.style.pointerEvents = "auto";
            })
            .catch(() => {
                if (typeof window.hideMainLoading === "function") {
                    window.hideMainLoading();
                }

                document.body.style.pointerEvents = "auto";
                window.location.href = url;
            });
    }

    function initSidebarMenu() {
        const menuData = getSidebarMenuData();
        renderSidebarMenu(menuData, "");

        const searchInput = document.getElementById("sidebar-menu-search");
        const clearBtn = document.getElementById("sidebar-menu-search-clear");

        if (searchInput) {
            searchInput.addEventListener("input", function () {
                const value = this.value || "";
                clearBtn?.classList.toggle("hidden", !value.trim());
                renderSidebarMenu(menuData, value);
            });

            searchInput.addEventListener("keydown", function (event) {
                if (event.key === "Escape") {
                    this.value = "";
                    clearBtn?.classList.add("hidden");
                    renderSidebarMenu(menuData, "");
                }
            });
        }

        clearBtn?.addEventListener("click", function () {
            if (!searchInput) {
                return;
            }

            searchInput.value = "";
            clearBtn.classList.add("hidden");
            renderSidebarMenu(menuData, "");
            searchInput.focus();
        });

        document.getElementById("menu-container")?.addEventListener("click", function (event) {
            const button = event.target.closest("button[data-menu-toggle]");
            if (!button || button.classList.contains("force-disabled")) {
                return;
            }

            event.preventDefault();
            event.stopPropagation();

            const id = button.getAttribute("data-menu-toggle");
            const target = id ? document.getElementById(id) : null;
            if (!target) {
                return;
            }

            const willOpen = target.classList.contains("hidden");
            target.classList.toggle("hidden", !willOpen);
            button.setAttribute("aria-expanded", willOpen ? "true" : "false");
        });

        document.body.addEventListener("click", function (event) {
            const link = event.target.closest("#logo-sidebar a.sidebar-link");
            if (!link) {
                return;
            }

            if (
                link.hasAttribute("target") ||
                link.hasAttribute("download") ||
                link.getAttribute("href") === "#" ||
                link.getAttribute("href")?.startsWith("javascript:") ||
                link.closest("[data-modal-toggle]") ||
                link.closest("[data-modal-target]")
            ) {
                return;
            }

            if (event.button !== 0 || event.ctrlKey || event.shiftKey || event.metaKey || event.altKey) {
                return;
            }

            const href = link.getAttribute("href");
            const dataUrl = link.getAttribute("data-url");
            const url = dataUrl || href;

            if (!url) {
                return;
            }

            if (url.startsWith("http://") || url.startsWith("https://")) {
                const targetUrl = new URL(url, window.location.origin);
                if (targetUrl.origin !== window.location.origin) {
                    return;
                }
            }

            if (url.startsWith("/Login/Logout") || link.classList.contains("force-disabled")) {
                return;
            }

            if (!url.startsWith("/")) {
                return;
            }

            if (normalizePath(url) === "/home") {
                window.location.href = url;
                return;
            }

            event.preventDefault();

            if (typeof window.showMainLoading === "function") {
                window.showMainLoading();
            }

            document.body.style.pointerEvents = "none";
            loadPageIntoMainContent(url);
        });

        window.addEventListener("popstate", function () {
            loadPageIntoMainContent(window.location.pathname + window.location.search);
        });
    }

    function initSidebarStateControls() {
        const body = document.body;
        const sidebar = document.getElementById("logo-sidebar");
        const pinBtn = document.getElementById("pin-sidebar");
        const toggleSidebarBtn = document.getElementById("toggle-sidebar");
        const mobileToggleBtn = document.querySelector('[data-drawer-toggle="logo-sidebar"]');

        if (!body || !sidebar) {
            return;
        }

        let hoverTimer = null;
        let isHoverOpen = false;

        function removeSidebarBackdrop() {
            document.querySelectorAll(".sidebar-backdrop, [drawer-backdrop]").forEach(element => element.remove());
        }

        function openMobileSidebar() {
            body.classList.add(SIDEBAR_STATES.MOBILE_OPEN);

            if (!document.querySelector(".sidebar-backdrop")) {
                const backdrop = document.createElement("div");
                backdrop.className = "sidebar-backdrop lg:hidden";
                backdrop.addEventListener("click", () => {
                    body.classList.remove(SIDEBAR_STATES.MOBILE_OPEN);
                    removeSidebarBackdrop();
                });
                document.body.appendChild(backdrop);
            }
        }

        function closeMobileSidebar() {
            body.classList.remove(SIDEBAR_STATES.MOBILE_OPEN);
            sidebar.classList.add("translate-x-full");
            removeSidebarBackdrop();
        }

        function applyDesktopSidebarState() {
            const savedSidebarState = localStorage.getItem("sidebarState");

            body.classList.remove(SIDEBAR_STATES.MOBILE_OPEN);

            if (savedSidebarState === SIDEBAR_STATES.COLLAPSED) {
                body.classList.remove(SIDEBAR_STATES.PINNED);
                body.classList.add(SIDEBAR_STATES.COLLAPSED);
                return;
            }

            body.classList.remove(SIDEBAR_STATES.COLLAPSED);
            body.classList.add(SIDEBAR_STATES.PINNED);
        }

        function setDesktopSidebarState(state) {
            if (state === SIDEBAR_STATES.COLLAPSED) {
                body.classList.remove(SIDEBAR_STATES.PINNED, SIDEBAR_STATES.MOBILE_OPEN);
                body.classList.add(SIDEBAR_STATES.COLLAPSED);
            } else if (state === SIDEBAR_STATES.PINNED) {
                body.classList.remove(SIDEBAR_STATES.COLLAPSED, SIDEBAR_STATES.MOBILE_OPEN);
                body.classList.add(SIDEBAR_STATES.PINNED);
            }

            localStorage.setItem("sidebarState", state);
        }

        function initSidebarState() {
            if (window.innerWidth >= 1024) {
                applyDesktopSidebarState();
                removeSidebarBackdrop();
                sidebar.classList.remove("translate-x-full");
                return;
            }

            body.classList.remove(
                SIDEBAR_STATES.PINNED,
                SIDEBAR_STATES.COLLAPSED,
                SIDEBAR_STATES.MOBILE_OPEN
            );
            removeSidebarBackdrop();
            sidebar.classList.add("translate-x-full");
        }

        sidebar.addEventListener("mouseenter", () => {
            if (window.innerWidth < 1024 || !body.classList.contains(SIDEBAR_STATES.COLLAPSED)) {
                return;
            }

            hoverTimer = setTimeout(() => {
                body.classList.remove(SIDEBAR_STATES.COLLAPSED);
                body.classList.add(SIDEBAR_STATES.PINNED);
                isHoverOpen = true;
            }, 200);
        });

        sidebar.addEventListener("mouseleave", () => {
            if (window.innerWidth < 1024) {
                return;
            }

            if (hoverTimer) {
                clearTimeout(hoverTimer);
                hoverTimer = null;
            }

            if (isHoverOpen) {
                body.classList.remove(SIDEBAR_STATES.PINNED);
                body.classList.add(SIDEBAR_STATES.COLLAPSED);
                isHoverOpen = false;
            }
        });

        toggleSidebarBtn?.addEventListener("click", () => {
            if (window.innerWidth < 1024) {
                if (body.classList.contains(SIDEBAR_STATES.MOBILE_OPEN)) {
                    closeMobileSidebar();
                } else {
                    openMobileSidebar();
                    sidebar.classList.remove("translate-x-full");
                }
                return;
            }

            if (body.classList.contains(SIDEBAR_STATES.PINNED)) {
                setDesktopSidebarState(SIDEBAR_STATES.COLLAPSED);
            } else {
                setDesktopSidebarState(SIDEBAR_STATES.PINNED);
            }
        });

        pinBtn?.addEventListener("click", () => {
            if (window.innerWidth < 1024) {
                return;
            }

            if (body.classList.contains(SIDEBAR_STATES.PINNED)) {
                setDesktopSidebarState(SIDEBAR_STATES.COLLAPSED);
            } else {
                setDesktopSidebarState(SIDEBAR_STATES.PINNED);
            }
        });

        mobileToggleBtn?.addEventListener("click", () => {
            if (window.innerWidth >= 1024) {
                return;
            }

            if (body.classList.contains(SIDEBAR_STATES.MOBILE_OPEN)) {
                closeMobileSidebar();
            } else {
                openMobileSidebar();
                sidebar.classList.remove("translate-x-full");
            }
        });

        window.addEventListener("resize", initSidebarState);

        document.addEventListener("click", function (event) {
            const link = event.target.closest("#logo-sidebar a");
            if (!link || window.innerWidth >= 1024) {
                return;
            }

            closeMobileSidebar();
        });

        if (document.documentElement.getAttribute("dir") === "rtl") {
            sidebar.classList.add("right-0");
            sidebar.classList.remove("left-0");
        }

        initSidebarState();
    }

    function togglePasswordVisibility(inputId) {
        const input = document.getElementById(inputId);
        const icon = input?.parentElement?.querySelector('[data-password-toggle-icon] i');

        if (!input || !icon) {
            return;
        }

        if (input.type === "password") {
            input.type = "text";
            icon.classList.remove("fa-eye");
            icon.classList.add("fa-eye-slash");
            return;
        }

        input.type = "password";
        icon.classList.remove("fa-eye-slash");
        icon.classList.add("fa-eye");
    }

    function initPasswordToggleButtons() {
        document.addEventListener("click", function (event) {
            const button = event.target.closest("[data-password-toggle]");
            if (!button) {
                return;
            }

            event.preventDefault();
            togglePasswordVisibility(button.getAttribute("data-password-toggle"));
        });
    }

    function updatePasswordCheck(id, isValid) {
        const element = document.getElementById(id);
        const icon = element?.querySelector("i");
        if (!icon) {
            return;
        }

        icon.className = isValid
            ? "fa-solid fa-circle-check text-green-400"
            : "fa-solid fa-circle-xmark text-red-400";
    }

    function calculatePasswordChecks(password) {
        return {
            length: password.length >= 12,
            uppercase: /[A-Z]/.test(password),
            lowercase: /[a-z]/.test(password),
            number: /[0-9]/.test(password)
        };
    }

    function getPasswordStrengthState(password) {
        const checks = calculatePasswordChecks(password);
        let strength = 0;

        if (checks.length) {
            strength += 25;
        }

        if (checks.uppercase) {
            strength += 25;
        }

        if (checks.lowercase) {
            strength += 25;
        }

        if (checks.number) {
            strength += 25;
        }

        if (strength < 50) {
            return { checks, strength, color: "bg-red-500", text: "ضعيفة" };
        }

        if (strength < 100) {
            return { checks, strength, color: "bg-yellow-500", text: "متوسطة" };
        }

        return { checks, strength, color: "bg-green-500", text: "قوية" };
    }

    function bindPasswordStrength(options) {
        const input = document.getElementById(options.inputId);
        if (!input) {
            return;
        }

        input.addEventListener("input", function (event) {
            const password = event.target.value;
            const strengthContainer = document.getElementById(options.containerId);
            const strengthBar = document.getElementById(options.barId);
            const strengthText = document.getElementById(options.textId);

            if (!password.length) {
                strengthContainer?.classList.add("hidden");
                return;
            }

            strengthContainer?.classList.remove("hidden");

            const state = getPasswordStrengthState(password);

            updatePasswordCheck(options.checkIds.length, state.checks.length);
            updatePasswordCheck(options.checkIds.uppercase, state.checks.uppercase);
            updatePasswordCheck(options.checkIds.lowercase, state.checks.lowercase);
            updatePasswordCheck(options.checkIds.number, state.checks.number);

            if (strengthBar) {
                strengthBar.style.width = `${state.strength}%`;
                strengthBar.className = `h-full transition-all duration-300 ${state.color}`;
            }

            if (strengthText) {
                strengthText.textContent = state.text;
                strengthText.className = `text-xs font-medium ${state.color.replace("bg-", "text-")}`;
            }
        });
    }

    function bindPasswordTrimOnBlur(formSelector) {
        document.querySelectorAll(`${formSelector} input[type="password"]`).forEach(input => {
            input.addEventListener("blur", function () {
                this.value = this.value.trim();
            });
        });
    }

    function validatePasswordFields(currentPassword, newPassword, confirmPassword) {
        if (!currentPassword || !newPassword || !confirmPassword) {
            return "جميع الحقول مطلوبة";
        }

        if (newPassword !== confirmPassword) {
            return "mismatch";
        }

        if (newPassword.length < 12) {
            return "كلمة المرور يجب أن لا تقل عن 12 خانة";
        }

        if (!/[A-Z]/.test(newPassword)) {
            return "كلمة المرور يجب أن تحتوي على حرف إنجليزي كبير واحد على الأقل (A-Z)";
        }

        if (!/[a-z]/.test(newPassword)) {
            return "كلمة المرور يجب أن تحتوي على حرف إنجليزي صغير واحد على الأقل (a-z)";
        }

        if (!/[0-9]/.test(newPassword)) {
            return "كلمة المرور يجب أن تحتوي على رقم واحد على الأقل (0-9)";
        }

        if (currentPassword === newPassword) {
            return "كلمة المرور الجديدة يجب أن تختلف عن الحالية";
        }

        return "";
    }

    function bindChangePasswordForm() {
        const form = document.getElementById("change-password-form");
        if (!form) {
            return;
        }

        form.addEventListener("submit", async function (event) {
            event.preventDefault();

            const errorDiv = document.getElementById("password-error");
            const submitBtn = this.querySelector('button[type="submit"]');
            const currentPassword = this.currentPassword.value.trim();
            const newPassword = this.newPassword.value.trim();
            const confirmPassword = this.confirmPassword.value.trim();

            errorDiv?.classList.add("hidden");

            const validationResult = validatePasswordFields(currentPassword, newPassword, confirmPassword);
            if (validationResult) {
                if (validationResult === "mismatch" && errorDiv) {
                    errorDiv.innerHTML = `
                كلمة المرور الجديدة وتأكيد كلمة المرور غير متطابقتين<br>
                <small class="text-xs opacity-75">
                    الطول: ${newPassword.length} ≠ ${confirmPassword.length}
                </small>
            `;
                } else if (errorDiv) {
                    errorDiv.textContent = validationResult;
                }

                errorDiv?.classList.remove("hidden");
                return;
            }

            if (submitBtn) {
                submitBtn.disabled = true;
                submitBtn.innerHTML = '<i class="fa-solid fa-spinner fa-spin me-2"></i>جاري الحفظ...';
            }

            try {
                const response = await fetch("/Login/ChangePassword", {
                    method: "POST",
                    headers: {
                        "Content-Type": "application/json",
                        "X-Requested-With": "XMLHttpRequest"
                    },
                    body: JSON.stringify({
                        oldPassword: currentPassword,
                        newPassword
                    })
                });

                const result = await response.json();

                if (result.success) {
                    if (typeof window.toastr !== "undefined") {
                        window.toastr.success(result.message || "تم تغيير كلمة المرور بنجاح");
                    } else {
                        window.alert(result.message || "تم تغيير كلمة المرور بنجاح");
                    }

                    const modalInstance = window.FlowbiteInstances?.getInstance("Modal", "change-password-modal");
                    if (modalInstance) {
                        modalInstance.hide();
                    }

                    this.reset();

                    setTimeout(() => {
                        window.location.href = "/Login?logout=2";
                    }, 2000);
                } else {
                    if (errorDiv) {
                        errorDiv.textContent = result.message || "فشل تغيير كلمة المرور";
                        errorDiv.classList.remove("hidden");
                    }
                }
            } catch {
                if (errorDiv) {
                    errorDiv.textContent = "حدث خطأ أثناء تغيير كلمة المرور";
                    errorDiv.classList.remove("hidden");
                }
            } finally {
                if (submitBtn) {
                    submitBtn.disabled = false;
                    submitBtn.innerHTML = '<i class="fa-solid fa-check me-2"></i>حفظ كلمة المرور';
                }
            }
        });

        bindPasswordTrimOnBlur("#change-password-form");
    }

    function disableNavigationForForcedPasswordChange() {
        document.querySelectorAll("aside#logo-sidebar .sidebar-link").forEach(link => {
            link.classList.add("force-disabled");
        });

        document.querySelectorAll('nav#top-header a[href="/Home"]').forEach(link => {
            link.classList.add("force-disabled");
        });

        document.querySelectorAll('#user-dropdown a:not([href="/Login/Logout"])').forEach(link => {
            link.classList.add("force-disabled");
        });

        document.querySelectorAll("aside#logo-sidebar button[data-menu-toggle]").forEach(button => {
            button.classList.add("force-disabled");
        });

        document.getElementById("pin-sidebar")?.classList.add("force-disabled");
        document.getElementById("toggle-sidebar")?.classList.add("force-disabled");
    }

    function bindForceChangePasswordForm() {
        const form = document.getElementById("force-change-password-form");
        if (!form) {
            return;
        }

        document.body.classList.add("modal-open");
        disableNavigationForForcedPasswordChange();

        setTimeout(() => {
            document.getElementById("force-current-password")?.focus();
        }, 500);

        document.addEventListener("keydown", function (event) {
            if (event.key === "Escape") {
                event.preventDefault();
                return false;
            }

            return true;
        }, true);

        form.addEventListener("submit", async function (event) {
            event.preventDefault();

            const errorDiv = document.getElementById("force-password-error");
            const submitBtn = this.querySelector('button[type="submit"]');
            const currentPassword = this.currentPassword.value.trim();
            const newPassword = this.newPassword.value.trim();
            const confirmPassword = this.confirmPassword.value.trim();

            errorDiv?.classList.add("hidden");

            const showError = message => {
                if (!errorDiv) {
                    return;
                }

                errorDiv.textContent = message;
                errorDiv.classList.remove("hidden");
                errorDiv.classList.add("animate-shake");
                setTimeout(() => errorDiv.classList.remove("animate-shake"), 500);
            };

            if (!currentPassword || !newPassword || !confirmPassword) {
                showError("❌ جميع الحقول مطلوبة");
                return;
            }

            if (newPassword !== confirmPassword) {
                showError("❌ كلمة المرور الجديدة وتأكيد كلمة المرور غير متطابقتين");
                return;
            }

            if (newPassword.length < 12) {
                showError("❌ كلمة المرور يجب أن لا تقل عن 12 خانة");
                return;
            }

            if (!/[A-Z]/.test(newPassword)) {
                showError("❌ يجب أن تحتوي على حرف كبير (A-Z)");
                return;
            }

            if (!/[a-z]/.test(newPassword)) {
                showError("❌ يجب أن تحتوي على حرف صغير (a-z)");
                return;
            }

            if (!/[0-9]/.test(newPassword)) {
                showError("❌ يجب أن تحتوي على رقم (0-9)");
                return;
            }

            if (currentPassword === newPassword) {
                showError("❌ كلمة المرور الجديدة يجب أن تختلف عن الحالية");
                return;
            }

            if (submitBtn) {
                submitBtn.disabled = true;
                submitBtn.innerHTML = '<i class="fa-solid fa-spinner fa-spin me-2"></i>جاري تغيير كلمة المرور...';
            }

            try {
                const response = await fetch("/Login/ChangePassword", {
                    method: "POST",
                    headers: {
                        "Content-Type": "application/json",
                        "X-Requested-With": "XMLHttpRequest"
                    },
                    body: JSON.stringify({
                        oldPassword: currentPassword,
                        newPassword
                    })
                });

                const result = await response.json();

                if (result.success) {
                    window.alert("✅ تم تغيير كلمة المرور بنجاح! سيتم تسجيل خروجك الآن...");
                    setTimeout(() => {
                        window.location.href = "/Login?logout=2";
                    }, 1000);
                    return;
                }

                showError(result.message || "❌ فشل تغيير كلمة المرور");
            } catch {
                showError("❌ حدث خطأ أثناء تغيير كلمة المرور");
            } finally {
                if (submitBtn) {
                    submitBtn.disabled = false;
                    submitBtn.innerHTML = '<i class="fa-solid fa-shield-halved me-2"></i>تغيير كلمة المرور الآن';
                }
            }
        });

        bindPasswordTrimOnBlur("#force-change-password-form");
    }

    applyInitialSidebarState();

    runWhenReady(function () {
        initSidebarMenu();
        initSidebarStateControls();
        initPasswordToggleButtons();
        bindPasswordStrength({
            inputId: "new-password",
            containerId: "password-strength",
            barId: "strength-bar",
            textId: "strength-text",
            checkIds: {
                length: "check-length",
                uppercase: "check-uppercase",
                lowercase: "check-lowercase",
                number: "check-number"
            }
        });
        bindPasswordStrength({
            inputId: "force-new-password",
            containerId: "force-password-strength",
            barId: "force-strength-bar",
            textId: "force-strength-text",
            checkIds: {
                length: "force-check-length",
                uppercase: "force-check-uppercase",
                lowercase: "force-check-lowercase",
                number: "force-check-number"
            }
        });
        bindChangePasswordForm();
        bindForceChangePasswordForm();
    });
})();
