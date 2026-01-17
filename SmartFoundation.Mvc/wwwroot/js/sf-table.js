// wwwroot/js/sf-table.js - Complete Rewrite

window.__sfTableGlobalBound = window.__sfTableGlobalBound || false;

(function () {
    const register = () => {
        Alpine.data("sfTable", (cfg) => ({
            // ===== Configuration Properties =====
            endpoint: cfg.endpoint || "/smart/execute",
            spName: cfg.spName || "",
            operation: cfg.operation || "select",
            /*operation: cfg.operation || "select",*/

            //  NEW: Profile View — Full block)
            viewMode: (cfg.viewMode ?? "Table"), // "Table" | "Profile"
            // إعدادات البروفايل من الكنترول)
            profileTitleField: (cfg.profileTitleField ?? null),
            profileSubtitleField: (cfg.profileSubtitleField ?? null),
            profileMetaFields: Array.isArray(cfg.profileMetaFields) ? cfg.profileMetaFields : [], 
            profileFields: Array.isArray(cfg.profileFields) ? cfg.profileFields : [],            
            profileCssClass: (cfg.profileCssClass ?? ""),
            profileColumns: Number.isFinite(Number(cfg.profileColumns)) ? Number(cfg.profileColumns) : 2,
            profileShowHeader: (cfg.profileShowHeader !== false),
            profileIcon: (cfg.profileIcon ?? "fa-solid fa-id-card"),
            profileTitleText: (cfg.profileTitleText ?? "البيانات الأساسية"),
            // ===== Helpers =====
            normalizeFieldName(v) {
                if (v == null) return "";
                if (typeof v === "string") return v.trim();
                // لو جاك object من السيرفر
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
            //========End Profile=============//




            // Pagination
            pageSize: cfg.pageSize || 10,
            pageSizes: cfg.pageSizes || [10, 25, 50, 100],
            enablePagination: cfg.enablePagination !== false, //  جديد
            // NEW: Server paging (fast mode) - off by default
            serverPaging: !!cfg.serverPaging,
            // Search
            searchable: !!cfg.searchable,
            searchPlaceholder: cfg.searchPlaceholder || "بحث…",
            quickSearchFields: cfg.quickSearchFields || [],
            searchDelay: 300,
            searchTimer: null,
            // Display Options
            showHeader: cfg.showHeader !== false,
            showFooter: cfg.showFooter !== false,
            allowExport: !!cfg.allowExport,
            autoRefresh: !!(cfg.autoRefresh || cfg.autoRefreshOnSubmit),
            enableCellCopy: !!cfg.enableCellCopy,
            // Structure
            columns: Array.isArray(cfg.columns) ? cfg.columns : [],
            actions: Array.isArray(cfg.actions) ? cfg.actions : [],
            // ===== Guards (NEW) =====
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
            // Client-side mode support (new)
            clientSideMode: !!cfg.clientSideMode,
            initialRows: Array.isArray(cfg.rows) ? cfg.rows : [],
            // Selection
            selectable: !!cfg.selectable,
            rowIdField: cfg.rowIdField || "Id",
            singleSelect: !!cfg.singleSelect, // NEW: read from config
            stripHtml(html) {
                const div = document.createElement('div');
                div.innerHTML = html ?? '';
                return (div.textContent || div.innerText || '').trim();
            },

            // ===== Cell Copy Tooltip (fixed over the clicked cell) =====
            showCellCopied(cellEl, msg = "تم النسخ") {
                if (!cellEl) return;

                // add styles once
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

                // remove any old tooltip
                document.querySelectorAll(".sf-cell-copied").forEach(x => x.remove());

                const rect = cellEl.getBoundingClientRect();

                const tip = document.createElement("div");
                tip.className = "sf-cell-copied";
                tip.textContent = msg;
                document.body.appendChild(tip);

                // center tooltip over cell
                const tipRect = tip.getBoundingClientRect();
                const left = rect.left + (rect.width / 2) - (tipRect.width / 2);
                const gap = 2;
                const top = rect.top - tipRect.height - gap;


                // keep inside viewport
                const safeLeft = Math.max(8, Math.min(left, window.innerWidth - tipRect.width - 8));
                const safeTop = Math.max(8, top);

                tip.style.left = safeLeft + "px";
                tip.style.top = safeTop + "px";

                setTimeout(() => tip.remove(), 900);
            },

            // ===== Modern Copy (NO execCommand) =====
            async copyCell(row, col, e) {
                if (!this.enableCellCopy) return;

                const cellEl = e?.currentTarget || e?.target?.closest("td,th");

                try {
                    const html = this.formatCell(row, col);
                    const text = this.stripHtml(html);
                    if (!text) return;

                    // 1) Secure context + Clipboard API
                    if (navigator.clipboard?.writeText && window.isSecureContext) {
                        await navigator.clipboard.writeText(text);
                        this.showCellCopied(cellEl, "تم النسخ");
                        return;
                    }

                    // 2) Fallback: ClipboardItem (قد يعمل في بعض المتصفحات حتى لو غير secure)
                    if (navigator.clipboard?.write && typeof ClipboardItem !== "undefined") {
                        const blob = new Blob([text], { type: "text/plain" });
                        const item = new ClipboardItem({ "text/plain": blob });
                        await navigator.clipboard.write([item]);
                        this.showCellCopied(cellEl, "تم النسخ");
                        return;
                    }

                    // 3) No supported method
                    this.showCellCopied(cellEl, "المتصفح يمنع النسخ");
                } catch (err) {
                    console.error("Copy cell failed:", err);
                    this.showCellCopied(cellEl, "فشل النسخ");
                }
            },

            // Grouping & Storage
            groupBy: cfg.groupBy || null,
            storageKey: cfg.storageKey || null,
            // Toolbar
            toolbar: cfg.toolbar || {},
            // ===== Internal State =====
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
            activeIndex: -1,  //  Keyboard row navigation
            // Selection State
            selectedKeys: new Set(),
            selectAll: false,
            modal: {
                open: false,
                title: "",
                message: "",   // جديد
                messageClass: "",   // NEW
                messageIcon: "",    // NEW
                messageIsHtml: false, // NEW
                html: "",
                action: null,
                loading: false,
                error: null
            },
            //  Step 3: style rules from server
            styleRules: Array.isArray(cfg.styleRules) ? cfg.styleRules : [],

            applyStyleRules(row, col, target /* 'row' | 'cell' | 'column' */) {
                const normTarget = String(target || 'cell').toLowerCase();

                const rules = (this.styleRules || [])
                    .filter(r => {
                        const rt = String(r.target || 'cell').toLowerCase();

                        //  لو target=cell شغّل معه قواعد column أيضًا
                        if (normTarget === 'cell') return rt === 'cell' || rt === 'column';

                        return rt === normTarget;
                    })
                    .filter(r => {
                        const rt = String(r.target || 'cell').toLowerCase();
                        // cell/column لازم Field يطابق العمود الحالي
                        if ((rt === "cell" || rt === "column") && r.field) return r.field === col?.field;
                        // row: لو فيه Field نطبّق حسبه، ولو ما فيه Field نطبّق دائمًا
                        if (rt === "row") return true;
                        return false;
                    })
                    .sort((a, b) => (a.priority || 0) - (b.priority || 0));
                    const isMatch = (r) => {
                    const op = String(r.op || "eq").toLowerCase();
                    const val = r.value;
                    let left;
                    const rt = String(r.target || 'cell').toLowerCase();
                    if (rt === "row") {
                        // rule صف عام بدون field = يطبق دائمًا
                        if (!r.field) return true;
                        left = row?.[r.field];
                    } else {
                        left = row?.[col?.field];
                    }
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
                };

                let classes = [];
                for (const r of rules) {
                    if (r && r.cssClass && isMatch(r)) {
                        classes.push(r.cssClass);
                        if (r.stopOnMatch) break;
                    }
                }
                return classes.join(" ");
            },
            // ===== Initialization =====
            init() {
                this.loadStoredPreferences();
                this.bindPrintListenerOnce();



                // ✅ تعطيل الـ Pagination فعليًا
                if (!this.enablePagination) {
                    this.page = 1;
                    this.pages = 1;

                    // اعرض كل الصفوف في صفحة وحدة
                    this.pageSize = (this.rows && this.rows.length)
                        ? this.rows.length
                        : this.pageSize;
                }


                this.load();
                this.setupEventListeners();

            },

            loadStoredPreferences() {
                if (!this.storageKey) return;
                try {
                    const stored = localStorage.getItem(this.storageKey);
                    if (stored) {
                        const prefs = JSON.parse(stored);
                        if (prefs.pageSize) this.pageSize = prefs.pageSize;
                        if (prefs.sort) this.sort = prefs.sort;
                        if (prefs.columns && Array.isArray(this.columns)) {
                            this.columns.forEach(col => {
                                const storedCol = prefs.columns.find(c => c.field === col.field);
                                if (storedCol && storedCol.visible !== undefined) {
                                    col.visible = storedCol.visible;
                                }
                            });
                        }
                    }
                } catch (e) {
                    console.warn("Failed to load preferences:", e);
                }
            },
            savePreferences() {
                if (!this.storageKey) return;
                try {
                    const prefs = {
                        pageSize: this.pageSize,
                        sort: this.sort,
                        columns: this.columns.map(col => ({
                            field: col.field,
                            visible: col.visible !== false
                        }))
                    };
                    localStorage.setItem(this.storageKey, JSON.stringify(prefs));
                } catch (e) {
                    console.warn("Failed to save preferences:", e);
                }
            },

            initSelect2InModal(modalEl) {
                if (!window.jQuery || !jQuery.fn || !jQuery.fn.select2) return;

                const $modal = jQuery(modalEl);

                // 1) destroy أي تهيئة قديمة
                $modal.find("select.js-select2").each(function () {
                    const $sel = jQuery(this);
                    if ($sel.hasClass("select2-hidden-accessible")) {
                        $sel.select2("destroy");
                    }
                });
                // 2) init
                $modal.find("select.js-select2").each(function () {
                    const $sel = jQuery(this);

                    const minResults = $sel.data("s2-min-results"); // ممكن undefined
                    const ph =
                        $sel.data("s2-placeholder") ||
                        $sel.find('option[value=""]').text() ||
                        "الرجاء الاختيار";

                    $sel.select2({
                        width: "100%",
                        dir: "rtl",
                        dropdownParent: jQuery(document.body), //  يرسم dropdown فوق المودال
                        placeholder: ph,
                        allowClear: false,
                        minimumResultsForSearch:
                            (minResults === undefined || minResults === null) ? 0 : Number(minResults)
                    });

                });
            },

            setupEventListeners() {
                //  يمنع تكرار ربط الأحداث (لأنه Alpine يسوي instance لكل جدول)
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

                    //  زر X أو زر إلغاء أو أي زر إغلاق
                    if (e.target.closest('.sf-modal-close,[data-modal-close],.sf-modal-cancel,.sf-modal-btn-cancel')) {
                        e.preventDefault();
                        api.closeModal();
                        return;
                    }

                    //  الضغط على الخلفية (خارج الصندوق) يغلق المودال
                    const backdrop = e.target.closest('.sf-modal-backdrop');
                    if (backdrop) {
                        const inside = e.target.closest('.sf-modal');
                        if (!inside) {
                            e.preventDefault();
                            api.closeModal();
                        }
                    }
                });

                // depends dropdowns (listener واحد فقط)
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

                        // ❗ مهم: لا تستخدم return هنا
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

                                //  إذا كان متفعل select2 على العنصر: أعد تهيئته بعد تغيير الخيارات
                                if (window.jQuery && jQuery.fn.select2) {
                                    const $sel = $(dependentSelect);

                                    if ($sel.hasClass('select2-hidden-accessible')) {
                                        $sel.select2('destroy');
                                    }

                                    // استخدم نفس إعداداتك (ومنها minResults/placeholder من data-attrs)
                                    this.initSelect2InModal(modalEl);
                                }
                            }

                        } catch (error) {
                            console.error('Error loading dependent options:', error);
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
                    // ===== FAST MODE: server-side paging (only if enabled) =====
                    if (this.serverPaging) {
                        const body = {
                            Component: "Table",
                            SpName: this.spName,
                            Operation: this.operation,
                            Paging: { Page: this.page, Size: this.pageSize },
                            Params: {
                                q: this.q || null,
                                sortField: this.sort.field || null,
                                sortDir: this.sort.dir || "asc"
                            }
                        };

                        const json = await this.postJson(this.endpoint, body);
                        // بيانات الصفحة الحالية فقط
                        this.rows = Array.isArray(json?.data) ? json.data : [];
                        // إجمالي السجلات (إذا السيرفر يرجعه)
                        const total = json?.total ?? json?.count ?? json?.Total ?? json?.Count ?? null;
                        // إذا ما رجع total، نخليها صفحة واحدة عشان ما ينكسر شيء
                        if (total == null) {
                            this.total = this.rows.length;
                            this.pages = 1;
                            this.page = 1;
                        } else {
                            this.total = Number(total) || 0;
                            this.pages = Math.max(1, Math.ceil(this.total / this.pageSize));
                            this.page = Math.min(this.page, this.pages);
                        }
                        // في وضع السيرفر ما نحتاج allRows/filteredRows
                        this.allRows = [];
                        this.filteredRows = [];

                        this.savePreferences();
                        this.updateSelectAllState();
                        return;
                    }

                    // ===== OLD MODE (unchanged): client-side =====
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
                    }

                    this.applyFiltersAndSort();

                } catch (e) {
                    console.error("Load error:", e);
                    this.error = e.message || "خطأ في تحميل البيانات";
                } finally {
                    this.loading = false;
                }
            },

            applyFiltersAndSort() {
                let filtered = [...this.allRows];

                if (this.q) {
                    const tokens = String(this.q)
                        .toLowerCase()
                        .trim()
                        .split(/\s+/)
                        .filter(Boolean);

                    const fields = this.columns
                        .filter(c => c.visible !== false && c.field)
                        .map(c => c.field);

                    if (tokens.length) {
                        filtered = filtered.filter(row => {
                            // نجمع كل القيم القابلة للبحث في نص واحد
                            const haystack = fields
                                .map(f => String(row?.[f] ?? "").toLowerCase())
                                .join(" ");

                            // لازم كل كلمات البحث موجودة (AND)
                            return tokens.every(t => haystack.includes(t));
                        });
                    }
                }

                // Apply sorting
                if (this.sort.field) {
                    filtered.sort((a, b) => {
                        let valA = a[this.sort.field];
                        let valB = b[this.sort.field];

                        // Handle nulls
                        if (valA == null && valB == null) return 0;
                        if (valA == null) return 1;
                        if (valB == null) return -1;

                        // Handle numbers
                        if (typeof valA === 'number' && typeof valB === 'number') {
                            return this.sort.dir === 'asc' ? valA - valB : valB - valA;
                        }
                        // Handle dates
                        const dateA = new Date(valA);
                        const dateB = new Date(valB);
                        if (!isNaN(dateA) && !isNaN(dateB)) {
                            return this.sort.dir === 'asc' ? dateA - dateB : dateB - dateA;
                        }
                        // Handle strings
                        valA = String(valA).toLowerCase();
                        valB = String(valB).toLowerCase();

                        if (this.sort.dir === 'asc') {
                            return valA < valB ? -1 : valA > valB ? 1 : 0;
                        } else {
                            return valA > valB ? -1 : valA < valB ? 1 : 0;
                        }
                    });
                }

                this.filteredRows = filtered;
                this.total = filtered.length;
                this.pages = Math.max(1, Math.ceil(this.total / this.pageSize));
                this.page = Math.min(this.page, this.pages);

                // Apply pagination
                const startIdx = (this.page - 1) * this.pageSize;
                this.rows = filtered.slice(startIdx, startIdx + this.pageSize);

                this.savePreferences();
                this.updateSelectAllState();

            },

            debouncedSearch() {
                clearTimeout(this.searchTimer);
                this.searchTimer = setTimeout(() => {
                    this.page = 1;
                    if (this.serverPaging) {
                        this.load();            // ✅ سيرفر سايد
                    } else {
                        this.applyFiltersAndSort();
                    }
                }, this.searchDelay);
            },

            refresh() {
                this.allRows = [];
                this.load();
            },

            // ===== Columns Management =====
            visibleColumns() {
                return this.columns.filter(col => col.visible !== false);
            },

            toggleColumnVisibility(col) {
                col.visible = col.visible === false;
                this.savePreferences();
            },

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
                    this.load();                //  سيرفر سايد
                } else {
                    this.applyFiltersAndSort();
                }
            },

            // ===== Selection Management =====
            toggleRow(row) {
                const key = row?.[this.rowIdField];
                if (key == null) return;

                if (this.singleSelect) {
                    // clicking selected row → clear all; else select only this row
                    if (this.selectedKeys.has(key)) {
                        this.selectedKeys.clear();
                    } else {
                        this.selectedKeys.clear();
                        this.selectedKeys.add(key);
                    }
                } else {
                    // original multi-select
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
                    // In single-select mode, select first visible row or clear
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
                    // selectAll reflects whether one selected exists on current page
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


            // ===== Export Functions (XLSX pdf true) =====
            // ===== Export Functions (XLSX pdf true) =====
            exportData(type) {
                if (!this.allowExport) return;

                // PDF
                if (type === "pdf") {
                    this.openExportPdfModal();
                    return;
                }

                // Excel
                if (type === "excel") {
                    this.openExportExcelModal();
                    return;
                }

                // غير مدعوم
                this.showToast("نوع التصدير غير مدعوم", "error");
            },


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

                // تحريك الدالة خارج الـ innerHTML وتثبيتها على window
                window.toggleExportCount = function () {
                    const scope = document.getElementById("exportScope")?.value;
                    const countContainer = document.getElementById("countContainer");
                    if (!countContainer) return;
                    countContainer.style.display = (scope === "from_selected_count") ? "" : "none";
                };
                this.modal.html = `
                                <form id="sfExportExcelForm" class="sf-modal-form" onsubmit="return false;">
                                    <div class="grid grid-cols-12 gap-4">

                                        <!-- نطاق التصدير -->
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

                                        <!-- خيار العناوين -->
                                        <div class="col-span-12 md:col-span-6 flex items-center justify-start md:justify-end">
                                            <label class="flex items-center gap-2">
                                            <input type="checkbox" name="includeHeaders" checked class="sf-checkbox" />
                                            <span class="text-sm">تضمين العناوين (Header) كأول صف في Excel</span>
                                        </label>

                                        </div>

                                        <!-- عدد الصفوف -->
                                        <div class="col-span-12 md:col-span-6" id="countContainer" style="display: none;">
                                            <label class="block text-sm font-medium mb-1">عدد الصفوف</label>
                                            <input name="count" type="number" min="1" value="1" class="sf-modal-input" />
                                            <p class="mt-1 text-xs text-gray-500">مثال: 1 لتصدير صف واحد، أو 100 لتصدير 100 صف.</p>
                                        </div>

                                           <!-- أزرار -->
                                            <!-- اختيار الأعمدة -->
                                            <div class="col-span-12">
                                                <label class="block text-base font-medium mb-2">اختر الأعمدة المراد تصديرها :</label>
                                                <div class="grid grid-cols-2 gap-2" id="columnsCheckboxes">
                                                    <!-- سيتم تعبئة الأعمدة هنا عبر JavaScript -->
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
                    // 1) تحديث إظهار/إخفاء عدد الصفوف
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

                    // قراءة الأعمدة المختارة
                    const selectedFields = Array.from(document.querySelectorAll("input[name=exportCols]:checked")).map(i => i.value);

                    const allCols = exportVisibleOnly
                        ? this.visibleColumns().filter(c => c.showInExport !== false)
                        : (this.columns || []).filter(c => c.field && c.showInExport !== false);

                    // فلترة الأعمدة بناء على اختيار المستخدم
                    const cols = allCols.filter(c => selectedFields.includes(c.field));


                    if (!cols.length) {
                        this.showToast("لا توجد أعمدة للتصدير", "error");
                        return;
                    }

                    this.exportXlsx({ rows: rowsToExport, cols, includeHeaders, rtl });
                    this.closeModal();

                } catch (e) {
                    console.error(e);
                    this.showToast("فشل التصدير: " + (e.message || e), "error");
                }
            },

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
                                // نحول من px إلى wpx تقريبًا (تقدير XLSX.js)
                                const width = Math.ceil(rect.width);
                                return { wpx: width };
                            }
                        } catch (e) {
                            console.warn('فشل استخراج عرض العمود:', e);
                        }
                        return { wpx: 150 }; // fallback
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

            /*===== نهاية تصدير اكسل =====*/


            /*===== بداية تصدير PDF =====*/

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
                    console.error(e);
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

            /*===== نهاية تصدير PDF =====*/

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

            // ===== Actions Management =====

            async doAction(action, row) {
                if (!action) return;

                try {
                    // التحقق من متطلبات الاختيار
                    if (action.requireSelection) {
                        const selectedCount = this.selectedKeys.size;
                        if (selectedCount < (action.minSelection || 1)) {
                            this.showToast(`يجب اختيار ${action.minSelection || 1} عنصر على الأقل`, 'error');
                            return;
                        }
                        if (action.maxSelection > 0 && selectedCount > action.maxSelection) {
                            this.showToast(`لا يمكن اختيار أكثر من ${action.maxSelection} عنصر`, 'error');
                            return;
                        }

                        // إذا row ما وصل، جيبه من الاختيار الحالي
                        if (!row) row = this.getSelectedRowFromCurrentData();
                    }

                    // Guards
                    const guardRes = this.evalGuards(action);
                    if (!guardRes.allowed) {
                        this.showToast(guardRes.message || "غير مسموح", "error");
                        return;
                    }

                    // Confirm if needed
                    if (action.confirmText && !confirm(action.confirmText)) return;

                    // ✅ 1) OnClickJs (قبل المودال/السب)
                    const js = action.onClickJs || action.OnClickJs;
                    if (js && String(js).trim()) {
                        try {
                            const code = String(js).trim();

                            // إذا مكتوب كاسم دالة فقط: myFunc
                            // أو myFunc(...)
                            const isFnCallOrName =
                                /^[a-zA-Z_$][\w$]*(\s*\(.*\))?$/.test(code);

                            if (isFnCallOrName) {
                                const fnName = code.split('(')[0].trim();
                                const fn = window[fnName];
                                if (typeof fn === "function") {
                                    // استدعاء الدالة وتمرير (row, action, tableApi)
                                    fn(row, action, this);
                                    return;
                                }
                            }

                            // تنفيذ نص JS مباشرة مع سياق (row/action/table)
                            // نمرر row/action/table كمتغيرات داخل التنفيذ
                            // eslint-disable-next-line no-new-func
                            const runner = new Function("row", "action", "table", code);
                            runner(row, action, this);
                            return;

                        } catch (err) {
                            console.error("OnClickJs failed:", err);
                            this.showToast("فشل تنفيذ الأمر", "error");
                            return;
                        }
                    }

                    // Open modal
                    // التأكيد إذا كان مطلوباً
                    if (action.confirmText && !confirm(action.confirmText)) {
                        return;
                    }

                    // فتح المودال مع فحص Guards
                    if (action.openModal) {
                        await this.openModal(action, row);
                        return;
                    }

                    // Execute stored procedure
                    // ===== OnClickJs للأزرار التي لا تفتح مودال =====

                    if (action.onClickJs) {
                        try {
                            // تنفيذ الكود الجافاسكربت المخصص
                            
                            const fn = new Function('action', 'row', action.onClickJs);
                            fn.call(this, action, row);
                        } catch (e) {
                            console.error("OnClickJs execution error:", e);
                            this.showToast("فشل تنفيذ الإجراء", 'error');
                        }
                        return;
                    }

                    // تنفيذ stored procedure
                    if (action.saveSp) {
                        const success = await this.executeSp(action.saveSp, action.saveOp || "execute", row);
                        if (success && this.autoRefresh) {
                            this.clearSelection();
                            await this.refresh();
                        }
                        return;
                    }

                } catch (e) {
                    console.error("Action error:", e);
                    this.showToast("فشل في تنفيذ الإجراء: " + e.message, 'error');
                }
            },


            async doBulkDelete() {
                if (this.selectedKeys.size === 0) {
                    this.showToast("لم يتم اختيار أي عناصر للحذف", 'error');
                    return;
                }

                if (!confirm(`هل تريد حقاً حذف ${this.selectedKeys.size} عنصر؟`)) {
                    return;
                }

                try {
                    const body = {
                        Component: "Table",
                        SpName: this.spName,
                        Operation: "bulk_delete",
                        Params: { ids: Array.from(this.selectedKeys) }
                    };

                    await this.postJson(this.endpoint, body);
                    this.showToast(`تم حذف ${this.selectedKeys.size} عنصر بنجاح`, 'success');
                    this.clearSelection();
                    await this.refresh();

                } catch (e) {
                    console.error("Bulk delete error:", e);
                    this.showToast("فشل في الحذف: " + e.message, 'error');
                }
            },

            // ===== Modal Management =====
            async openModal(action, row) {
                this.modal.open = true;
                window.__sfTableActive = this; //جديد
                this.modal.title = action.modalTitle || action.label || "";
                this.modal.message = action.modalMessage || ""; //  جديد
                this.modal.messageClass = action.modalMessageClass || "";
                this.modal.messageIcon = action.modalMessageIcon || "";
                this.modal.messageIsHtml = !!action.modalMessageIsHtml;
                this.modal.action = action;
                this.modal.loading = true;
                this.modal.error = null;
                this.modal.html = "";

                try {
                    
                    if (action.formUrl) {
                        const url = this.fillUrl(action.formUrl, row);
                        const resp = await fetch(url);
                        if (!resp.ok) throw new Error(`Failed to load form: ${resp.status}`);
                        this.modal.html = await resp.text();

                    } else if (action.openForm) {
                        this.modal.html = this.generateFormHtml(action.openForm, row);

                    } else if (row) {
                        // يعرض تفاصيل الصف باستخدام أعمدة الجدول نفسها
                        const columns =
                            this.columns ||
                            this.table?.columns ||
                            this.$data?.columns ||
                            [];

                        this.modal.html = this.formatDetailView(row, columns);

                    } else if (action.modalSp) {
                        const body = {
                            Component: "Table",
                            SpName: action.modalSp,
                            Operation: action.modalOp || "detail",
                            Params: row || {}
                        };
                        const json = await this.postJson(this.endpoint, body);
                        this.modal.html = this.formatDetailView(json.data, columns);
                    }

                    this.$nextTick(() => {
                        this.initModalScripts();

                        const modalEl =
                            document.querySelector('.sf-modal') ||
                            this.$el.querySelector('.sf-modal');

                        if (!modalEl) return;

                        // زر الحفظ داخل المودال: يغيّر الزر فقط إلى "جاري الحفظ…"
                        const form = modalEl.querySelector('form');
                        if (form && !form.__saveBound) {
                            form.__saveBound = true;

                            // عند الضغط على حفظ (submit)
                            form.addEventListener('submit', (e) => {
                                const btn =
                                    form.querySelector('.sf-modal-btn-save') ||
                                    form.querySelector('button[type="submit"]');

                                if (!btn) return;

                                // منع تكرار الضغط
                                if (btn.__saving) return;
                                btn.__saving = true;

                                // حفظ النص الأصلي
                                btn.__originalText = btn.textContent;

                                // تغيير شكل/نص الزر فقط
                                btn.disabled = true;
                                btn.classList.add("opacity-60", "pointer-events-none");
                                btn.textContent ="جاري الحفظ .."

                                
                                clearTimeout(btn.__restoreTimer);
                                btn.__restoreTimer = setTimeout(() => {
                                    if (this.modal?.open) {
                                        btn.disabled = false;
                                        btn.classList.remove("opacity-60", "pointer-events-none");
                                        btn.textContent = btn.__originalText || "حفظ";
                                        btn.__saving = false;
                                    }
                                }, 15000); // 15 ثانية
                            });

                            // إذا الفورم غير صالح (required…): رجّع الزر مباشرة
                            form.addEventListener('invalid', (e) => {
                                const btn =
                                    form.querySelector('.sf-modal-btn-save') ||
                                    form.querySelector('button[type="submit"]');

                                if (!btn) return;

                                clearTimeout(btn.__restoreTimer);

                                btn.disabled = false;
                                btn.classList.remove("opacity-60", "pointer-events-none");
                                btn.textContent = btn.__originalText || "حفظ";
                                btn.__saving = false;

                            }, true);
                        }

                        // datepickers داخل المودال
                        this.initDatePickers(modalEl);

                        // ===== drag =====
                        (function () {
                            const modal = modalEl;
                            const header = modal.querySelector('.sf-modal-header');

                            if (!modal || !header) return;

                            if (modal.__dragBound) return;
                            modal.__dragBound = true;

                            let isDragging = false;
                            let startX = 0;
                            let startY = 0;
                            let startLeft = 0;
                            let startTop = 0;

                            header.addEventListener('mousedown', function (e) {
                                if (e.target.closest('.sf-modal-close,[data-modal-close],button,a,input,select,textarea')) return;

                                e.preventDefault();
                                isDragging = true;

                                const rect = modal.getBoundingClientRect();
                                startX = e.clientX;
                                startY = e.clientY;
                                startLeft = rect.left;
                                startTop = rect.top;

                                modal.style.transform = 'none';
                                modal.style.left = startLeft + 'px';
                                modal.style.top = startTop + 'px';

                                document.addEventListener('mousemove', onMouseMove);
                                document.addEventListener('mouseup', onMouseUp);
                            });

                            function onMouseMove(e) {
                                if (!isDragging) return;

                                const dx = e.clientX - startX;
                                const dy = e.clientY - startY;

                                modal.style.left = (startLeft + dx) + 'px';
                                modal.style.top = (startTop + dy) + 'px';
                            }

                            function onMouseUp() {
                                isDragging = false;
                                document.removeEventListener('mousemove', onMouseMove);
                                document.removeEventListener('mouseup', onMouseUp);
                            }
                        })();

                        // تفعيل التحجيم
                        this.enableModalResize(modalEl);

                        // select2 داخل المودال
                        this.initSelect2InModal(modalEl);
                    });




                } catch (e) {
                    console.error("Modal error:", e);
                    this.modal.error = e.message;
                } finally {
                    this.modal.loading = false;
                }
            },

            closeModal() {

                if (this.__printHandle && typeof this.__printHandle.cancel === "function") {
                    this.__printHandle.cancel();
                    this.__printHandle = null;
                }

                // (اختياري) احتياط عام
                if (window.__sfPrintSession?.active) {
                    window.__sfPrintSession.canceled = true;
                }

                this.modal.open = false;
                this.modal.html = "";
                this.modal.action = null;
                this.modal.error = null;
                this.modal.message = ""; //  جديد
                this.modal.messageClass = "";
                this.modal.messageIcon = "";
                this.modal.messageIsHtml = false;
                if (window.__sfTableActive === this) window.__sfTableActive = null;//جديد
            },

            // ===== Form Generation =====
            generateFormHtml(formConfig, rowData) {
                if (!formConfig) return "";

                const formId = formConfig.formId || "modalForm";
                const method = formConfig.method || "POST";
                const action = formConfig.actionUrl || "#";

                let html = `<form id="${formId}" method="${method}" action="${action}" class="sf-modal-form">`;
                html += `<div class="grid grid-cols-12 gap-4">`;
                // Generate fields
                (formConfig.fields || []).forEach(field => {
                    if (field.isHidden || field.type === "hidden") {
                        const value = rowData ? (rowData[field.name] || field.value || "") : (field.value || "");
                        html += `<input type="hidden" name="${this.escapeHtml(field.name)}" value="${this.escapeHtml(value)}">`;
                    } else {
                        html += this.generateFieldHtml(field, rowData);
                    }
                });
                // Generate buttons
                if (formConfig.buttons && formConfig.buttons.length > 0) {
                    html += `<div class="col-span-12 flex justify-end gap-2 mt-4">`;
                    formConfig.buttons.forEach(btn => {
                        if (btn.show !== false) {
                            const btnType = btn.type || "button";

                            // تحديد هل هو زر إلغاء
                            const isCancel =
                                btn.isCancel === true ||
                                btn.role === 'cancel' ||
                                (btn.text && (
                                    btn.text === 'إلغاء' ||
                                    btn.text === 'الغاء' ||
                                    btn.text.toLowerCase() === 'cancel'
                                ));

                            // نضيف كلاس sf-modal-cancel لزر الإلغاء
                            const extraClasses = isCancel ? ' sf-modal-cancel' : '';
                            const btnClass = `btn btn-${btn.color || 'secondary'}${extraClasses}`;
                            const icon = btn.icon ? `<i class="${btn.icon}"></i> ` : "";

                            // لا نضع onclick لزر الإلغاء (الـ listener العام يتولى الإغلاق)
                            const onClick = (!isCancel && btn.type !== 'submit') ? (btn.onClickJs || "") : "";

                            html += `<button type="${btnType}" class="${btnClass}" ${onClick ? `onclick="${onClick}"` : ""}>${icon}${btn.text}</button>`;
                        }
                    });
                    html += `</div>`;
                } else {
                    // Default buttons
                    html += `<div class="col-span-12 flex justify-end gap-2 mt-4 sf-modal-actions">`;

                    // زر حفظ
                    html += `<button type="submit" class="btn btn-success sf-modal-btn-save">حفظ</button>`;

                    // زر إلغاء
                    html += `<button type="button" class="btn btn-secondary sf-modal-btn-cancel sf-modal-cancel">إلغاء</button>`;

                    html += `</div>`;


                }
                html += `</div></form>`;
                return html;
            },

            enableModalDrag(modalEl) {
                if (!modalEl) return;
                const header = modalEl.querySelector('.sf-modal-header');
                if (!header) return;
                //  منع تكرار الربط لو فتحته أكثر من مرة
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
                    // لا تسحب إذا ضغطت على زر الإغلاق
                    if (e.target.closest('.sf-modal-close,[data-modal-close],button,a,input,select,textarea')) return;
                    e.preventDefault();
                    isDragging = true;
                    const rect = modalEl.getBoundingClientRect();
                    startX = e.clientX;
                    startY = e.clientY;
                    startLeft = rect.left;
                    startTop = rect.top;
                    // أول سحب: فك التمركز translate
                    modalEl.style.transform = 'none';
                    modalEl.style.left = startLeft + 'px';
                    modalEl.style.top = startTop + 'px';
                    document.addEventListener('mousemove', onMouseMove);
                    document.addEventListener('mouseup', onMouseUp);
                });
            },

            enableModalResize(modalEl) {
                if (!modalEl) return;
                // منع تكرار الربط
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
                    // يمين/يسار
                    if (dir.includes('e')) newW = startW + dx;
                    if (dir.includes('w')) { newW = startW - dx; newL = startL + dx; }
                    // أعلى/أسفل
                    if (dir.includes('s')) newH = startH + dy;
                    if (dir.includes('n')) { newH = startH - dy; newT = startT + dy; }
                    // clamp
                    newW = clamp(newW, minW, maxW);
                    newH = clamp(newH, minH, maxH);
                    // تصحيح left/top عند السحب من w/n
                    if (dir.includes('w')) newL = startL + (startW - newW);
                    if (dir.includes('n')) newT = startT + (startH - newH);
                    // تثبيت داخل الشاشة
                    newL = clamp(newL, 16, vw - newW - 16);
                    newT = clamp(newT, 16, vh - newH - 16);
                    // فك التمركز
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

                // لمس (اختياري)
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

            initDatePickers(rootEl) {
                if (typeof flatpickr === "undefined") return;
                (rootEl || document)
                    .querySelectorAll("input.js-date")
                    .forEach(el => {
                        if (el._flatpickr) return;
                        flatpickr(el, {
                            locale: flatpickr.l10ns.ar,
                            dateFormat: "Y-m-d",
                            altInput: false,       //  هذا يمنع الصيغة الطويلة
                            defaultDate: null,
                            allowInput: true,
                            disableMobile: true
                        });
                    });
            },

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

                    case "custom":
                        pattern = field.pattern ? `pattern="${field.pattern}"` : "";
                        oninput = "";
                        break;

                }

                let inputType = (field.type || "text").toLowerCase();
                if (textMode === "email") inputType = "email";
                if (textMode === "url") inputType = "url";
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

                        const hasIcon = !!field.icon;

                        const isRtl =
                            (field.textMode && String(field.textMode).toLowerCase() === "arabic") ||
                            document?.documentElement?.dir === "rtl";

                        // كلاس اتجاه الأيقونة
                        const iconSideClass = isRtl ? "sf-icon-right" : "sf-icon-left";

                        // كلاس يضاف للـ input فقط إذا فيه أيقونة
                        const iconInputClass = hasIcon ? `sf-has-icon ${iconSideClass}` : "";

                        // HTML الأيقونة
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
                                        type="${inputType}"
                                        name="${this.escapeHtml(field.name)}"
                                        value="${this.escapeHtml(value)}"
                                        class="sf-modal-input ${iconInputClass}"
                                        ${placeholder}
                                        ${required}
                                        ${disabled}
                                        ${readonly}
                                        ${maxLength}
                                        ${autocomplete}
                                        ${spellcheck}
                                        ${autocapitalize}
                                        ${autocorrect}
                                        ${pattern}
                                        ${oninput}
                                    />
                                </div>

                                ${field.helpText
                                                    ? `<p class="mt-1 text-xs text-gray-500">${this.escapeHtml(field.helpText)}</p>`
                                                    : ''}
                            </div>`;
                        break;
                    }


                    case "textarea":
                        const rows = field.rows || 3;
                        fieldHtml = `
                        <div class="form-group ${colCss}">
                            <label class="block text-sm font-medium text-gray-700 mb-1">
                                ${this.escapeHtml(field.label)} ${field.required ? '<span class="text-red-500">*</span>' : ''}

                            </label>
                            <textarea name="${this.escapeHtml(field.name)}" rows="${rows}"
                                     class="sf-modal-input"
                                     ${placeholder} ${required} ${disabled} ${readonly} ${maxLength}>${this.escapeHtml(value)}</textarea>
                            ${field.helpText ? `<p class="mt-1 text-xs text-gray-500">${this.escapeHtml(field.helpText)}</p>` : ''}
                        </div>`;
                        break;



                    case "select": {
                        let options = "";

                        // =========================
                        // 1) Placeholder
                        // =========================
                        options += `<option value="" disabled ${!value ? "selected" : ""}>${this.escapeHtml(field.placeholder || "الرجاء الاختيار")}</option>`;

                        (field.options || []).forEach(opt => {
                            const optValue = opt.value ?? opt.Value ?? "";
                            const optText = opt.text ?? opt.Text ?? "";
                            const selected = String(value) === String(optValue) ? "selected" : "";
                            options += `<option value="${this.escapeHtml(optValue)}" ${selected}>${this.escapeHtml(optText)}</option>`;
                        });

                        // =========================
                        // 2) onchange / depends
                        // =========================
                        let onChangeHandler = field.onChangeJs || "";

                        //  onchange (لأن listener العام يتولى)
                        if (!(field.dependsUrl && field.dependsOn) && onChangeHandler && !field.dependsUrl) {
                            onChangeHandler = `${onChangeHandler}`;
                        }
                        const onChangeAttr = onChangeHandler ? `onchange="${this.escapeHtml(onChangeHandler)}"` : "";
                        const dependsOnAttr = field.dependsOn ? `data-depends-on="${this.escapeHtml(field.dependsOn)}"` : "";
                        const dependsUrlAttr = field.dependsUrl ? `data-depends-url="${this.escapeHtml(field.dependsUrl)}"` : "";
                        // =========================
                        // 3)  Select2 switch (من الكنترول)
                        // =========================
                        // يدعم camelCase و PascalCase
                        const useSelect2 = !!(field.select2 ?? field.Select2);
                        // اختياري (لو ما تبيها احذفها من هنا ومن FieldConfig)
                        const minResults = field.select2MinResultsForSearch ?? field.Select2MinResultsForSearch;
                        const s2Placeholder = field.select2Placeholder ?? field.Select2Placeholder;
                        // إذا Select2=true ضف الكلاس + data attributes
                        const select2Class = useSelect2 ? "js-select2" : "";
                        const s2MinAttr = (useSelect2 && minResults !== undefined && minResults !== null)
                            ? `data-s2-min-results="${this.escapeHtml(minResults)}"`
                            : "";
                        const s2PhAttr = (useSelect2 && s2Placeholder)
                            ? `data-s2-placeholder="${this.escapeHtml(s2Placeholder)}"`
                            : "";
                        // =========================
                        // 4) HTML
                        // =========================
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

                        // كلاس اتجاه الأيقونة
                        const iconSideClass = isRtl ? "sf-icon-right" : "sf-icon-left";

                        // كلاس يضاف للـ input فقط إذا فيه أيقونة
                        const iconInputClass = hasIcon ? `sf-has-icon ${iconSideClass}` : "";

                        // HTML الأيقونة
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
                        // رقم >= 0 فقط (بدون سالب)
                        const min0 = `min="0"`;
                        const numStep = field.step !== undefined ? `step="${field.step}"` : `step="1"`;
                        const numMax = field.max !== undefined ? `max="${field.max}"` : "";

                        // يمنع إدخال السالب و e و + ويقص أي شيء غير رقم (ويسمح بنقطة لو step فيه كسور)
                        const allowDecimal =
                            String(field.step ?? "").includes('.') ||
                            (typeof field.step === 'number' && !Number.isInteger(field.step));

                        const numberOnInput = allowDecimal
                            ? `oninput="this.value=this.value.replace(/[^0-9.]/g,''); if(this.value.startsWith('.')) this.value='0'+this.value; if(this.value.includes('.')){const p=this.value.split('.'); this.value=p[0]+'.'+p.slice(1).join('');}"`
                            : `oninput="this.value=this.value.replace(/\\D/g,'')"`;

                        const numberOnKeyDown =
                            `onkeydown="if(['-','e','E','+'].includes(event.key)) event.preventDefault()"`;

                        /* ===== ICON SUPPORT (نفس طريقة text/date) ===== */
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

                        // أرقام فقط + أقصى 10 أرقام
                        const nidOnInput =
                            `oninput="` +
                            `this.value=this.value.replace(/\\D/g,'');` +
                            `if(this.value.length>10)this.value=this.value.slice(0,10);` +
                            `"`;

                        const nidOnKeyDown =
                            `onkeydown="if(['-','e','E','+','.'].includes(event.key)) event.preventDefault()"`;

                        /* ===== ICON SUPPORT (نفس طريقة text/date/number) ===== */
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
                        autocomplete="new-password"
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

                                // digits to ascii
                                v = v.replace(/[٠-٩]/g, d => '٠١٢٣٤٥٦٧٨٩'.indexOf(d));
                                v = v.replace(/[۰-۹]/g, d => '۰۱۲۳۴۵۶۷۸۹'.indexOf(d));

                                // keep digits only
                                v = v.replace(/\\s+/g,'');
                                v = v.replace(/^\\+/, '');      // +966... -> 966...
                                v = v.replace(/\\D/g,'');

                                // Saudi normalize to 05XXXXXXXX
                                if (v.startsWith('966') ) v = '0' + v.slice(3);     // 9665xxxxxxxx -> 05xxxxxxxx
                                if (v.startsWith('00966')) v = '0' + v.slice(5);    // 009665xxxxxxxx -> 05xxxxxxxx
                                if (v.startsWith('5') && v.length === 9) v = '0' + v; // 5xxxxxxxx -> 05xxxxxxxx

                                // force prefix 05 if user started typing mobile
                                if (v.length >= 2 && !v.startsWith('05')) {
                                    if (v.startsWith('0')) v = '05' + v.slice(2);
                                    else v = '05' + v.replace(/^05/, '').slice(0); // fallback
                                }

                                if (v.length > 10) v = v.slice(0,10);
                                el.value = v;
                            })(this);
                        `;

                                        const validateFn = `
                            (function(el){
                                // normalize first
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
                            })this);
                        `;

                        // initial normalize (server value)
                        const initial = (() => {
                            let v = (value ?? '').toString();
                            v = v.replace(/[٠-٩]/g, d => '٠١٢٣٤٥٦٧٨٩'.indexOf(d));
                            v = v.replace(/[۰-۹]/g, d => '۰۱۲۳۴۵۶۷۸۹'.indexOf(d));
                            v = v.replace(/\s+/g, '').replace(/^\+/, '').replace(/\D/g, '');

                            if (v.startsWith('00966')) v = '0' + v.slice(5);
                            if (v.startsWith('966')) v = '0' + v.slice(3);
                            if (v.startsWith('5') && v.length === 9) v = '0' + v;
                            if (v.length > 10) v = v.slice(0, 10);
                            return v;
                        })();

                        // IMPORTANT: oninput لا يعرض رسالة، فقط يطبّع
                        const onInput = `oninput="${normalizeFn} this.setCustomValidity('');"`;
                        // التحقق فقط عند blur/invalid
                        const onBlur = `onblur="${validateFn}"`;
                        const onInvalid = `oninvalid="${validateFn}"`;
                        const onChange = `onchange="${normalizeFn}"`;
                        const onKeyDown =
                            `onkeydown="if(['-','e','E','+','.'].includes(event.key)) event.preventDefault()"`;

                        /* ===== ICON SUPPORT (نفس طريقة text/date/number) ===== */
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
                                    autocomplete="new-password"
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
                        // Fallback to text input
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

            resolveColCss(colCss) {
                if (!colCss) return "col-span-12 md:col-span-6";

                if (/^\d{1,2}$/.test(colCss)) {
                    const n = Math.max(1, Math.min(12, parseInt(colCss, 10)));
                    return `col-span-12 md:col-span-${n}`;
                }

                return colCss.includes('col-span') ? colCss : `col-span-12 ${colCss}`;
            },

            initModalScripts() {
                const form = this.$el.querySelector('.sf-modal form');
                if (form) {

                    // ===== تخصيص رسالة required =====
                    form.querySelectorAll("[required]").forEach(input => {

                        // منع رسالة المتصفح الافتراضية
                        input.addEventListener("invalid", function (e) {
                            e.preventDefault();
                            this.setCustomValidity("حقل إجباري");
                        });

                        // عند تعديل المدخلات، أعد التحقق
                        input.addEventListener("input", function () {
                            this.setCustomValidity("");
                        });
                    });
                    // ===== نهاية تعديل required =====

                    form.addEventListener('submit', (e) => {
                        e.preventDefault();
                        this.saveModalChanges();
                    });

                    /*this.setupDependentDropdowns(form);*/
                }
            },

            setupDependentDropdowns(form) {
                // Find all selects with data-depends-on attribute
                const dependentSelects = form.querySelectorAll('select[data-depends-on]');
                
                dependentSelects.forEach(dependentSelect => {
                    const parentFieldName = dependentSelect.getAttribute('data-depends-on');
                    const dependsUrl = dependentSelect.getAttribute('data-depends-url');
                    
                    if (!parentFieldName || !dependsUrl) return;
                    
                    // Find the parent select
                    const parentSelect = form.querySelector(`select[name="${parentFieldName}"]`);
                    if (!parentSelect) {
                        console.warn(`Parent select not found: ${parentFieldName}`);
                        return;
                    }
                    // Attach change handler to parent
                    parentSelect.addEventListener('change', async (e) => {
                        const parentValue = e.target.value;
                        // Show loading state
                        const originalHtml = dependentSelect.innerHTML;
                        dependentSelect.innerHTML = '<option value="-1">جاري التحميل...</option>';
                        dependentSelect.disabled = true;
                        try {
                            // Build URL with parent value
                            const url = `${dependsUrl}?${parentFieldName}=${encodeURIComponent(parentValue)}`;
                            // Fetch new options
                            const response = await fetch(url);
                            if (!response.ok) {
                                throw new Error(`HTTP ${response.status}`);
                            }                      
                            const data = await response.json();
                            // Rebuild options
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

                            //  تحديث select2 بعد تغيير الخيارات
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
                            console.error('Error loading dependent options:', error);
                            dependentSelect.innerHTML = originalHtml;
                            this.showToast('فشل تحميل الخيارات: ' + error.message, 'error');
                        } finally {
                            dependentSelect.disabled = false;
                        }
                    });
                    
                    // Trigger initial load if parent has value
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
                        //  تحديث سريع بدون refresh ثقيل
                        if (this.serverPaging) {
                            await this.load(); // يرجّع نفس الصفحة فقط
                        } else {
                            const saved = result.data || result.row || result.item || null;
                            const id = (saved && saved[this.rowIdField]) ?? formData[this.rowIdField];

                            if (saved) {
                                const idx = this.allRows.findIndex(r => r[this.rowIdField] == id);
                                if (idx >= 0) this.allRows[idx] = { ...this.allRows[idx], ...saved };
                                else this.allRows.unshift(saved);
                            }

                            this.applyFiltersAndSort();
                        }

                        this.closeModal();
                        this.clearSelection();
                    }


                    //if (success) {
                    //    this.closeModal();
                    //    if (this.autoRefresh) {
                    //        this.clearSelection();
                    //        await this.refresh();
                    //    }
                    //}

                } catch (e) {
                    console.error("Save error:", e);
                    this.modal.error = e.message || "فشل في الحفظ";
                } finally {
                    this.modal.loading = false;
                }
            },

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

            // ===== Form Serialization =====
            serializeForm(form) {
                const formData = new FormData(form);
                const data = {};
                
                // Handle regular form fields
                for (const [key, value] of formData.entries()) {
                    if (data[key]) {
                        // Multiple values - convert to array
                        if (Array.isArray(data[key])) {
                            data[key].push(value);
                        } else {
                            data[key] = [data[key], value];
                        }
                    } else {
                        data[key] = value;
                    }
                }
                
                // Handle unchecked checkboxes
                form.querySelectorAll('input[type="checkbox"][name]').forEach(checkbox => {
                    if (!formData.has(checkbox.name)) {
                        data[checkbox.name] = false;
                    } else {
                        data[checkbox.name] = true;
                    }
                });
                
                // Clean up data types
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
                    return result; //بدل true
                } catch (e) {
                    console.error("Execute SP error:", e);
                    this.showToast("⚠️ " + (e.message || "فشل العملية"), 'error');

                    if (e.server?.errors) this.applyServerErrors(e.server.errors);

                    return null;
                }
            },

            async postJson(url, body) {
                const headers = { "Content-Type": "application/json" };
                
                // Add CSRF token if available
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
                    // Response is not JSON
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

            getCsrfToken() {
                const meta = document.querySelector('meta[name="request-verification-token"]');
                if (meta?.content) return meta.content;
                
                const input = document.querySelector('input[name="__RequestVerificationToken"]');
                return input?.value || null;
            },

            applyServerErrors(errors) {
                const form = this.$el.querySelector('.sf-modal form');
                if (!form || !errors) return;
                
                // Clear existing errors
                form.querySelectorAll('[data-error-msg]').forEach(el => el.remove());
                form.querySelectorAll('.ring-red-500, .border-red-500').forEach(el => {
                    el.classList.remove('ring-red-500', 'border-red-500', 'ring-1');
                });
                
                // Apply new errors
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

            formatCell(row, col) {
                let value = row[col.field];
                if (value == null) return "";
                // هل العمود مطلوب له truncate؟
                const shouldTruncate = !!(col.truncate ?? col.Truncate);
                // مساعد: يلف الناتج داخل span مع title (بعد تنظيف المسافات) لعرض النص الكامل
                const wrapTruncate = (htmlOrText, titleText) => {
                    if (!shouldTruncate) return htmlOrText;
                    const raw = (titleText ?? "");
                    const clean = String(raw).replace(/\s+/g, " ").trim(); // ✅ يشيل المسافات الزائدة ويطبعها
                    const t = this.escapeHtml(clean);
                    return `<span class="sf-truncate" title="${t}">${htmlOrText}</span>`;
                };

                switch (col.type) {
                    case "date":
                        try {
                            const txt = new Date(value).toLocaleDateString('ar-SA');
                            return wrapTruncate(this.escapeHtml(txt), txt);
                        } catch {
                            const txt = String(value);
                            return wrapTruncate(this.escapeHtml(txt), txt);
                        }

                    case "datetime":
                        try {
                            const txt = new Date(value).toLocaleString('ar-SA');
                            return wrapTruncate(this.escapeHtml(txt), txt);
                        } catch {
                            const txt = String(value);
                            return wrapTruncate(this.escapeHtml(txt), txt);
                        }

                    case "bool":
                        // tooltip للـ bool غير مهم عادة
                        return value
                            ? '<span class="text-green-600">✓</span>'
                            : '<span class="text-red-600">✗</span>';

                    case "money":
                        try {
                            const txt = new Intl.NumberFormat('ar-SA', {
                                style: 'currency',
                                currency: 'SAR'
                            }).format(value);
                            return wrapTruncate(this.escapeHtml(txt), txt);
                        } catch {
                            const txt = String(value);
                            return wrapTruncate(this.escapeHtml(txt), txt);
                        }

                    case "badge": {
                        const badgeClass =
                            col.badge?.map?.[value] ||
                            col.badge?.defaultClass ||
                            "bg-gray-100 text-gray-800";

                        const txt = String(value);
                        const html =
                            `<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${badgeClass}">${this.escapeHtml(txt)}</span>`;

                        return wrapTruncate(html, txt);
                    }

                    case "link": {
                        const txt = String(value);
                        if (col.linkTemplate) {
                            const href = this.fillUrl(col.linkTemplate, row);
                            const html =
                                `<a href="${this.escapeHtml(href)}" class="text-blue-600 hover:text-blue-800 hover:underline">${this.escapeHtml(txt)}</a>`;
                            return wrapTruncate(html, txt);
                        }
                        return wrapTruncate(this.escapeHtml(txt), txt);
                    }

                    case "image":
                        if (col.imageTemplate) {
                            const src = this.fillUrl(col.imageTemplate, row);
                            return `<img src="${this.escapeHtml(src)}" alt="${this.escapeHtml(String(value))}" class="h-8 w-8 rounded object-cover">`;
                        }
                        return "";

                    default: {
                        const txt = String(value);
                        return wrapTruncate(this.escapeHtml(txt), txt);
                    }
                }
            },

            // ===== Grouping =====
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


            rangeText() {
                if (this.total === 0) return "0 من 0";
                const start = (this.page - 1) * this.pageSize + 1;
                const end = Math.min(this.page * this.pageSize, this.total);
                return `${start} - ${end} من ${this.total}`;
            },

            // ===== Utility Functions =====
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

           
            showToast(message, type = 'info') {
                const toast = document.createElement('div');
                toast.textContent = message;
                Object.assign(toast.style, {
                    position: 'fixed',
                    top: '20px',
                    left: '50%',
                    transform: 'translateX(-50%)',
                    padding: '1rem 2rem',
                    borderRadius: '0.5rem',
                    color: 'white',
                    backgroundColor:
                        type === 'error' ? '#EF4444' :
                            type === 'success' ? '#16A34A' :
                                '#3B82F6',
                    zIndex: '10000',
                    fontSize: '1rem',
                    textAlign: 'center',
                    maxWidth: '90%',
                    boxShadow: '0 4px 8px rgba(0, 0, 0, 0.1)',
                });

                document.body.appendChild(toast);

                setTimeout(() => {
                    toast.remove();
                }, 3000);
            },



            // ===== Advanced Features =====
            toggleFullscreen() {
                const element = this.$el;
                if (!document.fullscreenElement) {
                    element.requestFullscreen?.().catch(err => 
                        console.error('Fullscreen error:', err)
                    );
                } else {
                    document.exitFullscreen?.();
                }
            },

            changeDensity(density) {
                this.$el.setAttribute('data-density', density);
                this.savePreferences();
            },

            //========== بداية الطباعه =========


            // ===== Busy Print (NEW) =====
            showBusyPrint(message = "جاري تجهيز البيانات للطباعة...", opts = {}) {
                const isHtml = (opts.isHtml === true);

                this.modal.open = true;
                window.__sfTableActive = this;
                window.__sfTableLastActive = this;

                this.modal.title = opts.title || "طباعة";
                this.modal.message = message;

                // لو ما أرسلت class/icon استخدم الافتراضي
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



            //========== نهاية الطباعه =========


        }));

        // دالة عامة للطباعة مع Busy modal
        window.sfPrintWithBusy = window.sfPrintWithBusy || function (table, options) {
            options = options || {};

            if (!table) return false;

            // افتراضي: نفس الرسالة الجميلة اللي عندك
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

            // ✅ افتح مودال الـ Busy
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

            // ✅ كوّن رابط الطباعة من نفس الصفحة
            let url;
            try {
                const u = new URL(window.location.href);
                u.searchParams.set('pdf', String(pdfVal));

                // أي بارامترات إضافية
                if (options.extraParams && typeof options.extraParams === "object") {
                    Object.keys(options.extraParams).forEach(k => {
                        const v = options.extraParams[k];
                        if (v === null || v === undefined) return;
                        u.searchParams.set(k, String(v));
                    });
                }

                url = u.toString();
            } catch (e) {
                table.hideBusyPrint();
                table.showToast("تعذر تجهيز رابط الطباعة", "error");
                return false;
            }

            // ✅ ابدأ الطباعة عبر iframe
            table.__printHandle = sfOpenPrint(url, {
                onBeforePrint: () => table.hideBusyPrint(),
                onAfterPrint: () => table.hideBusyPrint(), // احتياط
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


document.addEventListener("DOMContentLoaded", () => {

    document.body.addEventListener("invalid", function (e) {
        e.target.setCustomValidity("يرجى ملء هذا الحقل");
    }, true);

    document.body.addEventListener("input", function (e) {
        e.target.setCustomValidity("");
    }, true);

});

