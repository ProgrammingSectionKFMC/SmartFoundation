/* SmartFoundation - SmartAccordion v5 - SmartForm in same workspace.
 * Generic UI: search, status filtering, paging, accessible expansion,
 * authenticated DataLoad; native POST delegates writes to configured server gateways.
 */
(function () {
    "use strict";
    if (window.SmartAccordion) return;

    const instances = new WeakMap();
    const statuses = new Set(["success", "warning", "danger", "info"]);
    const tones = new Set(["primary", "danger"]);
    const el = (tag, css, text) => {
        const node = document.createElement(tag);
        if (css) node.className = css;
        if (text !== undefined && text !== null) node.textContent = String(text);
        return node;
    };
    const value = (row, key) => {
        if (!key || !row || typeof row !== "object") return "";
        const v = row[key];
        return v === null || v === undefined ? "" : String(v);
    };
    const normalize = text => String(text ?? "").toLocaleLowerCase("ar").trim();
    const validSize = n => Number.isSafeInteger(Number(n)) && Number(n) > 0 && Number(n) <= 100;

    function configFor(root) {
        try { return JSON.parse(root.dataset.sfAccordionConfig || "{}"); }
        catch { return {}; }
    }

    function init(root) {
        if (instances.has(root)) return instances.get(root);
        const cfg = configFor(root);
        const sizes = Array.isArray(cfg.pageSizes) ? cfg.pageSizes.map(Number).filter(validSize) : [];
        const defaultSize = validSize(cfg.pageSize) ? Number(cfg.pageSize) : 5;
        if (!sizes.includes(defaultSize)) sizes.unshift(defaultSize);
        const state = {
            root, config: cfg, items: [], rows: new Map(),
            page: 1, pageSize: defaultSize, pageSizes: [...new Set(sizes)],
            query: "", status: "", expanded: new Set(),
            abort: null, requestId: 0
        };
        instances.set(root, state);
        const sizeSelect = root.querySelector("[data-sf-accordion-page-size]");
        if (sizeSelect) {
            state.pageSizes.forEach(n => {
                const option = el("option", "", n);
                option.value = String(n);
                sizeSelect.append(option);
            });
            sizeSelect.value = String(state.pageSize);
        }
        if (cfg.dataSource) render(root, []);
        else render(root, Array.isArray(cfg.items) ? cfg.items : []);
        if (cfg.dataSource?.loadOnPageReady &&
            !root.closest("[data-sf-drawer]") && !root.closest("[data-sf-accordion-modal]")) {
            load(root, {});
        }
        return state;
    }

    function showMessage(root, message, kind) {
        const node = root.querySelector("[data-sf-accordion-message]");
        if (!node) return;
        node.textContent = message || "";
        node.className = "sf-accordion__message" + (kind ? " is-" + kind : "");
        node.hidden = !message;
    }

    function resetNavigation(state) {
        state.page = 1;
        state.query = "";
        state.status = "";
        state.expanded.clear();
        const search = state.root.querySelector("[data-sf-accordion-search]");
        if (search) search.value = "";
        const filter = state.root.querySelector("[data-sf-accordion-status-filter]");
        if (filter) filter.value = "";
    }

    function updateFilters(state) {
        const select = state.root.querySelector("[data-sf-accordion-status-filter]");
        const distinct = new Map();
        state.items.forEach(entry => {
            const status = String(entry.item?.statusText ?? "").trim();
            if (status) distinct.set(status, (distinct.get(status) || 0) + 1);
        });
        if (select) {
            select.replaceChildren();
            const all = el("option", "", "جميع الحالات");
            all.value = "";
            select.append(all);
            for (const [status, count] of distinct) {
                const option = el("option", "", `${status} (${count})`);
                option.value = status;
                select.append(option);
            }
            if (!distinct.has(state.status)) state.status = "";
            select.value = state.status;
        }
        const summary = state.root.querySelector("[data-sf-accordion-summary]");
        if (summary) {
            const fragment = document.createDocumentFragment();
            const addStat = (label, count, tone) => {
                const box = el("div", "sf-accordion__stat" + (tone ? ` is-${tone}` : ""));
                box.append(el("span", "sf-accordion__stat-label", label),
                           el("strong", "sf-accordion__stat-count", count));
                fragment.append(box);
            };
            addStat("إجمالي السجلات", state.items.length);
            for (const [status, count] of Array.from(distinct).slice(0, 4)) {
                addStat(status, count);
            }
            summary.replaceChildren(fragment);
        }
    }

    function searchText(item) {
        const parts = [item.id, item.title, item.subtitle, item.amountText, item.statusText];
        if (Array.isArray(item.details)) {
            item.details.forEach(f => parts.push(f?.label, f?.value));
        }
        return normalize(parts.filter(x => x != null).join(" "));
    }

    function visibleEntries(state) {
        return state.items.filter(entry => {
            const item = entry.item;
            if (state.status && String(item.statusText ?? "") !== state.status) return false;
            return !state.query || searchText(item).includes(state.query);
        });
    }

    function setExpanded(button, expanded) {
        button.setAttribute("aria-expanded", String(expanded));
        const body = document.getElementById(button.getAttribute("aria-controls"));
        if (body && button.closest("[data-sf-accordion]")?.contains(body)) body.hidden = !expanded;
    }

    function renderItem(state, entry, i) {
        const cfg = state.config, item = entry.item, id = String(item.id);
        const opened = state.expanded.has(id);
        const article = el("article", "sf-accordion__item");
        article.dataset.sfAccordionItem = "";
        article.dataset.itemId = id;
        const trigger = el("button", "sf-accordion__trigger");
        trigger.type = "button";
        trigger.dataset.sfAccordionToggle = "";
        trigger.setAttribute("aria-expanded", String(opened));
        const detailId = state.root.id + "-details-" + i;
        trigger.setAttribute("aria-controls", detailId);
        const identity = el("span", "sf-accordion__identity");
        identity.append(el("strong", "sf-accordion__item-title", item.title || "—"));
        if (item.subtitle) identity.append(el("small", "sf-accordion__item-subtitle", item.subtitle));
        trigger.append(identity);
        const trailing = el("span", "sf-accordion__trailing");
        if (item.amountText) trailing.append(el("strong", "sf-accordion__amount", item.amountText));
        if (item.statusText) {
            const tone = statuses.has(normalize(item.statusTone)) ? normalize(item.statusTone) : "neutral";
            trailing.append(el("span", "sf-accordion__status is-" + tone, item.statusText));
        }
        trigger.append(trailing);
        const chevron = el("i", "fa-solid fa-chevron-down sf-accordion__chevron");
        chevron.setAttribute("aria-hidden", "true");
        trigger.append(chevron);
        article.append(trigger);
        const body = el("div", "sf-accordion__body");
        body.id = detailId;
        body.dataset.sfAccordionBody = "";
        body.hidden = !opened;
        if (Array.isArray(item.details) && item.details.length) {
            const dl = el("dl", "sf-accordion__details");
            item.details.forEach(field => {
                const part = el("div", "sf-accordion__detail");
                part.append(el("dt", "", field.label || ""),
                            el("dd", "", field.value ?? "—"));
                dl.append(part);
            });
            body.append(dl);
        }
        const sourceRow = entry.row || item.values || item;
        const actions = (cfg.actions || []).filter(a => {
            if (!a || !a.key) return false;
            if (!a.visibleWhenField) return true;
            return normalize(value(sourceRow, a.visibleWhenField)) === normalize(a.visibleWhenEquals);
        });
        if (actions.length) {
            const bar = el("div", "sf-accordion__actions");
            actions.forEach(action => {
                const tone = tones.has(normalize(action.tone)) ? normalize(action.tone) : "default";
                const button = el("button", "sf-accordion__action is-" + tone);
                button.type = "button";
                button.dataset.sfAccordionAction = String(action.key);
                button.dataset.itemId = id;
                if (action.icon && /^fa[-\w\s]+$/.test(String(action.icon))) {
                    const icon = el("i", String(action.icon));
                    icon.setAttribute("aria-hidden", "true");
                    button.append(icon);
                }
                button.append(document.createTextNode(String(action.text || action.key)));
                bar.append(button);
            });
            body.append(bar);
        }
        article.append(body);
        return article;
    }

    function renderCurrent(state) {
        const root = state.root;
        const host = root.querySelector("[data-sf-accordion-items]");
        const empty = root.querySelector("[data-sf-accordion-empty]");
        if (!host || !empty) return;
        const filtered = visibleEntries(state);
        const paginate = state.config.enablePagination !== false;
        const pages = paginate ? Math.max(1, Math.ceil(filtered.length / state.pageSize)) : 1;
        state.page = Math.min(Math.max(1, state.page), pages);
        const start = paginate ? (state.page - 1) * state.pageSize : 0;
        const shown = paginate ? filtered.slice(start, start + state.pageSize) : filtered;
        const fragment = document.createDocumentFragment();
        shown.forEach((entry, i) => fragment.append(renderItem(state, entry, start + i)));
        host.replaceChildren(fragment);
        empty.hidden = filtered.length > 0;
        empty.textContent = filtered.length > 0 ? "" :
            ((state.query || state.status) ? "لا توجد سجلات مطابقة للبحث أو التصفية" :
              (state.config.emptyText || "لا توجد سجلات للعرض"));
        const pager = root.querySelector("[data-sf-accordion-pagination]");
        if (pager) {
            pager.hidden = !paginate || filtered.length <= state.pageSize;
            const range = root.querySelector("[data-sf-accordion-page-range]");
            if (range) range.textContent = filtered.length ?
                `عرض ${start + 1}–${start + shown.length} من ${filtered.length}` : "لا توجد سجلات";
            const pageLabel = root.querySelector("[data-sf-accordion-page-label]");
            if (pageLabel) pageLabel.textContent = `${state.page} / ${pages}`;
            const prev = root.querySelector("[data-sf-accordion-prev]");
            const next = root.querySelector("[data-sf-accordion-next]");
            if (prev) prev.disabled = state.page <= 1;
            if (next) next.disabled = state.page >= pages;
        }
        root.dispatchEvent(new CustomEvent("sf-accordion:rendered", {
            bubbles: true,
            detail: { id: root.id, count: state.items.length, filteredCount: filtered.length, page: state.page }
        }));
    }

    function render(rootOrId, items, originalRows) {
        const root = typeof rootOrId === "string" ? document.getElementById(rootOrId.replace(/^#/, "")) : rootOrId;
        if (!root?.matches?.("[data-sf-accordion]")) return false;
        const state = instances.get(root) || initEmpty(root);
        const collected = [], rows = new Map(), seen = new Set();
        (items || []).forEach((item, i) => {
            if (!item || typeof item !== "object") return;
            const id = String(item.id ?? "");
            if (!id || seen.has(id)) return;
            seen.add(id);
            const row = originalRows?.[i] ?? item.values ?? item;
            collected.push({ item, row });
            rows.set(id, row);
        });
        state.items = collected;
        state.rows = rows;
        state.expanded.clear();
        // Respect initiallyOpen for an unfiltered first render.
        for (const entry of collected) {
            if (entry.item.initiallyOpen !== true) continue;
            state.expanded.add(String(entry.item.id));
            if (!state.config.allowMultipleOpen) break;
        }
        state.page = 1;
        updateFilters(state);
        renderCurrent(state);
        return true;
    }

    function initEmpty(root) {
        const cfg = configFor(root);
        const sizes = Array.isArray(cfg.pageSizes) ? cfg.pageSizes.map(Number).filter(validSize) : [];
        const defaultSize = validSize(cfg.pageSize) ? Number(cfg.pageSize) : 5;
        if (!sizes.includes(defaultSize)) sizes.unshift(defaultSize);
        const state = {
            root, config: cfg, items: [], rows: new Map(), page: 1, pageSize: defaultSize,
            pageSizes: [...new Set(sizes)], query: "", status: "", expanded: new Set(),
            abort: null, requestId: 0
        };
        instances.set(root, state);
        const sizeSelect = root.querySelector("[data-sf-accordion-page-size]");
        if (sizeSelect) {
            state.pageSizes.forEach(n => {
                const option = el("option", "", n);
                option.value = String(n);
                sizeSelect.append(option);
            });
            sizeSelect.value = String(state.pageSize);
        }
        return state;
    }

    function mapRow(row, ds) {
        return {
            id: value(row, ds.idField),
            title: value(row, ds.titleField) || "—",
            subtitle: value(row, ds.subtitleField),
            amountText: value(row, ds.amountField),
            statusText: value(row, ds.statusField),
            statusTone: value(row, ds.statusToneField),
            details: (ds.detailFields || []).map(f => ({ label: f.label || "", value: value(row, f.field) || "—" }))
        };
    }

    async function load(target, context) {
        const root = typeof target === "string" ? document.getElementById(target.replace(/^#/, "")) : target;
        if (!root?.matches?.("[data-sf-accordion]")) return false;
        const state = init(root), ds = state.config.dataSource;
        if (!ds) return false;
        state.abort?.abort();
        const abort = new AbortController();
        state.abort = abort;
        const requestId = ++state.requestId;
        resetNavigation(state);
        render(root, []);
        showMessage(root, state.config.loadingText || "جاري التحميل...", "loading");
        try {
            if (!ds.pageName || !ds.actionType) throw new Error("ActionType/PageName are required");
            const params = { ...(ds.fixedParameters || {}) };
            for (const [param, field] of Object.entries(ds.parameterMap || {})) {
                if (!/^parameter_(0[1-9]|10)$/.test(param)) throw new Error("Invalid parameter name");
                const v = context?.[field] ?? context?.[param];
                if (v === null || v === undefined || v === "") throw new Error("Missing context field: " + field);
                params[param] = v;
            }
            const token = window.getRequestVerificationToken?.();
            if (!token) throw new Error("Missing antiforgery token");
            const endpoint = new URL(ds.endpoint || "/crud/extradataload", window.location.origin);
            if (endpoint.origin !== window.location.origin) throw new Error("Cross-origin endpoint rejected");
            const response = await fetch(endpoint.pathname + endpoint.search, {
                method: "POST", credentials: "same-origin", signal: abort.signal,
                headers: { "Content-Type": "application/json", "X-Requested-With": "XMLHttpRequest", "RequestVerificationToken": token },
                body: JSON.stringify({ pageName_: ds.pageName, ActionType: ds.actionType, tableIndex: ds.tableIndex ?? 0, parameters: params })
            });
            if (!response.ok) throw new Error("HTTP " + response.status);
            const json = await response.json();
            if (json?.success !== true || !Array.isArray(json.table?.rows)) throw new Error("Invalid gateway result");
            if (abort.signal.aborted || state.requestId !== requestId) return false;
            const rows = json.table.rows;
            const items = rows.map(row => mapRow(row, ds));
            const ids = items.map(item => String(item.id || ""));
            if (ids.some(x => !x) || new Set(ids).size !== ids.length) {
                throw new Error("Duplicate or missing accordion row identity");
            }
            render(root, items, rows);
            showMessage(root, "");
            root.dispatchEvent(new CustomEvent("sf-accordion:loaded", {
                bubbles: true, detail: { id: root.id, count: rows.length }
            }));
            return true;
        } catch (error) {
            if (abort.signal.aborted || state.requestId !== requestId) return false;
            showMessage(root, "تعذر تحميل البيانات، يرجى إعادة المحاولة", "error");
            root.dispatchEvent(new CustomEvent("sf-accordion:error", {
                bubbles: true, detail: { id: root.id, message: String(error?.message || error) }
            }));
            return false;
        }
    }


    // Form mode is a presentation feature. Its form remains the EXISTING
    // SmartForm component, not a custom HTML form or second modal.
    function workspaceFor(root) {
        return root?.closest("[data-sf-accordion-workspace]") || null;
    }

    function formError(pane, message) {
        const node = pane?.querySelector("[data-sf-accordion-form-error]");
        if (!node) return;
        node.textContent = message || "";
        node.hidden = !message;
    }

    function showList(root) {
        const workspace = workspaceFor(root);
        if (!workspace) return false;
        const list = workspace.querySelector("[data-sf-accordion-list-pane]");
        if (!list) return false;
        workspace.querySelectorAll("[data-sf-accordion-form-pane]").forEach(pane => {
            pane.hidden = true;
            formError(pane, "");
            const form = pane.querySelector("form.sf-form");
            if (form) {
                form.reset();
                delete form.dataset.sfAccordionRecord;
                delete form.dataset.sfAccordionReady;
            }
        });
        list.hidden = false;
        return true;
    }

    function openForm(root, action, row, title) {
        if (!action?.openForm || !row || typeof row !== "object") return false;
        const workspace = workspaceFor(root);
        if (!workspace) return false;
        const pane = Array.from(workspace.querySelectorAll("[data-sf-accordion-form-pane]"))
            .find(node => node.dataset.sfAccordionFormPane === String(action.key));
        const form = pane?.querySelector("form.sf-form");
        if (!pane || !form) return false;
        if (Object.keys(action.formParamMap || {}).length === 0) {
            formError(pane, "لم يتم تحديد ربط حقول النموذج بسجل العملية.");
            return false;
        }
        form.reset();
        formError(pane, "");
        for (const [target, source] of Object.entries(action.formParamMap || {})) {
            const control = form.elements.namedItem(target);
            const rowValue = value(row, source);
            if (!control || !source || !rowValue || !("value" in control)) {
                formError(pane, "تعذر قراءة معرّف العملية أو ربط حقولها. حدّث البيانات.");
                return false;
            }
            control.value = rowValue;
            control.dispatchEvent(new Event("change", { bubbles: true }));
        }
        // Do not put server-managed context (idaraID, entrydata, hostname) in the form.
        const list = workspace.querySelector("[data-sf-accordion-list-pane]");
        if (!list) return false;
        const label = pane.querySelector("[data-sf-accordion-form-record]");
        if (label) label.textContent = title || "";
        workspace.querySelectorAll("[data-sf-accordion-form-pane]").forEach(p => p.hidden = p !== pane);
        list.hidden = true;
        form.dataset.sfAccordionRecord = String(title || "selected");
        form.dataset.sfAccordionReady = "1";
        pane.querySelector("textarea:not([disabled]), input:not([type=hidden]):not([disabled]), select:not([disabled])")
            ?.focus({ preventScroll: true });
        root.dispatchEvent(new CustomEvent("sf-accordion:form-open", {
            bubbles: true, detail: { accordionId: root.id, action: action.key }
        }));
        return true;
    }

    // SmartForm's normal submit handler uses JSON, whereas /crud/insert
    // expects standard form fields. Inside an Accordion ONLY, use a native
    // browser form POST, preserving SmartForm's AntiforgeryToken and validation.
    // There is no custom finance fetch/CRUD implementation here.
    document.addEventListener("submit", function (event) {
        const form = event.target;
        if (!(form instanceof HTMLFormElement)) return;
        const pane = form.closest("[data-sf-accordion-form-pane]");
        if (!pane) return;
        event.preventDefault();
        event.stopImmediatePropagation();
        if (pane.hidden || form.dataset.sfAccordionReady !== "1") return;
        if (!form.reportValidity()) return;
        const workspace = pane.closest("[data-sf-accordion-workspace]");
        const root = workspace?.querySelector("[data-sf-accordion]");
        const state = root ? init(root) : null;
        const action = (state?.config.actions || []).find(a =>
            String(a?.key || "") === pane.dataset.sfAccordionFormPane && a.openForm);
        if (!action) return;
        for (const fieldName of Object.keys(action.formParamMap || {})) {
            const control = form.elements.namedItem(fieldName);
            if (!control || !String(control.value || "").trim()) {
                formError(pane, "تعذر تحديد العملية المطلوبة. ارجع إلى السجل واختر العملية مرة أخرى.");
                return;
            }
        }
        const token = form.elements.namedItem("__RequestVerificationToken");
        if (!token?.value) {
            formError(pane, "رمز الحماية غير متاح. حدّث الصفحة ثم أعد المحاولة.");
            return;
        }
        const route = String(action.openForm.actionUrl || "");
        const method = String(action.openForm.method || "POST").toUpperCase();
        let endpoint;
        try { endpoint = new URL(route, window.location.href); }
        catch { formError(pane, "عنوان تنفيذ النموذج غير صالح."); return; }
        if (method !== "POST" || !/^https?:$/.test(endpoint.protocol) ||
            endpoint.origin !== window.location.origin) {
            formError(pane, "تم رفض عنوان النموذج أو طريقة الإرسال غير الآمنة.");
            return;
        }
        form.action = endpoint.pathname + endpoint.search;
        form.method = "post";
        form.enctype = "application/x-www-form-urlencoded";
        form.dataset.sfAccordionReady = "0";
        form.querySelectorAll('button[type="submit"]').forEach(b => b.disabled = true);
        // Native form submit bypasses the JSON Alpine handler on SmartForm;
        // the existing MVC CRUD controller handles antiforgery, permission,
        // SQL transaction, TempData feedback and redirect as usual.
        HTMLFormElement.prototype.submit.call(form);
    }, true);

    function modalOf(target) {
        const root = typeof target === "string"
            ? document.getElementById(target.replace(/^#/, "")) : target;
        if (!root?.matches?.("[data-sf-accordion]")) return null;
        const dialog = root.closest("dialog[data-sf-accordion-modal]");
        return dialog ? { root, dialog } : null;
    }
    function openModal(target, context = {}) {
        const resolved = modalOf(target);
        if (!resolved || typeof resolved.dialog.showModal !== "function") return false;
        const {root, dialog} = resolved;
        const state = init(root);
        showList(root);
        resetNavigation(state);
        renderCurrent(state);
        if (!dialog.open) dialog.showModal();
        dialog.querySelector("[data-sf-accordion-modal-close]")?.focus({ preventScroll: true });
        if (state.config.dataSource) load(root, context);
        root.dispatchEvent(new CustomEvent("sf-accordion:modal-open", {
            bubbles: true, detail: { id: root.id }
        }));
        return true;
    }
    function closeModal(target) {
        const resolved = modalOf(target);
        if (!resolved || !resolved.dialog.open) return false;
        resolved.dialog.close();
        return true;
    }

    document.addEventListener("click", function (event) {
        const target = event.target;
        if (!(target instanceof Element)) return;
        const closeButton = target.closest("[data-sf-accordion-modal-close]");
        if (closeButton) {
            const root = closeButton.closest("[data-sf-accordion-modal]")?.querySelector("[data-sf-accordion]");
            if (root) { event.preventDefault(); closeModal(root); }
            return;
        }
        if (target.matches("dialog[data-sf-accordion-modal][open]")) {
            const rect = target.getBoundingClientRect();
            if (event.clientX < rect.left || event.clientX > rect.right ||
                event.clientY < rect.top || event.clientY > rect.bottom) target.close();
        }
    });

    document.addEventListener("close", function (event) {
        const dialog = event.target;
        if (!(dialog instanceof HTMLDialogElement) || !dialog.matches("[data-sf-accordion-modal]")) return;
        const root = dialog.querySelector("[data-sf-accordion]");
        if (!root) return;
        const state = init(root);
        showList(root);
        state.abort?.abort();
        ++state.requestId;
        if (state.config.dataSource) { render(root, []); showMessage(root, ""); }
    }, true);

    // SmartDrawer's keyboard capture should not steal focus from a top-layer dialog.
    window.addEventListener("keydown", function (event) {
        const dialog = document.querySelector("dialog[data-sf-accordion-modal][open]");
        if (!dialog || (event.key !== "Escape" && event.key !== "Tab")) return;
        if (event.key === "Escape") {
            event.preventDefault();
            event.stopImmediatePropagation();
            dialog.close();
        } else {
            event.stopImmediatePropagation();
        }
    }, true);

    document.addEventListener("click", function (event) {
        const target = event.target;
        if (!(target instanceof Element)) return;
        const back = target.closest("[data-sf-accordion-form-back]");
        if (back) {
            const workspace = back.closest("[data-sf-accordion-workspace]");
            const root = workspace?.querySelector("[data-sf-accordion]");
            if (root) {
                event.preventDefault();
                showList(root);
                root.querySelector("[data-sf-accordion-search]")?.focus({ preventScroll: true });
            }
            return;
        }
        const button = target.closest("[data-sf-accordion-toggle], [data-sf-accordion-action], [data-sf-accordion-prev], [data-sf-accordion-next]");
        const root = button?.closest("[data-sf-accordion]");
        if (!root || !button) return;
        const state = init(root);
        if (button.hasAttribute("data-sf-accordion-toggle")) {
            const id = button.closest("[data-sf-accordion-item]")?.dataset.itemId;
            if (!id) return;
            const willOpen = button.getAttribute("aria-expanded") !== "true";
            if (willOpen && !state.config.allowMultipleOpen) {
                state.expanded.clear();
                root.querySelectorAll("[data-sf-accordion-toggle]").forEach(b => setExpanded(b, false));
            }
            if (willOpen) state.expanded.add(id);
            else state.expanded.delete(id);
            setExpanded(button, willOpen);
        } else if (button.hasAttribute("data-sf-accordion-action")) {
            const id = button.dataset.itemId;
            const action = (state.config.actions || []).find(a =>
                String(a?.key || "") === String(button.dataset.sfAccordionAction || ""));
            const entry = state.items.find(e => String(e.item.id) === String(id));
            if (action?.openForm && entry) {
                openForm(root, action, state.rows.get(String(id)), entry.item.title);
                return;
            }
            root.dispatchEvent(new CustomEvent("sf-accordion:action", {
                bubbles: true, detail: {
                    accordionId: root.id, action: button.dataset.sfAccordionAction,
                    itemId: id, row: state.rows.get(String(id))
                }
            }));
        } else if (!button.disabled) {
            const step = button.hasAttribute("data-sf-accordion-prev") ? -1 : 1;
            state.page += step;
            state.expanded.clear();
            renderCurrent(state);
            root.querySelector("[data-sf-accordion-scroll]")?.scrollTo?.({ top: 0 });
        }
    });

    document.addEventListener("input", function (event) {
        const target = event.target;
        if (!target?.matches?.("[data-sf-accordion-search]")) return;
        const root = target.closest("[data-sf-accordion]");
        if (!root) return;
        const state = init(root);
        state.query = normalize(target.value);
        state.page = 1;
        state.expanded.clear();
        renderCurrent(state);
    });
    document.addEventListener("change", function (event) {
        const target = event.target;
        if (!target?.matches?.("[data-sf-accordion-status-filter], [data-sf-accordion-page-size]")) return;
        const root = target.closest("[data-sf-accordion]");
        if (!root) return;
        const state = init(root);
        if (target.hasAttribute("data-sf-accordion-status-filter")) state.status = target.value;
        else if (validSize(target.value) && state.pageSizes.includes(Number(target.value))) state.pageSize = Number(target.value);
        state.page = 1;
        state.expanded.clear();
        renderCurrent(state);
    });

    document.addEventListener("sf-drawer:close", function (event) {
        if (!(event.target instanceof Element)) return;
        event.target.querySelectorAll("dialog[data-sf-accordion-modal][open]").forEach(dialog => dialog.close());
        event.target.querySelectorAll("[data-sf-accordion]").forEach(root => {
            const state = init(root);
            showList(root);
            if (state.config.dataSource) {
                state.abort?.abort();
                ++state.requestId;
                render(root, []);
                showMessage(root, "");
            }
        });
    });
    document.addEventListener("sf-drawer:open", function (event) {
        if (!(event.target instanceof Element)) return;
        event.target.querySelectorAll("[data-sf-accordion]").forEach(root => {
            const state = init(root);
            if (state.config.renderInModal === true) return;
            if (state.config.dataSource?.reloadOnDrawerOpen !== false) load(root, event.detail?.context || {});
        });
    });

    const initAll = () => document.querySelectorAll("[data-sf-accordion]").forEach(init);
    if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", initAll);
    else initAll();
    window.SmartAccordion = Object.freeze({ load, render, init: initAll, openModal, closeModal });
})();
