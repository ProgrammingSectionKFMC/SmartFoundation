window.__sfTableGlobalBound = window.__sfTableGlobalBound || false;

(function () {
    const register = () => {
        Alpine.data("sfTable", (cfg) => ({

            // Core configuration
            endpoint: cfg.endpoint || "/smart/execute",
            spName: cfg.spName || "",
            operation: cfg.operation || "select",

            // Profile view configuration
            viewMode: (cfg.viewMode ?? "Table"),

            profileTitleField: (cfg.profileTitleField ?? null),
            profileSubtitleField: (cfg.profileSubtitleField ?? null),
            profileBadges: Array.isArray(cfg.profileBadges) ? cfg.profileBadges : [],
            profileMetaFields: Array.isArray(cfg.profileMetaFields) ? cfg.profileMetaFields : [],
            profileFields: Array.isArray(cfg.profileFields) ? cfg.profileFields : [],
            profileCssClass: (cfg.profileCssClass ?? ""),
            profileColumns: Number.isFinite(Number(cfg.profileColumns)) ? Number(cfg.profileColumns) : 2,
            profileShowHeader: (cfg.profileShowHeader !== false),
            profileIcon: (cfg.profileIcon ?? "fa-solid fa-id-card"),
            profileTitleText: (cfg.profileTitleText ?? "البيانات الأساسية"),

            // Profile helpers
            normalizeFieldName(v) {
                if (v == null) return "";
                if (typeof v === "string") return v.trim();

                return String(v.field ?? v.Field ?? v.name ?? v.Name ?? "").trim();
            },
            getProfileTitle(row) {
                const f = this.normalizeFieldName(this.profileTitleField);
                if (f && row?.[f] != null) return String(row[f]);
                const first = (this.visibleColumns?.() || []).find(c => c?.visible !== false && c?.field);
                return first ? String(row?.[first.field] ?? "") : "";
            },
            getProfileSubtitle(row) {
                const f = this.normalizeFieldName(this.profileSubtitleField);
                if (f && row?.[f] != null) return String(row[f]);
                return "";
            },
            profileMetaList() {
                const cols = (this.visibleColumns?.() || []).filter(c => c && c.visible !== false && c.field);
                const map = new Map(cols.map(c => [String(c.field), c]));

                const src = Array.isArray(this.profileMetaFields) ? this.profileMetaFields : [];
                const items = [];

                for (const it of src) {
                    const field = this.normalizeFieldName(it);
                    if (!field) continue;

                    const col = map.get(field);
                    const label =
                        (typeof it === "object" && (it.label || it.Label)) ||
                        (col?.label || col?.Label) ||
                        field;

                    items.push({ field, label });
                }

                return items;
            },
            profileColumnsList() {
                const cols = (this.visibleColumns?.() || [])
                    .filter(c => c && c.visible !== false && c.field);

                const titleF = String(this.normalizeFieldName(this.profileTitleField));
                const subF = String(this.normalizeFieldName(this.profileSubtitleField));
                if (Array.isArray(this.profileFields) && this.profileFields.length) {
                    const wanted = this.profileFields.map(f => String(this.normalizeFieldName(f))).filter(Boolean);
                    const map = new Map(cols.map(c => [String(c.field), c]));
                    return wanted.map(f => map.get(f)).filter(Boolean);
                }
                return cols.filter(c => String(c.field) !== titleF && String(c.field) !== subF);
            },

            profileGridClass() {
                const n = Math.max(1, Math.min(3, Number(this.profileColumns) || 2));
                return `sf-profile__grid sf-profile__grid--cols-${n}`;
            },
            profilePlaceholderCount(total, cols) {
                const c = Math.max(1, Math.min(3, Number(cols) || 2));
                const r = total % c;
                return r === 0 ? 0 : (c - r);
            },
            profileColumnsCount() {
                return (this.profileColumnsList?.() || []).length;
            },

            // Column filter state
            filtersEnabled: (cfg.filtersEnabled !== false),
            filtersRow: (cfg.filtersRow !== false),
            filtersDebounce: Number(cfg.filtersDebounce || 250),
            filtersTimer: null,
            columnFilters: (cfg.columnFilters && typeof cfg.columnFilters === "object") ? cfg.columnFilters : {},
            showFilters: false,
            filterToggleSeq: 0,

            filterOptionsCache: {},
            filterOptionsLoading: {},
            showColumnVisibility: (cfg.showColumnVisibility === true),
            enableColumnReorder: !!cfg.enableColumnReorder,
            dragColField: null,
            dragOverColField: null,
            draggingColField: null,
            ghostEl: null,
            ghostOffsetX: 0,
            ghostOffsetY: 0,
            boundGhostMove: null,

            // Column filter initialization
            initColumnFilters() {
                const cols = Array.isArray(this.columns) ? this.columns : [];
                if (!this.columnFilters || typeof this.columnFilters !== "object") this.columnFilters = {};

                for (const c of cols) {
                    const f = String(c?.field || "");
                    if (!f) continue;

                    if (this.columnFilters[f] !== undefined) continue;

                    const raw = (c?.filter?.defaultValue ?? c?.Filter?.DefaultValue);

                    let val = "";
                    if (raw === null || raw === undefined) {
                        val = "";
                    } else if (typeof raw === "string") {
                        val = raw.trim();
                    } else if (typeof raw === "number" || typeof raw === "boolean") {

                        val = "";
                    } else {
                        val = "";
                    }

                    if (val === "فلترة..." || val === "فلترة…") val = "";

                    this.columnFilters[f] = val;
                }
            },

            // Column filter definitions
            getColFilterDef(col) {
                const cf = col?.filter || col?.Filter || null;
                return cf;
            },

            isColFilterEnabled(col) {
                const def = this.getColFilterDef(col);
                if (!def) return false;

                const en = (def.enabled ?? def.Enabled);
                return en === true || String(en).toLowerCase() === "true";
            },

            getColFilterType(col) {
                const def = this.getColFilterDef(col);
                const t = (def?.type || def?.Type || "").toLowerCase();
                if (t) return t;

                const ct = String(col?.type || col?.Type || "").toLowerCase();
                if (["date", "datetime"].includes(ct)) return "date";
                if (["bool", "boolean"].includes(ct)) return "bool";
                if (["number", "int", "decimal", "float", "double", "money"].includes(ct)) return "number";
                return "text";
            },

            getColFilterMatch(col) {
                const def = this.getColFilterDef(col) || {};
                return String(def.match || def.Match || "contains").toLowerCase();
            },

            getColFilterPlaceholder(col) {
                const def = this.getColFilterDef(col);
                return def?.placeholder || def?.Placeholder || "فلترة…";
            },

            getColFilterOptions(col) {
                const def = this.getColFilterDef(col) || {};
                const type = this.getColFilterType(col);
                if (type !== "select") return [];

                const inline = def.options || def.Options;
                if (Array.isArray(inline) && inline.length) return inline;

                const src = String(def.optionsSource || def.OptionsSource || "client").toLowerCase();
                const key = String(def.optionsKey || def.OptionsKey || col?.field || "").trim();

                if (src === "server") {
                    return this.filterOptionsCache[key] || [];
                }

                const field = String(col?.field || "");
                if (!field) return [];

                const srcRows =
                    (Array.isArray(this.allRows) && this.allRows.length) ? this.allRows :
                        (Array.isArray(this.rows) && this.rows.length) ? this.rows : [];

                const uniq = new Map();
                for (const r of srcRows) {
                    const v = r?.[field];
                    const s = (v == null) ? "" : String(v).trim();
                    if (!s) continue;
                    if (!uniq.has(s)) uniq.set(s, s);
                    if (uniq.size >= 150) break;
                }
                return Array.from(uniq.keys()).sort().map(x => ({ value: x, text: x }));
            },
            renderColFilterOptions(selectEl, col) {
                if (!selectEl) return;

                const options = this.getColFilterOptions(col);
                const field = String(col?.field || "");
                const currentValue = String(this.columnFilters?.[field] ?? selectEl.value ?? "");
                const signature = JSON.stringify(options.map(opt => [
                    String(opt?.value ?? opt?.Value ?? ""),
                    String(opt?.text ?? opt?.Text ?? opt?.value ?? opt?.Value ?? "")
                ]));

                if (selectEl.dataset.sfOptionsSignature === signature) return;
                selectEl.dataset.sfOptionsSignature = signature;
                selectEl.innerHTML = "";

                const allOption = document.createElement("option");
                allOption.value = "";
                allOption.textContent = "الكل";
                selectEl.appendChild(allOption);

                options.forEach(opt => {
                    const option = document.createElement("option");
                    option.value = String(opt?.value ?? opt?.Value ?? "");
                    option.textContent = String(opt?.text ?? opt?.Text ?? opt?.value ?? opt?.Value ?? "");
                    selectEl.appendChild(option);
                });

                selectEl.value = currentValue;
            },

            normalizeFilterText(value) {
                return String(value ?? "")
                    .replace(/\u0640/g, "")
                    .replace(/[أإآ]/g, "ا")
                    .replace(/ى/g, "ي")
                    .replace(/\s+/g, " ")
                    .trim()
                    .toLowerCase();
            },

            getColFilterOptionText(col, value) {
                const currentValue = String(value ?? "").trim();
                if (!currentValue) return "";

                const options = this.getColFilterOptions(col) || [];
                const hit = options.find((opt) => {
                    const optValue = String(opt?.value ?? opt?.Value ?? "").trim();
                    return optValue === currentValue;
                });

                return String(
                    hit?.text ??
                    hit?.Text ??
                    hit?.value ??
                    hit?.Value ??
                    ""
                ).trim();
            },

            async fetchFilterOptionsForCol(col) {
                const def = this.getColFilterDef(col) || {};
                const type = this.getColFilterType(col);
                if (type !== "select") return;

                const src = String(def.optionsSource || def.OptionsSource || "client").toLowerCase();
                if (src !== "server") return;

                const key = String(def.optionsKey || def.OptionsKey || col?.field || "").trim();
                if (!key) return;

                if (this.filterOptionsCache[key]) return;

                if (this.filterOptionsLoading[key]) return;
                this.filterOptionsLoading[key] = true;

                try {

                    const url = `/smart/table/filter-options?key=${encodeURIComponent(key)}&sp=${encodeURIComponent(this.spName)}`;

                    const res = await fetch(url, { credentials: "same-origin" });
                    const data = await res.json();

                    this.filterOptionsCache[key] = Array.isArray(data) ? data : [];
                } catch (e) {
                    this.filterOptionsCache[key] = [];
                } finally {
                    this.filterOptionsLoading[key] = false;
                }
            },

            async preloadSelectFilters() {
                const cols = this.visibleColumns?.() || [];
                for (const col of cols) {
                    if (!this.isColFilterEnabled(col)) continue;
                    const def = this.getColFilterDef(col);

                    if (this.getColFilterType(col) === "select") {
                        await this.fetchFilterOptionsForCol(col);
                    }
                }
            },

            // Column filter actions
            onColumnFilterInput() {
                this.syncColumnFiltersFromDom();
                clearTimeout(this.filtersTimer);
                this.filtersTimer = setTimeout(() => {
                    this.page = 1;

                    if (this.serverPaging) {

                        this.load();
                    } else {

                        this.applyFiltersAndSort();
                    }

                    this.savePreferences?.();
                }, this.filtersDebounce);
            },

            clearAllColumnFilters() {
                const cols = Array.isArray(this.columns) ? this.columns : [];
                const nextFilters = { ...(this.columnFilters || {}) };
                for (const c of cols) {
                    const f = String(c?.field || "");
                    if (!f) continue;
                    nextFilters[f] = "";
                }
                this.columnFilters = nextFilters;
                this.$nextTick(() => this.refreshFilterControlsUI());
                this.onColumnFilterInput();
            },

            normalizeColumnFilterValue(value) {
                if (value == null) return "";
                if (Array.isArray(value)) return this.normalizeColumnFilterValue(value[0]);
                if (typeof value === "string") return value.trim();
                if (typeof value === "number" || typeof value === "boolean") return String(value);
                return "";
            },

            setColumnFilterValue(field, value) {
                const key = String(field || "").trim();
                if (!key) return false;

                const normalized = this.normalizeColumnFilterValue(value);
                const current = this.normalizeColumnFilterValue(this.columnFilters?.[key]);
                if (current === normalized) return false;

                this.columnFilters = {
                    ...(this.columnFilters || {}),
                    [key]: normalized
                };

                return true;
            },

            syncColumnFiltersFromDom() {
                if (!this.showFilters || !this.$el) return false;

                const controls = this.$el.querySelectorAll(".sf-filter-row [data-field]");
                if (!controls.length) return false;

                const nextFilters = { ...(this.columnFilters || {}) };
                let changed = false;

                controls.forEach((el) => {
                    const field = String(el.getAttribute("data-field") || "").trim();
                    if (!field) return;

                    const value = this.normalizeColumnFilterValue(el.value);
                    const current = this.normalizeColumnFilterValue(nextFilters[field]);
                    if (current === value) return;

                    nextFilters[field] = value;
                    changed = true;
                });

                if (changed) {
                    this.columnFilters = nextFilters;
                }

                return changed;
            },

            refreshFilterControlsUI() {
                if (!this.showFilters || !this.$el) return;

                const controls = this.$el.querySelectorAll(".sf-filter-row [data-field]");
                controls.forEach((el) => {
                    const field = String(el.getAttribute("data-field") || "").trim();
                    if (!field) return;

                    const value = this.normalizeColumnFilterValue(this.columnFilters?.[field]);

                    if (el.tagName === "SELECT" && window.jQuery && jQuery.fn) {
                        const $el = jQuery(el);
                        if ($el.data("select2")) {
                            $el.val(value).trigger("change.select2");
                            return;
                        }
                    }

                    if ((el.value ?? "") !== value) {
                        el.value = value;
                    }
                });
            },

            // Column filter matching
            matchText(hay, needle) {
                const h = (hay == null) ? "" : String(hay).toLowerCase();
                const n = (needle == null) ? "" : String(needle).toLowerCase().trim();
                if (!n) return true;

                const tokens = n.split(/\s+/).filter(Boolean);
                return tokens.every(t => h.includes(t));
            },

            matchNumber(val, expr) {
                const s = String(expr ?? "").trim();
                if (!s) return true;
                const n = Number(val);
                if (Number.isNaN(n)) return false;

                const m = s.match(/^(>=|<=|>|<|=)?\s*(-?\d+(\.\d+)?)$/);
                if (!m) return false;
                const op = m[1] || "=";
                const x = Number(m[2]);
                if (Number.isNaN(x)) return false;

                if (op === ">") return n > x;
                if (op === ">=") return n >= x;
                if (op === "<") return n < x;
                if (op === "<=") return n <= x;
                return n === x;
            },

            matchDate(val, expr) {
                const s = String(expr ?? "").trim();
                if (!s) return true;

                const d = new Date(val);
                if (Number.isNaN(d.getTime())) return false;

                const range = s.split("..").map(x => x.trim());
                const toDay = (x) => {
                    const z = new Date(x);
                    if (Number.isNaN(z.getTime())) return null;

                    return new Date(z.getFullYear(), z.getMonth(), z.getDate());
                };

                const dd = new Date(d.getFullYear(), d.getMonth(), d.getDate());

                if (range.length === 2) {
                    const a = toDay(range[0]);
                    const b = toDay(range[1]);
                    if (!a || !b) return false;
                    return dd >= a && dd <= b;
                }

                const m = s.match(/^(>=|<=|>|<|=)?\s*(\d{4}-\d{2}-\d{2})$/);
                if (m) {
                    const op = m[1] || "=";
                    const x = toDay(m[2]);
                    if (!x) return false;
                    if (op === ">") return dd > x;
                    if (op === ">=") return dd >= x;
                    if (op === "<") return dd < x;
                    if (op === "<=") return dd <= x;
                    return dd.getTime() === x.getTime();
                }

                return false;
            },

            matchBool(val, expr) {
                const s = String(expr ?? "").toLowerCase().trim();
                if (!s) return true;
                const b = !!val;
                if (["1", "true", "نعم", "yes", "y"].includes(s)) return b === true;
                if (["0", "false", "لا", "no", "n"].includes(s)) return b === false;
                return false;
            },

            rowPassesColumnFilters(row) {
                if (!this.filtersEnabled) return true;

                const cols = this.visibleColumns?.() || [];

                for (const col of cols) {
                    const field = String(col?.field || "");
                    if (!field) continue;

                    if (!this.isColFilterEnabled(col)) continue;

                    const fval = this.columnFilters?.[field];
                    if (fval == null || String(fval).trim() === "") continue;

                    const type = this.getColFilterType(col);
                    const cell = row?.[field];

                    if (type === "number") {
                        if (!this.matchNumber(cell, fval)) return false;
                    } else if (type === "date") {
                        if (!this.matchDate(cell, fval)) return false;
                    } else if (type === "bool") {
                        if (!this.matchBool(cell, fval)) return false;
                    } else if (type === "select") {
                        const cellValue = String(cell ?? "").trim();
                        const filterValue = String(fval ?? "").trim();
                        const cellNorm = this.normalizeFilterText(cellValue);
                        const filterNorm = this.normalizeFilterText(filterValue);

                        if (cellNorm === filterNorm) continue;

                        const optionText = this.getColFilterOptionText(col, fval);
                        const optionTextNorm = this.normalizeFilterText(optionText);
                        if (optionTextNorm && cellNorm === optionTextNorm) continue;

                        return false;
                    } else {

                        const m = this.getColFilterMatch(col);
                        if (m === "eq") {
                            const a = String(cell ?? "").trim();
                            const b = String(fval ?? "").trim();
                            if (a !== b) return false;
                        } else {
                            if (!this.matchText(cell, fval)) return false;
                        }
                    }
                }

                return true;
            },

            hasActiveColumnFilters() {
                this.syncColumnFiltersFromDom();
                if (!this.columnFilters || typeof this.columnFilters !== "object") return false;
                for (const k of Object.keys(this.columnFilters)) {
                    const v = this.columnFilters[k];
                    if (v == null) continue;
                    const s = String(v).trim();
                    if (s && s !== "فلترة..." && s !== "فلترة…") return true;
                }
                return false;
            },

            // Select2 filter controls
            initFilterSelect2() {

                if (!window.jQuery || !jQuery.fn || !jQuery.fn.select2) return;

                this.$nextTick(() => {
                    requestAnimationFrame(() => {
                        requestAnimationFrame(() => {

                            const root = this.$el;
                            const selects = root.querySelectorAll("select.sf-filter-select2");

                            const measureFilterDropdownWidth = (selectEl, placeholderText = "الكل") => {
                                const rect = selectEl.getBoundingClientRect();
                                const triggerWidth = Math.ceil(rect.width || 0);
                                const viewportWidth = Math.max(document.documentElement.clientWidth || 0, window.innerWidth || 0);

                                const texts = Array.from(selectEl.options || [])
                                    .map((opt) => (opt?.textContent || "").trim())
                                    .filter(Boolean);

                                if (placeholderText) {
                                    texts.push(String(placeholderText).trim());
                                }

                                const probe = document.createElement("span");
                                probe.style.position = "fixed";
                                probe.style.top = "-9999px";
                                probe.style.left = "-9999px";
                                probe.style.visibility = "hidden";
                                probe.style.whiteSpace = "nowrap";
                                probe.style.fontFamily = '"Tajawal", "Inter", "Segoe UI", sans-serif';
                                probe.style.fontSize = "13.5px";
                                probe.style.fontWeight = "500";
                                probe.style.lineHeight = "1";
                                document.body.appendChild(probe);

                                let widest = triggerWidth;
                                texts.forEach((text) => {
                                    probe.textContent = text;
                                    widest = Math.max(widest, Math.ceil(probe.getBoundingClientRect().width));
                                });

                                probe.remove();

                                const paddedWidth = widest + 84;
                                const maxWidth = Math.max(triggerWidth, Math.min(560, viewportWidth - 24));
                                return Math.max(triggerWidth, Math.min(paddedWidth, maxWidth));
                            };

                            const positionFilterDropdown = (selectEl, preferredWidth) => {
                                const $open = jQuery(".select2-container--open").filter(function () {
                                    return jQuery(this).find(".select2-dropdown.sf-filter-dropdown").length > 0;
                                }).last();

                                if (!$open.length) return;

                                const rect = selectEl.getBoundingClientRect();
                                const viewportWidth = Math.max(document.documentElement.clientWidth || 0, window.innerWidth || 0);
                                const scrollX = window.pageXOffset || document.documentElement.scrollLeft || 0;
                                const minViewportGap = 12;
                                const width = Math.max(Math.ceil(rect.width || 0), preferredWidth || 0);

                                let left = Math.round(rect.right + scrollX - width);
                                const minLeft = scrollX + minViewportGap;
                                const maxLeft = scrollX + viewportWidth - width - minViewportGap;
                                left = Math.max(minLeft, Math.min(left, maxLeft));

                                $open.addClass("sf-filter-dropdown-host");
                                $open.css({
                                    minWidth: `${Math.ceil(rect.width || 0)}px`,
                                    width: `${width}px`,
                                    maxWidth: `${Math.max(width, viewportWidth - (minViewportGap * 2))}px`,
                                    left: `${left}px`,
                                    right: "auto"
                                });

                                $open.find(".select2-dropdown.sf-filter-dropdown").css({
                                    width: "100%",
                                    minWidth: `${Math.ceil(rect.width || 0)}px`
                                });
                            };

                            const stripSelect2Title = ($select) => {
                                if (!$select || !$select.length) return;
                                const $container = $select.next(".select2");
                                $container.find(".select2-selection__rendered").removeAttr("title");
                                $container.find(".select2-selection").removeAttr("title");
                            };

                            selects.forEach((el) => {
                                const $el = jQuery(el);

                                if ($el.data("select2")) {
                                    $el.off(".sfFilter");
                                    $el.select2("destroy");
                                }

                                const minResults = el.getAttribute("data-s2-min-results");
                                const ph =
                            el.getAttribute("data-s2-placeholder") ||
                            $el.find('option[value=""]').first().text() ||
                            "الكل";

                                const dropdownParent = jQuery("body");

                                $el.select2({
                                    width: "100%",
                                    dir: "rtl",
                                    dropdownParent,
                                    containerCssClass: "sf-form",
                                    dropdownCssClass: "sf-form sf-filter-dropdown",
                                    dropdownAutoWidth: true,
                                    placeholder: ph,
                                    allowClear: false,
                                    minimumResultsForSearch:
                                (minResults === undefined || minResults === null || minResults === "")
                                    ? 0
                                    : Number(minResults)
                                });

                                stripSelect2Title($el);

                                const field = el.getAttribute("data-field");
                                const v = this.columnFilters?.[field] ?? "";
                                $el.val(v).trigger("change.select2");
                                stripSelect2Title($el);

                                $el.on("select2:open.sfFilter", () => {
                                    const preferredWidth = measureFilterDropdownWidth(el, ph);
                                    stripSelect2Title($el);
                                    requestAnimationFrame(() => {
                                        positionFilterDropdown(el, preferredWidth);
                                    });
                                    setTimeout(() => {
                                        positionFilterDropdown(el, preferredWidth);
                                    }, 0);
                                });

                                const syncFilterFromSelect = () => {
                                    const f = el.getAttribute("data-field");
                                    stripSelect2Title($el);
                                    this.setColumnFilterValue(f, $el.val());
                                    this.onColumnFilterInput();
                                };

                                $el.on("change.sfFilter", syncFilterFromSelect);
                                $el.on("select2:select.sfFilter select2:clear.sfFilter select2:unselect.sfFilter", syncFilterFromSelect);
                            });
                        });

                    });
                });
            },

            destroyFilterSelect2() {
                if (!window.jQuery || !jQuery.fn || !jQuery.fn.select2) return;

                const root = this.$el;
                const selects = root.querySelectorAll("select.sf-filter-select2");
                selects.forEach((el) => {
                    const $el = jQuery(el);
                    if ($el.data("select2")) {
                        $el.off(".sfFilter");
                        $el.select2("destroy");
                    }
                });
            },

            async toggleFilters() {
                const nextState = !this.showFilters;
                this.showFilters = nextState;

                const seq = ++this.filterToggleSeq;

                if (!nextState) {
                    this.destroyFilterSelect2();
                    return;
                }

                try {

                    await this.preloadSelectFilters();

                    if (seq !== this.filterToggleSeq || !this.showFilters) return;

                    await this.$nextTick();

                    if (seq !== this.filterToggleSeq || !this.showFilters) return;

                    this.destroyFilterSelect2();
                    this.initFilterSelect2();
                } catch (e) {

                    if (seq === this.filterToggleSeq) {
                        this.destroyFilterSelect2();
                    }
                }
            },

            clearFiltersUI() {
                this.clearAllColumnFilters();
            },

            // Table options
            pageSize: cfg.pageSize || 10,
            pageSizes: cfg.pageSizes || [10, 25, 50, 100],
            enablePagination: cfg.enablePagination !== false,
            showPageSizeSelector: cfg.showPageSizeSelector === true,

            serverPaging: !!cfg.serverPaging,

            searchable: !!cfg.searchable,
            searchPlaceholder: cfg.searchPlaceholder || "بحث…",
            quickSearchFields: cfg.quickSearchFields || [],
            searchDelay: 300,
            searchTimer: null,

            showHeader: cfg.showHeader !== false,
            showFooter: cfg.showFooter !== false,
            allowExport: !!cfg.allowExport,
            autoRefresh: !!(cfg.autoRefresh || cfg.autoRefreshOnSubmit),
            enableCellCopy: !!cfg.enableCellCopy,

            columns: Array.isArray(cfg.columns) ? cfg.columns : [],
            actions: Array.isArray(cfg.actions) ? cfg.actions : [],
            _columnsVersion: 0,
            _visibleColumnsCache: null,
            _visibleColumnsCacheVersion: -1,
            _toolbarActionCache: null,
            _toolbarButtonActionCache: null,
            _toolbarMenuActionCache: null,
            _rowEndActionCache: null,
            _rowEndButtonActionCache: null,
            _rowEndMenuActionCache: null,
            _styleRuleIndex: null,
            _styleRuleSource: null,
            _cellPillCache: null,
            _searchTextCache: null,
            _savePreferencesTimer: null,

            // Column visibility state
            colVisOpen: false,
            colVisSearch: "",
            colVisMap: {},
            colVisLoaded: true,
            colVisAnchorRect: null,
            colVisPlacement: {
                top: 0,
                left: 0,
                width: 320,
                maxHeight: 420
            },

            // Column visibility helpers
            colVisStorageKey() {
                const base =
                    (cfg && (cfg.storageKey || cfg.StorageKey)) ||
                    `sfTable:${cfg?.spName || cfg?.StoredProcedureName || "sp"}:${cfg?.operation || cfg?.Operation || "op"}`;
                return base + ":colvis";
            },

            colVisIsLocked(col) {
                const cp = col?.customProperties || col?.CustomProperties || {};
                const hideable = (cp.hideable ?? cp.Hideable);
                if (hideable === false) return true;
                if (col?.frozen || col?.Frozen) return true;
                return false;
            },

            colVisLoad() {
                return;
            },

            colVisSave() {
                return;
            },

            colVisIsShown(col) {
                const def = (col?.visible ?? col?.Visible);
                const v = this.colVisMap?.[col.field];
                return (typeof v === "boolean") ? v : !!def;
            },
            invalidateColumnCache() {
                this._columnsVersion = (this._columnsVersion || 0) + 1;
                this._visibleColumnsCache = null;
                this._visibleColumnsCacheVersion = -1;
            },
            invalidateActionCache() {
                this._toolbarActionCache = null;
                this._toolbarButtonActionCache = null;
                this._toolbarMenuActionCache = null;
                this._rowEndActionCache = null;
                this._rowEndButtonActionCache = null;
                this._rowEndMenuActionCache = null;
            },
            invalidateRowCaches() {
                this._searchTextCache = new WeakMap();
                this._cellPillCache = new WeakMap();
            },

            colVisToggle(col) {
                if (this.colVisIsLocked(col)) return;

                const now = this.colVisIsShown(col);
                const next = { ...(this.colVisMap || {}) };
                next[col.field] = !now;
                this.colVisMap = next;
                this.invalidateColumnCache();
            },

            colVisShowAll() {
                const cols = this.colVisBaseColumns();
                const next = { ...(this.colVisMap || {}) };

                cols.forEach(c => {
                    if (!this.colVisIsLocked(c)) next[c.field] = true;
                });

                this.colVisMap = next;
                this.invalidateColumnCache();
            },

            colVisReset() {
                this.colVisMap = {};
                this.invalidateColumnCache();
            },

            colVisApply() {
                return;
            },

            colVisFilteredColumns() {
                const q = String(this.colVisSearch || "").toLowerCase().trim();
                const cols = this.colVisBaseColumns();

                if (!q) return cols;

                return cols.filter(c => {
                    const lbl = this.colVisLabel(c).toLowerCase();
                    const fld = String(c.field ?? "").toLowerCase();
                    return lbl.includes(q) || fld.includes(q);
                });
            },

            colVisLabel(col) {
                return String(col?.label ?? col?.title ?? col?.header ?? col?.field ?? "").trim();
            },

            colVisBaseColumns() {
                return (this.columns || []).filter(c => {
                    const hasHeader = !!(c.label || c.title || c.header);
                    const visible = (c.visible ?? c.Visible) !== false;

                    const cp = c.customProperties || c.CustomProperties || {};
                    const hideable = (cp.hideable ?? cp.Hideable);
                    if (hideable === false) return false;

                    return hasHeader && visible;
                });
            },

            toggleColVis(e) {
                if (this.colVisOpen) {
                    this.closeColVis();
                    return;
                }

                const btn = e?.currentTarget || this.$refs?.colVisBtn || null;
                if (btn) {
                    this.colVisAnchorRect = btn.getBoundingClientRect();
                }

                this.colVisOpen = true;

                this.$nextTick(() => {
                    this.updateColVisPosition();

                    if (!this.__colVisBound) {
                        this.__colVisBound = true;

                        this.__colVisResizeHandler = () => {
                            if (!this.colVisOpen) return;
                            const liveBtn = this.$refs?.colVisBtn;
                            if (liveBtn) this.colVisAnchorRect = liveBtn.getBoundingClientRect();
                            this.updateColVisPosition();
                        };

                        this.__colVisScrollHandler = () => {
                            if (!this.colVisOpen) return;
                            const liveBtn = this.$refs?.colVisBtn;
                            if (liveBtn) this.colVisAnchorRect = liveBtn.getBoundingClientRect();
                            this.updateColVisPosition();
                        };

                        window.addEventListener("resize", this.__colVisResizeHandler, { passive: true });
                        window.addEventListener("scroll", this.__colVisScrollHandler, true);
                    }
                });
            },

            closeColVis() {
                this.colVisOpen = false;
                this.colVisAnchorRect = null;
            },

            colVisPanelStyle() {
                const p = this.colVisPlacement || {};

                return [
                    "position:fixed",
                    "z-index:2147483647",
                    "top:" + (p.top || 0) + "px",
                    "left:" + (p.left || 0) + "px",
                    "right:auto",
                    "bottom:auto",
                    "width:" + (p.width || 320) + "px",
                    "max-width:calc(100vw - 24px)",
                    "max-height:" + (p.maxHeight || 420) + "px",
                    "display:flex",
                    "flex-direction:column",
                    "overflow:hidden"
                ].join(";");
            },

            updateColVisPosition() {
                const panel = this.$refs?.colVisPanel;
                const btn = this.$refs?.colVisBtn;

                if (!panel) return;

                const anchorRect =
                    this.colVisAnchorRect ||
                    btn?.getBoundingClientRect?.() ||
                    null;

                if (!anchorRect) return;

                const GAP = 8;
                const MARGIN = 12;
                const viewportW = window.innerWidth;
                const viewportH = window.innerHeight;
                const panelWidth = Math.min(320, viewportW - (MARGIN * 2));

                panel.style.visibility = "hidden";
                panel.style.display = "flex";
                panel.style.flexDirection = "column";
                panel.style.width = panelWidth + "px";
                panel.style.maxHeight = "420px";
                panel.style.left = "-99999px";
                panel.style.top = "-99999px";

                let panelRect = panel.getBoundingClientRect();
                let measuredHeight = Math.ceil(panelRect.height || 320);

                const spaceBelow = viewportH - anchorRect.bottom - GAP - MARGIN;
                const spaceAbove = anchorRect.top - GAP - MARGIN;

                let top = 0;
                let maxHeight = 420;

                if (spaceBelow >= Math.min(measuredHeight, 420) || spaceBelow >= spaceAbove) {
                    maxHeight = Math.max(180, spaceBelow);
                    panel.style.maxHeight = maxHeight + "px";

                    panelRect = panel.getBoundingClientRect();
                    measuredHeight = Math.ceil(panelRect.height || measuredHeight);

                    top = anchorRect.bottom + GAP;

                    if (top + measuredHeight > viewportH - MARGIN) {
                        top = viewportH - measuredHeight - MARGIN;
                    }
                } else {
                    maxHeight = Math.max(180, spaceAbove);
                    panel.style.maxHeight = maxHeight + "px";

                    panelRect = panel.getBoundingClientRect();
                    measuredHeight = Math.ceil(panelRect.height || measuredHeight);

                    top = anchorRect.top - measuredHeight - GAP;

                    if (top < MARGIN) {
                        top = MARGIN;
                    }
                }

                let left = anchorRect.right - panelWidth;

                if (left < MARGIN) {
                    left = anchorRect.left;
                }

                if (left + panelWidth > viewportW - MARGIN) {
                    left = viewportW - panelWidth - MARGIN;
                }

                if (left < MARGIN) {
                    left = MARGIN;
                }

                top = Math.max(MARGIN, Math.min(top, viewportH - measuredHeight - MARGIN));

                this.colVisPlacement = {
                    top,
                    left,
                    width: panelWidth,
                    maxHeight
                };

                panel.style.cssText = this.colVisPanelStyle();
            },

            // Row selection helpers
            getSelectedRows() {
                const ids = new Set(Array.from(this.selectedKeys || []).map(String));
                const hay =
                    (this.serverPaging ? (Array.isArray(this.rows) ? this.rows : []) :
                        (Array.isArray(this.filteredRows) && this.filteredRows.length) ? this.filteredRows :
                            (Array.isArray(this.allRows) && this.allRows.length) ? this.allRows :
                                (Array.isArray(this.rows) ? this.rows : [])
                    );

                return hay.filter(r => ids.has(String(r?.[this.rowIdField])));
            },

            sfCompare(v, op, expected) {
                const vv = (v === null || v === undefined) ? "" : String(v);
                const ee = (expected === null || expected === undefined) ? "" : String(expected);
                switch (String(op || "eq").toLowerCase()) {
                    case "eq": return vv === ee;
                    case "neq": return vv !== ee;
                    case "contains": return vv.includes(ee);
                    case "startswith": return vv.startsWith(ee);
                    case "endswith": return vv.endsWith(ee);
                    case "in":
                        if (Array.isArray(expected)) return expected.map(String).includes(vv);
                        return ee.split(",").map(s => s.trim()).includes(vv);
                    case "notin":
                        if (Array.isArray(expected)) return !expected.map(String).includes(vv);
                        return !ee.split(",").map(s => s.trim()).includes(vv);
                    default:
                        return false;
                }
            },

            evalGuards(action) {
                const g = action?.guards || action?.Guards;
                if (!g) return { allowed: true, message: null };

                const appliesTo = String(g.appliesTo || g.AppliesTo || "any").toLowerCase();
                const rules = g.disableWhenAny || g.DisableWhenAny || [];
                if (!Array.isArray(rules) || rules.length === 0) return { allowed: true, message: null };

                const selectedRows = this.getSelectedRows();
                if (!selectedRows.length) return { allowed: true, message: null };

                const rowHits = (row) => rules.some(rule =>
                    this.sfCompare(
                        row?.[rule.field || rule.Field],
                        (rule.op || rule.Op || "eq"),
                        (rule.value ?? rule.Value)
                    )
                );

                const blocked = (appliesTo === "all") ? selectedRows.every(rowHits) : selectedRows.some(rowHits);
                if (!blocked) return { allowed: true, message: null };
                for (const row of selectedRows) {
                    for (const rule of rules) {
                        const field = rule.field || rule.Field;
                        const op = rule.op || rule.Op || "eq";
                        const val = rule.value ?? rule.Value;
                        if (this.sfCompare(row?.[field], op, val)) {
                            return { allowed: false, message: rule.message || rule.Message || "غير مسموح" };
                        }
                    }
                }

                return { allowed: false, message: "غير مسموح" };
            },

            // Data configuration
            clientSideMode: !!cfg.clientSideMode,
            headerColor: cfg.headerColor || "",
            initialRows: Array.isArray(cfg.rows) ? cfg.rows : [],

            selectable: !!cfg.selectable,
            rowIdField: cfg.rowIdField || "Id",
            singleSelect: !!cfg.singleSelect,
            // Cell utilities
            stripHtml(html) {
                const div = document.createElement('div');
                div.innerHTML = html ?? '';
                return (div.textContent || div.innerText || '').trim();
            },

            showCellCopied(cellEl, msg = "تم النسخ") {
                if (!cellEl) return;

                if (!window.__sfCellToastStyleAdded) {
                    window.__sfCellToastStyleAdded = true;
                    const st = document.createElement("style");
                    st.textContent = `
            .sf-cell-copied {
                position: fixed;
                padding: 6px 10px;
                border-radius: 4px;
                background: rgba(0,0,0,.9);
                color: #fff;
                font-size: 12px;
                line-height: 1;
                white-space: nowrap;
                overflow: hidden;
                text-overflow: ellipsis;
                max-width: 320px;
                z-index: 999999;
                pointer-events: none;
            }
        `;
                    document.head.appendChild(st);
                }

                document.querySelectorAll(".sf-cell-copied").forEach(x => x.remove());

                const rect = cellEl.getBoundingClientRect();

                const tip = document.createElement("div");
                tip.className = "sf-cell-copied";
                tip.textContent = msg;
                document.body.appendChild(tip);

                const tipRect = tip.getBoundingClientRect();
                const left = rect.left + (rect.width / 2) - (tipRect.width / 2);
                const gap = 2;
                const top = rect.top - tipRect.height - gap;

                const safeLeft = Math.max(8, Math.min(left, window.innerWidth - tipRect.width - 8));
                const safeTop = Math.max(8, top);

                tip.style.left = safeLeft + "px";
                tip.style.top = safeTop + "px";

                setTimeout(() => tip.remove(), 900);
            },

            async copyCell(row, col, e) {
                if (!this.enableCellCopy) return;

                const cellEl = e?.currentTarget || e?.target?.closest("td,th");

                try {
                    const html = this.formatCell(row, col);
                    const text = this.stripHtml(html);
                    if (!text) return;

                    if (navigator.clipboard?.writeText && window.isSecureContext) {
                        await navigator.clipboard.writeText(text);
                        this.showCellCopied(cellEl, "تم النسخ");
                        return;
                    }

                    if (navigator.clipboard?.write && typeof ClipboardItem !== "undefined") {
                        const blob = new Blob([text], { type: "text/plain" });
                        const item = new ClipboardItem({ "text/plain": blob });
                        await navigator.clipboard.write([item]);
                        this.showCellCopied(cellEl, "تم النسخ");
                        return;
                    }

                    this.showCellCopied(cellEl, "المتصفح يمنع النسخ");
                } catch (err) {
                    this.showCellCopied(cellEl, "فشل النسخ");
                }
            },

            // Toolbar and row actions
            groupBy: cfg.groupBy || null,
            storageKey: cfg.storageKey || null,

            toolbar: cfg.toolbar || {},
            normalizePlacement(value) {
                const p = String(value ?? "Button").trim().toLowerCase();
                if (p === "actionsmenu") return "actionsmenu";
                if (p === "rowend") return "rowend";
                if (p === "rowendmenu") return "rowendmenu";
                return "button";
            },
            tableHeaderStyle() {
                return this.headerColor ? "background-color:" + this.headerColor + ";" : "";
            },
            columnHeaderStyle(col) {
                return (col?.width ? "width:" + col.width + ";" : "") + this.tableHeaderStyle();
            },
            columnWidthStyle(col) {
                return col?.width ? "width:" + col.width + ";" : "";
            },
            rowActionsHeaderStyle() {
                return this.headerColor ? "background-color:" + this.headerColor + ";color:#fff;" : "background:#0a7257;color:#fff;";
            },
            toolbarActionEntries() {
                if (this._toolbarActionCache) return this._toolbarActionCache;

                const tb = this.toolbar || {};
                const items = [
                    { action: tb.add, show: tb.showAdd, enable: tb.enableAdd ?? true },
                    { action: tb.add1, show: tb.showAdd1, enable: tb.enableAdd1 ?? true },
                    { action: tb.add2, show: tb.showAdd2, enable: tb.enableAdd2 ?? true },
                    { action: tb.edit, show: tb.showEdit, enable: tb.enableEdit ?? true },
                    { action: tb.edit1, show: tb.showEdit1, enable: tb.enableEdit1 ?? true },
                    { action: tb.edit2, show: tb.showEdit2, enable: tb.enableEdit2 ?? true },
                    { action: tb.delete, show: tb.showDelete, enable: tb.enableDelete ?? true },
                    { action: tb.delete1, show: tb.showDelete1, enable: tb.enableDelete1 ?? true },
                    { action: tb.delete2, show: tb.showDelete2, enable: tb.enableDelete2 ?? true },
                    { action: tb.print, show: tb.showPrint, enable: true },
                    { action: tb.print1, show: tb.showPrint1, enable: true },
                    { action: tb.print2, show: tb.showPrint2, enable: true },
                    { action: tb.print3, show: tb.showPrint3, enable: true }
                ].filter(x => x.action && x.show !== false);

                const custom = Array.isArray(tb.customActions) ? tb.customActions : [];
                custom.forEach(a => items.push({ action: a, show: true, enable: true }));

                this._toolbarActionCache = items;
                return this._toolbarActionCache;
            },
            toolbarButtonActions() {
                if (this._toolbarButtonActionCache) return this._toolbarButtonActionCache;
                this._toolbarButtonActionCache = this.toolbarActionEntries()
                    .filter(x => this.normalizePlacement(x.action.placement ?? x.action.Placement) === "button");
                return this._toolbarButtonActionCache;
            },
            toolbarMenuActions() {
                if (this._toolbarMenuActionCache) return this._toolbarMenuActionCache;
                this._toolbarMenuActionCache = this.toolbarActionEntries()
                    .filter(x => this.normalizePlacement(x.action.placement ?? x.action.Placement) === "actionsmenu");
                return this._toolbarMenuActionCache;
            },
            hasToolbarMenuActions() {
                return this.toolbarMenuActions().length > 0;
            },
            rowEndActionEntries() {
                if (this._rowEndActionCache) return this._rowEndActionCache;

                const toolbarItems = this.toolbarActionEntries();
                const inlineItems = (Array.isArray(this.actions) ? this.actions : []).map(a => ({
                    action: a,
                    show: (a?.show ?? a?.Show ?? true),
                    enable: true
                }));

                this._rowEndActionCache = [...toolbarItems, ...inlineItems]
                    .filter(x => x.action && x.show !== false);
                return this._rowEndActionCache;
            },
            rowEndActions() {
                if (this._rowEndButtonActionCache) return this._rowEndButtonActionCache;
                this._rowEndButtonActionCache = this.rowEndActionEntries()
                    .filter(x => this.normalizePlacement(x.action.placement ?? x.action.Placement) === "rowend");
                return this._rowEndButtonActionCache;
            },
            rowEndMenuActions() {
                if (this._rowEndMenuActionCache) return this._rowEndMenuActionCache;
                this._rowEndMenuActionCache = this.rowEndActionEntries()
                    .filter(x => this.normalizePlacement(x.action.placement ?? x.action.Placement) === "rowendmenu");
                return this._rowEndMenuActionCache;
            },
            hasRowEndActions() {
                return this.rowEndActions().length > 0 || this.rowEndMenuActions().length > 0;
            },
            menuPanelState(prefix = "menu-", estimatedHeight = 220) {
                return {
                    open: false,
                    menuId: prefix + Math.random().toString(36).slice(2),
                    panelStyle: "",
                    placePanel() {
                        if (!this.$refs?.btn) return;

                        const r = this.$refs.btn.getBoundingClientRect();
                        const panelW = 220;
                        const gap = 6;
                        let left = r.right - panelW;

                        if (left < 8) left = 8;
                        if (left + panelW > window.innerWidth - 8) {
                            left = window.innerWidth - panelW - 8;
                        }

                        let top = r.bottom + gap;
                        if (top + estimatedHeight > window.innerHeight - 8) {
                            top = Math.max(8, r.top - estimatedHeight - gap);
                        }

                        this.panelStyle = `position:fixed; top:${top}px; left:${left}px; width:${panelW}px; z-index:99999;`;
                        if (this.$refs?.panel) {
                            this.$refs.panel.style.cssText = this.panelStyle;
                        }
                    }
                };
            },
            activeMenuId: null,
            isMenuOpen(menuId) {
                return !!menuId && this.activeMenuId === menuId;
            },
            openOnlyMenu(menuId) {
                this.activeMenuId = menuId || null;
            },
            closeAllMenus() {
                this.activeMenuId = null;
            },
            closeRowMenusExcept(menuId) {
                const root = this.$el || document;
                const keepId = menuId || null;
                root.querySelectorAll(".sf-row-menu").forEach((el) => {
                    const data = el.__x?.$data;
                    if (!data) return;
                    const currentId = data.menuId || null;
                    if (currentId !== keepId) {
                        data.open = false;
                    }
                });
            },
            runRowAction(action, row) {
                const requireSelection = !!(action?.requireSelection ?? action?.RequireSelection);
                if (requireSelection && row && this.rowIdField) {
                    const rowId = row[this.rowIdField];
                    this.selectedKeys.clear();
                    if (rowId !== undefined && rowId !== null) {
                        this.selectedKeys.add(rowId);
                    }
                    this.selectAll = false;
                }

                return this.doAction(action, row || null);
            },

            // Runtime state
            q: "",
            page: 1,
            pages: 0,
            total: 0,
            rows: [],
            allRows: [],
            filteredRows: [],
            sort: { field: null, dir: "asc" },
            loading: false,
            error: null,
            activeIndex: -1,

            selectedKeys: new Set(),
            selectAll: false,
            modal: {
                open: false,
                title: "",
                message: "",
                messageClass: "",
                messageIcon: "",
                messageIsHtml: false,
                html: "",
                action: null,
                loading: false,
                error: null
            },

            // Style rules
            styleRules: Array.isArray(cfg.styleRules) ? cfg.styleRules : [],
            ruleValue(rule, key) {
                if (!rule || !key) return undefined;
                return rule[key] ?? rule[key[0].toUpperCase() + key.slice(1)];
            },
            ruleTarget(rule) {
                return String(this.ruleValue(rule, "target") || "cell").toLowerCase();
            },
            ruleField(rule) {
                return this.ruleValue(rule, "field");
            },
            getStyleRuleIndex() {
                if (this._styleRuleIndex && this._styleRuleSource === this.styleRules) return this._styleRuleIndex;

                const index = {
                    rowRules: [],
                    cellRulesByField: new Map(),
                    columnRulesByField: new Map(),
                    pillRulesByField: new Map()
                };

                const addToMap = (map, field, rule) => {
                    const key = String(field || "");
                    if (!key) return;
                    if (!map.has(key)) map.set(key, []);
                    map.get(key).push(rule);
                };

                for (const rule of (this.styleRules || [])) {
                    const target = this.ruleTarget(rule);
                    const field = this.ruleField(rule);

                    if (target === "row") {
                        index.rowRules.push(rule);
                    } else if (target === "column") {
                        addToMap(index.columnRulesByField, field, rule);
                    } else {
                        addToMap(index.cellRulesByField, field, rule);
                    }

                    const pillEnabled = this.ruleValue(rule, "pillEnabled");
                    if (pillEnabled === true || String(pillEnabled).toLowerCase() === "true") {
                        addToMap(index.pillRulesByField, this.ruleValue(rule, "pillField") || field, rule);
                    }
                }

                const sortRules = (items) => items.sort((a, b) => (this.ruleValue(a, "priority") || 0) - (this.ruleValue(b, "priority") || 0));
                sortRules(index.rowRules);
                index.cellRulesByField.forEach(sortRules);
                index.columnRulesByField.forEach(sortRules);
                index.pillRulesByField.forEach(sortRules);

                this._styleRuleSource = this.styleRules;
                this._styleRuleIndex = index;
                return index;
            },
            ruleMatches(rule, row, col) {
                const op = String(this.ruleValue(rule, "op") || "eq").toLowerCase();
                const val = this.ruleValue(rule, "value");
                const target = this.ruleTarget(rule);
                const field = this.ruleField(rule);
                const left = target === "row"
                    ? (field ? row?.[field] : "")
                    : row?.[col?.field];

                if (target === "row" && !field) return true;

                const l = left ?? "";
                const v = val ?? "";
                const ln = Number(l);
                const vn = Number(v);
                const bothNum = !Number.isNaN(ln) && !Number.isNaN(vn);

                switch (op) {
                    case "eq": return String(l) === String(v);
                    case "neq": return String(l) !== String(v);
                    case "gt": return bothNum ? ln > vn : String(l) > String(v);
                    case "gte": return bothNum ? ln >= vn : String(l) >= String(v);
                    case "lt": return bothNum ? ln < vn : String(l) < String(v);
                    case "lte": return bothNum ? ln <= vn : String(l) <= String(v);
                    case "contains": return String(l).includes(String(v));
                    case "startswith": return String(l).startsWith(String(v));
                    case "endswith": return String(l).endsWith(String(v));
                    case "in":
                        if (Array.isArray(val)) return val.map(String).includes(String(l));
                        return String(v).split(",").map(s => s.trim()).includes(String(l));
                    default:
                        return false;
                }
            },
            pillRuleMatches(rule, row) {
                const op = String(this.ruleValue(rule, "op") || "eq").toLowerCase();
                const val = this.ruleValue(rule, "value") ?? "";
                const field = this.ruleField(rule);
                const left = field ? (row?.[field] ?? "") : "";
                const ln = Number(left);
                const vn = Number(val);
                const bothNum = !Number.isNaN(ln) && !Number.isNaN(vn);

                switch (op) {
                    case "eq": return String(left) === String(val);
                    case "neq": return String(left) !== String(val);
                    case "gt": return bothNum ? ln > vn : String(left) > String(val);
                    case "gte": return bothNum ? ln >= vn : String(left) >= String(val);
                    case "lt": return bothNum ? ln < vn : String(left) < String(val);
                    case "lte": return bothNum ? ln <= vn : String(left) <= String(val);
                    case "contains": return String(left).includes(String(val));
                    case "startswith": return String(left).startsWith(String(val));
                    case "endswith": return String(left).endsWith(String(val));
                    case "in":
                        if (Array.isArray(this.ruleValue(rule, "value"))) {
                            return this.ruleValue(rule, "value").map(String).includes(String(left));
                        }
                        return String(val).split(",").map(s => s.trim()).includes(String(left));
                    default:
                        return false;
                }
            },

            applyStyleRules(row, col, target  ) {
                const normTarget = String(target || 'cell').toLowerCase();
                const field = String(col?.field || "");
                const index = this.getStyleRuleIndex();
                const rules = normTarget === "row"
                    ? index.rowRules
                    : [
                        ...(index.cellRulesByField.get(field) || []),
                        ...(index.columnRulesByField.get(field) || [])
                    ];

                let classes = [];
                for (const r of rules) {
                    const cssClass = this.ruleValue(r, "cssClass");
                    if (r && cssClass && this.ruleMatches(r, row, col)) {
                        classes.push(cssClass);
                        if (this.ruleValue(r, "stopOnMatch")) break;
                    }
                }
                return classes.join(" ");
            },

            getPillForCell(row, col) {
                const field = String(col?.field || "");
                const rules = this.getStyleRuleIndex().pillRulesByField.get(field) || [];

                for (const r of rules) {
                    if (!this.pillRuleMatches(r, row)) continue;

                    const text =
                        (this.ruleValue(r, "pillText") != null ? String(this.ruleValue(r, "pillText")) :
                            (this.ruleValue(r, "pillTextField") ? String(row?.[this.ruleValue(r, "pillTextField")] ?? "") : "")
                        ).trim();

                    if (!text) continue;

                    return {
                        text,
                        css: String(this.ruleValue(r, "pillCssClass") || "pill"),
                        mode: String(this.ruleValue(r, "pillMode") || "replace").toLowerCase()
                    };
                }
                return null;
            },
            cellPillRule(row, col) {
                const field = String(col?.field || "");
                if (!field) return null;

                if (row && typeof row === "object") {
                    if (!this._cellPillCache) this._cellPillCache = new WeakMap();
                    let rowCache = this._cellPillCache.get(row);
                    if (!rowCache) {
                        rowCache = new Map();
                        this._cellPillCache.set(row, rowCache);
                    }

                    if (rowCache.has(field)) return rowCache.get(field);

                    const match = (this.getStyleRuleIndex().pillRulesByField.get(field) || [])
                        .find(r => this.pillRuleMatches(r, row)) || null;
                    rowCache.set(field, match);
                    return match;
                }

                return (this.getStyleRuleIndex().pillRulesByField.get(field) || [])
                    .find(r => this.pillRuleMatches(r, row)) || null;
            },
            hasCellPill(row, col) {
                return !!this.cellPillRule(row, col);
            },
            isCellPillIconOnly(row, col) {
                return !!this.ruleValue(this.cellPillRule(row, col), "iconOnly");
            },
            cellPillClass(row, col) {
                const rule = this.cellPillRule(row, col);
                return this.ruleValue(rule, "iconOnly")
                    ? (this.ruleValue(rule, "iconOnlyCssClass") || "sf-icon-only")
                    : (this.ruleValue(rule, "pillCssClass") || "pill");
            },
            cellPillTitle(row, col) {
                const rule = this.cellPillRule(row, col);
                return this.ruleValue(rule, "pillTitle") || this.ruleValue(rule, "pillText") || "";
            },
            cellPillSvg(row, col) {
                return this.ruleValue(this.cellPillRule(row, col), "pillSvg") || "";
            },
            cellPillIcon(row, col) {
                return this.ruleValue(this.cellPillRule(row, col), "pillIcon") || "";
            },
            cellPillText(row, col) {
                const rule = this.cellPillRule(row, col);
                return this.ruleValue(rule, "pillText") || row?.[col?.field] || "";
            },

            escapeHtml(s) {
                return String(s ?? "")
                    .replace(/&/g, "&amp;")
                    .replace(/</g, "&lt;")
                    .replace(/>/g, "&gt;")
                    .replace(/"/g, "&quot;")
                    .replace(/'/g, "&#39;");
            },

            renderCellContent(row, col, baseHtml) {

                const safe = (baseHtml == null) ? "" : String(baseHtml);

                const pill = this.getPillForCell(row, col);
                if (!pill) return safe;

                const pillHtml = `<span class="${this.escapeHtml(pill.css)}">${this.escapeHtml(pill.text)}</span>`;

                if (pill.mode === "append") return `${safe} ${pillHtml}`;
                if (pill.mode === "prepend") return `${pillHtml} ${safe}`;
                return pillHtml;
            },
            bindArabicValidationMessages() {
                if (window.__sfArabicValidationBound) return;
                window.__sfArabicValidationBound = true;

                const messageFor = (el) => {
                    if (el.validity?.valueMissing) return "الرجاء تعبئة هذا الحقل";
                    if (el.validity?.typeMismatch) return "الرجاء إدخال قيمة صحيحة";
                    if (el.validity?.patternMismatch) return el.getAttribute("data-pattern-message") || "القيمة المدخلة غير مطابقة للصيغة المطلوبة";
                    if (el.validity?.tooShort) return "القيمة المدخلة أقصر من الحد المطلوب";
                    if (el.validity?.tooLong) return "القيمة المدخلة أطول من الحد المسموح";
                    if (el.validity?.rangeUnderflow) return "القيمة أقل من الحد المسموح";
                    if (el.validity?.rangeOverflow) return "القيمة أعلى من الحد المسموح";
                    return "الرجاء إدخال قيمة صحيحة";
                };

                const applyMessages = (form) => {
                    if (!form) return;

                    form.querySelectorAll("input, select, textarea").forEach((el) => {
                        el.setCustomValidity("");

                        if (!el.willValidate || el.checkValidity()) return;
                        el.setCustomValidity(messageFor(el));
                    });
                };

                document.addEventListener("invalid", (e) => {
                    const el = e.target;
                    if (!el?.closest?.(".sf-modal-form")) return;
                    el.setCustomValidity(messageFor(el));
                }, true);

                document.addEventListener("pointerdown", (e) => {
                    const btn = e.target?.closest?.('.sf-modal-form button[type="submit"], .sf-modal-form input[type="submit"]');
                    if (!btn) return;
                    applyMessages(btn.closest(".sf-modal-form"));
                }, true);

                document.addEventListener("submit", (e) => {
                    const form = e.target;
                    if (!form?.matches?.(".sf-modal-form")) return;
                    applyMessages(form);
                }, true);

                document.addEventListener("input", (e) => {
                    const el = e.target;
                    if (!el?.closest?.(".sf-modal-form")) return;
                    el.setCustomValidity("");
                }, true);

                document.addEventListener("change", (e) => {
                    const el = e.target;
                    if (!el?.closest?.(".sf-modal-form")) return;
                    el.setCustomValidity("");
                }, true);
            },

            // Lifecycle
            init() {
                this.colVisLoad();
                this.loadStoredPreferences();
                this.initColumnFilters();
                this.bindArabicValidationMessages();

                if (!this.__colVisEscBound) {
                    this.__colVisEscBound = true;

                    document.addEventListener("keydown", (e) => {
                        if (e.key === "Escape" && this.colVisOpen) {
                            this.closeColVis();
                        }
                    });
                }

                this.bindPrintListenerOnce();

                if (!this.enablePagination) {
                    this.page = 1;
                    this.pages = 1;
                    this.pageSize = (this.rows && this.rows.length)
                        ? this.rows.length
                        : this.pageSize;
                }

                this.load();
                this.setupEventListeners();

                this.$nextTick(() => {
                    if (this.filtersEnabled && this.filtersRow && this.showFilters) {
                        this.initFilterSelect2();
                    }
                });
            },

            // Preferences
            loadStoredPreferences() {
                if (!this.storageKey) return;
                try {
                    const stored = localStorage.getItem(this.storageKey);
                    if (stored) {
                        const prefs = JSON.parse(stored);
                        if (prefs.pageSize) this.pageSize = prefs.pageSize;
                        if (prefs.sort) this.sort = prefs.sort;

                        if (prefs.columnFilters && typeof prefs.columnFilters === "object") {
                            this.columnFilters = prefs.columnFilters;

                            for (const k of Object.keys(this.columnFilters)) {
                                const v = this.columnFilters[k];

                                if (v == null) { this.columnFilters[k] = ""; continue; }

                                if (typeof v === "string") {
                                    const s = v.trim();
                                    this.columnFilters[k] = (s === "فلترة..." || s === "فلترة…") ? "" : s;
                                    continue;
                                }

                                if (typeof v === "number" || typeof v === "boolean") {
                                    this.columnFilters[k] = String(v);
                                    continue;
                                }

                                this.columnFilters[k] = "";
                            }
                        }

                        this.initColumnFilters();

                        if (this.columnFilters && typeof this.columnFilters === "object") {
                            for (const k of Object.keys(this.columnFilters)) {
                                const v = this.columnFilters[k];
                                const s = (v == null) ? "" : String(v).trim();
                                if (!s || s === "فلترة..." || s === "فلترة…") this.columnFilters[k] = "";
                            }
                        }

                        if (prefs.columns && Array.isArray(this.columns)) {
                            this.columns.forEach(col => {
                                const storedCol = prefs.columns.find(c => c.field === col.field);
                                if (storedCol && storedCol.visible !== undefined) {
                                    col.visible = storedCol.visible;
                                }
                            });
                            this.invalidateColumnCache();
                        }
                    }
                } catch (e) {
                }
            },
            savePreferences() {
                if (!this.storageKey) return;

                clearTimeout(this._savePreferencesTimer);
                this._savePreferencesTimer = setTimeout(() => {
                    this.persistPreferences();
                }, 150);
            },
            persistPreferences() {
                if (!this.storageKey) return;
                try {
                    const prefs = {
                        pageSize: this.pageSize,
                        sort: this.sort,

                        columnFilters: this.columnFilters || {},

                        columns: this.columns.map(col => ({
                            field: col.field,
                            visible: col.visible !== false
                        }))
                    };
                    localStorage.setItem(this.storageKey, JSON.stringify(prefs));
                } catch (e) {
                }
            },

            // Modal controls
            initSelect2InModal(modalEl) {
                if (!window.jQuery || !jQuery.fn || !jQuery.fn.select2) return;

                const $modal = jQuery(modalEl);
                const stripSelect2Title = ($select) => {
                    if (!$select || !$select.length) return;
                    const $container = $select.next(".select2");
                    $container.find(".select2-selection__rendered").removeAttr("title");
                    $container.find(".select2-selection").removeAttr("title");
                };
                $modal.find("select.js-select2").each(function () {
                    const $sel = jQuery(this);

                    $sel.off(".sfS2Bridge");

                    if ($sel.hasClass("select2-hidden-accessible")) {
                        $sel.select2("destroy");
                    }
                });

                $modal.find("select.js-select2").each(function () {
                    const $sel = jQuery(this);

                    const minResults = $sel.data("s2-min-results");
                    const ph =
                        $sel.data("s2-placeholder") ||
                        $sel.find('option[value=""]').text() ||
                        "الرجاء الاختيار";

                    $sel.select2({
                        width: "100%",
                        dir: "rtl",
                        dropdownParent: jQuery(document.body),
                        placeholder: ph,
                        allowClear: false,
                        minimumResultsForSearch:
                            (minResults === undefined || minResults === null) ? 0 : Number(minResults)
                    });

                    stripSelect2Title($sel);

                    $sel.on("select2:select.sfS2Bridge select2:clear.sfS2Bridge select2:unselect.sfS2Bridge", function (e) {
                        const el = this;
                        const value = $sel.val();
                        stripSelect2Title($sel);

                        queueMicrotask(() => {
                            el.dispatchEvent(new Event("input", { bubbles: true }));
                            el.dispatchEvent(new Event("change", { bubbles: true }));

                            el.dispatchEvent(new CustomEvent("sf:field-change", {
                                bubbles: true,
                                detail: {
                                    name: el.name || "",
                                    value: value,
                                    text: $sel.find("option:selected").text() || "",
                                    select2: true,
                                    originalEvent: e.type
                                }
                            }));
                        });
                    });
                });
            },

            // Event binding
            setupEventListeners() {

                if (window.__sfTableGlobalBound) return;
                window.__sfTableGlobalBound = true;

                document.addEventListener('keydown', (e) => {
                    if (e.key !== 'Escape') return;
                    const root = document.querySelector('[x-data*="sfTable"]');
                    if (root && root.__x?.$data?.modal?.open) root.__x.$data.closeModal();
                });

                document.addEventListener('click', (e) => {
                    const api = window.__sfTableActive;
                    if (!api || !api.modal?.open) return;

                    if (e.target.closest('.sf-modal-close,[data-modal-close],.sf-modal-cancel,.sf-modal-btn-cancel')) {
                        e.preventDefault();
                        api.closeModal();
                        return;
                    }

                });

                document.addEventListener('change', async (e) => {
                    const parentSelect = e.target.closest('select');
                    if (!parentSelect) return;

                    const parentName = parentSelect.name;
                    if (!parentName) return;

                    const form = parentSelect.closest('form');
                    if (!form) return;

                    const dependentSelects = form.querySelectorAll(`select[data-depends-on="${parentName}"]`);

                    for (const dependentSelect of dependentSelects) {
                        const dependsUrl = dependentSelect.getAttribute('data-depends-url');
                        if (!dependsUrl) continue;

                        const parentValue = parentSelect.value;

                        if (!parentValue || parentValue === '-1') {
                            dependentSelect.innerHTML = '<option value="-1">الرجاء الاختيار</option>';
                            continue;
                        }

                        const originalHtml = dependentSelect.innerHTML;
                        dependentSelect.innerHTML = '<option value="-1">جاري التحميل...</option>';
                        dependentSelect.disabled = true;

                        try {
                            const url = `${dependsUrl}${dependsUrl.includes('?') ? '&' : '?'}DDLValues=${encodeURIComponent(parentValue)}`;
                            const response = await fetch(url, { credentials: 'same-origin' });
                            if (!response.ok) throw new Error(`HTTP ${response.status}`);

                            const data = await response.json();

                            dependentSelect.innerHTML = '';
                            if (Array.isArray(data) && data.length > 0) {
                                for (const item of data) {
                                    const option = document.createElement('option');
                                    option.value = item.value;
                                    option.textContent = item.text;
                                    dependentSelect.appendChild(option);
                                }
                            } else {
                                dependentSelect.innerHTML = '<option value="-1">لا توجد خيارات متاحة</option>';
                            }

                            if (dependentSelect.classList.contains('js-select2')) {
                                const modalEl = dependentSelect.closest('.sf-modal') || document.body;

                                if (window.jQuery && jQuery.fn.select2) {
                                    const $sel = $(dependentSelect);

                                    if ($sel.hasClass('select2-hidden-accessible')) {
                                        $sel.select2('destroy');
                                    }

                                    this.initSelect2InModal(modalEl);
                                }
                            }

                        } catch (error) {
                            dependentSelect.innerHTML = originalHtml;
                        } finally {
                            dependentSelect.disabled = false;
                        }
                    }
                });
            },

            async load() {
                this.loading = true;
                this.error = null;
                try {

                    if (this.serverPaging) {
                        const body = {
                            Component: "Table",
                            SpName: this.spName,
                            Operation: this.operation,
                            Paging: { Page: this.page, Size: this.pageSize },
                            Params: {
                                q: this.q || null,
                                sortField: this.sort.field || null,
                                sortDir: this.sort.dir || "asc",
                                columnFilters: this.columnFilters || {}
                            }
                        };
                        const json = await this.postJson(this.endpoint, body);

                        this.rows = Array.isArray(json?.data) ? json.data : [];
                        this.invalidateRowCaches();

                        const total = json?.total ?? json?.count ?? json?.Total ?? json?.Count ?? null;

                        if (total == null) {
                            this.total = this.rows.length;
                            this.pages = 1;
                            this.page = 1;
                        } else {
                            this.total = Number(total) || 0;
                            this.pages = Math.max(1, Math.ceil(this.total / this.pageSize));
                            this.page = Math.min(this.page, this.pages);
                        }

                        this.allRows = [];
                        this.filteredRows = [];
                        this.invalidateRowCaches();

                        this.savePreferences();
                        this.updateSelectAllState();
                        return;
                    }

                    if (this.allRows.length === 0) {
                        if (this.clientSideMode && Array.isArray(this.initialRows) && this.initialRows.length > 0) {
                            this.allRows = this.initialRows;
                        } else {
                            const body = {
                                Component: "Table",
                                SpName: this.spName,
                                Operation: this.operation,
                                Paging: { Page: 1, Size: 1000000 }
                            };

                            const json = await this.postJson(this.endpoint, body);
                            this.allRows = Array.isArray(json?.data) ? json.data : [];
                        }
                        this.invalidateRowCaches();
                    }

                    this.applyFiltersAndSort();

                } catch (e) {
                    const msg = String(e?.message || "");
                    if (msg.includes("لايوجد بيانات")) {
                        this.rows = [];
                        this.allRows = [];
                        this.filteredRows = [];
                        this.invalidateRowCaches();
                        this.total = 0;
                        this.pages = 1;
                        this.page = 1;
                        this.error = null;
                        return;
                    }
                    this.error = msg || "خطأ في تحميل البيانات";
                } finally {
                    this.loading = false;
                }

            },

            // Data loading and filtering
            applyFiltersAndSort() {
                this.syncColumnFiltersFromDom();
                let filtered = [...this.allRows];

                if (this.q) {
                    const tokens = String(this.q)
                        .toLowerCase()
                        .trim()
                        .split(/\s+/)
                        .filter(Boolean);

                    const fields = this.visibleColumns()
                        .filter(c => c.field)
                        .map(c => c.field);
                    const fieldsKey = fields.join("\u001f");

                    if (tokens.length) {
                        filtered = filtered.filter(row => {
                            const haystack = this.getRowSearchText(row, fields, fieldsKey);
                            return tokens.every(t => haystack.includes(t));
                        });
                    }
                }

                if (this.filtersEnabled && this.hasActiveColumnFilters?.()) {
                    filtered = filtered.filter(row => this.rowPassesColumnFilters(row));
                }

                if (this.sort.field) {
                    filtered.sort((a, b) => {
                        let valA = a[this.sort.field];
                        let valB = b[this.sort.field];

                        if (valA == null && valB == null) return 0;
                        if (valA == null) return 1;
                        if (valB == null) return -1;

                        if (typeof valA === 'number' && typeof valB === 'number') {
                            return this.sort.dir === 'asc' ? valA - valB : valB - valA;
                        }

                        const dateA = new Date(valA);
                        const dateB = new Date(valB);
                        if (!isNaN(dateA) && !isNaN(dateB)) {
                            return this.sort.dir === 'asc' ? dateA - dateB : dateB - dateA;
                        }

                        valA = String(valA).toLowerCase();
                        valB = String(valB).toLowerCase();

                        if (this.sort.dir === 'asc') return valA < valB ? -1 : valA > valB ? 1 : 0;
                        return valA > valB ? -1 : valA < valB ? 1 : 0;
                    });
                }

                this.filteredRows = filtered;
                this.total = filtered.length;
                this.pages = Math.max(1, Math.ceil(this.total / this.pageSize));
                this.page = Math.min(this.page, this.pages);

                const startIdx = (this.page - 1) * this.pageSize;
                this.rows = filtered.slice(startIdx, startIdx + this.pageSize);

                this.savePreferences();
                this.updateSelectAllState();
            },
            getRowSearchText(row, fields, fieldsKey) {
                if (!row || typeof row !== "object") {
                    return fields.map(f => String(row?.[f] ?? "").toLowerCase()).join(" ");
                }

                if (!this._searchTextCache) this._searchTextCache = new WeakMap();

                const cached = this._searchTextCache.get(row);
                if (cached && cached.key === fieldsKey) return cached.text;

                const text = fields
                    .map(f => String(row?.[f] ?? "").toLowerCase())
                    .join(" ");

                this._searchTextCache.set(row, { key: fieldsKey, text });
                return text;
            },

            debouncedSearch() {
                clearTimeout(this.searchTimer);
                this.searchTimer = setTimeout(() => {
                    this.page = 1;
                    if (this.serverPaging) {
                        this.load();
                    } else {
                        this.applyFiltersAndSort();
                    }
                }, this.searchDelay);
            },

            refresh() {
                this.allRows = [];
                this.load();
            },

            // Column helpers
            visibleColumns() {
                if (this._visibleColumnsCache && this._visibleColumnsCacheVersion === this._columnsVersion) {
                    return this._visibleColumnsCache;
                }

                const cols = Array.isArray(this.columns) ? this.columns : [];
                this._visibleColumnsCache = cols.filter(c => this.colVisIsShown(c));
                this._visibleColumnsCacheVersion = this._columnsVersion;
                return this._visibleColumnsCache;
            },

            getColumnIndexByField(field) {
                return (this.columns || []).findIndex(c => String(c?.field || "") === String(field || ""));
            },

            onColumnDragStart(col, e) {
                if (!this.enableColumnReorder || !col?.field) return;

                this.dragColField = String(col.field);
                this.dragOverColField = null;
                this.draggingColField = String(col.field);

                try {
                    e?.stopPropagation?.();
                } catch { }

                if (e?.dataTransfer) {
                    e.dataTransfer.effectAllowed = "move";
                    e.dataTransfer.dropEffect = "move";
                    e.dataTransfer.setData("text/plain", String(col.field));
                }

                this.createDragGhost(e, col);
            },

            onColumnDragOver(col, e) {
                if (!this.enableColumnReorder || !this.dragColField || !col?.field) return;

                const overField = String(col.field);
                const dragField = String(this.dragColField);

                if (!overField || overField === dragField) return;

                e.preventDefault();

                try {
                    e?.stopPropagation?.();
                } catch { }

                this.dragOverColField = overField;

                if (e?.dataTransfer) {
                    e.dataTransfer.dropEffect = "move";
                }
            },

            onColumnDrop(targetCol, e) {
                if (!this.enableColumnReorder || !this.dragColField || !targetCol?.field) return;

                e.preventDefault();

                try {
                    e?.stopPropagation?.();
                } catch { }

                const fromField = String(this.dragColField || "");
                const toField = String(targetCol.field || "");

                if (!fromField || !toField || fromField === toField) {
                    this.dragColField = null;
                    this.dragOverColField = null;
                    this.draggingColField = null;
                    return;
                }

                const currentCols = Array.isArray(this.columns) ? [...this.columns] : [];
                const fromIndex = currentCols.findIndex(c => String(c?.field || "") === fromField);
                const toIndex = currentCols.findIndex(c => String(c?.field || "") === toField);

                if (fromIndex < 0 || toIndex < 0) {
                    this.dragColField = null;
                    this.dragOverColField = null;
                    this.draggingColField = null;
                    return;
                }

                const movedCol = currentCols[fromIndex];
                currentCols.splice(fromIndex, 1);
                currentCols.splice(toIndex, 0, movedCol);

                this.columns = [...currentCols];
                this.invalidateColumnCache();

                this.dragColField = null;
                this.dragOverColField = null;
                this.draggingColField = null;
                this.removeDragGhost();

                this.$nextTick(() => {
                    this.savePreferences?.();
                });
            },

            onColumnDragEnd() {
                this.dragColField = null;
                this.dragOverColField = null;
                this.draggingColField = null;
                this.removeDragGhost();
            },

            createDragGhost(e, col) {
                const field = String(col?.field || "");
                if (!field) return;

                const th = e.target.closest("th");
                if (!th) return;

                const label =
                    String(col?.label || col?.title || col?.header || col?.field || "").trim();

                const rect = th.getBoundingClientRect();
                const thStyle = window.getComputedStyle(th);
                const bgColor = thStyle.backgroundColor;
                const textColor = thStyle.color;
                const borderRadius = "6px";
                const ghost = document.createElement("div");
                ghost.className = "sf-col-ghost";
                ghost.style.position = "fixed";
                ghost.style.pointerEvents = "none";
                ghost.style.zIndex = "999999";
                ghost.style.left = rect.left + "px";
                ghost.style.top = rect.top + "px";
                ghost.style.background = "transparent";
                ghost.style.borderRadius = borderRadius;

                ghost.innerHTML = `
        <div class="sf-col-ghost__inner">
            <span class="sf-col-ghost__title">${this.escapeHtml(label)}</span>
        </div>
    `;

                const ghostInner = ghost.querySelector(".sf-col-ghost__inner");
                if (ghostInner) {
                    ghostInner.style.background = bgColor;
                    ghostInner.style.color = textColor;
                    ghostInner.style.borderRadius = borderRadius;
                    ghostInner.style.minWidth = rect.width + "px";
                    ghostInner.style.width = "max-content";
                    ghostInner.style.maxWidth = "none";
                }

                document.body.appendChild(ghost);

                this.ghostEl = ghost;
                this.ghostOffsetX = e.clientX - rect.left;
                this.ghostOffsetY = e.clientY - rect.top;

                if (e?.dataTransfer) {
                    const dragImg = document.createElement("div");
                    dragImg.style.position = "fixed";
                    dragImg.style.top = "-9999px";
                    dragImg.style.left = "-9999px";
                    dragImg.style.width = "1px";
                    dragImg.style.height = "1px";
                    dragImg.style.opacity = "0";
                    document.body.appendChild(dragImg);
                    e.dataTransfer.setDragImage(dragImg, 0, 0);

                    setTimeout(() => dragImg.remove(), 0);
                }

                this.boundGhostMove = (ev) => this.moveDragGhost(ev);
                document.addEventListener("dragover", this.boundGhostMove);
            },
            moveDragGhost(e) {
                if (!this.ghostEl) return;

                this.ghostEl.style.left = (e.clientX - this.ghostOffsetX) + 'px';
                this.ghostEl.style.top = (e.clientY - this.ghostOffsetY) + 'px';
            },

            removeDragGhost() {
                if (this.ghostEl) {
                    this.ghostEl.remove();
                    this.ghostEl = null;
                }

                if (this.boundGhostMove) {
                    document.removeEventListener('dragover', this.boundGhostMove);
                    this.boundGhostMove = null;
                }
            },

            toggleColumnVisibility(col) {
                col.visible = col.visible === false;
                this.invalidateColumnCache();
                this.savePreferences();
            },

            // Sorting and selection
            toggleSort(col) {
                if (!col.sortable) return;

                if (this.sort.field === col.field) {
                    this.sort.dir = this.sort.dir === "asc" ? "desc" : "asc";
                } else {
                    this.sort.field = col.field;
                    this.sort.dir = "asc";
                }

                this.page = 1;
                if (this.serverPaging) {
                    this.load();
                } else {
                    this.applyFiltersAndSort();
                }
            },

            toggleRow(row) {
                const key = row?.[this.rowIdField];
                if (key == null) return;

                if (this.singleSelect) {

                    if (this.selectedKeys.has(key)) {
                        this.selectedKeys.clear();
                    } else {
                        this.selectedKeys.clear();
                        this.selectedKeys.add(key);
                    }
                } else {

                    if (this.selectedKeys.has(key)) {
                        this.selectedKeys.delete(key);
                    } else {
                        this.selectedKeys.add(key);
                    }
                }
                this.updateSelectAllState();

            },

            toggleSelectAll() {
                if (this.singleSelect) {

                    if (this.selectAll && this.rows.length > 0) {
                        this.selectedKeys.clear();
                        this.selectedKeys.add(this.rows[0][this.rowIdField]);
                    } else {
                        this.selectedKeys.clear();
                    }
                } else {
                    if (this.selectAll) {
                        this.rows.forEach(row => this.selectedKeys.add(row[this.rowIdField]));
                    } else {
                        this.selectedKeys.clear();
                    }
                }
                this.updateSelectAllState();
            },

            updateSelectAllState() {
                if (this.singleSelect) {

                    const pageKeys = new Set(this.rows.map(r => r[this.rowIdField]));
                    const hasOnPage = Array.from(this.selectedKeys).some(k => pageKeys.has(k));
                    this.selectAll = hasOnPage && this.selectedKeys.size === 1;
                    return;
                }
                this.selectAll = this.rows.length > 0 &&
                    this.rows.every(row => this.selectedKeys.has(row[this.rowIdField]));
            },

            isSelected(row) {
                return this.selectedKeys.has(row[this.rowIdField]);
            },

            getSingleSelection() {
                if (this.selectedKeys.size === 1) {
                    const id = Array.from(this.selectedKeys)[0];
                    return this.allRows.find(row => row[this.rowIdField] === id);
                }
                return null;
            },

            clearSelection() {
                this.selectedKeys.clear();
                this.selectAll = false;
            },

            // Export actions
            exportData(type) {
                if (!this.allowExport) return;

                if (type === "pdf") {
                    this.openExportPdfModal();
                    return;
                }

                if (type === "excel") {
                    this.openExportExcelModal();
                    return;
                }

                this.showToast("نوع التصدير غير مدعوم", "error");
            },

            // Excel export modal
            openExportExcelModal() {
                if (!window.XLSX) {
                    this.showToast("مكتبة XLSX غير موجودة. أضف xlsx.full.min.js قبل sf-table.js", "error");
                    return;
                }

                const selectedRow = this.getSelectedRowFromCurrentData();
                if (!selectedRow) {
                    this.showToast("اختر صف واحد على الأقل قبل التصدير", "error");
                    return;
                }

                this.modal.open = true;
                window.__sfTableActive = this;
                this.modal.title = "تصدير Excel";
                this.modal.message = "";
                this.modal.messageClass = "";
                this.modal.messageIcon = "";
                this.modal.messageIsHtml = false;
                this.modal.loading = false;
                this.modal.error = null;
                const defaultCount = 1;

                window.toggleExportCount = function () {
                    const scope = document.getElementById("exportScope")?.value;
                    const countContainer = document.getElementById("countContainer");
                    if (!countContainer) return;
                    countContainer.style.display = (scope === "from_selected_count") ? "" : "none";
                };
                this.modal.html = `
                                <form id="sfExportExcelForm" class="sf-modal-form" onsubmit="return false;">
                                    <div class="grid grid-cols-12 gap-4">

                                        <div class="col-span-12 md:col-span-6">
                                            <label class="block text-sm font-medium mb-1">نطاق التصدير</label>
                                            <div class="sf-select-wrap">
                                                    <select
                                                        name="scope"
                                                        id="exportScope"
                                                        onchange="toggleExportCount()"
                                                        class="sf-modal-input"
                                                        required
                                                    >
                                                        <option value="all" selected>تصدير الكل</option>
                                                        <option value="from_selected_count">ابدأ من الصف المحدد وصدّر عدد</option>
                                                    </select>
                                                </div>
                                            <p class="mt-1 text-xs text-gray-500">
                                                "ابدأ من الصف المحدد" يعتمد على ترتيب البيانات الحالي (بحث/فرز/فلترة).
                                            </p>
                                        </div>

                                        <div class="col-span-12 md:col-span-6 flex items-center justify-start md:justify-end">
                                            <label class="flex items-center gap-2">
                                            <input type="checkbox" name="includeHeaders" checked class="sf-checkbox" />
                                            <span class="text-sm">تضمين العناوين (Header) كأول صف في Excel</span>
                                        </label>

                                        </div>

                                        <div class="col-span-12 md:col-span-6" id="countContainer" style="display: none;">
                                            <label class="block text-sm font-medium mb-1">عدد الصفوف</label>
                                            <input name="count" type="number" min="1" value="1" class="sf-modal-input" />
                                            <p class="mt-1 text-xs text-gray-500">مثال: 1 لتصدير صف واحد، أو 100 لتصدير 100 صف.</p>
                                        </div>

                                            <div class="col-span-12">
                                                <label class="block text-base font-medium mb-2">اختر الأعمدة المراد تصديرها :</label>
                                                <div class="grid grid-cols-2 gap-2" id="columnsCheckboxes">
                                                </div>
                                            </div>

<div class="col-span-12 flex justify-end gap-2 mt-4 sf-modal-actions">
                                            <button type="button" class="btn btn-success" data-export-excel-confirm>تصدير</button>
                                            <button type="button" class="btn btn-secondary sf-modal-cancel">إلغاء</button>
                                        </div>
                                    </div>
                                </form>

                                <script>
                                window.toggleExportCount = function () {
                                    const scope = document.getElementById("exportScope")?.value;
                                    const countContainer = document.getElementById("countContainer");
                                    if (!countContainer) return;
                                    countContainer.style.display = (scope === "from_selected_count") ? "" : "none";
                                };
                                </script>
                                `;

                this.$nextTick(() => {
                    const checkboxContainer = document.getElementById("columnsCheckboxes");
                    if (!checkboxContainer) return;

                    const visibleCols = this.visibleColumns().filter(c => c.showInExport !== false);
                    checkboxContainer.innerHTML = visibleCols.map((col, i) => `
                    <label class="flex items-center gap-2">
                        <input type="checkbox" name="exportCols" value="${col.field}" checked class="sf-checkbox" />
                        <span>${col.label || col.field}</span>
                    </label>
                    `).join("");
                });

                this.$nextTick(() => {

                    if (window.toggleExportCount) {
                        window.toggleExportCount();
                    }
                    const btn = document.querySelector('[data-export-excel-confirm]');
                    if (btn) {
                        btn.addEventListener('click', () => this.confirmExportExcelFromModal(), { once: true });
                    }
                    const modalEl =
                        document.querySelector('.sf-modal') ||
                        this.$el.querySelector('.sf-modal');
                    if (!modalEl) return;
                    this.enableModalDrag(modalEl);
                    this.enableModalResize(modalEl);
                    this.initSelect2InModal(modalEl);
                });
            },

            getSelectedRowFromCurrentData() {
                const ids = Array.from(this.selectedKeys || []);
                if (!ids.length) return null;

                const firstId = ids[0];

                const hay = (Array.isArray(this.filteredRows) && this.filteredRows.length) ? this.filteredRows
                    : (Array.isArray(this.allRows) && this.allRows.length) ? this.allRows
                        : (Array.isArray(this.rows) ? this.rows : []);

                return hay.find(r => String(r?.[this.rowIdField]) === String(firstId)) || null;
            },

            confirmExportExcelFromModal() {
                try {
                    const form = document.getElementById("sfExportExcelForm");
                    if (!form) return;

                    const fd = new FormData(form);
                    const scope = String(fd.get("scope") || "from_selected_count");
                    const count = Math.max(1, Number(fd.get("count") || 1));
                    const rtl = true;
                    const includeHeaders = fd.get("includeHeaders") === "on";
                    const exportVisibleOnly = true;

                    const dataView = (Array.isArray(this.filteredRows) && this.filteredRows.length)
                        ? this.filteredRows
                        : (Array.isArray(this.allRows) ? this.allRows : []);

                    if (!dataView.length && Array.isArray(this.rows)) {
                        dataView.push(...this.rows);
                    }

                    const selectedIds = new Set(Array.from(this.selectedKeys || []).map(String));
                    if (!selectedIds.size && scope !== "all") {
                        this.showToast("لا يوجد صف محدد", "error");
                        return;
                    }

                    let rowsToExport = [];

                    if (scope === "all") {
                        rowsToExport = dataView.slice();

                    } else if (scope === "from_selected_count") {
                        const startRow = this.getSelectedRowFromCurrentData();
                        if (!startRow) {
                            this.showToast("تعذر تحديد الصف المحدد كبداية", "error");
                            return;
                        }

                        const startIdx = dataView.findIndex(r => String(r?.[this.rowIdField]) === String(startRow?.[this.rowIdField]));
                        if (startIdx < 0) {
                            this.showToast("تعذر إيجاد الصف المحدد داخل البيانات الحالية", "error");
                            return;
                        }

                        const maxCount = dataView.length - startIdx;
                        const finalCount = Math.min(count, maxCount);

                        rowsToExport = dataView.slice(startIdx, startIdx + finalCount);
                    }

                    if (!rowsToExport.length) {
                        this.showToast("لا توجد بيانات للتصدير", "error");
                        return;
                    }

                    const selectedFields = Array.from(document.querySelectorAll("input[name=exportCols]:checked")).map(i => i.value);

                    const allCols = exportVisibleOnly
                        ? this.visibleColumns().filter(c => c.showInExport !== false)
                        : (this.columns || []).filter(c => c.field && c.showInExport !== false);

                    const cols = allCols.filter(c => selectedFields.includes(c.field));

                    if (!cols.length) {
                        this.showToast("لا توجد أعمدة للتصدير", "error");
                        return;
                    }

                    this.exportXlsx({ rows: rowsToExport, cols, includeHeaders, rtl });
                    this.closeModal();

                } catch (e) {
                    this.showToast("فشل التصدير: " + (e.message || e), "error");
                }
            },

            // Excel export writer
            exportXlsx({ rows, cols, includeHeaders, rtl }) {
                const aoa = [];

                if (includeHeaders) {
                    aoa.push(cols.map(c => c.label || c.field));
                }

                const forceText = col => {
                    const t = String(col.type || "").toLowerCase();
                    return ["phone", "tel", "nationalid", "nid", "identity"].includes(t);
                };

                rows.forEach(r => {
                    const rowArr = cols.map(c => {
                        let v = r?.[c.field];
                        if (v == null) return "";
                        const ct = String(c.type || "").toLowerCase();
                        if (["date", "datetime"].includes(ct)) {
                            try {
                                const d = new Date(v);
                                if (!Number.isNaN(d.getTime())) {
                                    return ct === "date"
                                        ? d.toISOString().slice(0, 10)
                                        : d.toISOString().replace("T", " ").slice(0, 19);
                                }
                            } catch { }
                            return String(v);
                        }
                        return (forceText(c) ? String(v) : v);
                    });
                    aoa.push(rowArr);
                });

                const ws = XLSX.utils.aoa_to_sheet(aoa);
                const range = XLSX.utils.decode_range(ws["!ref"] || "A1");
                for (let R = range.s.r; R <= range.e.r; ++R) {
                    for (let C = range.s.c; C <= range.e.c; ++C) {
                        const cellAddress = XLSX.utils.encode_cell({ r: R, c: C });
                        const cell = ws[cellAddress];
                        if (!cell) continue;
                        if (!cell.s) cell.s = {};
                        cell.s.alignment = { vertical: "center", horizontal: "center", wrapText: true };
                    }
                }

                const headerOffset = includeHeaders ? 1 : 0;
                cols.forEach((c, colIdx) => {
                    const t = String(c.type || "").toLowerCase();
                    if (["phone", "tel", "nationalid", "nid", "identity"].includes(t)) {
                        for (let r = 0; r < rows.length; r++) {
                            const cellAddress = XLSX.utils.encode_cell({ r: r + headerOffset, c: colIdx });
                            const cell = ws[cellAddress];
                            if (!cell) continue;
                            cell.t = "s";
                            cell.v = String(cell.v || "");
                        }
                    }
                });

                if (rtl) {
                    ws["!sheetViews"] = [{ rightToLeft: true, tabSelected: 1, workbookViewId: 0 }];
                    ws["!cols"] = cols.map((col, idx) => {
                        try {
                            const th = document.querySelector(`.sf-table thead tr th:nth-child(${idx + 1})`);
                            if (th) {
                                const rect = th.getBoundingClientRect();

                                const width = Math.ceil(rect.width);
                                return { wpx: width };
                            }
                        } catch (e) {
                        }
                        return { wpx: 150 };
                    });
                    ws["!direction"] = "rtl";
                }
                ws["!autofilter"] = {
                    ref: XLSX.utils.encode_range({
                        s: { c: 0, r: 0 },
                        e: { c: cols.length - 1, r: 0 }
                    })
                };
                const wb = XLSX.utils.book_new();
                XLSX.utils.book_append_sheet(wb, ws, "Export");
                XLSX.writeFile(wb, `export_${new Date().toISOString().slice(0, 10)}.xlsx`);
            },

            // PDF export modal
            openExportPdfModal() {
                const cfg = (this.toolbar && this.toolbar.exportConfig) ? this.toolbar.exportConfig : {};

                const enabled = (cfg.enablePdf ?? cfg.EnablePdf);
                if (enabled === false) {
                    this.showToast("PDF غير مفعل", "error");
                    return;
                }

                const selectedRow = this.getSelectedRowFromCurrentData();
                if (!selectedRow) {
                    this.showToast("اختر صف واحد على الأقل قبل التصدير", "error");
                    return;
                }

                this.modal.open = true;
                window.__sfTableActive = this;
                this.modal.title = "تصدير PDF";
                this.modal.message = "";
                this.modal.messageClass = "";
                this.modal.messageIcon = "";
                this.modal.messageIsHtml = false;
                this.modal.loading = false;
                this.modal.error = null;

                window.toggleExportCountPdf = function () {
                    const scope = document.getElementById("exportScopePdf")?.value;
                    const countContainer = document.getElementById("countContainerPdf");
                    if (!countContainer) return;
                    countContainer.style.display = (scope === "from_selected_count") ? "" : "none";
                };

                this.modal.html = `
                    <form id="sfExportPdfForm" class="sf-modal-form" onsubmit="return false;">
                        <div class="grid grid-cols-12 gap-4">

                            <div class="col-span-12 md:col-span-6">
                                <label class="block text-sm font-medium mb-1">نطاق التصدير</label>
                                <div class="sf-select-wrap">
                                    <select name="scope" id="exportScopePdf" onchange="toggleExportCountPdf()" class="sf-modal-input" required>
                                        <option value="all" selected>تصدير الكل</option>
                                        <option value="from_selected_count">ابدأ من الصف المحدد وصدّر عدد</option>
                                    </select>
                                </div>
                                <p class="mt-1 text-xs text-gray-500">
                                    "ابدأ من الصف المحدد" يعتمد على ترتيب البيانات الحالي (بحث/فرز/فلترة).
                                </p>
                            </div>

                            <div class="col-span-12 md:col-span-6" id="countContainerPdf" style="display:none;">
                                <label class="block text-sm font-medium mb-1">عدد الصفوف</label>
                                <input name="count" type="number" min="1" value="1" class="sf-modal-input" />
                                <p class="mt-1 text-xs text-gray-500">مثال: 1 لتصدير صف واحد، أو 100 لتصدير 100 صف.</p>
                            </div>

                            <div class="col-span-12">
                                <label class="block text-base font-medium mb-2">اختر الأعمدة المراد تصديرها :</label>
                                <div class="grid grid-cols-2 gap-2" id="columnsCheckboxesPdf"></div>
                            </div>

                            <div class="col-span-12 flex justify-end gap-2 mt-4 sf-modal-actions">
                                <button type="button" class="btn btn-danger" data-export-pdf-confirm>تصدير PDF</button>
                                <button type="button" class="btn btn-secondary sf-modal-cancel">إلغاء</button>
                            </div>
                        </div>
                    </form>
                    `;

                this.$nextTick(() => {
                    const checkboxContainer = document.getElementById("columnsCheckboxesPdf");
                    if (!checkboxContainer) return;

                    const visibleCols = this.visibleColumns().filter(c => c.showInExport !== false);
                    checkboxContainer.innerHTML = visibleCols.map(col => `
                        <label class="flex items-center gap-2">
                            <input type="checkbox" name="exportColsPdf" value="${col.field}" checked class="sf-checkbox" />
                            <span>${col.label || col.field}</span>
                        </label>
                    `).join("");

                    if (window.toggleExportCountPdf) window.toggleExportCountPdf();

                    const btn = document.querySelector('[data-export-pdf-confirm]');
                    if (btn) btn.addEventListener('click', () => this.confirmExportPdfFromModal(), { once: true });

                    const modalEl = document.querySelector('.sf-modal') || this.$el.querySelector('.sf-modal');
                    if (modalEl) {
                        this.enableModalDrag(modalEl);
                        this.enableModalResize(modalEl);
                        this.initSelect2InModal(modalEl);
                    }
                });
            },

            async confirmExportPdfFromModal() {
                const btn = document.querySelector('[data-export-pdf-confirm]');
                const originalText = btn ? btn.textContent : "تصدير PDF";

                try {
                    if (btn) {
                        btn.disabled = true;
                        btn.classList.add("opacity-60", "pointer-events-none");
                        btn.textContent = "جاري تجهيز الملف…";
                    }
                    this.modal.loading = true;
                    const cfg = (this.toolbar && this.toolbar.exportConfig) ? this.toolbar.exportConfig : {};
                    const endpoint = (cfg.pdfEndpoint ?? cfg.PdfEndpoint) || "/exports/pdf/table";
                    const form = document.getElementById("sfExportPdfForm");
                    if (!form) return;
                    const fd = new FormData(form);
                    const scope = String(fd.get("scope") || "all");
                    const count = Math.max(1, Number(fd.get("count") || 1));
                    const dataView = (Array.isArray(this.filteredRows) && this.filteredRows.length)
                        ? this.filteredRows
                        : (Array.isArray(this.allRows) ? this.allRows : []);
                    let rowsToExport = [];
                    if (scope === "all") {
                        rowsToExport = dataView.slice();
                    } else if (scope === "from_selected_count") {
                        const startRow = this.getSelectedRowFromCurrentData();
                        if (!startRow) {
                            this.showToast("تعذر تحديد الصف المحدد كبداية", "error");
                            return;
                        }
                        const startIdx = dataView.findIndex(r => String(r?.[this.rowIdField]) === String(startRow?.[this.rowIdField]));
                        if (startIdx < 0) {
                            this.showToast("تعذر إيجاد الصف المحدد داخل البيانات الحالية", "error");
                            return;
                        }

                        const maxCount = dataView.length - startIdx;
                        rowsToExport = dataView.slice(startIdx, startIdx + Math.min(count, maxCount));
                    }

                    if (!rowsToExport.length) {
                        this.showToast("لا توجد بيانات للتصدير", "error");
                        return;
                    }
                    const selectedFields = Array.from(document.querySelectorAll('input[name="exportColsPdf"]:checked'))
                        .map(i => i.value);

                    const allCols = this.visibleColumns().filter(c => c.showInExport !== false);
                    const cols = allCols.filter(c => selectedFields.includes(c.field));

                    if (!cols.length) {
                        this.showToast("لا توجد أعمدة للتصدير", "error");
                        return;
                    }
                    const colsRtl = cols.slice().reverse();
                    const payload = {
                        title: (cfg.pdfTitle ?? cfg.PdfTitle) || "تقرير",
                        logoUrl: (cfg.pdfLogoUrl ?? cfg.PdfLogoUrl) || null,
                        paper: (cfg.pdfPaper ?? cfg.PdfPaper) || "A4",
                        orientation: (cfg.pdfOrientation ?? cfg.PdfOrientation) || "portrait",
                        showSerial: (cfg.pdfShowSerial ?? cfg.PdfShowSerial) === true,
                        serialLabel: (cfg.pdfSerialLabel ?? cfg.PdfSerialLabel) || "#",
                        showPageNumbers: ((cfg.pdfShowPageNumbers ?? cfg.PdfShowPageNumbers) !== false),
                        showGeneratedAt: ((cfg.pdfShowGeneratedAt ?? cfg.PdfShowGeneratedAt) !== false),
                        showPageSizeSelector: cfg.showPageSizeSelector === true,
                        filename: (cfg.filename ?? cfg.Filename) || "export",
                        rightHeaderLine1: (cfg.rightHeaderLine1 ?? cfg.RightHeaderLine1) || "",
                        rightHeaderLine2: (cfg.rightHeaderLine2 ?? cfg.RightHeaderLine2) || "",
                        rightHeaderLine3: (cfg.rightHeaderLine3 ?? cfg.RightHeaderLine3) || "",
                        rightHeaderLine4: (cfg.rightHeaderLine4 ?? cfg.RightHeaderLine4) || "",
                        rightHeaderLine5: (cfg.rightHeaderLine5 ?? cfg.RightHeaderLine5) || "",

                        columns: colsRtl.map(c => ({ field: c.field, label: c.label || c.field })),
                        rows: rowsToExport
                    };

                    const blob = await this.postPdfBlob(endpoint, payload);
                    this.downloadBlob(blob, `${payload.filename}_${new Date().toISOString().slice(0, 10)}.pdf`);

                    this.closeModal();

                } catch (e) {
                    this.showToast("فشل تصدير PDF: " + (e.message || e), "error");

                } finally {

                    this.modal.loading = false;

                    if (btn) {
                        btn.disabled = false;
                        btn.classList.remove("opacity-60", "pointer-events-none");
                        btn.textContent = originalText;
                    }
                }
            },

            async postPdfBlob(url, body) {
                const headers = { "Content-Type": "application/json" };
                const csrfToken = this.getCsrfToken();
                if (csrfToken) headers["RequestVerificationToken"] = csrfToken;

                const resp = await fetch(url, {
                    method: "POST",
                    headers,
                    body: JSON.stringify(body)
                });

                if (!resp.ok) {
                    let msg = `HTTP ${resp.status}`;
                    try {
                        const j = await resp.json();
                        msg = j?.error || j?.message || msg;
                    } catch { }
                    throw new Error(msg);
                }

                return await resp.blob();
            },

            // Download helpers
            downloadBlob(blob, filename) {
                const url = URL.createObjectURL(blob);
                const a = document.createElement("a");
                a.href = url;
                a.download = filename;
                a.style.display = "none";
                document.body.appendChild(a);
                a.click();
                document.body.removeChild(a);
                URL.revokeObjectURL(url);
            },

            formatCellForExport(row, col) {
                let value = row[col.field];
                if (value == null) return "";

                switch (col.type) {
                    case "date":
                        return new Date(value).toLocaleDateString('ar-SA');
                    case "datetime":
                        return new Date(value).toLocaleString('ar-SA');
                    case "bool":
                        return value ? "نعم" : "لا";
                    case "money":
                        try {
                            return new Intl.NumberFormat('ar-SA', {
                                style: 'currency',
                                currency: 'SAR'
                            }).format(value);
                        } catch {
                            return value;
                        }
                    default:
                        return String(value);
                }
            },

            downloadFile(content, filename, mimeType) {
                const blob = new Blob([content], { type: mimeType });
                const url = URL.createObjectURL(blob);
                const a = document.createElement("a");
                a.href = url;
                a.download = filename;
                a.style.display = 'none';
                document.body.appendChild(a);
                a.click();
                document.body.removeChild(a);
                URL.revokeObjectURL(url);
            },

            async doAction(action, row) {
                if (!action) return;

                try {

                    const openModalFlag = !!(action.openModal ?? action.OpenModal);
                    const requireSelection = !!(action.requireSelection ?? action.RequireSelection);
                    const minSelection = Number(action.minSelection ?? action.MinSelection ?? 1) || 1;
                    const maxSelection = Number(action.maxSelection ?? action.MaxSelection ?? 0) || 0;

                    if (requireSelection) {
                        const selectedCount = this.selectedKeys?.size || 0;

                        if (selectedCount < minSelection) {
                            this.showToast(`يجب اختيار ${minSelection} عنصر على الأقل`, "error");
                            return;
                        }
                        if (maxSelection > 0 && selectedCount > maxSelection) {
                            this.showToast(`لا يمكن اختيار أكثر من ${maxSelection} عنصر`, "error");
                            return;
                        }

                        if (!row) row = this.getSelectedRowFromCurrentData?.() || null;
                    }

                    const guardRes = this.evalGuards?.(action) || { allowed: true };
                    if (!guardRes.allowed) {
                        this.showToast(guardRes.message || "غير مسموح", "error");
                        return;
                    }

                    const confirmText = action.confirmText ?? action.ConfirmText ?? "";
                    if (confirmText && !confirm(confirmText)) return;

                    const clickJs = action.onClickJs ?? action.OnClickJs ?? "";
                    if (clickJs && String(clickJs).trim()) {
                        try {
                            const code = String(clickJs).trim();

                            const isFnCallOrName = /^[a-zA-Z_$][\w$]*(\s*\(.*\))?$/.test(code);
                            if (isFnCallOrName) {
                                const fnName = code.split("(")[0].trim();
                                const fn = window?.[fnName];
                                if (typeof fn === "function") {
                                    fn(row || null, action, this);
                                    return;
                                }
                            }

                            const runner = new Function("row", "action", "table", code);
                            runner(row || null, action, this);
                            return;

                        } catch (err) {
                            this.showToast("فشل تنفيذ الأمر", "error");
                            return;
                        }
                    }

                    if (openModalFlag) {
                        const beforeJs = action.onBeforeOpenJs ?? action.OnBeforeOpenJs ?? "";
                        if (beforeJs && String(beforeJs).trim()) {
                            try {
                                const code = String(beforeJs).trim();
                                const runner = new Function("table", "act", "row", code);
                                runner(this, action, row || null);

                            } catch (err) {
                                this.showToast("فشل تجهيز المودال", "error");
                                return;
                            }
                        }

                        if (action.__cancelOpen) {
                            this.showToast("لا يوجد إجراء لاحق لهذه الحالة", "error");
                            return;
                        }

                        await this.openModal(action, row || null);
                        return;
                    }

                    const saveSp = action.saveSp ?? action.SaveSp ?? "";
                    if (saveSp) {
                        const op = action.saveOp ?? action.SaveOp ?? "execute";
                        const success = await this.executeSp?.(saveSp, op, row || null);
                        if (success && this.autoRefresh) {
                            this.clearSelection?.();
                            await this.refresh?.();
                        }
                        return;
                    }

                } catch (e) {
                    this.showToast("فشل في تنفيذ الإجراء: " + (e?.message || e), "error");
                }
            },

            async doBulkDelete() {
                if ((this.selectedKeys?.size || 0) === 0) {
                    this.showToast("لم يتم اختيار أي عناصر للحذف", "error");
                    return;
                }

                if (!confirm(`هل تريد حقاً حذف ${this.selectedKeys.size} عنصر؟`)) return;

                try {
                    const body = {
                        Component: "Table",
                        SpName: this.spName,
                        Operation: "bulk_delete",
                        Params: { ids: Array.from(this.selectedKeys) }
                    };

                    await this.postJson(this.endpoint, body);
                    this.showToast(`تم حذف ${this.selectedKeys.size} عنصر بنجاح`, "success");
                    this.clearSelection();
                    await this.refresh();

                } catch (e) {
                    this.showToast("فشل في الحذف: " + (e?.message || e), "error");
                }
            },

            async openModal(action, row) {
                this.modal.open = true;
                window.__sfTableActive = this;

                this.modal.title = action.modalTitle ?? action.ModalTitle ?? action.label ?? action.Label ?? "";
                this.modal.message = action.modalMessage ?? action.ModalMessage ?? "";
                this.modal.messageClass = action.modalMessageClass ?? action.ModalMessageClass ?? "";
                this.modal.messageIcon = action.modalMessageIcon ?? action.ModalMessageIcon ?? "";
                this.modal.messageIsHtml = !!(action.modalMessageIsHtml ?? action.ModalMessageIsHtml);

                this.modal.action = action;
                this.modal.loading = true;
                this.modal.error = null;
                this.modal.html = "";

                this.modal.extraPage = Number(this.modal.extraPage || 1) || 1;
                this.modal.extraQuery = String(this.modal.extraQuery || "");
                this.modal.extraSort = this.modal.extraSort || null;

                this.modal.__extraStateMap = this.modal.__extraStateMap || Object.create(null);

                const getState = (slotKey) => {
                    if (!this.modal.__extraStateMap[slotKey]) {
                        this.modal.__extraStateMap[slotKey] = {
                            page: 1,
                            query: "",
                            sort: null,
                            cache: []
                        };
                    }
                    return this.modal.__extraStateMap[slotKey];
                };

                const esc = (v) => {
                    if (v == null) return "";
                    return String(v)
                        .replaceAll("&", "&amp;")
                        .replaceAll("<", "&lt;")
                        .replaceAll(">", "&gt;")
                        .replaceAll('"', "&quot;")
                        .replaceAll("'", "&#39;");
                };

                const toBool = (v, def = true) => {
                    if (v === true || v === false) return v;
                    if (v == null) return def;
                    const s = String(v).trim().toLowerCase();
                    if (["0", "false", "no", "off"].includes(s)) return false;
                    if (["1", "true", "yes", "on"].includes(s)) return true;
                    return def;
                };

                const applyToggleFieldVisibility = (meta, rows = []) => {
                    const modalRoot =
                        document.querySelector(".sf-modal") ||
                        this.$el?.querySelector?.(".sf-modal");

                    if (!meta || !modalRoot) return;

                    const toggleField = meta.toggleField ?? meta.ToggleField;
                    if (!toggleField) return;

                    const toggleDefaultHidden = (meta.toggleDefaultHidden ?? meta.ToggleDefaultHidden) === true;
                    const toggleRequiredWhenShown = (meta.toggleRequiredWhenShown ?? meta.ToggleRequiredWhenShown) === true;

                    const toggleColumn = meta.toggleColumn ?? meta.ToggleColumn;
                    const toggleOperator = String(meta.toggleOperator ?? meta.ToggleOperator ?? "=").trim();
                    const toggleValue = meta.toggleValue ?? meta.ToggleValue;
                    const toggleCompareColumn = meta.toggleCompareColumn ?? meta.ToggleCompareColumn;

                    const field = modalRoot.querySelector(`[name="${toggleField}"]`);
                    if (!field) {
                        return;
                    }

                    const wrapper = field.closest(".form-group");
                    if (!wrapper) {
                        return;
                    }

                    if (!rows || !rows.length || !toggleColumn) {
                        wrapper.style.display = toggleDefaultHidden ? "none" : "";

                        if (toggleRequiredWhenShown) {
                            if (toggleDefaultHidden) field.removeAttribute("required");
                            else field.setAttribute("required", "required");
                        }

                        if (toggleDefaultHidden) {
                            if (field.type === "checkbox") field.checked = false;
                            else field.value = "";
                        }

                        return;
                    }

                    const r = rows[0] || {};

                    const leftRaw = r?.[toggleColumn];
                    const rightRaw = toggleCompareColumn
                        ? r?.[toggleCompareColumn]
                        : toggleValue;

                    const leftNum = Number(leftRaw);
                    const rightNum = Number(rightRaw);

                    const bothNumeric =
                        !Number.isNaN(leftNum) && String(leftRaw ?? "").trim() !== "" &&
                        !Number.isNaN(rightNum) && String(rightRaw ?? "").trim() !== "";

                    const left = bothNumeric ? leftNum : String(leftRaw ?? "").trim();
                    const right = bothNumeric ? rightNum : String(rightRaw ?? "").trim();

                    let show = false;

                    switch (toggleOperator) {
                        case ">": show = left > right; break;
                        case "<": show = left < right; break;
                        case ">=": show = left >= right; break;
                        case "<=": show = left <= right; break;
                        case "!=":
                        case "<>": show = left != right; break;
                        case "=":
                        case "==": show = left == right; break;
                        default: show = false; break;
                    }

                    wrapper.style.display = show ? "" : "none";

                    if (toggleRequiredWhenShown) {
                        if (show) {
                            field.setAttribute("required", "required");
                        } else {
                            field.removeAttribute("required");
                            if (field.type === "checkbox") field.checked = false;
                            else field.value = "";
                        }
                    }

                };

                this.applyToggleFieldVisibility = applyToggleFieldVisibility;

                this.__printExtraTable = (slotKey = "m1") => {
                    slotKey = String(slotKey || "m1");

                    const meta = this.__metaBySlot?.[slotKey] || {};
                    const st = this.modal.__extraStateMap?.[slotKey];
                    const rows = Array.isArray(st?.cache) ? st.cache : [];

                    if (!rows.length) {
                        this.showToast?.("لا توجد بيانات للطباعة", "error");
                        return;
                    }

                    const printFieldsRaw =
                        meta.printFields ??
                        meta.PrintFields ??
                        meta.visibleFields ??
                        meta.VisibleFields ??
                        [];

                    const printFields = Array.isArray(printFieldsRaw)
                        ? printFieldsRaw.map(x => String(x))
                        : [];

                    if (!printFields.length) {
                        this.showToast?.("لم يتم تعريف printFields في الميتا", "error");
                        return;
                    }

                    const headerMap =
                        meta.printHeaderMap ??
                        meta.PrintHeaderMap ??
                        meta.headerMap ??
                        meta.HeaderMap ??
                        {};

                    const title =
                        meta.printTitle ??
                        meta.PrintTitle ??
                        meta.extraTitle ??
                        meta.ExtraTitle ??
                        "طباعة البيانات";

                    const printOrientation = String(
                        meta.printOrientation ?? meta.PrintOrientation ?? "portrait"
                    ).trim().toLowerCase();

                    const orientation =
                        (printOrientation === "landscape" || printOrientation === "عرض")
                            ? "landscape"
                            : "portrait";

                    const showPageNumbers = (() => {
                        const v = meta.showPageNumbers ?? meta.ShowPageNumbers ?? false;
                        if (v === true || v === false) return v;
                        const s = String(v ?? "").trim().toLowerCase();
                        return ["1", "true", "yes", "on"].includes(s);
                    })();

                    const showPrintSerial = (() => {
                        const v = meta.showPrintSerial ?? meta.ShowPrintSerial ?? false;
                        if (v === true || v === false) return v;
                        const s = String(v ?? "").trim().toLowerCase();
                        return ["1", "true", "yes", "on"].includes(s);
                    })();

                    const serialLabel = String(
                        meta.printSerialLabel ?? meta.PrintSerialLabel ?? "م"
                    );

                    const cssHref = String(
                        meta.printCssHref ?? meta.PrintCssHref ?? "/css/site.css"
                    ).trim();

                    const escHtml = (v) => {
                        if (v == null) return "";
                        return String(v)
                            .replaceAll("&", "&amp;")
                            .replaceAll("<", "&lt;")
                            .replaceAll(">", "&gt;")
                            .replaceAll('"', "&quot;")
                            .replaceAll("'", "&#39;");
                    };

                    const formatValue = (val) => {
                        if (val == null || val === "") return "—";
                        return String(val);
                    };

                    const serialHead = showPrintSerial
                        ? `<th class="sf-print-th sf-print-th-serial">${escHtml(serialLabel)}</th>`
                        : "";

                    const ths = printFields
                        .map(f => {
                            const lbl = headerMap?.[f] ?? f;
                            return `<th class="sf-print-th">${escHtml(lbl)}</th>`;
                        })
                        .join("");

                    const trs = rows
                        .map((r, idx) => {
                            const lower = {};
                            Object.keys(r || {}).forEach(k => {
                                lower[String(k).toLowerCase()] = r[k];
                            });

                            const serialTd = showPrintSerial
                                ? `<td class="sf-print-td sf-print-td-serial">${idx + 1}</td>`
                                : "";

                            const tds = printFields
                                .map(f => {
                                    const val = r?.[f] ?? lower?.[String(f).toLowerCase()] ?? "";
                                    return `<td class="sf-print-td">${escHtml(formatValue(val))}</td>`;
                                })
                                .join("");

                            return `<tr class="sf-print-tr">${serialTd}${tds}</tr>`;
                        })
                        .join("");

                    const footerHtml = showPageNumbers
                        ? `
<div class="sf-print-footer">
    <span class="sf-print-page-num"></span>
</div>`
                        : "";

                    const html = `<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head>
    <meta charset="utf-8" />
    <title>${escHtml(title)}</title>
    <base href="${window.location.origin}/">
    <style>
        @page {
            size: A4 ${orientation};
            margin: 14mm 12mm 16mm 12mm;
        }
    </style>
    <link rel="stylesheet" href="${escHtml(cssHref)}" />
</head>
<body class="sf-print-body ${orientation === "landscape" ? "is-landscape" : "is-portrait"} ${showPageNumbers ? "has-page-numbers" : "no-page-numbers"} ${showPrintSerial ? "has-print-serial" : "no-print-serial"}">
    <div class="sf-print-wrap" data-orientation="${escHtml(orientation)}" data-page-numbers="${showPageNumbers ? "true" : "false"}">
        <div class="sf-print-header">
            <h1 class="sf-print-title">${escHtml(title)}</h1>
        </div>

        <div class="sf-print-meta">
            <div class="sf-print-date">${escHtml(new Date().toLocaleString("ar-SA"))}</div>
        </div>

        <div class="sf-print-table-box">
            <table class="sf-print-table">
                <thead class="sf-print-thead">
                    <tr class="sf-print-head-row">${serialHead}${ths}</tr>
                </thead>
                <tbody class="sf-print-tbody">
                    ${trs}
                </tbody>
            </table>
        </div>
    </div>

    ${footerHtml}
</body>
</html>`;

                    let frame = document.getElementById("sf-print-frame");
                    if (!frame) {
                        frame = document.createElement("iframe");
                        frame.id = "sf-print-frame";
                        frame.style.position = "fixed";
                        frame.style.right = "0";
                        frame.style.bottom = "0";
                        frame.style.width = "0";
                        frame.style.height = "0";
                        frame.style.border = "0";
                        frame.style.visibility = "hidden";
                        document.body.appendChild(frame);
                    }

                    const win = frame.contentWindow;
                    const doc = win.document;

                    doc.open();
                    doc.write(html);
                    doc.close();

                    const link = doc.querySelector('link[rel="stylesheet"]');
                    let printed = false;

                    const doPrint = () => {
                        if (printed) return;
                        printed = true;

                        setTimeout(() => {
                            win.focus();
                            win.print();

                            setTimeout(() => {
                                try {
                                    const l = doc.querySelector('link[rel="stylesheet"]');
                                    if (l) {
                                        l.onload = null;
                                        l.onerror = null;
                                    }
                                    doc.open();
                                    doc.write("");
                                    doc.close();
                                } catch (_) { }
                            }, 300);
                        }, 150);
                    };

                    if (link) {
                        link.onload = () => doPrint();

                        link.onerror = () => {
                            doPrint();
                        };

                        setTimeout(() => {
                            doPrint();
                        }, 1200);
                    } else {
                        doPrint();
                    }
                };

                const normalizeObjKeyLookup = (obj) => {
                    const map = {};
                    if (!obj || typeof obj !== "object") return map;
                    Object.keys(obj).forEach(k => { map[String(k).toLowerCase()] = obj[k]; });
                    return map;
                };

                const buildColumnsFromArray = (arr) => {
                    const colSet = new Set();
                    (arr || []).forEach(r => Object.keys(r || {}).forEach(k => colSet.add(k)));
                    return Array.from(colSet);
                };

                const resolveMetas = () => {
                    const isExtraMeta = (m) => {
                        if (!m || typeof m !== "object") return false;

                        return !!(
                            m.extraEndpoint ?? m.ExtraEndpoint ??
                            m.extraRequest ?? m.ExtraRequest ??
                            m.useRowExtra ?? m.UseRowExtra ??
                            m.lazyExtra ?? m.LazyExtra ??
                            m.extraSlotKey ?? m.ExtraSlotKey
                        );
                    };

                    const list = [
                        action.meta ?? action.Meta,
                        action.meta1 ?? action.Meta1,
                        action.meta2 ?? action.Meta2,
                        action.meta3 ?? action.Meta3,
                        action.meta4 ?? action.Meta4,
                        action.meta5 ?? action.Meta5
                    ].filter(isExtraMeta);

                    list.forEach((m, i) => {
                        if (!m.extraSlotKey && !m.ExtraSlotKey) m.extraSlotKey = `m${i + 1}`;

                        if (!m.extraTitle && !m.ExtraTitle) m.extraTitle = ``;
                    });

                    return list;
                };

                const resolveHeaderMap = (meta) => {
                    const hm = meta.headerMap ?? meta.HeaderMap ?? {};
                    const lower = {};
                    Object.keys(hm || {}).forEach(k => lower[String(k).toLowerCase()] = hm[k]);
                    return { raw: hm || {}, lower };
                };

                const resolveVisibleFields = (meta) => {
                    const vf = meta.visibleFields ?? meta.VisibleFields ?? null;
                    if (Array.isArray(vf) && vf.length) return vf.map(x => String(x));
                    return null;
                };

                const paginate = (items, page, pageSize) => {
                    const total = items.length;
                    const pages = Math.max(1, Math.ceil(total / pageSize));
                    const p = Math.min(Math.max(1, page), pages);
                    const start = (p - 1) * pageSize;
                    const slice = items.slice(start, start + pageSize);
                    return { page: p, pageSize, total, pages, slice, startIndex: start };
                };

                const renderPager = ({ page, pages, total }, slotKey = "m1") => {
                    if (pages <= 1) return "";

                    const maxBtns = 7;
                    let start = Math.max(1, page - Math.floor(maxBtns / 2));
                    let end = Math.min(pages, start + maxBtns - 1);
                    start = Math.max(1, end - maxBtns + 1);

                    const btn = (p, label, cls = "") => `
<button type="button"
        class="sf-extra-page-btn ${cls}"
        onclick="window.__sfTableActive?.__setExtraPage?.('${slotKey}', ${p})">
    ${label}
</button>`;

                    let btns = "";
                    btns += btn(Math.max(1, page - 1), "السابق", `sf-extra-page-btn--edge ${page <= 1 ? "is-disabled" : ""}`);
                    for (let p = start; p <= end; p++) {
                        btns += btn(p, p, `sf-extra-page-btn--num ${p === page ? "is-active" : ""}`);
                    }
                    btns += btn(Math.min(pages, page + 1), "التالي", `sf-extra-page-btn--edge ${page >= pages ? "is-disabled" : ""}`);

                    return `
<div class="sf-extra-pager">
    <div class="sf-extra-pager-info">
        <span class="sf-extra-pager-range">عدد السجلات: ${total}</span>
    </div>
    <div class="sf-extra-pager-nav">
        ${btns}
    </div>
    <div class="sf-extra-pager-info">
        <span class="sf-extra-pager-range">الصفحة: ${page} / ${pages}</span>
    </div>
</div>`;
                };

                const applyFilterSort = (data, cols, meta, stateOverride = null) => {
                    let out = Array.isArray(data) ? data.slice() : [];
                    const state = stateOverride ?? { page: 1, query: "", sort: null };

                    const enableSearch = toBool(meta.enableSearch ?? meta.EnableSearch, true);
                    const q = enableSearch ? String(state.query || "").trim().toLowerCase() : "";

                    if (q) {
                        out = out.filter(r => {
                            const lower = normalizeObjKeyLookup(r);
                            for (const k of cols) {
                                const lk = String(k).toLowerCase();
                                const val = (r?.[k] ?? lower?.[lk] ?? "");
                                if (val == null) continue;
                                if (String(val).toLowerCase().includes(q)) return true;
                            }
                            return false;
                        });
                    }

                    const sortable = (meta.sortable ?? meta.Sortable ?? true) !== false;
                    const sort = sortable ? (state.sort || null) : null;

                    if (sort && sort.key) {
                        const key = sort.key;
                        const dir = (sort.dir === "desc") ? -1 : 1;

                        out.sort((a, b) => {
                            const la = normalizeObjKeyLookup(a);
                            const lb = normalizeObjKeyLookup(b);
                            const av = (a?.[key] ?? la?.[String(key).toLowerCase()]);
                            const bv = (b?.[key] ?? lb?.[String(key).toLowerCase()]);

                            if (av == null && bv == null) return 0;
                            if (av == null) return 1;
                            if (bv == null) return -1;

                            const an = Number(av), bn = Number(bv);
                            const aNum = !Number.isNaN(an) && String(av).trim() !== "";
                            const bNum = !Number.isNaN(bn) && String(bv).trim() !== "";
                            if (aNum && bNum) return (an - bn) * dir;

                            return String(av).localeCompare(String(bv), "ar", { numeric: true, sensitivity: "base" }) * dir;
                        });
                    }

                    return out;
                };

                const resolveExtraUi = (meta) =>
                    String(meta.extraUi ?? meta.ExtraUi ?? "table").trim().toLowerCase();

                const resolveEmptyHtml = (meta) => {
                    const emptyHtml = meta.extraEmptyHtml ?? meta.ExtraEmptyHtml ?? null;
                    if (typeof emptyHtml === "string" && emptyHtml.trim()) return emptyHtml;

                    const emptyText = meta.emptyText ?? meta.EmptyText ?? "لا يوجد بيانات";
                    return `
<div class="p-6 text-center text-gray-500">
  <i class="fa-solid fa-table text-2xl mb-2 block opacity-60"></i>
  ${esc(emptyText)}
</div>`;
                };

                const renderSmartFormHtml = async (meta, row) => {
                    const formConfig = meta.extraFormConfig ?? meta.ExtraFormConfig ?? null;
                    if (!formConfig) return "";

                    const token =
                        document.querySelector('input[name="__RequestVerificationToken"]')?.value ||
                        document.querySelector('meta[name="RequestVerificationToken"]')?.content || "";

                    const resp = await fetch("/crud/renderform", {
                        method: "POST",
                        headers: {
                            "Content-Type": "application/json",
                            "X-Requested-With": "XMLHttpRequest",
                            ...(token ? { "RequestVerificationToken": token } : {})
                        },
                        body: JSON.stringify({ form: formConfig, row: row || {} })
                    });

                    return await resp.text();
                };

                const renderExtraUi = async (meta, rows, row) => {
                    const ui = resolveExtraUi(meta);

                    const tableHtml = (ui === "form")
                        ? ""
                        : (Array.isArray(rows) && rows.length ? renderExtraTable(rows, meta) : resolveEmptyHtml(meta));

                    const formHtml = (ui === "table")
                        ? ""
                        : await renderSmartFormHtml(meta, row);

                    if (ui === "form") return formHtml;
                    if (ui === "both") return formHtml + tableHtml;
                    return tableHtml;
                };

                const renderExtraTable = (extraArray, metaOverride = null, stateOverride = null, slotKeyOverride = "m1") => {
                    const meta = metaOverride ?? action.meta ?? action.Meta ?? {};
                    const slotKey = String(meta.extraSlotKey ?? meta.ExtraSlotKey ?? slotKeyOverride ?? "m1");

                    const state = stateOverride ?? {
                        page: 1,
                        query: "",
                        sort: null
                    };

                    const headerMap = resolveHeaderMap(meta);
                    const visibleFields = resolveVisibleFields(meta);

                    const pageSize = Number(meta.pageSize ?? meta.PageSize ?? 10) || 10;
                    const showRowNumbers = toBool(meta.showRowNumbers ?? meta.ShowRowNumbers, true);
                    const emptyText = meta.emptyText ?? meta.EmptyText ?? "لا توجد بيانات";
                    const enableSearch = (meta.enableSearch ?? meta.EnableSearch ?? true) !== false;
                    const sortable = (meta.sortable ?? meta.Sortable ?? true) !== false;
                    const showPrint = toBool(meta.showPrint ?? meta.ShowPrint, false);

                    let cols = buildColumnsFromArray(extraArray);

                    if (!cols.length) {
                        return `
<div class="sf-extra-wrap">
    <div class="sf-extra-empty text-center py-6 text-gray-500">
        <i class="fa-solid fa-table text-2xl mb-2 block opacity-60"></i>
        ${esc(emptyText)}
    </div>
</div>`;
                    }

                    if (visibleFields) {
                        const set = new Set(cols.map(c => String(c).toLowerCase()));
                        cols = visibleFields.filter(f => set.has(String(f).toLowerCase()));
                    }

                    if (!cols.length && extraArray.length) cols = Object.keys(extraArray[0] || {});

                    const filtered = applyFilterSort(extraArray, cols, meta, state);

                    const page = Number(state.page || 1) || 1;
                    const pg = paginate(filtered, page, pageSize);

                    const sortBtn = (key) => {
                        if (!sortable) return "";
                        const cur = state.sort;
                        const isCur = cur && String(cur.key).toLowerCase() === String(key).toLowerCase();
                        const dir = isCur ? (cur.dir === "asc" ? "desc" : "asc") : "asc";
                        const arrow = isCur ? (cur.dir === "asc" ? "▲" : "▼") : "";
                        return `
<button type="button" class="sf-extra-sort-btn"
        onclick="window.__sfTableActive?.__setExtraSort?.('${slotKey}','${esc(key)}','${dir}')">
    ${arrow}
</button>`;
                    };

                    const thead = cols.map(k => {
                        const lbl = headerMap.raw?.[k] ?? headerMap.lower?.[String(k).toLowerCase()] ?? k;
                        return `<th scope="col" class="sf-extra-th">${esc(lbl)} ${sortBtn(k)}</th>`;
                    }).join("");

                    const rowsHtml = pg.slice.map((r, idx) => {
                        const rowLower = normalizeObjKeyLookup(r);

                        const rowColorColumn = meta.rowColorColumn ?? meta.RowColorColumn;
                        const rowColorOperator = String(meta.rowColorOperator ?? meta.RowColorOperator ?? "=").trim();
                        const rowColorValue = meta.rowColorValue ?? meta.RowColorValue;
                        const rowColorCompareColumn = meta.rowColorCompareColumn ?? meta.RowColorCompareColumn;

                        const rowColorTrueStyle = meta.rowColorTrueStyle ?? meta.RowColorTrueStyle ?? "";
                        const rowColorFalseStyle = meta.rowColorFalseStyle ?? meta.RowColorFalseStyle ?? "";

                        let rowClass = "sf-extra-tr";
                        let rowStyle = "";

                        if (rowColorColumn && (rowColorTrueStyle || rowColorFalseStyle)) {
                            const leftRaw =
                                r?.[rowColorColumn] ??
                                rowLower?.[String(rowColorColumn).toLowerCase()] ??
                                null;

                            const rightRaw = rowColorCompareColumn
                                ? (
                                    r?.[rowColorCompareColumn] ??
                                    rowLower?.[String(rowColorCompareColumn).toLowerCase()] ??
                                    null
                                )
                                : rowColorValue;

                            const leftNum = Number(leftRaw);
                            const rightNum = Number(rightRaw);

                            const bothNumeric =
                                !Number.isNaN(leftNum) && String(leftRaw ?? "").trim() !== "" &&
                                !Number.isNaN(rightNum) && String(rightRaw ?? "").trim() !== "";

                            const left = bothNumeric ? leftNum : String(leftRaw ?? "").trim();
                            const right = bothNumeric ? rightNum : String(rightRaw ?? "").trim();

                            let ok = false;

                            switch (rowColorOperator) {
                                case ">": ok = left > right; break;
                                case "<": ok = left < right; break;
                                case ">=": ok = left >= right; break;
                                case "<=": ok = left <= right; break;
                                case "!=":
                                case "<>": ok = left != right; break;
                                case "=":
                                case "==": ok = left == right; break;
                                default: ok = false; break;
                            }

                            rowStyle = ok ? rowColorTrueStyle : rowColorFalseStyle;
                        }

                        const tds = cols.map(k => {
                            const lk = String(k).toLowerCase();
                            const val = (r?.[k] ?? rowLower?.[lk] ?? "");
                            const text = (val == null || val === "") ? "—" : String(val);
                            return `<td class="sf-extra-td" style="${esc(rowStyle || "")}" title="${esc(text)}">${esc(text)}</td>`;
                        }).join("");

                        const serial = showRowNumbers
                            ? `<td class="sf-extra-td sf-extra-serial" style="${esc(rowStyle || "")}">${pg.startIndex + idx + 1}</td>`
                            : "";

                        return `<tr class="${rowClass}" style="${esc(rowStyle || "")}">${serial}${tds}</tr>`;
                    }).join("");

                    const serialHead = showRowNumbers
                        ? `<th scope="col" class="sf-extra-th sf-extra-serial">م</th>`
                        : "";

                    const showMeta = toBool(meta.showMeta ?? meta.ShowMeta, true);

                    const infoHtml = "";

                    const searchBox = enableSearch ? `
<div class="sf-extra-search">

  <div class="sf-extra-search-tools">
    <input type="text"
           class="sf-extra-search-input"
           placeholder="بحث داخل البيانات..."
           value="${esc(state.query || "")}"
           oninput="window.__sfTableActive?.__setExtraQuery?.('${slotKey}', this.value)" />

    <button type="button"
            class="sf-extra-search-clear"
            onclick="window.__sfTableActive?.__setExtraQuery?.('${slotKey}', '')">
      مسح
    </button>
  </div>

  ${showPrint ? `
  <button type="button"
          class="sf-extra-print-btn"
          onclick="window.__sfTableActive?.__printExtraTable?.('${slotKey}')">
      <i class="fa fa-print"></i>
      طباعة
  </button>
  ` : ``}

</div>` : "";

                    return `
<div class="sf-extra-wrap">
  ${searchBox}

  <div class="sf-extra-scroll">
    <table class="sf-extra-table" dir="rtl">
      <thead>
        <tr>${serialHead}${thead}</tr>
      </thead>
      <tbody>
        ${rowsHtml || `
<tr>
    <td class="sf-extra-empty text-center py-6"
        colspan="${cols.length + (showRowNumbers ? 1 : 0)}">
        <div class="text-gray-500">
            <i class="fa-solid fa-table text-2xl mb-2 block opacity-60"></i>
            ${esc(emptyText)}
        </div>
    </td>
</tr>`}
      </tbody>
    </table>
  </div>

  ${infoHtml}
  ${renderPager(pg, slotKey)}
</div>`;
                };

                window.__sfTableActive.__renderExtraTable = renderExtraTable;

                this.renderExtraTable = renderExtraTable;

                const ensureExtraSlots = (modalEl, metas) => {
                    if (!modalEl) return;

                    const formEl = modalEl.querySelector("form");
                    if (!formEl) return;

                    let wrap = modalEl.querySelector(".sf-extra-multi-wrap");
                    if (!wrap) {
                        wrap = document.createElement("div");
                        wrap.className = "sf-extra-multi-wrap";
                        formEl.insertAdjacentElement("beforebegin", wrap);
                    } else {

                        wrap.querySelectorAll(".sf-extra-section").forEach(x => x.remove());
                    }

                    metas.forEach((meta) => {
                        const slotKey = String(meta.extraSlotKey ?? meta.ExtraSlotKey ?? "");
                        const title = String(meta.extraTitle ?? meta.ExtraTitle ?? "");

                        const sec = document.createElement("div");
                        sec.className = "sf-extra-section";
                        sec.setAttribute("data-slot", slotKey);

                        sec.innerHTML = `
  ${title ? `<div class="sf-extra-section-title" style="margin:8px 0;font-weight:500;text-align:center;">${esc(title)}</div>` : ""}
  <div class="sf-extra-section-body" id="sf-extra-${esc(slotKey)}"></div>
`;

                        wrap.appendChild(sec);
                    });
                };

                const injectExtraToSlot = (slotKey, html) => {
                    const el = document.getElementById(`sf-extra-${slotKey}`);
                    if (!el) return false;
                    el.innerHTML = html;
                    return true;
                };

                try {
                    const meta = action.meta ?? action.Meta ?? {};

                    this.__setExtraPage = (slotKey, p) => {
                        slotKey = String(slotKey || "m1");
                        const st = this.modal.__extraStateMap?.[slotKey];
                        if (!st) return;

                        st.page = Number(p) || 1;

                        if (Array.isArray(st.cache)) {
                            const html = window.__sfTableActive?.__renderExtraTable
                                ? window.__sfTableActive.__renderExtraTable(st.cache, this.__metaBySlot?.[slotKey], st, slotKey)
                                : `<div class="p-4 text-gray-500">تعذر رسم الجدول</div>`;

                            const el = document.getElementById(`sf-extra-${slotKey}`);
                            if (el) el.innerHTML = html;
                            this.$nextTick(() => this.initModalScripts?.());
                        }
                    };

                    this.__setExtraQuery = (slotKey, q) => {
                        slotKey = String(slotKey || "m1");
                        const st = this.modal.__extraStateMap?.[slotKey];
                        if (!st) return;

                        const el = document.getElementById(`sf-extra-${slotKey}`);
                        const active = document.activeElement;
                        const wasSearchInput =
                            active &&
                            active.classList &&
                            active.classList.contains("sf-extra-search-input");

                        const caretStart = wasSearchInput ? active.selectionStart : null;
                        const caretEnd = wasSearchInput ? active.selectionEnd : null;

                        st.query = String(q ?? "");
                        st.page = 1;

                        if (Array.isArray(st.cache)) {
                            const html = window.__sfTableActive?.__renderExtraTable
                                ? window.__sfTableActive.__renderExtraTable(st.cache, this.__metaBySlot?.[slotKey], st, slotKey)
                                : `<div class="p-4 text-gray-500">تعذر رسم الجدول</div>`;

                            if (el) el.innerHTML = html;

                            this.$nextTick(() => {
                                this.initModalScripts?.();

                                if (wasSearchInput && el) {
                                    const newInput = el.querySelector(".sf-extra-search-input");
                                    if (newInput) {
                                        newInput.focus();
                                        try {
                                            const pos = String(st.query || "").length;
                                            newInput.setSelectionRange(
                                                caretStart ?? pos,
                                                caretEnd ?? pos
                                            );
                                        } catch (_) { }
                                    }
                                }
                            });
                        }
                    };

                    this.__setExtraSort = (slotKey, key, dir) => {
                        slotKey = String(slotKey || "m1");
                        const st = this.modal.__extraStateMap?.[slotKey];
                        if (!st) return;

                        st.sort = { key: String(key || ""), dir: (dir === "desc" ? "desc" : "asc") };
                        st.page = 1;

                        if (Array.isArray(st.cache)) {
                            const html = window.__sfTableActive?.__renderExtraTable
                                ? window.__sfTableActive.__renderExtraTable(st.cache, this.__metaBySlot?.[slotKey], st, slotKey)
                                : `<div class="p-4 text-gray-500">تعذر رسم الجدول</div>`;

                            const el = document.getElementById(`sf-extra-${slotKey}`);
                            if (el) el.innerHTML = html;
                            this.$nextTick(() => this.initModalScripts?.());
                        }
                    };

                    if (action.__dynamicModal) {
                        const dyn = action.__dynamicModal;

                        const body = {
                            Component: "Table",
                            SpName: dyn.spName,
                            Operation: dyn.op || "select",
                            Params: dyn.params || {}
                        };

                        const json = await this.postJson(this.endpoint, body);

                        const html = (json && (json.html ?? json.Html)) || null;
                        const data = (json && (json.data ?? json.Data)) || null;

                        if (typeof html === "string" && html.trim()) {
                            this.modal.html = html;

                        } else if (Array.isArray(data)) {
                            if (!data.length) {
                                this.modal.html = `<div class="p-4 text-gray-500">لا توجد بيانات</div>`;
                            } else {
                                this.modal.extraPage = 1;
                                this.modal.extraQuery = "";
                                this.modal.extraSort = null;
                                this.modal.__extraCache = data;
                                this.modal.html = renderExtraTable(data);
                            }

                        } else if (data && typeof data === "object") {
                            const cols = Object.keys(data).map(k => ({ Field: k, Label: k, Type: "text", Visible: true }));
                            this.modal.html = this.formatDetailView(data, cols);

                        } else {
                            this.modal.html = `<div class="p-4 text-gray-500">لا توجد بيانات</div>`;
                        }
                    }

                    else if (action.formUrl ?? action.FormUrl) {
                        const url = this.fillUrl(action.formUrl ?? action.FormUrl, row);
                        const resp = await fetch(url);
                        if (!resp.ok) throw new Error(`Failed to load form: ${resp.status}`);
                        this.modal.html = await resp.text();
                    }

                    else if (action.openForm ?? action.OpenForm) {

                        const baseForm = action.openForm ?? action.OpenForm;
                        const meta = action.meta ?? action.Meta ?? {};

                        const formToRender = JSON.parse(JSON.stringify(baseForm));

                        const isDynamicFields = (meta.dynamicFieldsByRow ?? meta.DynamicFieldsByRow) === true;

                        if (!isDynamicFields || !row) {
                            this.modal.html = this.generateFormHtml(formToRender, row);
                        } else {
                            const targetField = String(meta.dynamicFieldsField ?? meta.DynamicFieldsField ?? "").trim();
                            const rawMap = meta.dynamicFieldsMap ?? meta.DynamicFieldsMap ?? null;
                            const defaultFields = meta.dynamicFieldsDefault ?? meta.DynamicFieldsDefault ?? null;

                            const rowValueRaw =
                                row?.[targetField] ??
                                row?.[String(targetField).toLowerCase()] ??
                                "";

                            const rowValueNormalized = String(rowValueRaw ?? "").trim().toLowerCase();

                            let selectedFields = null;

                            if (rawMap && typeof rawMap === "object") {
                                const normalizedMap = {};

                                Object.keys(rawMap).forEach(k => {
                                    normalizedMap[String(k).trim().toLowerCase()] = rawMap[k];
                                });

                                selectedFields = normalizedMap[rowValueNormalized] ?? null;
                            }

                            if (Array.isArray(selectedFields)) {
                                formToRender.fields = selectedFields;
                                formToRender.Fields = selectedFields;
                            } else if (Array.isArray(defaultFields)) {
                                formToRender.fields = defaultFields;
                                formToRender.Fields = defaultFields;
                            }

                            this.modal.html = this.generateFormHtml(formToRender, row);
                        }
                    }

                    else if (row) {
                        const columns = this.columns || this.table?.columns || this.$data?.columns || [];
                        this.modal.html = this.formatDetailView(row, columns);
                    }

                    else if (action.modalSp ?? action.ModalSp) {
                        const columns = this.columns || this.table?.columns || this.$data?.columns || [];
                        const meta2 = action.meta ?? action.Meta ?? {};
                        const idField = meta2.idField || "residentInfoID";
                        const paramName = meta2.paramName || "residentInfoID";

                        const idVal =
                            row?.[idField] ??
                            row?.p01 ??
                            row?.residentInfoID ??
                            row?.ResidentInfoID ??
                            null;

                        const params = {};
                        if (idVal != null && idVal !== "") params[paramName] = idVal;

                        const body = {
                            Component: "Table",
                            SpName: (action.modalSp ?? action.ModalSp),
                            Operation: (action.modalOp ?? action.ModalOp ?? "detail"),
                            Params: params
                        };

                        const json = await this.postJson(this.endpoint, body);
                        const html = (json && (json.html ?? json.Html)) || null;
                        const data = (json && (json.data ?? json.Data)) || null;

                        if (typeof html === "string" && html.trim()) {
                            this.modal.html = html;

                        } else if (Array.isArray(data)) {
                            if (!data.length) {
                                this.modal.html = `<div class="p-4 text-gray-500">لا توجد بيانات</div>`;
                            } else {
                                this.modal.extraPage = 1;
                                this.modal.extraQuery = "";
                                this.modal.extraSort = null;
                                this.modal.__extraCache = data;
                                this.modal.html = renderExtraTable(data);
                            }

                        } else if (data && typeof data === "object") {
                            const cols = Object.keys(data).map(k => ({ Field: k, Label: k, Type: "text", Visible: true }));
                            this.modal.html = this.formatDetailView(data, cols);

                        } else {
                            this.modal.html = `<div class="p-4 text-gray-500">لا توجد بيانات</div>`;
                        }
                    }

                    this.$nextTick(() => {
                        this.initModalScripts?.();

                        try {
                            const metas = resolveMetas();

                            const modalEl =
                                document.querySelector(".sf-modal") ||
                                this.$el?.querySelector?.(".sf-modal");

                            ensureExtraSlots(modalEl, metas);

                            this.__metaBySlot = Object.create(null);

                            metas.forEach((m) => {
                                const slotKey = String(m.extraSlotKey ?? m.ExtraSlotKey ?? "");
                                this.__metaBySlot[slotKey] = m;

                                getState(slotKey);

                                injectExtraToSlot(
                                    slotKey,
                                    `<div class="p-4 text-gray-500">اختر أولاً لعرض الجدول</div>`
                                );
                            });

                            metas.forEach((m) => this.bindExtraDepends(modalEl, m, action, row));

                        } catch (e) {
                        }

                        const modalEl =
                            document.querySelector(".sf-modal") ||
                            this.$el?.querySelector?.(".sf-modal");

                        if (!modalEl) return;

                        if (window.Alpine && typeof window.Alpine.initTree === "function") {
                            window.Alpine.initTree(modalEl);
                        }

                        const form = modalEl.querySelector("form");

                        const saveBtn =
                            form?.querySelector(".sf-modal-btn-save") ||
                            form?.querySelector('button[type="submit"]');

                        const setSaveEnabled = (enabled) => {
                            if (!saveBtn) return;
                            saveBtn.disabled = !enabled;
                            saveBtn.classList.toggle("opacity-60", !enabled);
                            saveBtn.classList.toggle("pointer-events-none", !enabled);
                        };

                        try {
                            const metas = resolveMetas();

                            metas.forEach(meta => {
                                const verifyFieldName = meta.verifyField ?? meta.VerifyField;
                                const verifyResetFields = meta.verifyResetFields ?? meta.VerifyResetFields ?? [];
                                const verifyRequiredMessage = meta.verifyRequiredMessage ?? meta.VerifyRequiredMessage ?? "يجب الضغط على زر التحقق أولاً قبل الحفظ";

                                if (!verifyFieldName || !form) return;

                                const verifyField = form.querySelector(`[name="${verifyFieldName}"]`);
                                if (!verifyField) return;

                                verifyField.value = "0";
                                setSaveEnabled(false);

                                (Array.isArray(verifyResetFields) ? verifyResetFields : []).forEach(fieldName => {
                                    const el = form.querySelector(`[name="${fieldName}"]`);
                                    if (!el || el.__verifyResetBound) return;

                                    el.__verifyResetBound = true;

                                    const resetVerify = () => {
                                        verifyField.value = "0";
                                        setSaveEnabled(false);
                                    };

                                    el.addEventListener("input", resetVerify);
                                    el.addEventListener("change", resetVerify);
                                });

                                if (!form.__verifySubmitBound) {
                                    form.__verifySubmitBound = true;

                                    form.addEventListener("submit", (e) => {
                                        const currentMetas = resolveMetas();

                                        for (const m of currentMetas) {
                                            const vfName = m.verifyField ?? m.VerifyField;
                                            const msg = m.verifyRequiredMessage ?? m.VerifyRequiredMessage ?? "يجب الضغط على زر التحقق أولاً قبل الحفظ";
                                            if (!vfName) continue;

                                            const vf = form.querySelector(`[name="${vfName}"]`);
                                            if (!vf) continue;

                                            if (String(vf.value ?? "0") !== "1") {
                                                e.preventDefault();
                                                e.stopPropagation();
                                                this.showToast?.(msg, "error");
                                                return false;
                                            }
                                        }
                                    }, true);
                                }
                            });
                        } catch (e) {
                        }

                        if (form && !form.__saveBound) {
                            form.__saveBound = true;

                            form.addEventListener("submit", (e) => {
                                const btn =
                                    form.querySelector(".sf-modal-btn-save") ||
                                    form.querySelector('button[type="submit"]');

                                if (!btn) return;
                                if (btn.__saving) return;

                                btn.__saving = true;
                                btn.__originalText = btn.textContent;

                                btn.disabled = true;
                                btn.classList.add("opacity-60", "pointer-events-none");
                                btn.textContent = "جاري الحفظ ..";

                                clearTimeout(btn.__restoreTimer);
                                btn.__restoreTimer = setTimeout(() => {
                                    if (this.modal?.open) {
                                        btn.disabled = false;
                                        btn.classList.remove("opacity-60", "pointer-events-none");
                                        btn.textContent = btn.__originalText || "حفظ";
                                        btn.__saving = false;
                                    }
                                }, 15000);
                            });

                            form.addEventListener("invalid", (e) => {
                                const btn =
                                    form.querySelector(".sf-modal-btn-save") ||
                                    form.querySelector('button[type="submit"]');

                                if (!btn) return;

                                clearTimeout(btn.__restoreTimer);
                                btn.disabled = false;
                                btn.classList.remove("opacity-60", "pointer-events-none");
                                btn.textContent = btn.__originalText || "حفظ";
                                btn.__saving = false;
                            }, true);
                        }

                        this.initDatePickers?.(modalEl);

                        (function () {
                            const modal = modalEl;
                            const header = modal?.querySelector?.(".sf-modal-header");
                            if (!modal || !header) return;
                            if (modal.__dragBound) return;
                            modal.__dragBound = true;

                            let isDragging = false;
                            let startX = 0;
                            let startY = 0;
                            let startLeft = 0;
                            let startTop = 0;

                            header.addEventListener("mousedown", function (e) {
                                if (e.target.closest(".sf-modal-close,[data-modal-close],button,a,input,select,textarea")) return;

                                e.preventDefault();
                                isDragging = true;

                                const rect = modal.getBoundingClientRect();
                                startX = e.clientX;
                                startY = e.clientY;
                                startLeft = rect.left;
                                startTop = rect.top;

                                modal.style.transform = "none";
                                modal.style.left = startLeft + "px";
                                modal.style.top = startTop + "px";

                                document.addEventListener("mousemove", onMouseMove);
                                document.addEventListener("mouseup", onMouseUp);
                            });

                            function onMouseMove(e) {
                                if (!isDragging) return;
                                const dx = e.clientX - startX;
                                const dy = e.clientY - startY;
                                modal.style.left = (startLeft + dx) + "px";
                                modal.style.top = (startTop + dy) + "px";
                            }

                            function onMouseUp() {
                                isDragging = false;
                                document.removeEventListener("mousemove", onMouseMove);
                                document.removeEventListener("mouseup", onMouseUp);
                            }
                        })();

                        this.enableModalResize?.(modalEl);
                        this.initSelect2InModal?.(modalEl);
                        try {
                            const metas = resolveMetas();
                            metas.forEach(m => this.applyToggleFieldVisibility?.(m, []));
                        } catch (e) {
                        }

                        const extraBtns = modalEl.querySelectorAll("[data-extra-trigger='1']");
                        if (extraBtns.length) {
                            try {
                                extraBtns.forEach(btn => {
                                    if (btn.__extraTriggerBound) return;
                                    btn.__extraTriggerBound = true;

                                    btn.addEventListener("click", async () => {
                                        const slotKey = String(btn.getAttribute("data-extra-slot") || "m2");
                                        const fieldName = String(btn.getAttribute("data-extra-field") || "");
                                        const meta = this.__metaBySlot?.[slotKey];

                                        if (!meta) {
                                            return;
                                        }

                                        const input = modalEl.querySelector(`[name="${fieldName}"]`);
                                        if (!input) {
                                            return;
                                        }

                                        const val = String(input.value ?? "").trim();
                                        if (!val || val === "-1" || val === "-99999") {
                                            const slotBody = modalEl.querySelector(`#sf-extra-${slotKey}`);
                                            if (slotBody) {
                                                slotBody.innerHTML = `<div class="p-4 text-red-500">يرجى تعبئة الحقل أولاً</div>`;
                                            }
                                            input.focus?.();
                                            return;
                                        }

                                        const req = meta.extraRequest ?? meta.ExtraRequest ?? {};
                                        const ctx = meta.ctx ?? meta.Ctx ?? {};
                                        const endpoint = meta.extraEndpoint ?? meta.ExtraEndpoint ?? "/crud/extradataload";
                                        const paramMap = meta.extraParamMap ?? meta.ExtraParamMap ?? {};
                                        const staticParams = meta.extraParams ?? meta.ExtraParams ?? null;

                                        const payload = {
                                            pageName_: req.pageName_,
                                            ActionType: req.ActionType,
                                            idaraID: Number(ctx.idaraID ?? 0) || null,
                                            entrydata: ctx.entrydata ?? null,
                                            hostname: ctx.hostname ?? null,
                                            tableIndex: (req.tableIndex ?? req.TableIndex) ?? null,
                                            parameters: {}
                                        };

                                        Object.keys(paramMap || {}).forEach(paramKey => {
                                            const field = String(paramMap[paramKey] ?? "").trim();
                                            if (!field) return;
                                            const el = modalEl.querySelector(`[name="${field}"]`);
                                            payload.parameters[paramKey] = el ? String(el.value ?? "").trim() : null;
                                        });

                                        if (staticParams && typeof staticParams === "object") {
                                            Object.keys(staticParams).forEach(k => {
                                                payload.parameters[k] = staticParams[k];
                                            });
                                        }

                                        const slotBody = modalEl.querySelector(`#sf-extra-${slotKey}`);
                                        if (slotBody) {
                                            slotBody.innerHTML = `<div class="p-4 text-gray-500">جاري التحقق...</div>`;
                                        }

                                        const token =
                                        document.querySelector('input[name="__RequestVerificationToken"]')?.value ||
                                        document.querySelector('meta[name="RequestVerificationToken"]')?.content || "";

                                        const resp = await fetch(endpoint, {
                                            method: "POST",
                                            headers: {
                                                "Content-Type": "application/json",
                                                "X-Requested-With": "XMLHttpRequest",
                                                ...(token ? { "RequestVerificationToken": token } : {})
                                            },
                                            body: JSON.stringify(payload)
                                        });

                                        const txt = await resp.text();
                                        let json = null;
                                        try { json = txt ? JSON.parse(txt) : null; }
                                        catch (e) { }

                                        const rows =
                                        (Array.isArray(json?.data) && json.data) ||
                                        (Array.isArray(json?.tables?.[0]?.rows) && json.tables[0].rows) ||
                                        (Array.isArray(json?.table?.rows) && json.table.rows) ||
                                        [];

                                        const verifyFieldName = meta.verifyField ?? meta.VerifyField;
                                        if (verifyFieldName) {
                                            const verifyField = modalEl.querySelector(`[name="${verifyFieldName}"]`);
                                            if (verifyField) {
                                                verifyField.value = "1";
                                                setSaveEnabled(true);
                                            }
                                        }

                                        const st = getState(slotKey);
                                        st.cache = rows;
                                        st.page = 1;
                                        st.query = "";
                                        st.sort = null;

                                        const html = renderExtraTable(rows, meta, st, slotKey);
                                        if (slotBody) slotBody.innerHTML = html;

                                        this.applyToggleFieldVisibility?.(meta, rows);

                                        if (window.Alpine && typeof window.Alpine.initTree === "function") {
                                            window.Alpine.initTree(slotBody);
                                        }
                                    });
                                });
                            } catch (e) {
                            }
                        }

                    });

                } catch (e) {
                    this.modal.error = e?.message || "فشل جلب البيانات";
                    this.modal.html = `<div class="p-4 text-red-600">${esc(this.modal.error)}</div>`;
                } finally {
                    this.modal.loading = false;
                }
            },

            // Dynamic field dependencies
            bindExtraDepends(modalEl, meta, action, row) {
                try {
                    if (!modalEl || !meta) return;

                    const esc = (v) => {
                        if (v == null) return "";
                        return String(v)
                            .replaceAll("&", "&amp;")
                            .replaceAll("<", "&lt;")
                            .replaceAll(">", "&gt;")
                            .replaceAll('"', "&quot;")
                            .replaceAll("'", "&#39;");
                    };

                    const get = (obj, k1, k2, def = null) => {
                        const v = obj?.[k1];
                        if (v !== undefined && v !== null) return v;
                        const v2 = obj?.[k2];
                        if (v2 !== undefined && v2 !== null) return v2;
                        return def;
                    };

                    const renderTableHtml = (rows, stateForRender = null) => {
                        const st = stateForRender || this.modal.__extraStateMap?.[slotKey] || {
                            page: 1,
                            query: "",
                            sort: null
                        };

                        if (typeof this.renderExtraTable === "function") {
                            return this.renderExtraTable(rows, meta, st, slotKey);
                        }

                        if (window.__sfTableActive && typeof window.__sfTableActive.__renderExtraTable === "function") {
                            return window.__sfTableActive.__renderExtraTable(rows, meta, st, slotKey);
                        }

                        if (Array.isArray(rows) && rows.length === 0) {
                            return `<div class="p-4 text-gray-500">لا يوجد بيانات</div>`;
                        }

                        return `<div class="p-4 text-gray-500">تعذر رسم الجدول (renderer غير موجود)</div>`;
                    };

                    const endpoint = get(meta, "extraEndpoint", "ExtraEndpoint", "/crud/extradataload");
                    const ctx = get(meta, "ctx", "Ctx", {}) || {};
                    const req = get(meta, "extraRequest", "ExtraRequest", {}) || {};

                    const dependsOn = get(meta, "extraDependsOn", "ExtraDependsOn", null);
                    const loadOnOpen = get(meta, "extraLoadOnOpen", "ExtraLoadOnOpen", false) === true;
                    const loadMode = String(get(meta, "extraLoadMode", "ExtraLoadMode", "change") || "change").toLowerCase();
                    const emptyBefore = get(meta, "extraEmptyTextBeforeSelect", "ExtraEmptyTextBeforeSelect", "اختر أولاً لعرض الجدول");

                    const slotKey = String(get(meta, "extraSlotKey", "ExtraSlotKey", "m1") || "m1");
                    const triggerField = String(get(meta, "extraTriggerField", "ExtraTriggerField", "") || "");
                    const slotBody = modalEl.querySelector(`#sf-extra-${slotKey}`);
                    if (!slotBody) {
                        return;
                    }

                    const uiMode = String(get(meta, "extraUi", "ExtraUi", "both") || "both").toLowerCase();

                    const singleParamName = get(meta, "extraParamName", "ExtraParamName", null);

                    const paramMap = get(meta, "extraParamMap", "ExtraParamMap", null);

                    const staticParams = get(meta, "extraParams", "ExtraParams", null);

                    if (!endpoint || !req?.pageName_ || !req?.ActionType) {
                        return;
                    }

                    const sel = dependsOn ? modalEl.querySelector(`[name="${dependsOn}"]`) : null;

                    const isDependsFlow = !!sel;

                    if (sel && sel.__sfExtraHandlerMap && sel.__sfExtraHandlerMap[slotKey]) {
                        sel.removeEventListener("change", sel.__sfExtraHandlerMap[slotKey]);
                        delete sel.__sfExtraHandlerMap[slotKey];
                    }

                    const triggerBtn = modalEl.querySelector(`[data-extra-trigger="1"][data-extra-slot="${slotKey}"]`);

                    if (triggerBtn && triggerBtn.__sfExtraClickHandler) {
                        triggerBtn.removeEventListener("click", triggerBtn.__sfExtraClickHandler);
                        triggerBtn.__sfExtraClickHandler = null;
                    }

                    const ensurePlaceholder = () => {
                        if (slotBody.querySelector(`[data-extra-placeholder="${slotKey}"]`)) return;

                        slotBody.innerHTML = `<div class="p-4 text-gray-500" data-extra-placeholder="${slotKey}">${esc(emptyBefore)}</div>`;
                    };

                    const showExtraSlot = (slotKey) => {
                        const sec = modalEl.querySelector(`.sf-extra-section[data-slot="${slotKey}"]`);
                        if (sec) sec.style.display = "";
                    };

                    const hideExtraSlot = (slotKey) => {
                        const sec = modalEl.querySelector(`.sf-extra-section[data-slot="${slotKey}"]`);
                        if (sec) sec.style.display = "none";
                    };

                    const setPlaceholderText = (text) => {
                        ensurePlaceholder();
                        const ph = slotBody.querySelector(`[data-extra-placeholder="${slotKey}"]`);

                        if (ph) ph.innerHTML = `<div style="text-align:center">${esc(text)}</div>`;
                    };

                    const buildPayload = (pickedVal) => {
                        const payload = {
                            pageName_: req.pageName_,
                            ActionType: req.ActionType,
                            idaraID: Number(ctx.idaraID ?? 0) || null,
                            entrydata: ctx.entrydata ?? null,
                            hostname: ctx.hostname ?? null,
                            tableIndex: (req.tableIndex ?? req.TableIndex) ?? null,
                            parameters: {}
                        };

                        if (staticParams && typeof staticParams === "object") {
                            Object.keys(staticParams).forEach(k => {
                                payload.parameters[k] = staticParams[k];
                            });
                        }

                        if (paramMap && typeof paramMap === "object") {
                            Object.keys(paramMap).forEach(paramKey => {
                                const fieldName = paramMap[paramKey];
                                const input = modalEl.querySelector(`[name="${fieldName}"]`);
                                const v = input ? String(input.value ?? "").trim() : "";
                                payload.parameters[paramKey] = v;
                            });
                        }

                        if ((!paramMap || typeof paramMap !== "object") && singleParamName) {
                            payload.parameters[singleParamName] = String(pickedVal ?? "").trim();
                        }

                        return payload;
                    };

                    const fetchRows = async (payload) => {
                        const token =
                            document.querySelector('input[name="__RequestVerificationToken"]')?.value ||
                            document.querySelector('meta[name="RequestVerificationToken"]')?.content || "";

                        const resp = await fetch(endpoint, {
                            method: "POST",
                            headers: {
                                "Content-Type": "application/json",
                                "X-Requested-With": "XMLHttpRequest",
                                ...(token ? { "RequestVerificationToken": token } : {})
                            },
                            body: JSON.stringify(payload)
                        });

                        const txt = await resp.text();
                        let json = null;
                        try { json = txt ? JSON.parse(txt) : null; } catch (e) {
                        }

                        const rows =
                            (Array.isArray(json?.data) && json.data) ||
                            (Array.isArray(json?.tables?.[0]?.rows) && json.tables[0].rows) ||
                            (Array.isArray(json?.table?.rows) && json.table.rows) ||
                            [];

                        return rows;
                    };

                    const renderRowsIntoModal = (rows) => {
                        const state = this.modal.__extraStateMap?.[slotKey] || null;
                        if (state) {
                            state.cache = Array.isArray(rows) ? rows : [];
                            state.page = 1;
                            state.query = "";
                            state.sort = null;
                        }

                        this.modal.__extraCache = Array.isArray(rows) ? rows : [];
                        this.modal.extraPage = 1;
                        this.modal.extraQuery = "";
                        this.modal.extraSort = null;

                        const tableHtml = renderTableHtml(this.modal.__extraCache, state);

                        slotBody.innerHTML = tableHtml;
                        showExtraSlot(slotKey);

                        if (window.Alpine && typeof window.Alpine.initTree === "function") {
                            window.Alpine.initTree(slotBody);
                        }
                    };

                    const loadTable = async (pickedVal) => {
                        const val = String(pickedVal ?? "").trim();

                        if (isDependsFlow) {
                            if (!val || val === "-1" || val === "-99999") {
                                this.modal.__extraCache = [];
                                hideExtraSlot(slotKey);
                                setPlaceholderText(emptyBefore);
                                return;
                            }
                        }

                        showExtraSlot(slotKey);
                        const payload = buildPayload(val);

                        setPlaceholderText("جاري تحميل الجدول...");

                        const rows = await fetchRows(payload);

                        renderRowsIntoModal(rows);
                        this.applyToggleFieldVisibility?.(meta, rows);
                    };

                    const triggerMode = String(get(meta, "extraTriggerMode", "ExtraTriggerMode", "") || "").toLowerCase();

                    if (triggerMode === "button") {
                        hideExtraSlot(slotKey);

                        const buttonFieldName = triggerField || dependsOn;
                        const triggerBtn = modalEl.querySelector(`[data-extra-trigger="1"][data-extra-slot="${slotKey}"]`);
                        const triggerInput = buttonFieldName
                            ? modalEl.querySelector(`[name="${buttonFieldName}"]`)
                            : null;

                        if (!triggerBtn) {
                            return;
                        }

                        const clickHandler = async () => {
                            const inputVal = triggerInput ? String(triggerInput.value ?? "").trim() : "";

                            if (!inputVal || inputVal === "-1" || inputVal === "-99999") {
                                showExtraSlot(slotKey);
                                setPlaceholderText(emptyBefore || "أدخل قيمة أولاً");
                                return;
                            }

                            showExtraSlot(slotKey);
                            await loadTable(inputVal);
                        };

                        triggerBtn.__sfExtraClickHandler = clickHandler;
                        triggerBtn.addEventListener("click", clickHandler);

                    } else if (isDependsFlow) {
                        const handler = async () => {
                            const currentVal = String(sel.value ?? "").trim();

                            if (!currentVal || currentVal === "-1" || currentVal === "-99999") {
                                hideExtraSlot(slotKey);
                                return;
                            }

                            showExtraSlot(slotKey);
                            await loadTable(currentVal);
                        };

                        sel.__sfExtraHandlerMap = sel.__sfExtraHandlerMap || Object.create(null);
                        sel.__sfExtraHandlerMap[slotKey] = handler;

                        sel.addEventListener("change", handler);

                        if (loadOnOpen) handler();
                        else hideExtraSlot(slotKey);

                    } else {
                        loadTable(null);
                    }

                } catch (e) {
                }
            },

            // Modal lifecycle
            closeModal() {

                if (this.__printHandle && typeof this.__printHandle.cancel === "function") {
                    this.__printHandle.cancel();
                    this.__printHandle = null;
                }
                if (window.__sfPrintSession?.active) window.__sfPrintSession.canceled = true;

                this.modal.open = false;
                this.modal.html = "";
                this.modal.action = null;
                this.modal.error = null;
                this.modal.message = "";
                this.modal.messageClass = "";
                this.modal.messageIcon = "";
                this.modal.messageIsHtml = false;

                this.modal.extraPage = 1;
                this.modal.extraQuery = "";
                this.modal.extraSort = null;
                this.modal.__extraCache = null;

                this.__setExtraPage = null;
                this.__setExtraQuery = null;
                this.__setExtraSort = null;

                if (window.__sfTableActive === this) window.__sfTableActive = null;
            },

            // Form rendering
            generateFormHtml(formConfig, rowData) {
                if (!formConfig) return "";

                const formId = formConfig.formId || "modalForm";
                const method = formConfig.method || "POST";
                const action = formConfig.actionUrl || "#";

                let html = `<form id="${formId}" method="${method}" action="${action}" class="sf-modal-form">`;
                html += `<div class="grid grid-cols-12 gap-4">`;

                (formConfig.fields || []).forEach(field => {
                    if (field.isHidden || field.type === "hidden") {
                        const value = rowData ? (rowData[field.name] || field.value || "") : (field.value || "");
                        const extraButtonText = field.extraButtonText ?? field.ExtraButtonText ?? "";
                        const extraButtonSlot = field.extraButtonSlot ?? field.ExtraButtonSlot ?? "";
                        const extraButtonClass = field.extraButtonClass ?? field.ExtraButtonClass ?? "btn btn-info";
                        const hasExtraButton = !!(extraButtonText && extraButtonSlot);
                        html += `<input type="hidden" name="${this.escapeHtml(field.name)}" value="${this.escapeHtml(value)}">`;
                    } else {
                        html += this.generateFieldHtml(field, rowData);
                    }
                });

                if (formConfig.buttons && formConfig.buttons.length > 0) {
                    html += `<div class="col-span-12 flex justify-end gap-2 mt-4">`;
                    formConfig.buttons.forEach(btn => {
                        if (btn.show !== false) {
                            const btnType = btn.type || "button";

                            const isCancel =
                                btn.isCancel === true ||
                                btn.role === 'cancel' ||
                                (btn.text && (
                                    btn.text === 'إلغاء' ||
                                    btn.text === 'الغاء' ||
                                    btn.text.toLowerCase() === 'cancel'
                                ));

                            const extraClasses = isCancel ? ' sf-modal-cancel' : '';
                            const btnClass = `btn btn-${btn.color || 'secondary'}${extraClasses}`;
                            const icon = btn.icon ? `<i class="${btn.icon}"></i> ` : "";

                            const onClick = (!isCancel && btn.type !== 'submit') ? (btn.onClickJs || "") : "";

                            html += `<button type="${btnType}" class="${btnClass}" ${onClick ? `onclick="${onClick}"` : ""}>${icon}${btn.text}</button>`;
                        }
                    });
                    html += `</div>`;
                } else {

                    html += `<div class="col-span-12 flex justify-end gap-2 mt-4 sf-modal-actions">`;

                    html += `<button type="submit" class="btn btn-success sf-modal-btn-save"><i class="fas fa-check"></i> تنفيذ</button>`;

                    html += `<button type="button" class="btn btn-secondary sf-modal-btn-cancel sf-modal-cancel">إلغاء</button>`;

                    html += `</div>`;

                }
                html += `</div></form>`;
                return html;
            },

            // Modal drag and resize
            enableModalDrag(modalEl) {
                if (!modalEl) return;
                const header = modalEl.querySelector('.sf-modal-header');
                if (!header) return;

                if (modalEl.__dragBound) return;
                modalEl.__dragBound = true;
                let isDragging = false;
                let startX = 0, startY = 0;
                let startLeft = 0, startTop = 0;
                const onMouseMove = (e) => {
                    if (!isDragging) return;
                    const dx = e.clientX - startX;
                    const dy = e.clientY - startY;
                    modalEl.style.left = (startLeft + dx) + 'px';
                    modalEl.style.top = (startTop + dy) + 'px';
                };

                const onMouseUp = () => {
                    isDragging = false;
                    document.removeEventListener('mousemove', onMouseMove);
                    document.removeEventListener('mouseup', onMouseUp);
                };

                header.addEventListener('mousedown', (e) => {

                    if (e.target.closest('.sf-modal-close,[data-modal-close],button,a,input,select,textarea')) return;
                    e.preventDefault();
                    isDragging = true;
                    const rect = modalEl.getBoundingClientRect();
                    startX = e.clientX;
                    startY = e.clientY;
                    startLeft = rect.left;
                    startTop = rect.top;

                    modalEl.style.transform = 'none';
                    modalEl.style.left = startLeft + 'px';
                    modalEl.style.top = startTop + 'px';
                    document.addEventListener('mousemove', onMouseMove);
                    document.addEventListener('mouseup', onMouseUp);
                });
            },

            enableModalResize(modalEl) {
                if (!modalEl) return;

                if (modalEl.__resizeBound) return;
                modalEl.__resizeBound = true;
                const computed = getComputedStyle(modalEl);
                if (computed.position === 'static') modalEl.style.position = 'fixed';
                const addHandle = (dir) => {
                    const h = document.createElement('div');
                    h.className = `sf-resize-handle sf-resize-${dir}`;
                    h.setAttribute('data-resize', dir);
                    modalEl.appendChild(h);
                    return h;
                };

                const dirs = ['n', 'e', 's', 'w', 'ne', 'nw', 'se', 'sw'];
                dirs.forEach(d => {
                    if (!modalEl.querySelector(`.sf-resize-handle[data-resize="${d}"]`)) {
                        addHandle(d);
                    }
                });

                const clamp = (v, min, max) => Math.max(min, Math.min(max, v));
                let isResizing = false;
                let dir = '';
                let startX = 0, startY = 0;
                let startW = 0, startH = 0;
                let startL = 0, startT = 0;
                const minW = parseInt(modalEl.getAttribute('data-min-w') || '520', 10);
                const minH = parseInt(modalEl.getAttribute('data-min-h') || '260', 10);
                const onMove = (e) => {
                    if (!isResizing) return;
                    const clientX = e.clientX ?? (e.touches && e.touches[0]?.clientX);
                    const clientY = e.clientY ?? (e.touches && e.touches[0]?.clientY);
                    if (clientX == null || clientY == null) return;
                    const dx = clientX - startX;
                    const dy = clientY - startY;
                    const vw = window.innerWidth;
                    const vh = window.innerHeight;
                    const maxW = vw - 32;
                    const maxH = vh - 32;
                    let newW = startW;
                    let newH = startH;
                    let newL = startL;
                    let newT = startT;

                    if (dir.includes('e')) newW = startW + dx;
                    if (dir.includes('w')) { newW = startW - dx; newL = startL + dx; }

                    if (dir.includes('s')) newH = startH + dy;
                    if (dir.includes('n')) { newH = startH - dy; newT = startT + dy; }

                    newW = clamp(newW, minW, maxW);
                    newH = clamp(newH, minH, maxH);

                    if (dir.includes('w')) newL = startL + (startW - newW);
                    if (dir.includes('n')) newT = startT + (startH - newH);

                    newL = clamp(newL, 16, vw - newW - 16);
                    newT = clamp(newT, 16, vh - newH - 16);

                    modalEl.style.transform = 'none';
                    modalEl.style.left = newL + 'px';
                    modalEl.style.top = newT + 'px';
                    modalEl.style.width = newW + 'px';
                    modalEl.style.height = newH + 'px';
                };
                const onUp = () => {
                    if (!isResizing) return;
                    isResizing = false;
                    document.removeEventListener('mousemove', onMove);
                    document.removeEventListener('mouseup', onUp);
                    document.removeEventListener('touchmove', onMove, { passive: false });
                    document.removeEventListener('touchend', onUp);
                };
                modalEl.addEventListener('mousedown', (e) => {
                    const h = e.target.closest('.sf-resize-handle');
                    if (!h) return;
                    e.preventDefault();
                    isResizing = true;
                    dir = h.getAttribute('data-resize') || '';
                    const rect = modalEl.getBoundingClientRect();
                    startX = e.clientX;
                    startY = e.clientY;
                    startW = rect.width;
                    startH = rect.height;
                    startL = rect.left;
                    startT = rect.top;
                    document.addEventListener('mousemove', onMove);
                    document.addEventListener('mouseup', onUp);
                });

                modalEl.addEventListener('touchstart', (e) => {
                    const h = e.target.closest('.sf-resize-handle');
                    if (!h) return;
                    e.preventDefault();
                    const t = e.touches[0];
                    if (!t) return;
                    isResizing = true;
                    dir = h.getAttribute('data-resize') || '';
                    const rect = modalEl.getBoundingClientRect();
                    startX = t.clientX;
                    startY = t.clientY;
                    startW = rect.width;
                    startH = rect.height;
                    startL = rect.left;
                    startT = rect.top;
                    document.addEventListener('touchmove', onMove, { passive: false });
                    document.addEventListener('touchend', onUp);
                }, { passive: false });
            },

            // Date picker setup
            initDatePickers(rootEl) {
                if (typeof flatpickr === "undefined") return;
                (rootEl || document)
                    .querySelectorAll("input.js-date")
                    .forEach(el => {
                        if (el._flatpickr) return;
                        flatpickr(el, {
                            locale: flatpickr.l10ns.ar,
                            dateFormat: "Y-m-d",
                            altInput: false,
                            defaultDate: null,
                            allowInput: true,
                            disableMobile: true
                        });
                    });
            },

            // Field rendering
            generateFieldHtml(field, rowData) {
                if (!field || !field.name) return "";
                const value = rowData
                    ? (rowData[field.name] || field.value || "")
                    : (field.value || "");
                const colCss = this.resolveColCss(field.colCss || "6");
                const required = (field.required ?? field.Required) ? "required" : "";
                const disabled = (field.disabled ?? field.Disabled) ? "disabled" : "";
                const readonly = (field.readonly ?? field.Readonly) ? "readonly" : "";
                const placeholder = field.placeholder
                    ? `placeholder="${this.escapeHtml(field.placeholder)}"`
                    : "";
                const maxLength = field.maxLength
                    ? `maxlength="${field.maxLength}"`
                    : "";
                const autocomplete = field.autocomplete
                    ? `autocomplete="${this.escapeHtml(field.autocomplete)}"`
                    : "";
                const spellcheck =
                    (field.spellcheck !== undefined && field.spellcheck !== null)
                        ? `spellcheck="${field.spellcheck ? "true" : "false"}"`
                        : "";
                const autocapitalize = field.autocapitalize
                    ? `autocapitalize="${this.escapeHtml(field.autocapitalize)}"`
                    : "";
                const autocorrect = field.autocorrect
                    ? `autocorrect="${this.escapeHtml(field.autocorrect)}"`
                    : "";
                const textMode = (field.textMode || "").toLowerCase();
                let oninput = "";
                let pattern = "";
                switch (textMode) {
                    case "arabic":
                        oninput = `oninput="this.value=this.value.replace(/[^\\u0600-\\u06FF\\s]/g,'')"`;
                        pattern = 'pattern="[\\u0600-\\u06FF\\s]+"';
                        break;

                    case "english":
                        oninput = `oninput="this.value=this.value.replace(/[^A-Za-z\\s]/g,'')"`;
                        pattern = 'pattern="[A-Za-z\\s]+"';
                        break;

                    case "numeric":
                        oninput = `oninput="this.value=this.value.replace(/[^0-9]/g,'')"`;
                        pattern = 'pattern="[0-9]+"';
                        break;

                    case "alphanumeric":
                        oninput = `oninput="this.value=this.value.replace(/[^A-Za-z0-9\\s]/g,'')"`;
                        pattern = 'pattern="[A-Za-z0-9\\s]+"';
                        break;

                    case "arabicnum":
                        oninput = `oninput="this.value=this.value.replace(/[^\\u0600-\\u06FF0-9\\s]/g,'')"`;
                        pattern = 'pattern="[\\u0600-\\u06FF0-9\\s]+"';
                        break;

                    case "engsentence":
                        oninput = `oninput="this.value=this.value.replace(/[^A-Za-z0-9\\s.,!?'"()-]/g,'')"`;
                        pattern = 'pattern="[A-Za-z0-9\\s.,!?\'\\"()-]+"';
                        break;

                    case "arsentence":
                        oninput = `oninput="this.value=this.value.replace(/[^\\u0600-\\u06FF0-9\\s.,!?،؟'"()-]/g,'')"`;
                        pattern = 'pattern="[\\u0600-\\u06FF0-9\\s.,!?،؟\'\\"()-]+"';
                        break;

                    case "email":
                        oninput = `oninput="this.value=this.value.replace(/[^A-Za-z0-9@._-]/g,'')"`;
                        pattern = 'pattern="[A-Za-z0-9@._-]+"';
                        break;

                    case "url":
                        oninput = `oninput="this.value=this.value.replace(/[^A-Za-z0-9/:.?&=#_-]/g,'')"`;
                        pattern = 'pattern="[A-Za-z0-9/:.?&=#_-]+"';
                        break;

                    case "money_sar":
                        oninput = `oninput="sfMoneySarOnInput(this)"`;
                        pattern = 'pattern="^\\d+(\\.\\d{0,2})?$"';
                        break;

                    case "custom":
                        pattern = field.pattern ? `pattern="${field.pattern}"` : "";
                        oninput = "";
                        break;
                }

                let inputType = (field.type || "text").toLowerCase();
                if (textMode === "email") inputType = "email";
                if (textMode === "url") inputType = "url";
                if (textMode === "money_sar") inputType = "text";

                let fieldHtml = "";
                const hasIcon = field.icon && field.icon.trim() !== "";
                const iconHtml = hasIcon
                    ? `<i class="${this.escapeHtml(field.icon)} absolute right-3 top-3 text-gray-400 pointer-events-none"></i>`
                    : "";

                switch ((field.type || "text").toLowerCase()) {

                    case "text":
                    case "email":
                    case "url":
                    case "search": {

                        const acRaw = field.autocomplete ?? field.Autocomplete;
                        const ac = (acRaw ?? "").toString().trim();
                        const defaultAc =
                            (textMode === "email") ? "email" :
                                (textMode === "url") ? "url" :
                                    "off";

                        const autocompleteAttr = ac
                            ? `autocomplete="${this.escapeHtml(ac)}"`
                            : `autocomplete="${defaultAc}"`;

                        const hasIcon = !!field.icon;

                        const hasExtraButton = !!(field.extraButton ?? field.ExtraButton);
                        const extraButton = field.extraButton ?? field.ExtraButton ?? null;
                        const extraButtonText = extraButton?.text ?? extraButton?.Text ?? "تنفيذ";
                        const extraButtonClass = extraButton?.className ?? extraButton?.ClassName ?? "btn btn-info";
                        const extraButtonSlot = extraButton?.slotKey ?? extraButton?.SlotKey ?? "m2";

                        const isRtl =
                            (field.textMode && String(field.textMode).toLowerCase() === "arabic") ||
                            document?.documentElement?.dir === "rtl";

                        const iconSideClass = isRtl ? "sf-icon-right" : "sf-icon-left";
                        const iconInputClass = hasIcon ? `sf-has-icon ${iconSideClass}` : "";
                        const iconVal = (field.icon || "").toString().trim();
                        const isImgIcon = /\.(svg|png|jpg|jpeg|webp)$/i.test(iconVal);

                        const iconHtml = hasIcon
                            ? (isImgIcon
                                ? `<span class="sf-input-icon ${iconSideClass}">
                <img src="${this.escapeHtml(iconVal)}" class="sf-svg-icon" alt="" />
               </span>`
                                : `<span class="sf-input-icon ${iconSideClass}">
                <i class="${this.escapeHtml(iconVal)}"></i>
               </span>`)
                            : "";

                        const inputmodeAttr =
                            (textMode === "numeric") ? `inputmode="numeric"` :
                                (textMode === "money_sar") ? `inputmode="decimal"` :
                                    "";

                        const searchInputType =
                            (textMode === "email") ? "email" :
                                (textMode === "url") ? "url" :
                                    "text";

                        fieldHtml = `
<div class="form-group ${colCss}">
    <label class="block text-sm font-medium text-gray-700 mb-1">
        ${this.escapeHtml(field.label)}
        ${field.required ? '<span class="text-red-500">*</span>' : ''}
    </label>
    <div class="sf-field-wrap">
        ${iconHtml}
        <div class="flex gap-2 items-start">
            <input
                type="${searchInputType}"
                name="${this.escapeHtml(field.name)}"
                value="${this.escapeHtml(value)}"
                class="sf-modal-input ${iconInputClass}"
                ${placeholder}
                ${required}
                ${disabled}
                ${readonly}
                ${maxLength}
                ${autocompleteAttr}
                ${spellcheck}
                ${autocapitalize}
                ${autocorrect}
                ${inputmodeAttr}
                ${pattern}
                ${oninput}
            />
            ${hasExtraButton ? `
                <button
                    type="button"
                    class="${this.escapeHtml(extraButtonClass)}"
                    data-extra-trigger="1"
                    data-extra-slot="${this.escapeHtml(extraButtonSlot)}"
                    data-extra-field="${this.escapeHtml(field.name)}"
                >
                    ${this.escapeHtml(extraButtonText)}
                </button>
            ` : ""}
        </div>
    </div>
    ${field.helpText
                ? `<p class="mt-1 text-xs text-gray-500">${this.escapeHtml(field.helpText)}</p>`
                : ''}
</div>`;
                        break;
                    }

                    case "fileupload": {
                        const val = (a, b, d = undefined) => (a !== undefined && a !== null ? a : (b !== undefined && b !== null ? b : d));

                        const acceptRaw = val(field.accept, field.Accept, "");
                        const accept = acceptRaw ? `accept="${this.escapeHtml(acceptRaw)}"` : "";

                        const maxFiles = val(field.maxFiles, field.MaxFiles, null);
                        const multiple = (val(field.multiple, field.Multiple, false) || (typeof maxFiles === "number" && maxFiles > 1)) ? "multiple" : "";

                        const requiredAttr = required;
                        const disabledAttr = disabled;

                        const maxFileSize = val(field.maxFileSize, field.MaxFileSize, "");
                        const maxTotalSize = val(field.maxTotalSize, field.MaxTotalSize, "");
                        const allowEmpty = val(field.allowEmptyFile, field.AllowEmptyFile, false) ? "true" : "false";

                        const uploadFolder = val(field.uploadFolder, field.UploadFolder, "");
                        const uploadSubFolder = val(field.uploadSubFolder, field.UploadSubFolder, "");

                        const saveMode = val(field.saveMode, field.SaveMode, "physical");
                        const fileNameMode = val(field.fileNameMode, field.FileNameMode, "uuid");
                        const overwrite = val(field.overwrite, field.Overwrite, false) ? "true" : "false";
                        const keepExt = val(field.keepOriginalExtension, field.KeepOriginalExtension, true) ? "true" : "false";

                        const sanitize = val(field.sanitizeFileName, field.SanitizeFileName, true) ? "true" : "false";
                        const blockDoubleExt = val(field.blockDoubleExtension, field.BlockDoubleExtension, true) ? "true" : "false";
                        const scanOnUpload = val(field.scanOnUpload, field.ScanOnUpload, false) ? "true" : "false";

                        const mimeTypes = Array.isArray(val(field.allowedMimeTypes, field.AllowedMimeTypes, null))
                            ? val(field.allowedMimeTypes, field.AllowedMimeTypes).join(",")
                            : "";

                        const showSize = val(field.showFileSize, field.ShowFileSize, true) ? "true" : "false";
                        const showRemove = val(field.showRemoveButton, field.ShowRemoveButton, true) ? "true" : "false";
                        const showDownload = val(field.showDownloadButton, field.ShowDownloadButton, true) ? "true" : "false";
                        const showPreviewBtn = val(field.showPreviewButton, field.ShowPreviewButton, true) ? "true" : "false";
                        const showProgress = val(field.showUploadProgress, field.ShowUploadProgress, true) ? "true" : "false";

                        const enablePreview = val(field.enablePreview, field.EnablePreview, false) ? "true" : "false";
                        const previewMode = val(field.previewMode, field.PreviewMode, "modal");
                        const previewTypes = val(field.previewableTypes, field.PreviewableTypes, ".pdf,.jpg,.png");
                        const previewTitle = val(field.previewTitle, field.PreviewTitle, "معاينة");
                        const previewHeight = val(field.previewHeight, field.PreviewHeight, 600);

                        const previewPaper = val(field.previewPaper, field.PreviewPaper, "");
                        const previewOrientation = val(field.previewOrientation, field.PreviewOrientation, "portrait");

                        const readOnlyFiles = val(field.readOnlyFiles, field.ReadOnlyFiles, false) ? "true" : "false";
                        const autoUpload = val(field.autoUpload, field.AutoUpload, false) ? "true" : "false";

                        const uploadCategory = val(field.uploadCategory, field.UploadCategory, "");
                        const bindToEntityId = val(field.bindToEntityId, field.BindToEntityId, "");

                        const errSize = val(field.errorMessageSize, field.ErrorMessageSize, "");
                        const errType = val(field.errorMessageType, field.ErrorMessageType, "");
                        const errCount = val(field.errorMessageCount, field.ErrorMessageCount, "");
                        const errTotal = val(field.errorMessageTotal, field.ErrorMessageTotal, "");

                        const uploadApi = val(field.uploadEndpoint, field.UploadEndpoint, "/api/files/upload");
                        const previewApi = val(field.previewEndpoint, field.PreviewEndpoint, "/api/files/preview");
                        const downloadApi = val(field.downloadEndpoint, field.DownloadEndpoint, "/api/files/download");
                        const deleteApi = val(field.deleteEndpoint, field.DeleteEndpoint, "/api/files/delete");

                        const hintParts = [];
                        if (acceptRaw) hintParts.push(`الصيغ: ${this.escapeHtml(acceptRaw)}`);
                        if (maxFileSize) hintParts.push(`الحد الأقصى للملف: ${maxFileSize}MB`);
                        if (maxTotalSize) hintParts.push(`الإجمالي: ${maxTotalSize}MB`);
                        const hint = hintParts.join(" - ");

                        const safeName = (field.name || "").trim();
                        const safeNameAttr = this.escapeHtml(safeName);

                        const inputId = `sf_fu_${safeName}_${Math.random().toString(36).slice(2, 8)}`;

                        fieldHtml = `
                        <div class="form-group ${colCss}">
                          <label class="block text-sm font-medium text-gray-700 mb-1">
                            ${this.escapeHtml(field.label)}
                            ${val(field.required, field.Required, false) ? '<span class="text-red-500">*</span>' : ''}
                          </label>

                          <div class="sf-file-upload"
                            data-name="${safeName}"
                            data-max-files="${maxFiles ?? ""}"
                            data-max-file-size="${maxFileSize}"
                            data-max-total-size="${maxTotalSize}"
                            data-allow-empty="${allowEmpty}"
                            data-upload-folder="${this.escapeHtml(uploadFolder)}"
                            data-upload-subfolder="${this.escapeHtml(uploadSubFolder)}"
                            data-save-mode="${this.escapeHtml(saveMode)}"
                            data-file-name-mode="${this.escapeHtml(fileNameMode)}"
                            data-overwrite="${overwrite}"
                            data-keep-ext="${keepExt}"
                            data-sanitize="${sanitize}"
                            data-block-double="${blockDoubleExt}"
                            data-scan="${scanOnUpload}"
                            data-mime-types="${this.escapeHtml(mimeTypes)}"
                            data-show-size="${showSize}"
                            data-show-remove="${showRemove}"
                            data-show-download="${showDownload}"
                            data-show-preview-btn="${showPreviewBtn}"
                            data-show-progress="${showProgress}"
                            data-preview="${enablePreview}"
                            data-preview-mode="${this.escapeHtml(previewMode)}"
                            data-preview-types="${this.escapeHtml(previewTypes)}"
                            data-preview-title="${this.escapeHtml(previewTitle)}"
                            data-preview-height="${previewHeight}"
                            data-preview-paper="${this.escapeHtml(previewPaper)}"
                            data-preview-orientation="${this.escapeHtml(previewOrientation)}"
                            data-error-size="${this.escapeHtml(errSize)}"
                            data-error-type="${this.escapeHtml(errType)}"
                            data-error-count="${this.escapeHtml(errCount)}"
                            data-error-total="${this.escapeHtml(errTotal)}"
                            data-readonly="${readOnlyFiles}"
                            data-auto-upload="${autoUpload}"
                            data-upload-category="${this.escapeHtml(uploadCategory)}"
                            data-bind-entity="${this.escapeHtml(bindToEntityId)}"
                            data-upload-api="${this.escapeHtml(uploadApi)}"
                            data-preview-api="${this.escapeHtml(previewApi)}"
                            data-download-api="${this.escapeHtml(downloadApi)}"
                            data-delete-api="${this.escapeHtml(deleteApi)}"
                          >
                            <div class="sf-file-bar">
                              <label class="sf-file-btn" for="${inputId}">إرفاق ملف</label>

                              <label class="sf-file-meta sf-file-field" for="${inputId}">
                                <span class="sf-file-picked">لم يتم اختيار ملفات</span>
                              </label>
                            </div>

                            <input
                              id="${inputId}"
                              type="file"
                              name="${safeName}"
                              class="sf-file-input"
                              ${accept}
                              ${multiple}
                              ${requiredAttr}
                              ${disabledAttr}
                            />

                            <input type="hidden" name="${safeName}__uploaded" class="sf-file-uploaded" value="[]" />

                            <input type="hidden" name="${safeName}__folder" value="${this.escapeHtml(uploadFolder)}" />
                            <input type="hidden" name="${safeName}__subfolder" value="${this.escapeHtml(uploadSubFolder)}" />
                            <input type="hidden" name="${safeName}__maxFiles" value="${maxFiles ?? ""}" />
                            <input type="hidden" name="${safeName}__maxFileSizeMb" value="${this.escapeHtml(String(maxFileSize ?? ""))}" />
                            <input type="hidden" name="${safeName}__maxTotalMb" value="${this.escapeHtml(String(maxTotalSize ?? ""))}" />

                            ${hint ? `<div class="sf-file-hint">${hint}</div>` : ""}
                            <div class="sf-file-errors hidden"></div>
                            <div class="sf-file-list"></div>
                          </div>

                          ${field.helpText ? `<p class="mt-1 text-xs text-gray-500">${this.escapeHtml(field.helpText)}</p>` : ""}
                        </div>`;
                        break;
                    }

                    case "textarea": {
                        const acRaw = field.autocomplete ?? field.Autocomplete;
                        const ac = (acRaw ?? "").toString().trim();
                        const defaultAc = "off";
                        const autocompleteAttr = ac
                            ? `autocomplete="${this.escapeHtml(ac)}"`
                            : `autocomplete="${defaultAc}"`;
                        const rows = field.rows || 3;
                        fieldHtml = `
                        <div class="form-group ${colCss}">
                            <label class="block text-sm font-medium text-gray-700 mb-1">
                                ${this.escapeHtml(field.label)} ${field.required ? '<span class="text-red-500">*</span>' : ''}
                            </label>
                            <textarea
                                name="${this.escapeHtml(field.name)}"
                                rows="${rows}"
                                class="sf-modal-input"
                                ${placeholder}
                                ${required}
                                ${disabled}
                                ${readonly}
                                ${maxLength}
                                ${autocompleteAttr}
                            >${this.escapeHtml(value)}</textarea>
                            ${field.helpText
                ? `<p class="mt-1 text-xs text-gray-500">${this.escapeHtml(field.helpText)}</p>`
                : ''}
                            </div>`;
                        break;
                    }

                    case "select": {
                        let options = "";

                        options += `<option value="" disabled ${!value ? "selected" : ""}>${this.escapeHtml(field.placeholder || "الرجاء الاختيار")}</option>`;

                        (field.options || []).forEach(opt => {
                            const optValue = opt.value ?? opt.Value ?? "";
                            const optText = opt.text ?? opt.Text ?? "";
                            const selected = String(value) === String(optValue) ? "selected" : "";
                            options += `<option value="${this.escapeHtml(optValue)}" ${selected}>${this.escapeHtml(optText)}</option>`;
                        });

                        let onChangeHandler = field.onChangeJs || "";

                        if (!(field.dependsUrl && field.dependsOn) && onChangeHandler && !field.dependsUrl) {
                            onChangeHandler = `${onChangeHandler}`;
                        }
                        const onChangeAttr = onChangeHandler ? `onchange="${this.escapeHtml(onChangeHandler)}"` : "";
                        const dependsOnAttr = field.dependsOn ? `data-depends-on="${this.escapeHtml(field.dependsOn)}"` : "";
                        const dependsUrlAttr = field.dependsUrl ? `data-depends-url="${this.escapeHtml(field.dependsUrl)}"` : "";

                        const useSelect2 = !!(field.select2 ?? field.Select2);

                        const minResults = field.select2MinResultsForSearch ?? field.Select2MinResultsForSearch;
                        const s2Placeholder = field.select2Placeholder ?? field.Select2Placeholder;

                        const select2Class = useSelect2 ? "js-select2" : "";
                        const s2MinAttr = (useSelect2 && minResults !== undefined && minResults !== null)
                            ? `data-s2-min-results="${this.escapeHtml(minResults)}"`
                            : "";
                        const s2PhAttr = (useSelect2 && s2Placeholder)
                            ? `data-s2-placeholder="${this.escapeHtml(s2Placeholder)}"`
                            : "";

                        fieldHtml = `
                        <div class="form-group ${colCss}">
                            <label class="block text-sm font-medium text-gray-700 mb-1">
                                ${this.escapeHtml(field.label)} ${(field.required ?? field.Required) ? '<span class="text-red-500">*</span>' : ''}
                            </label>

                            <div class="sf-select-wrap">
                                <select
                                    name="${this.escapeHtml(field.name)}"
                                    class="sf-modal-input sf-modal-select ${select2Class}"
                                    ${required}
                                    ${disabled}
                                    ${onChangeAttr}
                                    ${dependsOnAttr}
                                    ${dependsUrlAttr}
                                    ${s2MinAttr}
                                    ${s2PhAttr}
                                >
                                    ${options}
                                </select>
                            </div>

                            ${field.helpText ? `<p class="mt-1 text-xs text-gray-500">${this.escapeHtml(field.helpText)}</p>` : ''}
                        </div>`;
                        break;
                    }

                    case "checkbox":
                        const checked = value === true || value === "true" || value === "1" || value === 1 ? "checked" : "";
                        fieldHtml = `
                        <div class="form-group ${colCss}">
                            <label class="inline-flex items-center">
                                <input type="checkbox" name="${this.escapeHtml(field.name)}" value="1"
                                       ${checked} ${required} ${disabled}
                                       class="rounded border-gray-300 text-blue-600 shadow-sm focus:border-blue-300 focus:ring focus:ring-blue-200 focus:ring-opacity-50">
                                <span class="ml-2 text-sm text-gray-700">
                                    ${this.escapeHtml(field.label)} ${field.required ? '<span class="text-red-500">*</span>' : ''}
                                </span>
                            </label>
                            ${field.helpText ? `<p class="mt-1 text-xs text-gray-500">${this.escapeHtml(field.helpText)}</p>` : ''}
                        </div>`;
                        break;

                    case "date": {

                        const hasIcon = !!field.icon;
                        const isRtl = document?.documentElement?.dir === "rtl";

                        const iconSideClass = isRtl ? "sf-icon-right" : "sf-icon-left";

                        const iconInputClass = hasIcon ? `sf-has-icon ${iconSideClass}` : "";

                        const iconHtml = hasIcon
                            ? `<span class="sf-input-icon ${iconSideClass}">
                                    <i class="${this.escapeHtml(field.icon)}"></i>
                               </span>`
                            : "";

                        fieldHtml = `
                            <div class="form-group ${colCss}">
                                <label class="block text-sm font-medium text-gray-700 mb-1">
                                    ${this.escapeHtml(field.label)}
                                    ${field.required ? '<span class="text-red-500">*</span>' : ''}
                                </label>

                                <div class="sf-field-wrap">
                                    ${iconHtml}
                                    <input
                                        type="text"
                                        name="${this.escapeHtml(field.name)}"
                                        value="${this.escapeHtml(value)}"
                                        class="sf-modal-input js-date ${iconInputClass}"
                                        data-default-date=""
                                        data-alt-input="true"
                                        data-date-format="Y-m-d"
                                        autocomplete="off"
                                        ${required} ${disabled} ${readonly}
                                    />
                                </div>

                                ${field.helpText
                ? `<p class="mt-1 text-xs text-gray-500">${this.escapeHtml(field.helpText)}</p>`
                : ''}
                            </div>`;
                        break;
                    }

                    case "number":
                        const min0 = `min="0"`;
                        const numStep = field.step !== undefined ? `step="${field.step}"` : `step="1"`;
                        const numMax = field.max !== undefined ? `max="${field.max}"` : "";

                        const allowDecimal =
                            String(field.step ?? "").includes('.') ||
                            (typeof field.step === 'number' && !Number.isInteger(field.step));

                        const ac = field.autocomplete ?? field.Autocomplete;
                        const autocompleteAttr =
                            (ac !== undefined && ac !== null && String(ac).trim() !== "")
                                ? `autocomplete="${this.escapeHtml(ac)}"`
                                : `autocomplete="off"`;

                        const numberOnInput = allowDecimal
                            ? `oninput="this.value=this.value.replace(/[^0-9.]/g,''); if(this.value.startsWith('.')) this.value='0'+this.value; if(this.value.includes('.')){const p=this.value.split('.'); this.value=p[0]+'.'+p.slice(1).join('');}"`
                            : `oninput="this.value=this.value.replace(/\\D/g,'')"`;

                        const numberOnKeyDown =
                            `onkeydown="if(['-','e','E','+'].includes(event.key)) event.preventDefault()"`;

                        const hasIcon = !!field.icon;
                        const isRtl = document?.documentElement?.dir === "rtl";

                        const iconSideClass = isRtl ? "sf-icon-right" : "sf-icon-left";
                        const iconInputClass = hasIcon ? `sf-has-icon ${iconSideClass}` : "";

                        const iconHtml = hasIcon
                            ? `<span class="sf-input-icon ${iconSideClass}">
                            <i class="${this.escapeHtml(field.icon)}"></i>
                           </span>`
                            : "";

                        fieldHtml = `
                        <div class="form-group ${colCss}">
                            <label class="block text-sm font-medium text-gray-700 mb-1">
                                ${this.escapeHtml(field.label)} ${field.required ? '<span class="text-red-500">*</span>' : ''}
                            </label>

                            <div class="sf-field-wrap">
                                ${iconHtml}
                                <input
                                    type="number"
                                    inputmode="numeric"
                                    name="${this.escapeHtml(field.name)}"
                                    value="${this.escapeHtml(value)}"
                                    class="sf-modal-input ${iconInputClass}"
                                    ${autocompleteAttr}
                                    ${placeholder}
                                    ${min0}
                                    ${numMax}
                                    ${numStep}
                                    ${required}
                                    ${disabled}
                                    ${readonly}
                                    ${numberOnKeyDown}
                                    ${numberOnInput}
                                >
                            </div>
                            ${field.helpText
                ? `<p class="mt-1 text-xs text-gray-500">${this.escapeHtml(field.helpText)}</p>`
                : ''}
                        </div>`;
                        break;

                    case "nationalid":
                    case "nid":
                    case "identity": {

                        const nidOnInput =
                            `oninput="` +
                            `this.value=this.value.replace(/\\D/g,'');` +
                            `if(this.value.length>10)this.value=this.value.slice(0,10);` +
                            `"`;

                        const nidOnKeyDown =
                            `onkeydown="if(['-','e','E','+','.'].includes(event.key)) event.preventDefault()"`;
                        const acRaw = field.autocomplete ?? field.Autocomplete;
                        const ac = (acRaw ?? "").toString().trim();
                        const autocompleteAttr = ac
                            ? `autocomplete="${this.escapeHtml(ac)}"`
                            : `autocomplete="new-password"`;
                        const hasIcon = !!field.icon;
                        const isRtl = document?.documentElement?.dir === "rtl";
                        const iconSideClass = isRtl ? "sf-icon-right" : "sf-icon-left";
                        const iconInputClass = hasIcon ? `sf-has-icon ${iconSideClass}` : "";
                        const iconHtml = hasIcon
                            ? `<span class="sf-input-icon ${iconSideClass}">
                                <i class="${this.escapeHtml(field.icon)}"></i>
                           </span>`
                            : "";
                        fieldHtml = `
                        <div class="form-group ${colCss}">
                            <label class="block text-sm font-medium text-gray-700 mb-1">
                                ${this.escapeHtml(field.label)} ${field.required ? '<span class="text-red-500">*</span>' : ''}
                            </label>
                            <div class="sf-field-wrap">
                                ${iconHtml}
                                <input
                                    type="text"
                                    inputmode="numeric"
                                    name="${this.escapeHtml(field.name)}"
                                    value="${this.escapeHtml(value)}"
                                    class="sf-modal-input ${iconInputClass}"
                                    ${placeholder}
                                    ${required}
                                    ${disabled}
                                    ${readonly}
                                    ${autocompleteAttr}
                                    autocorrect="off"
                                    autocapitalize="off"
                                    spellcheck="false"
                                    maxlength="10"
                                    pattern="^[0-9]{1,10}$"
                                    title="الهوية الوطنية يجب أن تكون أرقام فقط وبحد أقصى 10 رقم"
                                    ${nidOnKeyDown}
                                    ${nidOnInput}
                                />
                            </div>
                            ${field.helpText ? `<p class="mt-1 text-xs text-gray-500">${this.escapeHtml(field.helpText)}</p>` : ''}
                        </div>`;
                        break;
                    }

                    case "phone":
                    case "tel": {

                        const normalizeFn = `
                                        (function(el){
                                            let v = (el.value || '');

                                            v = v.replace(/[٠-٩]/g, d => '٠١٢٣٤٥٦٧٨٩'.indexOf(d));
                                            v = v.replace(/[۰-۹]/g, d => '۰۱۲۳۴۵۶۷۸۹'.indexOf(d));

                                            v = v.replace(/\\s+/g,'');
                                            v = v.replace(/^\\+/, '');
                                            v = v.replace(/\\D/g,'');

                                            if (v.startsWith('966'))  v = '0' + v.slice(3);
                                            if (v.startsWith('00966')) v = '0' + v.slice(5);
                                            if (v.startsWith('5') && v.length === 9) v = '0' + v;

                                            if (v.length >= 2 && !v.startsWith('05')) {
                                                if (v.startsWith('0')) v = '05' + v.slice(2);
                                                else v = '05' + v.replace(/^05/, '').slice(0);
                                            }

                                            if (v.length > 10) v = v.slice(0,10);
                                            el.value = v;
                                        })(this);
                                    `;

                        const validateFn = `
                                        (function(el){
                                            ${normalizeFn.replace(/this/g, 'el')}

                                            const v = (el.value || '');
                                            if (${field.required ? 'true' : 'false'} && !v) {
                                                el.setCustomValidity('رقم الجوال مطلوب');
                                                return;
                                            }
                                            if (!v) { el.setCustomValidity(''); return; }

                                            if (!/^05\\d{8}$/.test(v)) {
                                                el.setCustomValidity('رقم الجوال يجب أن يبدأ بـ 05 ثم 8 أرقام');
                                            } else {
                                                el.setCustomValidity('');
                                            }
                                        })(this);
                                    `;

                        const acRaw = field.autocomplete ?? field.Autocomplete;
                        const ac = (acRaw ?? "").toString().trim();
                        const autocompleteAttr = ac
                            ? `autocomplete="${this.escapeHtml(ac)}"`
                            : `autocomplete="new-password"`;
                        const initial = (() => {
                            let v = (value ?? '').toString();
                            v = v.replace(/[٠-٩]/g, d => '٠١٢٣٤٥٦٧٨٩'.indexOf(d));
                            v = v.replace(/[۰-۹]/g, d => '۰۱۲۳۴۵۶۷۸۹'.indexOf(d));
                            v = v.replace(/\\s+/g, '').replace(/^\\+/, '').replace(/\\D/g, '');
                            if (v.startsWith('00966')) v = '0' + v.slice(5);
                            if (v.startsWith('966')) v = '0' + v.slice(3);
                            if (v.startsWith('5') && v.length === 9) v = '0' + v;
                            if (v.length > 10) v = v.slice(0, 10);
                            return v;
                        })();
                        const onInput = `oninput="${normalizeFn} this.setCustomValidity('');"`;
                        const onBlur = `onblur="${validateFn}"`;
                        const onInvalid = `oninvalid="${validateFn}"`;
                        const onChange = `onchange="${normalizeFn}"`;
                        const onKeyDown =
                            `onkeydown="if(['-','e','E','+','.'].includes(event.key)) event.preventDefault()"`;
                        const hasIcon = !!field.icon;
                        const isRtl = document?.documentElement?.dir === "rtl";

                        const iconSideClass = isRtl ? "sf-icon-right" : "sf-icon-left";
                        const iconInputClass = hasIcon ? `sf-has-icon ${iconSideClass}` : "";

                        const iconHtml = hasIcon
                            ? `<span class="sf-input-icon ${iconSideClass}">
                        <i class="${this.escapeHtml(field.icon)}"></i>
                        </span>`
                            : "";

                        fieldHtml = `
                        <div class="form-group ${colCss}">
                            <label class="block text-sm font-medium text-gray-700 mb-1">
                                ${this.escapeHtml(field.label)} ${field.required ? '<span class="text-red-500">*</span>' : ''}
                            </label>

                            <div class="sf-field-wrap">
                                ${iconHtml}

                                <input
                                    type="text"
                                    inputmode="numeric"
                                    name="${this.escapeHtml(field.name)}"
                                    value="${this.escapeHtml(initial)}"
                                    class="sf-modal-input ${iconInputClass}"
                                    ${placeholder}
                                    ${required}
                                    ${disabled}
                                    ${readonly}
                                    data-sa-mobile="1"
                                    ${autocompleteAttr}
                                    autocorrect="off"
                                    autocapitalize="off"
                                    spellcheck="false"
                                    maxlength="10"
                                    title="مثال: 05XXXXXXXX"
                                    ${onKeyDown}
                                    ${onChange}
                                    ${onInvalid}
                                    ${onBlur}
                                    ${onInput}
                                />
                            </div>

                            ${field.helpText ? `<p class="mt-1 text-xs text-gray-500">${this.escapeHtml(field.helpText)}</p>` : ''}
                        </div>`;
                        break;
                    }

                    case "iban":
                        fieldHtml = `
                        <div class="form-group ${colCss}">
                            <label class="block text-sm font-medium text-gray-700 mb-1">
                                ${this.escapeHtml(field.label)} ${field.required ? '<span class="text-red-500">*</span>' : ''}

                            </label>
                            <input type="text" name="${this.escapeHtml(field.name)}"
                                   value="${this.escapeHtml(value)}"
                                   class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 font-mono"
                                   ${placeholder} ${required} ${disabled} ${readonly} ${maxLength}>
                            ${field.helpText ? `<p class="mt-1 text-xs text-gray-500">${this.escapeHtml(field.helpText)}</p>` : ''}
                        </div>`;
                        break;

                    default:

                        fieldHtml = `
                        <div class="form-group ${colCss}">
                            <label class="block text-sm font-medium text-gray-700 mb-1">
                                ${this.escapeHtml(field.label)} ${field.required ? '<span class="text-red-500">*</span>' : ''}

                            </label>
                            <input type="text" name="${this.escapeHtml(field.name)}"
                                   value="${this.escapeHtml(value)}"
                                   class="sf-modal-input"
                                   ${placeholder} ${required} ${disabled} ${readonly} ${maxLength}>
                            ${field.helpText ? `<p class="mt-1 text-xs text-gray-500">${this.escapeHtml(field.helpText)}</p>` : ''}
                        </div>`;
                        break;
                }

                return fieldHtml;
            },

            // CSS helpers
            resolveColCss(colCss) {
                if (!colCss) return "col-span-12";

                const raw = colCss.toString().trim();

                if (/^\d{1,2}$/.test(raw)) {
                    const n = Math.max(1, Math.min(12, parseInt(raw, 10)));
                    return `col-span-${n}`;
                }

                if (raw.includes("col-span")) return raw;

                return `col-span-12 ${raw}`;
            },

            initModalScripts() {
                const form = this.$el.querySelector('.sf-modal form');
                if (form) {

                    form.querySelectorAll("[required]").forEach(input => {
                        if (!input.value) {
                            input.setCustomValidity("الرجاء تعبئة هذا الحقل");
                        }

                        input.addEventListener("invalid", function () {
                            this.setCustomValidity("الرجاء تعبئة هذا الحقل");
                        });

                        input.addEventListener("input", function () {
                            this.setCustomValidity("");
                            if (!this.checkValidity()) {
                                this.setCustomValidity("الرجاء تعبئة هذا الحقل");
                            }
                        });

                        input.addEventListener("change", function () {
                            this.setCustomValidity("");
                            if (!this.checkValidity()) {
                                this.setCustomValidity("الرجاء تعبئة هذا الحقل");
                            }
                        });
                    });

                    form.addEventListener('submit', (e) => {
                        e.preventDefault();
                        this.saveModalChanges();
                    });

                }
            },

            // Dependent dropdowns
            setupDependentDropdowns(form) {

                const dependentSelects = form.querySelectorAll('select[data-depends-on]');

                dependentSelects.forEach(dependentSelect => {
                    const parentFieldName = dependentSelect.getAttribute('data-depends-on');
                    const dependsUrl = dependentSelect.getAttribute('data-depends-url');

                    if (!parentFieldName || !dependsUrl) return;

                    const parentSelect = form.querySelector(`select[name="${parentFieldName}"]`);
                    if (!parentSelect) {
                        return;
                    }

                    parentSelect.addEventListener('change', async (e) => {
                        const parentValue = e.target.value;

                        const originalHtml = dependentSelect.innerHTML;
                        dependentSelect.innerHTML = '<option value="-1">جاري التحميل...</option>';
                        dependentSelect.disabled = true;
                        try {

                            const url = `${dependsUrl}?${parentFieldName}=${encodeURIComponent(parentValue)}`;

                            const response = await fetch(url);
                            if (!response.ok) {
                                throw new Error(`HTTP ${response.status}`);
                            }
                            const data = await response.json();

                            dependentSelect.innerHTML = '';

                            if (Array.isArray(data) && data.length > 0) {
                                data.forEach(item => {
                                    const option = document.createElement('option');
                                    option.value = item.value;
                                    option.textContent = item.text;
                                    dependentSelect.appendChild(option);
                                });
                            } else {
                                dependentSelect.innerHTML = '<option value="-1">لا توجد خيارات متاحة</option>';
                            }

                            if (window.jQuery && jQuery.fn.select2 && dependentSelect.classList.contains('js-select2')) {
                                const parentModal = dependentSelect.closest('.sf-modal') || document.body;

                                $(dependentSelect).select2('destroy');
                                $(dependentSelect).select2({
                                    width: '100%',
                                    dir: 'rtl',
                                    dropdownParent: $(parentModal)
                                });
                            }

                        } catch (error) {
                            dependentSelect.innerHTML = originalHtml;
                            this.showToast('فشل تحميل الخيارات: ' + error.message, 'error');
                        } finally {
                            dependentSelect.disabled = false;
                        }
                    });

                    if (parentSelect.value && parentSelect.value !== '' && parentSelect.value !== '-1') {
                        parentSelect.dispatchEvent(new Event('change'));
                    }
                });
            },

            async saveModalChanges() {
                if (!this.modal.action) return;

                const form = this.$el.querySelector('.sf-modal form');
                if (!form) return;

                try {
                    this.modal.loading = true;
                    this.modal.error = null;
                    const formData = this.serializeForm(form);
                    const result = await this.executeSp(
                        this.modal.action.saveSp,
                        this.modal.action.saveOp || (this.modal.action.isEdit ? "update" : "insert"),
                        formData
                    );

                    if (result) {

                        if (this.serverPaging) {
                            await this.load();
                        } else {
                            const saved = result.data || result.row || result.item || null;
                            const id = (saved && saved[this.rowIdField]) ?? formData[this.rowIdField];

                            if (saved) {
                                const idx = this.allRows.findIndex(r => r[this.rowIdField] == id);
                                if (idx >= 0) this.allRows[idx] = { ...this.allRows[idx], ...saved };
                                else this.allRows.unshift(saved);
                                this.invalidateRowCaches();
                            }

                            this.applyFiltersAndSort();
                        }

                        this.closeModal();
                        this.clearSelection();
                    }

                } catch (e) {
                    this.modal.error = e.message || "فشل في الحفظ";
                } finally {
                    this.modal.loading = false;
                }
            },

            // Detail view rendering
            formatDetailView(row, columns) {
                if (!row || !Array.isArray(columns)) {
                    return `<div class="sf-detail-empty">لا توجد بيانات</div>`;
                }

                let html = `<div class="sf-detail-grid">`;

                columns.forEach(col => {
                    if (col.visible === false || !col.field) return;

                    const value = row[col.field];
                    if (value == null || value === "") return;

                    let displayValue = value;

                    switch (col.type) {
                        case "date":
                            displayValue = new Date(value).toLocaleDateString("ar-SA");
                            break;
                        case "datetime":
                            displayValue = new Date(value).toLocaleString("ar-SA");
                            break;
                        case "bool":
                            displayValue = value ? "نعم" : "لا";
                            break;
                        case "money":
                            displayValue = new Intl.NumberFormat("ar-SA", {
                                style: "currency",
                                currency: "SAR"
                            }).format(value);
                            break;
                    }

                    html += `
                    <div class="sf-detail-row">
                        <div class="sf-detail-label">
                            ${this.escapeHtml(col.label || col.field)}
                        </div>
                        <div class="sf-detail-value">
                            ${this.escapeHtml(displayValue)}
                        </div>
                    </div>`;
                });

                html += `</div>`;
                return html;
            },

            // Form serialization
            serializeForm(form) {
                const formData = new FormData(form);
                const data = {};

                for (const [key, value] of formData.entries()) {
                    if (data[key]) {

                        if (Array.isArray(data[key])) {
                            data[key].push(value);
                        } else {
                            data[key] = [data[key], value];
                        }
                    } else {
                        data[key] = value;
                    }
                }

                form.querySelectorAll('input[type="checkbox"][name]').forEach(checkbox => {
                    if (!formData.has(checkbox.name)) {
                        data[checkbox.name] = false;
                    } else {
                        data[checkbox.name] = true;
                    }
                });

                Object.keys(data).forEach(key => {
                    let value = data[key];
                    if (typeof value === 'string') {
                        const trimmed = value.trim();
                        if (trimmed === '') {
                            data[key] = null;
                        } else if (/^\d+$/.test(trimmed) && !trimmed.startsWith('0')) {
                            data[key] = parseInt(trimmed, 10);
                        } else if (/^\d+\.\d+$/.test(trimmed)) {
                            data[key] = parseFloat(trimmed);
                        } else {
                            data[key] = trimmed;
                        }
                    }
                });

                return data;
            },

            async executeSp(spName, operation, params) {
                try {
                    const body = {
                        Component: "Form",
                        SpName: spName,
                        Operation: operation,
                        Params: params || {}
                    };
                    const result = await this.postJson(this.endpoint, body);
                    if (result?.message) this.showToast(result.message, 'success');
                    return result;
                } catch (e) {
                    this.showToast("⚠️ " + (e.message || "فشل العملية"), 'error');

                    if (e.server?.errors) this.applyServerErrors(e.server.errors);

                    return null;
                }
            },

            async postJson(url, body) {
                const headers = { "Content-Type": "application/json" };

                const csrfToken = this.getCsrfToken();
                if (csrfToken) {
                    headers["RequestVerificationToken"] = csrfToken;
                }

                const response = await fetch(url, {
                    method: "POST",
                    headers,
                    body: JSON.stringify(body)
                });

                let json = null;
                try {
                    json = await response.json();
                } catch (e) {

                }

                if (!response.ok) {
                    const message = json?.error || `HTTP ${response.status}`;
                    throw new Error(message);
                }

                if (json && json.success === false) {
                    const error = new Error(json.error || "العملية فشلت");
                    error.server = json;
                    throw error;
                }

                return json;
            },

            // Server communication
            getCsrfToken() {
                const meta = document.querySelector('meta[name="request-verification-token"]');
                if (meta?.content) return meta.content;

                const input = document.querySelector('input[name="__RequestVerificationToken"]');
                return input?.value || null;
            },

            applyServerErrors(errors) {
                const form = this.$el.querySelector('.sf-modal form');
                if (!form || !errors) return;

                form.querySelectorAll('[data-error-msg]').forEach(el => el.remove());
                form.querySelectorAll('.ring-red-500, .border-red-500').forEach(el => {
                    el.classList.remove('ring-red-500', 'border-red-500', 'ring-1');
                });

                Object.entries(errors).forEach(([fieldName, message]) => {
                    const field = form.querySelector(`[name="${fieldName}"]`);
                    if (field) {
                        field.classList.add('border-red-500', 'ring-1', 'ring-red-500');

                        const errorDiv = document.createElement('div');
                        errorDiv.className = 'text-red-600 text-sm mt-1';
                        errorDiv.setAttribute('data-error-msg', '1');
                        errorDiv.textContent = Array.isArray(message) ? message.join(', ') : String(message);

                        field.parentElement.appendChild(errorDiv);
                    }
                });
            },

            // Cell formatting
            formatCell(row, col) {
                let value = row[col.field];
                if (value == null) value = "";

                const shouldTruncate = !!(col.truncate ?? col.Truncate);

                const wrapTruncate = (htmlOrText, titleText) => {
                    if (!shouldTruncate) return htmlOrText;
                    const raw = (titleText ?? "");
                    const clean = String(raw).replace(/\s+/g, " ").trim();
                    const t = this.escapeHtml(clean);
                    return `<span class="sf-truncate" title="${t}">${htmlOrText}</span>`;
                };

                let base = "";

                switch (col.type) {
                    case "date":
                        try {
                            const txt = new Date(value).toLocaleDateString('ar-SA');
                            base = wrapTruncate(this.escapeHtml(txt), txt);
                        } catch {
                            const txt = String(value);
                            base = wrapTruncate(this.escapeHtml(txt), txt);
                        }
                        return this.renderCellContent(row, col, base);

                    case "datetime":
                        try {
                            const txt = new Date(value).toLocaleString('ar-SA');
                            base = wrapTruncate(this.escapeHtml(txt), txt);
                        } catch {
                            const txt = String(value);
                            base = wrapTruncate(this.escapeHtml(txt), txt);
                        }
                        return this.renderCellContent(row, col, base);

                    case "bool":
                        base = value
                            ? '<span class="text-green-600">✓</span>'
                            : '<span class="text-red-600">✗</span>';
                        return this.renderCellContent(row, col, base);

                    case "money":
                        try {
                            const txt = new Intl.NumberFormat('ar-SA', { style: 'currency', currency: 'SAR' }).format(value);
                            base = wrapTruncate(this.escapeHtml(txt), txt);
                        } catch {
                            const txt = String(value);
                            base = wrapTruncate(this.escapeHtml(txt), txt);
                        }
                        return this.renderCellContent(row, col, base);

                    case "badge": {
                        const badgeClass =
                            col.badge?.map?.[value] ||
                            col.badge?.defaultClass ||
                            "bg-gray-100 text-gray-800";

                        const txt = String(value);
                        const html =
                            `<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${badgeClass}">${this.escapeHtml(txt)}</span>`;

                        base = wrapTruncate(html, txt);
                        return this.renderCellContent(row, col, base);
                    }

                    case "link": {
                        const txt = String(value);
                        if (col.linkTemplate) {
                            const href = this.fillUrl(col.linkTemplate, row);
                            const html =
                                `<a href="${this.escapeHtml(href)}" class="text-blue-600 hover:text-blue-800 hover:underline">${this.escapeHtml(txt)}</a>`;
                            base = wrapTruncate(html, txt);
                            return this.renderCellContent(row, col, base);
                        }
                        base = wrapTruncate(this.escapeHtml(txt), txt);
                        return this.renderCellContent(row, col, base);
                    }

                    case "image":
                        if (col.imageTemplate) {
                            const src = this.fillUrl(col.imageTemplate, row);
                            base = `<img src="${this.escapeHtml(src)}" alt="${this.escapeHtml(String(value))}" class="h-8 w-8 rounded object-cover">`;
                            return this.renderCellContent(row, col, base);
                        }
                        return this.renderCellContent(row, col, "");

                    default: {
                        const txt = String(value);
                        base = wrapTruncate(this.escapeHtml(txt), txt);
                        return this.renderCellContent(row, col, base);
                    }
                }
            },

            // Grouping and pagination
            groupedRows() {
                if (!this.groupBy) {
                    return [{ key: null, label: null, items: this.rows }];
                }

                const groups = {};
                this.rows.forEach(row => {
                    const key = row[this.groupBy] ?? "غير محدد";
                    if (!groups[key]) {
                        groups[key] = [];
                    }
                    groups[key].push(row);
                });

                return Object.entries(groups).map(([key, items]) => ({
                    key,
                    label: `${this.groupBy}: ${key}`,
                    count: items.length,
                    items
                }));
            },

            goToPage(page) {
                const newPage = Math.max(1, Math.min(page, this.pages || 1));
                if (newPage !== this.page) {
                    this.page = newPage;
                    if (this.serverPaging) this.load();
                    else this.applyFiltersAndSort();
                }
            },

            nextPage() {
                if (this.page < (this.pages || 1)) {
                    this.page++;
                    if (this.serverPaging) this.load();
                    else this.applyFiltersAndSort();
                }
            },

            prevPage() {
                if (this.page > 1) {
                    this.page--;
                    if (this.serverPaging) this.load();
                    else this.applyFiltersAndSort();
                }
            },

            firstPage() {
                this.goToPage(1);
            },

            lastPage() {
                this.goToPage(this.pages || 1);
            },

            visiblePageNumbers() {
                const total = Number(this.pages || 1);
                const current = Number(this.page || 1);
                const maxButtons = 5;

                if (total <= maxButtons) {
                    return Array.from({ length: total }, (_, i) => i + 1);
                }

                let start = Math.max(1, current - 2);
                let end = start + maxButtons - 1;

                if (end > total) {
                    end = total;
                    start = end - maxButtons + 1;
                }

                return Array.from({ length: end - start + 1 }, (_, i) => start + i);
            },

            rangeText() {
                if (this.total === 0) return "0 من 0";
                const start = (this.page - 1) * this.pageSize + 1;
                const end = Math.min(this.page * this.pageSize, this.total);
                return `${start} - ${end} من ${this.total}`;
            },

            // URL and text helpers
            fillUrl(template, data) {
                if (!template || !data) return template || "";
                return template.replace(/\{(\w+)\}/g, (match, key) => data[key] || "");
            },

            escapeHtml(unsafe) {
                return String(unsafe || "")
                    .replace(/&/g, "&amp;")
                    .replace(/</g, "&lt;")
                    .replace(/>/g, "&gt;")
                    .replace(/"/g, "&quot;")
                    .replace(/'/g, "&#039;");
            },

            // Toast notifications
            showToast(message, type = 'info') {
                const toast = document.createElement('div');

                const bg =
                    type === 'error'
                        ? 'linear-gradient(135deg,#ef4444,#dc2626)'
                        : type === 'success'
                            ? 'linear-gradient(135deg,#16a34a,#15803d)'
                            : 'linear-gradient(135deg,#3b82f6,#2563eb)';

                toast.innerHTML = `
        <div style="display:flex;align-items:center;gap:8px;">
            <span>${message}</span>
        </div>
        <button type="button"
                class="toast-close-btn"
                style="
                    position:absolute;
                    top:6px;
                    left:8px;
                    background:none;
                    border:none;
                    color:white;
                    font-size:18px;
                    line-height:1;
                    cursor:pointer;
                    padding:0;
                    margin:0;">
            ×
        </button>
    `;

                Object.assign(toast.style, {
                    position: 'fixed',
                    top: '10px',
                    left: '20px',
                    padding: '0.65rem 1.6rem 0.65rem 2rem',
                    borderRadius: '6px',
                    color: 'white',
                    background: bg,
                    zIndex: '99999',
                    fontSize: '0.95rem',
                    fontWeight: '500',
                    boxShadow: '0 6px 18px rgba(0,0,0,0.2)',
                    backdropFilter: 'blur(6px)',
                    border: '1px solid rgba(255,255,255,0.15)',
                    direction: 'rtl',
                    width: 'fit-content',
                    maxWidth: '420px'
                });

                toast.style.display = 'inline-block';
                toast.style.whiteSpace = 'nowrap';

                document.body.appendChild(toast);

                let timer;

                const closeToast = () => {
                    toast.style.opacity = '0';
                    toast.style.transition = '0.3s';
                    setTimeout(() => toast.remove(), 300);
                };

                const startTimer = () => {
                    timer = setTimeout(closeToast, 3000);
                };

                const stopTimer = () => {
                    clearTimeout(timer);
                };

                toast.addEventListener('mouseenter', stopTimer);
                toast.addEventListener('mouseleave', startTimer);

                const closeBtn = toast.querySelector('.toast-close-btn');
                closeBtn.addEventListener('click', closeToast);

                startTimer();
            },

            // Display controls
            toggleFullscreen() {
                const element = this.$el;
                if (!document.fullscreenElement) {
                    element.requestFullscreen?.().catch(() => {});
                } else {
                    document.exitFullscreen?.();
                }
            },

            changeDensity(density) {
                this.$el.setAttribute('data-density', density);
                this.savePreferences();
            },

            // Print workflow
            showBusyPrint(message = "جاري تجهيز البيانات للطباعة...", opts = {}) {
                const isHtml = (opts.isHtml === true);

                this.modal.open = true;
                window.__sfTableActive = this;
                window.__sfTableLastActive = this;

                this.modal.title = opts.title || "طباعة";
                this.modal.message = message;

                this.modal.messageClass = opts.messageClass || "border border-sky-200 bg-sky-50 text-sky-700";
                this.modal.messageIcon = opts.messageIcon || "";

                this.modal.messageIsHtml = isHtml;

                this.modal.error = null;
                this.modal.html = "";
                this.modal.loading = true;

            },

            hideBusyPrint() {
                this.modal.loading = false;
                this.modal.open = false;
            },

            bindPrintListenerOnce() {
                if (window.__sfPrintBound) return;
                window.__sfPrintBound = true;

                window.addEventListener("message", (ev) => {
                    if (ev.origin !== window.location.origin) return;

                    const msg = ev.data || {};
                    if (msg.type !== "sf-print") return;

                    const table = window.__sfTableActive || window.__sfTableLastActive;
                    if (!table) return;

                    if (msg.stage === "ready" || msg.stage === "print-opened" || msg.stage === "print-closed") {
                        table.hideBusyPrint?.();
                        return;
                    }

                    if (msg.stage === "error") {
                        table.hideBusyPrint?.();
                        table.showToast?.(msg.message || "فشل تجهيز الطباعة", "error");
                        return;
                    }
                });
            }

        }));

        window.sfPrintWithBusy = window.sfPrintWithBusy || function (table, options) {
            options = options || {};

            if (!table) return false;

            const defaultHtml = `
        <div class="space-y-3 text-center">
          <div class="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-blue-400 text-white text-sm">
            جاري تجهيز البيانات للطباعة الرجاء الانتظار
            <i class="fa fa-spinner animate-spin"></i>
          </div>

          <div class="text-base">
            <span class="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-red-400 text-white text-sm">
              وقت الطباعة يعتمد على عدد السجلات المراد طباعتها وسرعة الاتصال
              <i class="fa fa-bolt"></i>
            </span>
          </div>

          <div class="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-green-50 text-green-700 text-sm">
            حفاظًا على البيئة وتماشياً مع مستهدفات رؤية 2030 نأمل تقليل الطباعة
            <i class="fa fa-leaf"></i>
          </div>
        </div>
    `;

            const busy = options.busy || {};
            const pdfVal = (options.pdf ?? options.pdfVal ?? 1);

            if (options.messageText) {
                table.showBusyPrint(options.messageText, {
                    isHtml: false,
                    title: busy.title || "الطباعة",
                    icon: (busy.icon === undefined) ? "fa fa-print" : busy.icon,
                    className: busy.className || "border border-sky-200 bg-sky-50 text-sky-700"
                });
            } else {
                table.showBusyPrint(options.messageHtml || defaultHtml, {
                    isHtml: true,
                    title: busy.title || "الطباعة",
                    icon: (busy.icon === undefined) ? "fa fa-print" : busy.icon,
                    className: busy.className || "border border-sky-200 bg-sky-50 text-sky-700"
                });
            }

            let url;
            try {
                const u = new URL(window.location.href);
                u.searchParams.set('pdf', String(pdfVal));

                if (options.extraParams && typeof options.extraParams === "object") {
                    Object.keys(options.extraParams).forEach(k => {
                        const v = options.extraParams[k];
                        if (v === null || v === undefined) return;
                        u.searchParams.set(k, String(v));
                    });
                }

                const reservedKeys = new Set([
                    "pdf",
                    "pdfVal",
                    "busy",
                    "messageText",
                    "messageHtml",
                    "extraParams"
                ]);

                Object.keys(options).forEach(k => {
                    if (reservedKeys.has(k)) return;

                    const v = options[k];
                    if (v === null || v === undefined) return;

                    u.searchParams.set(k, String(v));
                });

                url = u.toString();
            } catch (e) {
                table.hideBusyPrint();
                table.showToast("تعذر تجهيز رابط الطباعة", "error");
                return false;
            }

            table.__printHandle = sfOpenPrint(url, {
                onBeforePrint: () => table.hideBusyPrint(),
                onAfterPrint: () => table.hideBusyPrint(),
                onError: (e) => {
                    table.hideBusyPrint();
                    table.showToast('تعذر فتح الطباعة: ' + (e?.message || e), 'error');
                }
            });

            if (!table.__printHandle) {
                table.hideBusyPrint();
                table.showToast('تعذر بدء الطباعة', 'error');
                return false;
            }

            return true;
        };

    };

    if (window.Alpine) {
        register();
    } else {
        document.addEventListener("alpine:init", register);
    }
})();

window.sfRouteEditForm = function (table, act, row) {
    if (!table || !act) return;

    act.__cancelOpen = false;

    const meta = act.Meta || act.meta;
    if (!meta) return;

    const routeBy = meta.routeBy || meta.RouteBy;
    const routes = meta.routes || meta.Routes;
    if (!routeBy || !routes) return;

    const r = row || table.getSelectedRowFromCurrentData?.() || (table.getSelectedRows?.()[0] ?? null);
    if (!r) return;

    const key = String(r?.[routeBy] ?? "");
    const route = routes[key] || routes["*"];

    if (!route) {

        act.ModalTitle = act.modalTitle = "";
        act.ModalMessage = act.modalMessage = "";

        const of0 = act.OpenForm || act.openForm;
        if (of0) {
            of0.Title = of0.title = "";
            of0.Fields = of0.fields = [];
        }

        act.__cancelOpen = true;

        return;
    }

    if (route.title != null) {
        act.ModalTitle = route.title;
        act.modalTitle = route.title;

        const of = act.OpenForm || act.openForm;
        if (of) {
            of.Title = route.title;
            of.title = route.title;
        }
    }

    if (route.message != null) {
        act.ModalMessage = route.message;
        act.modalMessage = route.message;
    }

    const of = act.OpenForm || act.openForm;
    if (of && route.fields) {
        of.Fields = route.fields;
        of.fields = route.fields;
    }
};

(function () {
    if (window.__sfFileUploadDelegated) return;
    window.__sfFileUploadDelegated = true;

    const MB = 1024 * 1024;

    function formatSize(bytes) {
        if (!Number.isFinite(bytes)) return "";
        const kb = 1024, mb = kb * 1024;
        if (bytes >= mb) return (bytes / mb).toFixed(2) + " MB";
        if (bytes >= kb) return (bytes / kb).toFixed(1) + " KB";
        return bytes + " B";
    }

    function extOf(name) {
        const i = (name || "").lastIndexOf(".");
        return i > -1 ? name.slice(i + 1).toLowerCase() : "";
    }

    function hasDoubleExtension(name) {
        const n = (name || "").toLowerCase();
        const parts = n.split(".").filter(Boolean);
        return parts.length >= 3;
    }

    function parseCsv(s) {
        return (s || "")
            .split(",")
            .map(x => x.trim())
            .filter(Boolean);
    }

    function getCfg(root) {
        const ds = root.dataset;
        const maxFiles = ds.maxFiles ? Number(ds.maxFiles) : null;
        const maxFileSizeMb = ds.maxFileSize ? Number(ds.maxFileSize) : null;
        const maxTotalSizeMb = ds.maxTotalSize ? Number(ds.maxTotalSize) : null;

        return {
            name: ds.name || "",
            readonly: ds.readonly === "true",
            allowEmpty: ds.allowEmpty === "true",
            maxFiles: Number.isFinite(maxFiles) ? maxFiles : null,
            maxFileSizeBytes: Number.isFinite(maxFileSizeMb) ? (maxFileSizeMb * MB) : null,
            maxTotalBytes: Number.isFinite(maxTotalSizeMb) ? (maxTotalSizeMb * MB) : null,

            mimeTypes: parseCsv(ds.mimeTypes),
            blockDouble: ds.blockDouble === "true",

            showSize: ds.showSize === "true",
            showRemove: ds.showRemove === "true",
            showDownload: ds.showDownload === "true",
            showPreviewBtn: ds.showPreviewBtn === "true",
            showProgress: ds.showProgress === "true",

            enablePreview: ds.preview === "true",
            previewMode: (ds.previewMode || "modal").toLowerCase(),
            previewTypes: parseCsv(ds.previewTypes).map(x => x.toLowerCase()),
            previewTitle: ds.previewTitle || "معاينة",
            previewHeight: Number(ds.previewHeight) || 600,

            previewPaper: (ds.previewPaper || "").toLowerCase(),
            previewOrientation: (ds.previewOrientation || "portrait").toLowerCase(),

            autoUpload: ds.autoUpload === "true",
            uploadCategory: ds.uploadCategory || "",
            bindEntity: ds.bindEntity || "",

            uploadApi: ds.uploadApi || "",
            previewApi: ds.previewApi || "",
            downloadApi: ds.downloadApi || "",
            deleteApi: ds.deleteApi || "",

            errSize: ds.errorSize || "حجم الملف أكبر من المسموح",
            errType: ds.errorType || "صيغة الملف غير مدعومة",
            errCount: ds.errorCount || "عدد الملفات تجاوز الحد المسموح",
            errTotal: ds.errorTotal || "إجمالي الملفات أكبر من المسموح"
        };
    }

    function canPreviewLocal(cfg, fileName) {
        if (!cfg.enablePreview) return false;
        if (!cfg.previewTypes.length) return false;
        const ext = "." + extOf(fileName);
        return cfg.previewTypes.includes(ext);
    }

    function computePaperSize(paper, orientation) {
        const p = (paper || "").toLowerCase();
        const orient = (orientation || "portrait").toLowerCase();
        if (p !== "a4") return null;

        const ratioPortrait = 210 / 297;
        const maxH = Math.max(320, Math.floor(window.innerHeight - 36));
        const maxW = Math.max(320, Math.floor(window.innerWidth - 36));

        let w, h;
        if (orient === "landscape") {
            const r = 297 / 210;
            w = Math.min(maxW, Math.floor(maxH * r));
            h = Math.floor(w / r);
            if (h > maxH) { h = maxH; w = Math.floor(h * r); }
        } else {
            w = Math.min(maxW, Math.floor(maxH * ratioPortrait));
            h = Math.floor(w / ratioPortrait);
            if (h > maxH) { h = maxH; w = Math.floor(h * ratioPortrait); }
        }
        return { w, h };
    }

    (function () {
        if (window.__sfFileUploadReserveFix) return;
        window.__sfFileUploadReserveFix = true;

        function updateOne(root) {
            const bar = root.querySelector(".sf-file-bar");
            const btn = root.querySelector(".sf-file-btn");
            if (!bar || !btn) return;

            const w = Math.ceil(btn.getBoundingClientRect().width);
            root.style.setProperty("--sf-choose-reserve", w + "px");
        }

        function updateAll() {
            document.querySelectorAll(".sf-file-upload").forEach(updateOne);
        }

        document.addEventListener("DOMContentLoaded", updateAll);
        window.addEventListener("load", updateAll);
        window.addEventListener("resize", updateAll);

        const mo = new MutationObserver(() => updateAll());
        mo.observe(document.documentElement, { childList: true, subtree: true });
    })();

    function ensurePreviewModal() {
        let m = document.getElementById("sf-preview-modal");
        if (m) return m;

        m = document.createElement("div");
        m.id = "sf-preview-modal";
        m.className = "sf-preview hidden";
        m.innerHTML = `
      <div class="sf-preview-backdrop" data-sf-preview-close></div>
      <div class="sf-preview-dialog" role="dialog" aria-modal="true">
        <div class="sf-preview-head">
          <div class="sf-preview-title"></div>
          <button type="button" class="sf-preview-close" data-sf-preview-close>×</button>
        </div>
        <div class="sf-preview-body"></div>
      </div>`;
        document.body.appendChild(m);

        m.addEventListener("click", (e) => {
            if (e.target.closest("[data-sf-preview-close]")) hidePreview();
        });

        document.addEventListener("keydown", (e) => {
            if (e.key === "Escape") hidePreview();
        });

        window.addEventListener("resize", () => {
            const mm = document.getElementById("sf-preview-modal");
            if (!mm || mm.classList.contains("hidden")) return;
            const dialog = mm.querySelector(".sf-preview-dialog");
            if (!dialog) return;
            const paper = dialog.dataset.paper || "";
            const orientation = dialog.dataset.orientation || "";
            if (!paper) return;
            const size = computePaperSize(paper, orientation);
            if (!size) return;
            dialog.style.setProperty("--sfPreviewW", `${size.w}px`);
            dialog.style.setProperty("--sfPreviewH", `${size.h}px`);
        });

        return m;
    }

    function showPreview({ title, url, kind, height, paper, orientation }) {
        const m = ensurePreviewModal();
        m.querySelector(".sf-preview-title").textContent = title || "معاينة";

        const body = m.querySelector(".sf-preview-body");
        body.innerHTML = "";

        const dialog = m.querySelector(".sf-preview-dialog");
        dialog.dataset.paper = paper || "";
        dialog.dataset.orientation = orientation || "";

        const size = paper ? computePaperSize(paper, orientation) : null;
        if (size) {
            dialog.style.setProperty("--sfPreviewW", `${size.w}px`);
            dialog.style.setProperty("--sfPreviewH", `${size.h}px`);
        } else {
            dialog.style.removeProperty("--sfPreviewW");
            dialog.style.setProperty("--sfPreviewH", `${Number(height) || 600}px`);
        }

        if (kind === "img") {
            const img = document.createElement("img");
            img.src = url;
            img.className = "sf-preview-img";
            body.appendChild(img);
        } else {
            const iframe = document.createElement("iframe");
            iframe.src = url;
            iframe.className = "sf-preview-frame";
            iframe.setAttribute("title", title || "Preview");
            body.appendChild(iframe);
        }

        m.classList.remove("hidden");
        document.body.classList.add("sf-preview-open");
    }

    function hidePreview() {
        const m = document.getElementById("sf-preview-modal");
        if (!m) return;
        m.classList.add("hidden");
        document.body.classList.remove("sf-preview-open");
        const body = m.querySelector(".sf-preview-body");
        if (body) body.innerHTML = "";
        const dialog = m.querySelector(".sf-preview-dialog");
        if (dialog) {
            dialog.style.removeProperty("--sfPreviewW");
            dialog.style.removeProperty("--sfPreviewH");
            dialog.dataset.paper = "";
            dialog.dataset.orientation = "";
        }
    }

    function setErrors(root, msgs) {
        const box = root.querySelector(".sf-file-errors");
        if (!box) return;
        if (!msgs || !msgs.length) {
            box.classList.add("hidden");
            box.innerHTML = "";
            return;
        }
        box.classList.remove("hidden");
        box.innerHTML = msgs.map(m => `<div class="sf-file-error">${m}</div>`).join("");
    }

    function validateFiles(cfg, files) {
        const errs = [];

        if (cfg.maxFiles && files.length > cfg.maxFiles) errs.push(cfg.errCount);

        let total = 0;
        for (const f of files) {
            total += (f.size || 0);

            if (!cfg.allowEmpty && (f.size === 0)) errs.push(cfg.errSize);
            if (cfg.maxFileSizeBytes && f.size > cfg.maxFileSizeBytes) errs.push(cfg.errSize);

            if (cfg.mimeTypes.length) {
                if (f.type && !cfg.mimeTypes.includes(f.type)) errs.push(cfg.errType);
            }

            if (cfg.blockDouble && hasDoubleExtension(f.name)) errs.push(cfg.errType);
        }

        if (cfg.maxTotalBytes && total > cfg.maxTotalBytes) errs.push(cfg.errTotal);

        return [...new Set(errs)];
    }

    function renderLocal(root, input) {
        const cfg = getCfg(root);

        const picked = root.querySelector(".sf-file-picked");
        const list = root.querySelector(".sf-file-list");
        if (!picked || !list) return;

        const files = Array.from(input.files || []);
        list.innerHTML = "";

        if (!files.length) {
            picked.textContent = "لم يتم اختيار ملفات";
            setErrors(root, []);
            return;
        }

        const errs = validateFiles(cfg, files);
        setErrors(root, errs);

        picked.textContent = files.length === 1 ? files[0].name : `${files.length} ملفات`;

        files.forEach((f, idx) => {
            const row = document.createElement("div");
            row.className = "sf-file-item";

            const previewable = canPreviewLocal(cfg, f.name);

            row.innerHTML = `
        <div class="sf-file-left">
          <button type="button" class="sf-file-namebtn" data-kind="local" data-i="${idx}" title="${f.name}">
            ${f.name}
          </button>
          ${cfg.showSize ? `<div class="sf-file-size">${formatSize(f.size)}</div>` : ``}
        </div>

        <div class="sf-file-actions">
          ${cfg.showPreviewBtn && previewable ? `<button type="button" class="sf-file-action sf-file-preview" data-kind="local" data-i="${idx}">معاينة</button>` : ``}
          ${cfg.showRemove && !cfg.readonly ? `<button type="button" class="sf-file-action sf-file-remove" data-kind="local" data-i="${idx}">حذف</button>` : ``}
        </div>`;
            list.appendChild(row);
        });
    }

    function rebuildInputFiles(input, files) {
        const dt = new DataTransfer();
        files.forEach(f => dt.items.add(f));
        input.files = dt.files;
    }

    function getFileByIndex(root, idx) {
        const input = root.querySelector(".sf-file-input");
        if (!input) return null;
        const files = Array.from(input.files || []);
        return { input, files, file: files[idx] || null };
    }

    function getUploadedHidden(root) {
        return root.querySelector(".sf-file-uploaded");
    }

    function getUploadedIds(root) {
        const h = getUploadedHidden(root);
        if (!h) return [];
        try { return JSON.parse(h.value || "[]") || []; } catch { return []; }
    }

    function setUploadedIds(root, ids) {
        const h = getUploadedHidden(root);
        if (!h) return;
        h.value = JSON.stringify(ids || []);
    }

    function xhrUpload(url, formData, onProgress) {
        const xhr = new XMLHttpRequest();
        const p = new Promise((resolve, reject) => {
            xhr.open("POST", url, true);

            xhr.upload.onprogress = (e) => {
                if (!e.lengthComputable) return;
                const pct = Math.round((e.loaded / e.total) * 100);
                onProgress && onProgress(pct);
            };

            xhr.onload = () => {
                if (xhr.status >= 200 && xhr.status < 300) {
                    try { resolve(JSON.parse(xhr.responseText || "{}")); }
                    catch { resolve({}); }
                } else {
                    try {
                        const j = JSON.parse(xhr.responseText || "{}");
                        const msg = j.message || j.error || `Upload failed: ${xhr.status}`;
                        reject(new Error(msg));
                    } catch {
                        reject(new Error(`Upload failed: ${xhr.status}`));
                    }
                }
            };

            xhr.onerror = () => reject(new Error("Upload failed: network error"));
            xhr.onabort = () => reject(new Error("Upload aborted"));
            xhr.send(formData);
        });

        return { promise: p, abort: () => { try { xhr.abort(); } catch { } } };
    }

    function renderUploaded(root, items) {
        const cfg = getCfg(root);
        const picked = root.querySelector(".sf-file-picked");
        const list = root.querySelector(".sf-file-list");
        if (!picked || !list) return;

        list.innerHTML = "";
        if (!items || !items.length) {
            picked.textContent = "لم يتم اختيار ملفات";
            return;
        }

        picked.textContent = items.length === 1 ? items[0].fileName : `${items.length} ملفات`;

        items.forEach((it) => {
            const row = document.createElement("div");
            row.className = "sf-file-item";

            const previewable = cfg.enablePreview && canPreviewLocal(cfg, it.fileName);
            row.innerHTML = `
        <div class="sf-file-left">
          <button type="button" class="sf-file-namebtn" data-kind="uploaded" data-id="${it.id}" title="${it.fileName}">
            ${it.fileName}
          </button>
          ${cfg.showSize ? `<div class="sf-file-size">${formatSize(it.size)}</div>` : ``}
        </div>
        <div class="sf-file-actions">
          ${cfg.showPreviewBtn && previewable ? `<button type="button" class="sf-file-action sf-file-preview" data-kind="uploaded" data-id="${it.id}">معاينة</button>` : ``}
          ${cfg.showRemove && !cfg.readonly ? `<button type="button" class="sf-file-action sf-file-remove" data-kind="uploaded" data-id="${it.id}">حذف</button>` : ``}
        </div>`;
            list.appendChild(row);
        });
    }

    async function doAutoUpload(root, input) {
        const cfg = getCfg(root);

        if (root.__sfUploadAbort && typeof root.__sfUploadAbort === "function") {
            root.__sfUploadAbort();
            root.__sfUploadAbort = null;
        }
        if (root.__sfUploading) {
            return;
        }
        root.__sfUploading = true;

        const files = Array.from(input.files || []);
        const errs = validateFiles(cfg, files);
        setErrors(root, errs);
        if (errs.length) { root.__sfUploading = false; return; }

        if (!cfg.uploadApi) {
            setErrors(root, ["UploadEndpoint غير معرف"]);
            root.__sfUploading = false;
            return;
        }

        const meta = root.querySelector(".sf-file-meta");
        let progEl = meta ? meta.querySelector(".sf-file-progress") : null;
        if (cfg.showProgress && meta) {
            if (!progEl) {
                progEl = document.createElement("div");
                progEl.className = "sf-file-progress";
                progEl.textContent = "";
                meta.appendChild(progEl);
            }
            progEl.textContent = "0%";
        }

        const fd = new FormData();
        files.forEach(f => fd.append("files", f));

        fd.append("fieldName", cfg.name);
        fd.append("maxFiles", String(cfg.maxFiles ?? ""));
        fd.append("maxFileSizeMb", String(cfg.maxFileSizeBytes ? (cfg.maxFileSizeBytes / MB) : ""));
        fd.append("maxTotalSizeMb", String(cfg.maxTotalBytes ? (cfg.maxTotalBytes / MB) : ""));
        fd.append("allowEmptyFile", String(cfg.allowEmpty));
        fd.append("allowedMimeTypes", cfg.mimeTypes.join(","));
        fd.append("blockDoubleExtension", String(cfg.blockDouble));

        fd.append("uploadCategory", cfg.uploadCategory);
        fd.append("bindToEntityId", cfg.bindEntity);

        fd.append("uploadFolder", root.dataset.uploadFolder || "");
        fd.append("uploadSubFolder", root.dataset.uploadSubfolder || "");
        fd.append("fileNameMode", root.dataset.fileNameMode || "uuid");
        fd.append("overwrite", root.dataset.overwrite || "false");
        fd.append("keepOriginalExtension", root.dataset.keepExt || "true");
        fd.append("sanitizeFileName", root.dataset.sanitize || "true");

        try {
            const { promise, abort } = xhrUpload(cfg.uploadApi, fd, (pct) => {
                if (cfg.showProgress && progEl) progEl.textContent = pct + "%";
            });
            root.__sfUploadAbort = abort;

            const res = await promise;
            const uploaded = Array.isArray(res.files) ? res.files : [];

            setUploadedIds(root, uploaded.map(x => x.id));
            renderUploaded(root, uploaded);

            setErrors(root, []);
            if (cfg.showProgress && progEl) progEl.textContent = "تم الرفع ✅";
        } catch (e) {
            const msg = String(e?.message || e);
            if (!/aborted/i.test(msg)) setErrors(root, [msg]);
            if (cfg.showProgress && progEl) progEl.textContent = "";
        } finally {
            root.__sfUploading = false;
            root.__sfUploadAbort = null;
        }
    }

    document.addEventListener("change", (e) => {
        const input = e.target;
        if (!(input instanceof HTMLInputElement)) return;
        if (input.type !== "file" || !input.classList.contains("sf-file-input")) return;

        const root = input.closest(".sf-file-upload");
        if (!root) return;

        const cfg = getCfg(root);

        if (cfg.readonly) {
            input.value = "";
            renderLocal(root, input);
            return;
        }

        if (cfg.autoUpload) {
            setUploadedIds(root, []);
            doAutoUpload(root, input);
        } else {
            renderLocal(root, input);
        }
    });

    document.addEventListener("click", (e) => {
        const root = e.target.closest(".sf-file-upload");
        if (!root) return;

        const cfg = getCfg(root);
        const input = root.querySelector(".sf-file-input");
        if (!input) return;

        const btn = e.target.closest(".sf-file-preview, .sf-file-namebtn, .sf-file-download, .sf-file-remove");
        if (!btn) return;

        const kind = btn.dataset.kind || (btn.classList.contains("sf-file-preview") ? btn.dataset.kind : "local");

        if (!cfg.autoUpload || kind === "local") {
            if (btn.classList.contains("sf-file-preview") || btn.classList.contains("sf-file-namebtn")) {
                const idx = Number(btn.dataset.i);
                if (!Number.isFinite(idx)) return;

                const got = getFileByIndex(root, idx);
                if (!got || !got.file) return;

                const file = got.file;
                if (!canPreviewLocal(cfg, file.name)) return;

                const url = URL.createObjectURL(file);
                const isImg = /\.(png|jpe?g|gif|webp|bmp)$/i.test(file.name);

                if (cfg.previewMode === "newtab") {
                    window.open(url, "_blank");
                    setTimeout(() => URL.revokeObjectURL(url), 60_000);
                } else {
                    showPreview({
                        title: cfg.previewTitle,
                        url,
                        kind: isImg ? "img" : "doc",
                        height: cfg.previewHeight,
                        paper: cfg.previewPaper || "",
                        orientation: cfg.previewOrientation
                    });
                    setTimeout(() => URL.revokeObjectURL(url), 60_000);
                }
                return;
            }

            if (btn.classList.contains("sf-file-remove")) {
                if (cfg.readonly) return;

                const idx = Number(btn.dataset.i);
                if (!Number.isFinite(idx)) return;

                const files = Array.from(input.files || []);
                files.splice(idx, 1);
                rebuildInputFiles(input, files);
                renderLocal(root, input);
                return;
            }

            return;
        }

        const id = btn.dataset.id;
        if (!id) return;

        if (btn.classList.contains("sf-file-preview") || btn.classList.contains("sf-file-namebtn")) {
            if (!cfg.previewApi) return;

            const url = `${cfg.previewApi}?id=${encodeURIComponent(id)}`;
            if (cfg.previewMode === "newtab") {
                window.open(url, "_blank");
            } else {
                const name = (btn.getAttribute("title") || btn.textContent || "").trim();
                const isImg = /\.(png|jpe?g|gif|webp|bmp)$/i.test(name);

                showPreview({
                    title: cfg.previewTitle,
                    url,
                    kind: isImg ? "img" : "doc",
                    height: cfg.previewHeight,
                    paper: cfg.previewPaper || "",
                    orientation: cfg.previewOrientation
                });
            }
            return;
        }

        if (btn.classList.contains("sf-file-remove")) {
            if (cfg.readonly) return;
            if (!cfg.deleteApi) return;

            fetch(`${cfg.deleteApi}?id=${encodeURIComponent(id)}`, { method: "DELETE" })
                .then(r => r.ok ? r.json().catch(() => ({})) : Promise.reject(new Error("Delete failed")))
                .then(() => {
                    const ids = getUploadedIds(root).filter(x => x !== id);
                    setUploadedIds(root, ids);
                    const row = btn.closest(".sf-file-item");
                    if (row) row.remove();
                })
                .catch(() => setErrors(root, ["فشل حذف الملف"]));

            return;
        }
    });

    window.SFFileUpload = window.SFFileUpload || {};
    window.SFFileUpload.setErrors = setErrors;
    window.SFFileUpload.validateFiles = validateFiles;
    window.SFFileUpload.getCfg = getCfg;
})();

(function () {
    if (window.__sfModalMultipartSubmitFix) return;
    window.__sfModalMultipartSubmitFix = true;

    const SUCCESS_TOAST_MS = 3000;
    const MAX_WAIT_CLOSE_MS = 1200;

    function isMultipartForm(form) {
        const enc = (form.getAttribute("enctype") || "").toLowerCase();
        if (enc.includes("multipart/form-data")) return true;
        return !!form.querySelector('input[type="file"]');
    }

    function showToast(type, msg, timeoutMs) {
        const text = (msg || "").toString().trim();
        if (!text) return;

        const t = window.toastr;
        if (t && typeof t[type] === "function") {
            const old = t.options ? { ...t.options } : null;
            t.options = t.options || {};
            t.options.timeOut = Number(timeoutMs) > 0 ? Number(timeoutMs) : 3000;
            t.options.extendedTimeOut = 1200;
            t[type](text);
            if (old) t.options = old;
            return;
        }
    }

    function setFileInlineError(form, msg) {
        const root = form.querySelector(".sf-file-upload");
        if (!root) return;
        if (window.SFFileUpload && typeof window.SFFileUpload.setErrors === "function") {
            window.SFFileUpload.setErrors(root, msg ? [String(msg)] : []);
        }
    }

    async function readResponseSmart(res) {
        const ct = (res.headers.get("content-type") || "").toLowerCase();
        if (ct.includes("application/json")) {
            const j = await res.json().catch(() => null);
            return { kind: "json", json: j };
        }
        const t = await res.text().catch(() => "");
        return { kind: "text", text: t };
    }

    function tryCloseModal(form) {
        const modal = form.closest(".sf-modal");
        if (!modal) return { closed: false, modal: null };

        try {
            if (modal.__x && modal.__x.$data && typeof modal.__x.$data.closeModal === "function") {
                modal.__x.$data.closeModal();
                return { closed: true, modal };
            }
        } catch { }

        return { closed: false, modal };
    }

    function waitForModalGone(modal, timeoutMs) {
        return new Promise((resolve) => {
            if (!modal) return resolve(false);

            const isGone = () => {
                if (!document.body.contains(modal)) return true;

                if (modal.classList.contains("hidden")) return true;
                if (modal.hasAttribute("hidden")) return true;
                if (modal.getAttribute("aria-hidden") === "true") return true;

                const cs = getComputedStyle(modal);
                if (cs.display === "none" || cs.visibility === "hidden" || Number(cs.opacity) === 0) return true;

                return false;
            };

            if (isGone()) return resolve(true);

            const t0 = Date.now();
            const mo = new MutationObserver(() => {
                if (isGone()) {
                    try { mo.disconnect(); } catch { }
                    resolve(true);
                } else if (Date.now() - t0 > timeoutMs) {
                    try { mo.disconnect(); } catch { }
                    resolve(false);
                }
            });

            try {
                mo.observe(document.body, {
                    childList: true,
                    subtree: true,
                    attributes: true,
                    attributeFilter: ["class", "style", "hidden", "aria-hidden"]
                });
            } catch { }

            setTimeout(() => {
                try { mo.disconnect(); } catch { }
                resolve(isGone());
            }, Math.max(200, timeoutMs));
        });
    }

    function lockForm(form) {
        if (form.__sfSubmitting) return false;
        form.__sfSubmitting = true;

        const btns = Array.from(form.querySelectorAll('button[type="submit"], input[type="submit"]'));
        form.__sfPrevDisabled = btns.map(b => ({ el: b, disabled: b.disabled }));
        btns.forEach(b => (b.disabled = true));

        return true;
    }

    function unlockForm(form) {
        form.__sfSubmitting = false;

        const prev = form.__sfPrevDisabled || [];
        prev.forEach(x => { try { x.el.disabled = x.disabled; } catch { } });
        form.__sfPrevDisabled = null;

        if (form.__sfAbort && typeof form.__sfAbort.abort === "function") {
            form.__sfAbort = null;
        }
    }

    async function postFormData(form) {
        const action = form.getAttribute("action") || window.location.href;
        const method = (form.getAttribute("method") || "POST").toUpperCase();

        setFileInlineError(form, "");

        if (form.__sfAbort && typeof form.__sfAbort.abort === "function") {
            try { form.__sfAbort.abort(); } catch { }
        }
        const ac = new AbortController();
        form.__sfAbort = ac;

        const fd = new FormData(form);
        const token = form.querySelector('input[name="__RequestVerificationToken"]')?.value;

        const res = await fetch(action, {
            method,
            body: fd,
            headers: token ? { "RequestVerificationToken": token } : undefined,
            credentials: "same-origin",
            signal: ac.signal
        });

        if (res.redirected) {
            window.location.href = res.url;
            return true;
        }

        const payload = await readResponseSmart(res);

        if (payload.kind === "json" && payload.json) {
            const j = payload.json || {};
            const ok = (res.ok && (j.ok !== false)) || (j.ok === true);

            if (ok) {
                const msg = j.message || "تم الحفظ بنجاح.";

                const { closed, modal } = tryCloseModal(form);
                if (closed) await waitForModalGone(modal, MAX_WAIT_CLOSE_MS);

                showToast("success", msg, SUCCESS_TOAST_MS);

                setTimeout(() => window.location.reload(), SUCCESS_TOAST_MS + 250);
                return true;
            } else {
                const msg = j.message || j.error || "حدث خطأ.";
                showToast("error", msg, 3500);
                setFileInlineError(form, msg);
                return false;
            }
        }

        if (res.ok) {
            const { closed, modal } = tryCloseModal(form);
            if (closed) await waitForModalGone(modal, MAX_WAIT_CLOSE_MS);

            showToast("success", "تم الحفظ بنجاح.", SUCCESS_TOAST_MS);
            setTimeout(() => window.location.reload(), SUCCESS_TOAST_MS + 250);
            return true;
        }

        const errText = (payload.kind === "text" ? payload.text : "") || "";
        showToast("error", "تعذر الإرسال. تحقق من الملف وحاول مرة أخرى.", 4000);
        setFileInlineError(form, "تعذر الإرسال. تحقق من الملف وحاول مرة أخرى.");
        return false;
    }

    document.addEventListener("submit", function (e) {
        const form = e.target;
        if (!(form instanceof HTMLFormElement)) return;
        if (!form.closest(".sf-modal")) return;
        if (!isMultipartForm(form)) return;

        e.preventDefault();
        e.stopPropagation();

        if (!lockForm(form)) return;

        postFormData(form)
            .then((ok) => {
                if (!ok) unlockForm(form);

            })
            .catch(err => {
                if (err && /aborted|abort/i.test(String(err))) return;
                showToast("error", "حدث خطأ غير متوقع أثناء الإرسال.", 4000);
                unlockForm(form);
            });
    }, true);
})();

window.sfMoneySarOnInput = function (el) {
    let v = (el.value || "");

    v = v.replace(/[^\d.]/g, "");

    const firstDot = v.indexOf(".");
    if (firstDot !== -1) {
        v = v.slice(0, firstDot + 1) + v.slice(firstDot + 1).replace(/\./g, "");
    }

    let [intPart, decPart] = v.split(".");

    intPart = (intPart || "").replace(/^0+(?=\d)/, "");

    if (decPart != null) decPart = decPart.slice(0, 2);

    el.value = decPart != null ? `${intPart}.${decPart}` : intPart;
};

window.sfToggle = function(el, forcedValue) {
    const d = el?.dataset || {};
    const value = (forcedValue != null)
        ? String(forcedValue).trim()
        : String(el?.value ?? "").trim();

    const group = d.sfToggleGroup;
    const mapStr = d.sfToggleMap || "";
    if (!group || !mapStr) return;

    const root = el.closest('form') || document;

    root.querySelectorAll(`[data-sf-toggle-group="${group}"]`)
        .forEach(x => x.closest('.form-group')?.style.setProperty('display', 'none'));

    if (!value) return;

    const rules = mapStr.split('|').map(s => s.trim()).filter(Boolean);
    const rule = rules.find(r => r.startsWith(value + ':'));
    if (!rule) return;

    const names = rule.slice((value + ':').length).split(',').map(s => s.trim()).filter(Boolean);
    names.forEach(n => {
        const target = root.querySelector(`[name="${n}"]`);
        if (target) target.closest('.form-group')?.style.setProperty('display', 'block');
    });
};

async function sfEnsureLazyExtraLoaded(action, row, ctx) {
    const meta = action?.Meta || action?.meta || {};
    if (!meta.useRowExtra || !meta.lazyExtra) return;

    const extraKey = meta.extraKey || "__extra";

    if (Array.isArray(row[extraKey]) && row[extraKey].length > 0) return;

    const endpoint = meta.extraEndpoint;
    const req = meta.extraRequest || {};
    const map = req.paramMap || {};

    const payload = {
        pageName_: req.pageName_,
        ActionType: req.ActionType,
        idaraID: ctx?.idaraID,
        entrydata: ctx?.entrydata,
        hostname: ctx?.hostname,
        tableIndex: req.tableIndex ?? null,
        parameters: {}
    };

    for (const [paramName, rowField] of Object.entries(map)) {
        payload.parameters[paramName] = row[rowField];
    }

    if (window.sfBusy?.show) sfBusy.show({ title: "جاري تحميل البيانات الإضافية..." });

    const res = await fetch(endpoint, {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            "X-Requested-With": "XMLHttpRequest"
        },
        body: JSON.stringify(payload)
    });

    const json = await res.json();

    if (window.sfBusy?.hide) sfBusy.hide();

    if (!json?.success) {
        if (window.sfToast?.error) sfToast.error(json?.message || "فشل تحميل البيانات الإضافية");
        row[extraKey] = [];
        return;
    }

    if (json.table?.rows) row[extraKey] = json.table.rows;
    else row[extraKey] = json.data || [];
}

(function () {
    var TAB_STORE_PREFIX = 'sf:activeTab:';

    function safeEsc(value) {
        if (window.CSS && window.CSS.escape) return window.CSS.escape(value);
        return String(value).replace(/"/g, '\\"');
    }

    function getTabStorageKey(groupKey) {
        var pageKey = window.location.pathname + window.location.search;
        return TAB_STORE_PREFIX + pageKey + ':' + groupKey;
    }

    function saveActiveTab(groupKey, tabKey) {
        if (!groupKey) return;
        try {
            sessionStorage.setItem(getTabStorageKey(groupKey), tabKey || '');
        } catch (e) { }
    }

    function loadActiveTab(groupKey) {
        if (!groupKey) return '';
        try {
            return sessionStorage.getItem(getTabStorageKey(groupKey)) || '';
        } catch (e) {
            return '';
        }
    }

    function syncTabHost(host) {
        if (!host) return;

        var activeKey = host.dataset.activeTab || "";
        var buttons = host.querySelectorAll('[data-role="tab-button"]');
        var panels = host.querySelectorAll('[data-role="tab-panel"]');

        buttons.forEach(function (btn) {
            var isActive = btn.dataset.tabKey === activeKey;
            btn.classList.toggle('is-active', isActive);
            btn.setAttribute('aria-selected', isActive ? 'true' : 'false');
            btn.setAttribute('tabindex', isActive ? '0' : '-1');
        });

        panels.forEach(function (panel) {
            var isActive = panel.dataset.tabKey === activeKey;
            panel.style.display = isActive ? '' : 'none';
            panel.classList.toggle('is-active', isActive);
            panel.setAttribute('aria-hidden', isActive ? 'false' : 'true');
        });

        if (host.dataset.tabGroup) {
            saveActiveTab(host.dataset.tabGroup, activeKey);
        }
    }

    function ensureTabHost(mount, groupKey) {
        if (!mount || !mount.parentNode) return null;

        var selector = '.sf-tab-panel[data-tab-group="' + safeEsc(groupKey) + '"]';
        var parent = mount.parentNode;
        var host = parent.querySelector(selector);

        if (host) return host;

        host = document.createElement('div');
        host.className = 'sf-tab-panel';
        host.setAttribute('data-tab-group', groupKey);
        host.innerHTML =
            '<div class="sf-tab-panel__header" data-role="tab-header"></div>' +
            '<div class="sf-tab-panel__body" data-role="tab-body"></div>';

        parent.insertBefore(host, mount);
        return host;
    }

    function initAlpineTree(el) {
        if (!el || !window.Alpine || typeof window.Alpine.initTree !== 'function') return;
        window.Alpine.initTree(el);
    }

    function cloneTemplateContent(tpl) {
        if (!tpl || !tpl.content) return null;
        return tpl.content.cloneNode(true);
    }

    function sortChildren(container, roleName) {
        Array.from(container.querySelectorAll('[data-role="' + roleName + '"]'))
            .sort(function (a, b) {
                return parseInt(a.dataset.tabOrder || '0', 10) - parseInt(b.dataset.tabOrder || '0', 10);
            })
            .forEach(function (el) {
                container.appendChild(el);
            });
    }

    function pickDefaultActive(host) {
        if (!host) return;

        var groupKey = host.dataset.tabGroup || '';
        var saved = loadActiveTab(groupKey);

        if (saved) {
            var savedBtn = host.querySelector('[data-role="tab-button"][data-tab-key="' + safeEsc(saved) + '"]');
            if (savedBtn) {
                host.dataset.activeTab = saved;
                return;
            }
            return;
        }

        var current = host.dataset.activeTab;
        if (current) {
            var exists = host.querySelector('[data-role="tab-button"][data-tab-key="' + safeEsc(current) + '"]');
            if (exists) return;
        }

        var preferred =
            host.querySelector('[data-role="tab-button"][data-tab-default="true"]') ||
            host.querySelector('[data-role="tab-button"]');

        if (preferred) {
            host.dataset.activeTab = preferred.dataset.tabKey || "";
        }
    }

    window.sfSetActiveTab = function (groupKey, tabKey) {
        if (!groupKey || !tabKey) return;

        var host = document.querySelector('.sf-tab-panel[data-tab-group="' + safeEsc(groupKey) + '"]');
        if (!host) {
            saveActiveTab(groupKey, tabKey);
            return;
        }

        host.dataset.activeTab = tabKey;
        syncTabHost(host);
    };

    window.sfInitTabGroup = function (mount) {
        if (!mount || mount.dataset.tabMounted === 'true') return;
        if (!mount.isConnected) return;

        var groupKey = mount.dataset.tabGroup || 'default';
        var tabKey = mount.dataset.tabKey || ('tab_' + Math.random().toString(36).slice(2));
        var isDefault = mount.dataset.tabDefault === 'true';
        var tabOrder = parseInt(mount.dataset.tabOrder || '0', 10);

        var sourceTpl = mount.querySelector('template[data-role="tab-source"]');
        if (!sourceTpl) return;

        var fragment = cloneTemplateContent(sourceTpl);
        if (!fragment) return;

        var button = fragment.querySelector('[data-role="tab-button"]');
        var panel = fragment.querySelector('[data-role="tab-panel"]');
        if (!button || !panel) return;

        var host = ensureTabHost(mount, groupKey);
        if (!host) return;

        host.dataset.tabGroup = groupKey;

        var header = host.querySelector('[data-role="tab-header"]');
        var body = host.querySelector('[data-role="tab-body"]');

        button.dataset.tabKey = tabKey;
        button.dataset.tabOrder = String(tabOrder);
        button.dataset.tabDefault = isDefault ? 'true' : 'false';

        panel.dataset.tabKey = tabKey;
        panel.dataset.tabOrder = String(tabOrder);

        if (!header.querySelector('[data-role="tab-button"][data-tab-key="' + safeEsc(tabKey) + '"]')) {
            header.appendChild(button);
        }

        if (!body.querySelector('[data-role="tab-panel"][data-tab-key="' + safeEsc(tabKey) + '"]')) {
            body.appendChild(panel);
            initAlpineTree(panel);
        }

        sortChildren(header, 'tab-button');
        sortChildren(body, 'tab-panel');

        var liveButton = header.querySelector('[data-role="tab-button"][data-tab-key="' + safeEsc(tabKey) + '"]');

        if (liveButton && !liveButton.dataset.tabBound) {
            liveButton.addEventListener('click', function (e) {
                e.preventDefault();
                e.stopPropagation();
                host.dataset.activeTab = tabKey;
                syncTabHost(host);
            });

            liveButton.dataset.tabBound = 'true';
        }

        if (!loadActiveTab(groupKey) && isDefault && !host.dataset.activeTab) {
            host.dataset.activeTab = tabKey;
        }

        mount.dataset.tabMounted = 'true';
        mount.style.display = 'none';
    };

    window.sfInitAllPendingTabMounts = function (root) {
        (root || document).querySelectorAll('.sf-tab-mount:not([data-tab-mounted="true"])')
            .forEach(function (mount) {
                window.sfInitTabGroup(mount);
            });
    };

    function bootTabs() {
        window.sfInitAllPendingTabMounts(document);

        document.querySelectorAll('.sf-tab-panel[data-tab-group]').forEach(function (host) {
            pickDefaultActive(host);

            if (host.dataset.activeTab) {
                syncTabHost(host);
            }
        });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', bootTabs);
    } else {
        bootTabs();
    }

    window.addEventListener('load', bootTabs);
    document.addEventListener('alpine:init', bootTabs);
    document.addEventListener('alpine:initialized', bootTabs);

    var observer = new MutationObserver(function (mutations) {
        var shouldBoot = false;

        for (var i = 0; i < mutations.length; i++) {
            var m = mutations[i];

            if (m.addedNodes && m.addedNodes.length) {
                shouldBoot = true;
                break;
            }
        }

        if (shouldBoot) {
            bootTabs();
        }
    });

    observer.observe(document.documentElement, {
        childList: true,
        subtree: true
    });
})();

(function () {
    function scrollTableBoxesToRight() {
        document.querySelectorAll('.table-box').forEach(function (box) {
            box.scrollLeft = box.scrollWidth;
        });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', scrollTableBoxesToRight);
    } else {
        scrollTableBoxesToRight();
    }

    window.addEventListener('load', scrollTableBoxesToRight);

    requestAnimationFrame(scrollTableBoxesToRight);
    setTimeout(scrollTableBoxesToRight, 0);
    setTimeout(scrollTableBoxesToRight, 120);
    setTimeout(scrollTableBoxesToRight, 300);
})();
