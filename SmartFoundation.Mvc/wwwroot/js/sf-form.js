//  تسجيل مكون Alpine للنموذج
(function () {
    const register = () => {
        Alpine.data('smartForm', () => ({
            loading: false,
            message: '',
            success: true,
            show: false,

            //  دالة إرسال النموذج (ترسل JSON)
            async submitForm(actionUrl = "/smart/execute", method = "POST", event) {
                if (event) event.preventDefault();

                this.loading = true;
                this.show = false;

                try {
                    const form = event?.target || document.querySelector('form');
                    if (!form) throw new Error("⚠️ لم يتم العثور على النموذج");

                    if (!form.reportValidity()) {
                        this.showMessage("⚠️ يرجى تعبئة جميع الحقول بشكل صحيح", false);
                        return;
                    }

                    const formData = new FormData(form);
                    const params = Object.fromEntries(formData.entries());

                    const smartRequest = {
                        Component: "Form",
                        SpName: form.getAttribute('data-sp') || 'sp_SmartFormDemo',
                        Operation: form.getAttribute('data-operation') || 'insert',
                        Params: params,
                        Meta: {}
                    };

                    // add the header and handle 401 before parsing JSON
                    const response = await fetch(actionUrl, {
                        method,
                        headers: {
                            'Content-Type': 'application/json',
                            'Accept': 'application/json',
                            'X-Requested-With': 'XMLHttpRequest'
                        },
                        body: JSON.stringify(smartRequest)
                    });

                    if (response.status === 401) {
                        window.location.href = "/Login/Index?logout=1";
                        return;
                    }

                    const result = await response.json();

                    
                    if (result.success) {
                        this.showMessage(result.message || "✅ تم حفظ البيانات بنجاح!", true);
                        document.dispatchEvent(new CustomEvent("form-saved", { detail: result }));
                    } else {
                        this.showMessage(result.error || result.message || "⚠️ حدث خطأ أثناء الحفظ", false);
                    }
                } catch (error) {
                    console.error("submitForm error:", error);
                    this.showMessage("⚠️ حدث خطأ في الاتصال بالسيرفر", false);
                } finally {
                    this.loading = false;
                }
            },

            //دالة عرض الرسائل (نجاح/خطأ)
            showMessage(message, isSuccess = true) {
                this.message = message;
                this.success = isSuccess;
                this.show = true;
                setTimeout(() => { this.show = false; }, 5000);
            }
        }));
    };

    if (window.Alpine) register();
    else document.addEventListener("alpine:init", register);
})();

//  دالة عامة للتوستر
function toast(message, success = true) {
    const elements = document.querySelectorAll('[x-data]');
    let found = false;
    for (const el of elements) {
        const alpineData = el._x_dataStack?.[0];
        if (alpineData && typeof alpineData.showMessage === 'function') {
            alpineData.showMessage(message, success);
            found = true;
            break;
        }
    }
    if (!found) alert(message);
}

//  دالة إرسال النموذج العامة (خارج Alpine) – JSON
async function submitForm(actionUrl = "/smart/execute", method = "POST", formId = null) {
    try {
        let form = formId ? document.getElementById(formId) : document.querySelector("form");
        if (!form) throw new Error("⚠️ لم يتم العثور على أي فورم");

        if (!form.reportValidity()) {
            return { success: false, error: "⚠️ يرجى تعبئة جميع الحقول بشكل صحيح" };
        }

        const formData = new FormData(form);
        const params = Object.fromEntries(formData.entries());

        const body = {
            Component: "Form",
            SpName: form.getAttribute("data-sp") || "sp_SmartFormDemo",
            Operation: form.getAttribute("data-operation") || "insert",
            Params: params,
            Meta: {}
        };

        const resp = await fetch(actionUrl, {
            method,
            headers: { "Content-Type": "application/json", "Accept": "application/json" },
            body: JSON.stringify(body)
        });

        const json = await resp.json();

        if (json.success ?? resp.ok) {
            //  هنا برضه نعرض رسالة السيرفر لو موجودة
            toast(json.message || "✅ تم حفظ البيانات بنجاح!", true);
            document.dispatchEvent(new CustomEvent("form-saved", { detail: json }));
        } else {
            toast(json.error || json.message || "⚠️ حدث خطأ أثناء الحفظ", false);
        }

        return { success: json.success ?? resp.ok, error: json.error, meta: json.meta };
    } catch (e) {
        console.error("submitForm error:", e);
        toast("⚠️ حدث خطأ في الاتصال بالسيرفر", false);
        return { success: false, error: "⚠️ حدث خطأ في الاتصال بالسيرفر" };
    }
}

//  دوال إضافية
function cancelForm() { if (window.history.length > 1) history.back(); }
function editForm() { console.log("editForm: افتح وضع التعديل"); }
function deleteForm() { console.log("deleteForm: نفّذ تأكيد ثم submitForm('/smart/execute', 'POST', 'myFormId')"); }



function sfInitSelect2(root = document) {
    if (!window.jQuery || !jQuery.fn || !jQuery.fn.select2) return;

    const $root = jQuery(root);
    const stripSelect2Title = ($select) => {
        if (!$select || !$select.length) return;
        const $container = $select.next(".select2");
        $container.find(".select2-selection__rendered").removeAttr("title");
        $container.find(".select2-selection").removeAttr("title");
    };

    $root
        .find('select.js-select2:not([data-sf-select2-skip-global="1"])')
        .add($root.is('select.js-select2:not([data-sf-select2-skip-global="1"])') ? $root : [])
        .each(function () {
            const $s = jQuery(this);
            if ($s.data('select2')) return;

            const ph = $s.data('s2-placeholder') || '';
            const min = $s.data('s2-min-results');

            $s.select2({
                width: '100%',
                dir: 'rtl',
                placeholder: ph,
                minimumResultsForSearch:
                    (min !== undefined && min !== null && min !== '')
                        ? parseInt(min, 10)
                        : 0
            });

            stripSelect2Title($s);
            $s.on("change.sfNoTitle select2:select.sfNoTitle select2:clear.sfNoTitle select2:unselect.sfNoTitle select2:open.sfNoTitle", function () {
                stripSelect2Title($s);
            });
        });
}


(function () {
    const run = () => sfInitSelect2(document);

    document.addEventListener("DOMContentLoaded", run);

    const obs = new MutationObserver((mutations) => {
        for (const m of mutations) {
            for (const node of m.addedNodes) {
                if (node.nodeType !== 1) continue;
                if (
                    node.matches?.('select.js-select2:not([data-sf-select2-skip-global="1"])') ||
                    node.querySelector?.('select.js-select2:not([data-sf-select2-skip-global="1"])')
                ) {
                    sfInitSelect2(node);
                }
            }
        }
    });

    obs.observe(document.body, { childList: true, subtree: true });
})();


(function () {
    function closeAllDropdowns() {
        // 1) Select2
        if (window.jQuery && jQuery.fn && jQuery.fn.select2) {
            jQuery("select.select2-hidden-accessible").each(function () {
                try { jQuery(this).select2("close"); } catch (e) { }
            });
        }

        // 2) لو عندك dropdown مخصص (panel) مثل .sf-select-panel
        document.querySelectorAll(".sf-select-panel").forEach(p => p.remove());

        // 3) تنظيف أي بقايا dropdown في DOM (احتياط)
        document.querySelectorAll(".select2-container--open").forEach(el => el.classList.remove("select2-container--open"));
        document.querySelectorAll(".select2-dropdown").forEach(el => el.style.display = "none");
    }

    // اقفل قبل التنقل (التقاط الحدث قبل ما يشتغل الراوتر/التحميل)
    document.addEventListener("click", function (e) {
        const a = e.target.closest("a[href]");
        if (!a) return;

        // تجاهل الروابط اللي ما تنقل صفحة فعليًا
        const href = a.getAttribute("href") || "";
        if (href === "#" || href.startsWith("javascript:")) return;

        closeAllDropdowns();
    }, true);

    // لو عندك Turbo/HTMX (اختياري ومفيد)
    document.addEventListener("turbo:before-visit", closeAllDropdowns);
    document.addEventListener("htmx:beforeRequest", closeAllDropdowns);
})();




// sfNav: دالة تنقّل عامة لـ SmartForm تقرأ قيمة الحقل (input/select)، تتحقق منها (Required / Reject / Regex)، تبني الرابط من data-sf-url و data-sf-key، تعرض toastr عند الخطأ، ثم تنفّذ التنقّل — تُستخدم مع onclick / onchange وتعتمد على data-* من FieldConfig و FormButtonConfig.
// ===== SmartForm: Navigation Helper (Generic) =====
window.sfNav = function (el, forcedValue) {
    const d = el?.dataset || {};
    const fieldName = d.sfField;
    let value = (forcedValue != null)
        ? String(forcedValue).trim()
        : (fieldName
            ? (document.querySelector(`[name="${fieldName}"]`)?.value ?? '').trim()
            : (el?.value ?? '').trim());

   
    // required
    if (d.sfRequired === "1" && !value) {
        return (window.toastr?.error(d.sfRequiredMsg || "الرجاء تعبئة الحقل"));
    }

    // reject (مثل -1 للـ select)
    if (d.sfReject != null && String(value) === String(d.sfReject)) {
        const type = d.sfToastType || "info";
        return (window.toastr?.[type]?.(d.sfRejectMsg || "الرجاء الاختيار اولا"));
    }

    // pattern (regex)
    if (d.sfPattern) {
        const re = new RegExp(d.sfPattern);
        if (!re.test(value)) {
            return (window.toastr?.error(d.sfPatternMsg || "قيمة غير صحيحة"));
        }
    }

    // 3) بناء الرابط 
    const url = d.sfUrl;
    const key = d.sfKey;

    if (!url) {
        return (window.toastr?.error("sfUrl غير موجود"));
    }
    const qs = new URLSearchParams();
    if (key) qs.set(key, value);

    // مفاتيح إضافية (ثابتة NavValX أو ديناميكية من حقول أخرى NavFieldX)
    for (let i = 2; i <= 5; i++) {
        const k = d[`sfKey${i}`];
        if (!k) continue;

        // 1) ثابت
        let v = d[`sfVal${i}`];

        // 2) ديناميكي من حقل آخر
        if ((v == null || v === "") && d[`sfField${i}`]) {
            const srcName = d[`sfField${i}`];
            v = (document.querySelector(`[name="${srcName}"]`)?.value ?? "").trim();

            // إذا المصدر فاضي، امنع التنقّل
            if (!v) {
                return window.toastr?.info("اكمل الاختيارات المطلوبة أولاً");
            }
        }

        if (v != null && v !== "") qs.set(k, v);
    }

    const finalUrl = qs.toString() ? `${url}?${qs}` : url;
    window.location.href = finalUrl;
};

// sfToggle: دالة عامة للتحكم في إظهار/إخفاء حقول الفورم بناءً على قيمة الحقل الحالي
// تستخدم data-sf-toggle-group لتجميع الحقول، و data-sf-toggle-map لتحديد أي حقول تظهر لكل قيمة
window.sfToggle = function (el, forcedValue) {
    const d = el?.dataset || {};
    const value = (forcedValue != null)
        ? String(forcedValue).trim()
        : String(el?.value ?? "").trim();

    const group = d.sfToggleGroup;
    const mapStr = d.sfToggleMap || "";
    if (!group || !mapStr) return;

    const root = el.closest('form') || document;

    // اخفاء كل العناصر التابعة للمجموعة
    root.querySelectorAll(`[data-sf-toggle-group="${group}"]`)
        .forEach(x => x.closest('.form-group')?.style.setProperty('display', 'none'));

    if (!value) return;

    // استخراج القائمة المطلوبة من الخريطة: "1:A,B|2:C"
    const rules = mapStr.split('|').map(s => s.trim()).filter(Boolean);
    const rule = rules.find(r => r.startsWith(value + ':'));
    if (!rule) return;

    const names = rule.slice((value + ':').length).split(',').map(s => s.trim()).filter(Boolean);
    names.forEach(n => {
        const target = root.querySelector(`[name="${n}"]`);
        if (target) target.closest('.form-group')?.style.setProperty('display', 'block');
    });
};

// SupportMyTickets:
// - Fill p06 (page URL) when p05 (page name) changes
// - Load and filter p07 (actions) by selected page + user permissions
window.sfSupportPageChanged = async function (el) {
    const form = el?.closest("form") || document;
    const selectedPage = (el?.value || "").trim();
    const pageUrlInput = form.querySelector('input[name="p06"]');
    const actionSelect = form.querySelector('select[name="p07"]');

    const refreshSelect2 = (selectEl) => {
        if (!selectEl || !window.jQuery || !jQuery.fn || !jQuery.fn.select2) return;
        const $s = jQuery(selectEl);
        if ($s.data("select2")) {
            $s.trigger("change.select2");
        }
    };

    const resetActions = () => {
        if (!actionSelect) return;

        actionSelect.innerHTML = "";
        actionSelect.selectedIndex = -1;
        actionSelect.disabled = true;
        refreshSelect2(actionSelect);
    };

    if (pageUrlInput) {
        pageUrlInput.value = "";
        pageUrlInput.dispatchEvent(new Event("input", { bubbles: true }));
        pageUrlInput.dispatchEvent(new Event("change", { bubbles: true }));
    }

    resetActions();

    if (!selectedPage) return;

    try {
        const url = `/Support/SupportMyTicketsPageMeta?pageName=${encodeURIComponent(selectedPage)}`;
        const response = await fetch(url, {
            method: "GET",
            headers: {
                "Accept": "application/json",
                "X-Requested-With": "XMLHttpRequest"
            }
        });

        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }

        const data = await response.json();
        const pageUrl = (data?.pageUrl || "").toString().trim();
        const actions = Array.isArray(data?.actions) ? data.actions : [];

        if (pageUrlInput) {
            pageUrlInput.value = pageUrl;
            pageUrlInput.dispatchEvent(new Event("input", { bubbles: true }));
            pageUrlInput.dispatchEvent(new Event("change", { bubbles: true }));
        }

        if (!actionSelect) return;

        actionSelect.innerHTML = "";

        for (const action of actions) {
            const value = (action?.value ?? action?.Value ?? "").toString().trim();
            const text = (action?.text ?? action?.Text ?? value).toString().trim();
            if (!value) continue;

            const opt = document.createElement("option");
            opt.value = value;
            opt.textContent = text;
            actionSelect.appendChild(opt);
        }

        actionSelect.value = "";
        actionSelect.selectedIndex = -1;
        actionSelect.disabled = actions.length === 0;
        refreshSelect2(actionSelect);
    } catch (err) {
        console.error("sfSupportPageChanged error:", err);
        resetActions();
        if (window.toastr?.error) {
            window.toastr.error("تعذر تحميل إجراءات الصفحة المختارة");
        }
    }
};

// SupportPhoneTickets:
// - p09 (caller) controls p05 (page list) based on selected caller permissions
// - p05 controls p06 (URL) + p07 (actions) for selected caller/page
window.sfSupportPhoneCallerChanged = async function (el) {
    const form = el?.closest("form") || document;
    const callerUserId = (el?.value || "").trim();
    const pageSelect = form.querySelector('select[name="p05"]');
    const pageUrlInput = form.querySelector('input[name="p06"]');
    const actionSelect = form.querySelector('select[name="p07"]');

    const refreshSelect2 = (selectEl) => {
        if (!selectEl || !window.jQuery || !jQuery.fn || !jQuery.fn.select2) return;
        const $s = jQuery(selectEl);
        if ($s.data("select2")) {
            $s.trigger("change.select2");
        }
    };

    const resetActions = () => {
        if (!actionSelect) return;
        actionSelect.innerHTML = "";
        actionSelect.value = "";
        actionSelect.selectedIndex = -1;
        actionSelect.disabled = true;
        refreshSelect2(actionSelect);
    };

    const resetPages = () => {
        if (!pageSelect) return;
        pageSelect.innerHTML = "";
        pageSelect.value = "";
        pageSelect.selectedIndex = -1;
        pageSelect.disabled = true;
        refreshSelect2(pageSelect);
    };

    if (pageUrlInput) {
        pageUrlInput.value = "";
        pageUrlInput.dispatchEvent(new Event("input", { bubbles: true }));
        pageUrlInput.dispatchEvent(new Event("change", { bubbles: true }));
    }

    resetPages();
    resetActions();

    if (!callerUserId) return;

    try {
        const url = `/Support/SupportPhoneTicketsPageMeta?callerUserId=${encodeURIComponent(callerUserId)}`;
        const response = await fetch(url, {
            method: "GET",
            headers: {
                "Accept": "application/json",
                "X-Requested-With": "XMLHttpRequest"
            }
        });

        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }

        const data = await response.json();
        const pages = Array.isArray(data?.pages) ? data.pages : [];

        if (!pageSelect) return;

        pageSelect.innerHTML = "";
        for (const page of pages) {
            const value = (page?.value ?? page?.Value ?? "").toString().trim();
            const text = (page?.text ?? page?.Text ?? value).toString().trim();
            if (!value) continue;

            const opt = document.createElement("option");
            opt.value = value;
            opt.textContent = text;
            pageSelect.appendChild(opt);
        }

        pageSelect.value = "";
        pageSelect.selectedIndex = -1;
        pageSelect.disabled = pages.length === 0;
        refreshSelect2(pageSelect);
    } catch (err) {
        console.error("sfSupportPhoneCallerChanged error:", err);
        if (window.toastr?.error) {
            window.toastr.error("تعذر تحميل صفحات المستخدم المختار");
        }
    }
};

window.sfSupportPhonePageChanged = async function (el) {
    const form = el?.closest("form") || document;
    const selectedPage = (el?.value || "").trim();
    const callerSelect = form.querySelector('select[name="p09"]');
    const callerUserId = (callerSelect?.value || "").trim();
    const pageUrlInput = form.querySelector('input[name="p06"]');
    const actionSelect = form.querySelector('select[name="p07"]');

    const refreshSelect2 = (selectEl) => {
        if (!selectEl || !window.jQuery || !jQuery.fn || !jQuery.fn.select2) return;
        const $s = jQuery(selectEl);
        if ($s.data("select2")) {
            $s.trigger("change.select2");
        }
    };

    const resetActions = () => {
        if (!actionSelect) return;
        actionSelect.innerHTML = "";
        actionSelect.value = "";
        actionSelect.selectedIndex = -1;
        actionSelect.disabled = true;
        refreshSelect2(actionSelect);
    };

    if (pageUrlInput) {
        pageUrlInput.value = "";
        pageUrlInput.dispatchEvent(new Event("input", { bubbles: true }));
        pageUrlInput.dispatchEvent(new Event("change", { bubbles: true }));
    }

    resetActions();

    if (!selectedPage || !callerUserId) return;

    try {
        const url = `/Support/SupportPhoneTicketsPageMeta?callerUserId=${encodeURIComponent(callerUserId)}&pageName=${encodeURIComponent(selectedPage)}`;
        const response = await fetch(url, {
            method: "GET",
            headers: {
                "Accept": "application/json",
                "X-Requested-With": "XMLHttpRequest"
            }
        });

        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }

        const data = await response.json();
        const pageUrl = (data?.pageUrl || "").toString().trim();
        const actions = Array.isArray(data?.actions) ? data.actions : [];

        if (pageUrlInput) {
            pageUrlInput.value = pageUrl;
            pageUrlInput.dispatchEvent(new Event("input", { bubbles: true }));
            pageUrlInput.dispatchEvent(new Event("change", { bubbles: true }));
        }

        if (!actionSelect) return;

        actionSelect.innerHTML = "";
        for (const action of actions) {
            const value = (action?.value ?? action?.Value ?? "").toString().trim();
            const text = (action?.text ?? action?.Text ?? value).toString().trim();
            if (!value) continue;

            const opt = document.createElement("option");
            opt.value = value;
            opt.textContent = text;
            actionSelect.appendChild(opt);
        }

        actionSelect.value = "";
        actionSelect.selectedIndex = -1;
        actionSelect.disabled = actions.length === 0;
        refreshSelect2(actionSelect);
    } catch (err) {
        console.error("sfSupportPhonePageChanged error:", err);
        resetActions();
        if (window.toastr?.error) {
            window.toastr.error("تعذر تحميل إجراءات الصفحة المختارة");
        }
    }
};


// تفعيل الانتر على نفس الحقل + منع التكرار
window.sfEnter = (function () {

    let locked = false; // قفل لمنع الضغط المتكرر

    return function (inputEl) {
        if (!inputEl || locked) return;

        locked = true; // اقفل فورًا

        try {
            // 1) لو فيه زر inline (بحث / تنقّل)
            const btn = inputEl.closest('.form-group')?.querySelector('button[data-sf-field]');
            if (btn) {
                window.sfNav(btn);
                return;
            }

            // 2) غير كذا: submit الفورم
            const form = inputEl.closest('form');
            if (!form) return;

            form.requestSubmit?.();
            if (!form.requestSubmit) {
                form.dispatchEvent(new Event('submit', { cancelable: true, bubbles: true }));
            }

        } finally {
            // فك القفل بعد 300ms
            setTimeout(() => { locked = false; }, 500);
        }
    };

})();

// PeriodicMaintenance START — Move Group modal handlers
function sfOpenMoveGroupModal(row, action, table) {
    if (!row) {
        if (table && table.getSelectedRows) {
            var rows = table.getSelectedRows();
            if (rows && rows.length > 0) row = rows[0];
        }
        if (!row) { if (typeof toastr !== 'undefined') toastr.error('اختر مركبة'); return; }
    }
    var chassis = row.chassisNumber || row.chassisNumber_FK || '';
    var currentGroup = row.GroupCode || row.groupCode || '';
    if (!chassis) { if (typeof toastr !== 'undefined') toastr.error('رقم الهيكل غير متوفر'); return; }

    if (action.openForm && action.openForm.fields) {
        action.openForm.fields.forEach(function(f) {
            if (f.name === 'p01') f.value = String(chassis);
            if (f.name === 'currentGroup_display') f.value = currentGroup || 'غير معينة';
        });
    }
    if (table && typeof table.openModal === 'function') table.openModal(action, row);
}

function sfSubmitMoveGroup(btn) {
    try {
        var form = btn.closest('form');
        if (!form) return;
        form.querySelectorAll('select:disabled').forEach(function(sel) { sel.disabled = false; });
        btn.disabled = true;
        btn.innerHTML = '<i class="fa fa-spinner fa-spin"></i> جاري النقل...';
        form.submit();
    } catch(e) {
        btn.disabled = false;
        btn.innerHTML = 'تأكيد النقل';
        if (typeof toastr !== 'undefined') toastr.error('sfSubmitMoveGroup: ' + e.message);
        else alert('sfSubmitMoveGroup: ' + e.message);
    }
}
// PeriodicMaintenance END

function sfAutoEndDate(el, days) {
    if (!el || !days) return;
    var form = el.closest('form');
    if (!form) return;

    var startVal = el.value;
    if (!startVal) return;

    var startDate = new Date(startVal);
    if (isNaN(startDate.getTime())) return;

    var endDate = new Date(startDate);
    endDate.setDate(endDate.getDate() + days);

    var yyyy = endDate.getFullYear();
    var mm = String(endDate.getMonth() + 1).padStart(2, '0');
    var dd = String(endDate.getDate()).padStart(2, '0');
    var endStr = yyyy + '-' + mm + '-' + dd;

    var allInputs = form.querySelectorAll('input.js-date, input[type="date"]');
    var foundSelf = false;
    for (var i = 0; i < allInputs.length; i++) {
        if (allInputs[i] === el) { foundSelf = true; continue; }
        if (foundSelf) {
            var target = allInputs[i];
            if (target._flatpickr) {
                target._flatpickr.setDate(endStr);
            } else {
                target.value = endStr;
            }
            break;
        }
    }
}

function sfSetArmyNumber(el) {
    if (!el) return;
    var chassis = el.value;
    if (!chassis) return;
    var form = el.closest('form');
    if (!form) return;

    if (window.__armyNumberLookup) {
        var display = form.querySelector('input[name="armyNumber_display"]');
        if (display) {
            display.value = window.__armyNumberLookup[chassis] || '';
        }
    }

    sfSetGroupFromVehicle(chassis, form);
}

function sfSetGroupFromVehicle(chassis, form) {
    if (!form) return;
    var groupSelect = form.querySelector('select[name="p02"]');
    if (!groupSelect) return;

    if (!window.__vehicleGroupLookup || !window.__vehicleGroupLookup[chassis]) {
        groupSelect.value = '';
        groupSelect.disabled = false;
        if (window.jQuery && jQuery.fn.select2) {
            jQuery(groupSelect).val('').trigger('change');
            jQuery(groupSelect).prop('disabled', false);
        }
        return;
    }

    var info = window.__vehicleGroupLookup[chassis];
    var gid = String(info.groupID || info.GroupID || '');
    if (gid) {
        groupSelect.value = gid;
        groupSelect.disabled = true;
        if (window.jQuery && jQuery.fn.select2) {
            jQuery(groupSelect).val(gid).trigger('change');
            jQuery(groupSelect).prop('disabled', true);
        }
    }
}

async function sfOpenClosePeriodicModal(row, action, table) {
    if (!row) {
        if (table && table.getSelectedRows) {
            var rows = table.getSelectedRows();
            if (rows && rows.length > 0) row = rows[0];
        }
        if (!row) { table && table.showToast ? table.showToast('اختر أمر صيانة واحد', 'error') : alert('اختر أمر صيانة واحد'); return; }
    }
    var ordID = row.openOrderID || row.MaintOrdID;
    if (!ordID) { table && table.showToast ? table.showToast('رقم أمر الصيانة غير متوفر', 'error') : alert('رقم أمر الصيانة غير متوفر'); return; }

    try {
        var resp = await fetch('/Vehicle/GetPeriodicDetails?maintOrdID=' + ordID);
        var data = await resp.json();
    } catch (err) {
        if (table && table.showToast) table.showToast('خطأ في تحميل بنود الفحص', 'error');
        else alert('خطأ في تحميل بنود الفحص');
        return;
    }

    if (!data.success || !data.items || data.items.length === 0) {
        if (table && table.showToast) table.showToast('لا توجد بنود فحص لهذا الأمر', 'error');
        else alert('لا توجد بنود فحص لهذا الأمر');
        return;
    }

    var baseFields = [];
    if (action.openForm && action.openForm.fields) {
        action.openForm.fields.forEach(function(f) {
            var clone = Object.assign({}, f);
            if (clone.name === 'p01') clone.value = String(ordID);
            baseFields.push(clone);
        });
    }

    data.items.forEach(function(item) {
        var key = item.typesID_FK || item.MaintDetailesID;
        var detailId = item.MaintDetailesID || 0;
        var name = item.itemName || 'بند';
        var curNotes = item.Notes || '';

        baseFields.push({
            name: '__cl_detailid_' + key,
            type: 'hidden',
            value: String(detailId),
            isHidden: true,
            extraCss: 'hidden'
        });

        baseFields.push({
            name: '__cl_type_' + key,
            type: 'hidden',
            value: String(key),
            isHidden: true,
            extraCss: 'hidden'
        });

        baseFields.push({
            name: '__cl_name_' + key,
            label: name,
            type: 'text',
            colCss: '12',
            readonly: true,
            isHidden: true,
            value: name,
            extraCss: 'hidden'
        });

        baseFields.push({
            name: '__cl_check_' + key,
            label: name,
            type: 'checkbox',
            colCss: '12'
        });

        baseFields.push({
            name: '__cl_notes_' + key,
            label: 'الإجراء التصحيحي',
            type: 'textarea',
            colCss: '12',
            value: curNotes
        });
    });

    var formConfig = Object.assign({}, action.openForm || {});
    formConfig.fields = baseFields;
    action.openForm = formConfig;

    if (table && typeof table.openModal === 'function') {
        table.openModal(action, row);
    }

    setTimeout(function() {
        var p02 = document.querySelector('.sf-modal form [name="p02"]');
        if (p02) {
            var today = new Date();
            var yyyy = today.getFullYear();
            var mm = String(today.getMonth() + 1).padStart(2, '0');
            var dd = String(today.getDate()).padStart(2, '0');
            var todayStr = yyyy + '-' + mm + '-' + dd;
            if (p02._flatpickr) {
                p02._flatpickr.setDate(todayStr);
            } else {
                p02.value = todayStr;
            }
        }
    }, 300);
}

function sfSubmitCloseChecklist(btn) {
    var form = btn.closest('form');
    if (!form) return;

    var closeDate = form.querySelector('[name="p02"]');
    if (closeDate && !closeDate.value) {
        if (typeof toastr !== 'undefined') toastr.error('تاريخ الإغلاق مطلوب');
        else alert('تاريخ الإغلاق مطلوب');
        return;
    }

    var checkboxes = form.querySelectorAll('[name^="__cl_check_"]');
    var unchecked = [];
    checkboxes.forEach(function(cb) {
        if (!cb.checked) unchecked.push(cb);
    });

    if (unchecked.length > 0) {
        if (typeof toastr !== 'undefined') toastr.error('يجب تحديد جميع البنود كمكتملة قبل الإغلاق (' + unchecked.length + ' بند غير مكتمل)');
        else alert('يجب تحديد جميع البنود كمكتملة قبل الإغلاق');
        return;
    }

    var details = [];
    checkboxes.forEach(function(cb) {
        var key = cb.name.replace('__cl_check_', '');
        var detailIdField = form.querySelector('[name="__cl_detailid_' + key + '"]');
        var typeField = form.querySelector('[name="__cl_type_' + key + '"]');
        var notesField = form.querySelector('[name="__cl_notes_' + key + '"]');
        details.push({
            MaintDetailesID: detailIdField ? parseInt(detailIdField.value) : 0,
            typesID_FK: typeField ? parseInt(typeField.value) : null,
            CheckStatus_FK: cb.checked ? '268' : '',
            Notes: notesField ? notesField.value : ''
        });
    });

    var p04 = form.querySelector('[name="p04"]');
    if (p04) p04.value = JSON.stringify(details);

    form.querySelectorAll('select:disabled').forEach(function(sel) {
        sel.disabled = false;
    });

    var body = new FormData(form);
    var redirectUrl = body.get('redirectUrl') || '/Vehicle/PeriodicMaintenance';

    btn.disabled = true;
    btn.innerHTML = '<i class="fa fa-spinner fa-spin"></i> جاري الإغلاق...';

    fetch('/crud/update', { method: 'POST', body: body, redirect: 'manual' })
        .then(function() {
            window.location.href = redirectUrl;
        })
        .catch(function(err) {
            btn.disabled = false;
            btn.innerHTML = '<i class="fa fa-lock"></i> إغلاق الأمر';
            if (typeof toastr !== 'undefined') toastr.error('خطأ: ' + err.message);
            else alert('خطأ: ' + err.message);
        });
}

function sfSubmitPeriodicInsert(btn) {
    try {
        var form = btn.closest('form');
        if (!form) return;

        // include disabled selects so their values are submitted with the form
        form.querySelectorAll('select:disabled').forEach(function(sel) {
            sel.disabled = false;
        });

        btn.disabled = true;
        btn.innerHTML = '<i class="fa fa-spinner fa-spin"></i> جاري الحفظ...';

        // Native submit: the server (/crud/insert) sets the real result in TempData
        // (success message OR error message, e.g. duplicate-order rejection) and returns
        // a redirect. Letting the browser follow that redirect is what surfaces the true
        // outcome on the page — no false "success" when the operation actually failed.
        form.submit();
    } catch(e) {
        btn.disabled = false;
        btn.innerHTML = 'حفظ';
        if (typeof toastr !== 'undefined') toastr.error('sfSubmitPeriodicInsert: ' + e.message);
        else alert('sfSubmitPeriodicInsert: ' + e.message);
    }
}

async function sfOpenGeneralCloseModal(row, action, table) {
    if (!row) {
        if (table && table.getSelectedRows) {
            var rows = table.getSelectedRows();
            if (rows && rows.length > 0) row = rows[0];
        }
        if (!row) { table && table.showToast ? table.showToast('اختر أمر صيانة واحد', 'error') : alert('اختر أمر صيانة واحد'); return; }
    }
    var ordID = row.MaintOrdID || row.p01;
    if (!ordID) { table && table.showToast ? table.showToast('رقم أمر الصيانة غير متوفر', 'error') : alert('رقم أمر الصيانة غير متوفر'); return; }

    try {
        var resp = await fetch('/Vehicle/GetGeneralFaults?maintOrdID=' + ordID);
        var data = await resp.json();
    } catch (err) {
        if (table && table.showToast) table.showToast('خطأ في تحميل الأعطال', 'error');
        else alert('خطأ في تحميل الأعطال');
        return;
    }

    if (!data.success || !data.items || data.items.length === 0) {
        if (table && table.showToast) table.showToast('لا توجد أعطال مسجلة لهذا الأمر', 'error');
        else alert('لا توجد أعطال مسجلة لهذا الأمر');
        return;
    }

    var baseFields = [];
    if (action.openForm && action.openForm.fields) {
        action.openForm.fields.forEach(function(f) {
            if (f.name && f.name.indexOf('__gf_') === 0) return;
            var clone = Object.assign({}, f);
            if (clone.name === 'p01') clone.value = String(ordID);
            baseFields.push(clone);
        });
    }

    // Implemented by 60014017 — pre-fill workshop checkboxes from row data
    var existingWs = (row.workshopIDs || "").split(",").map(function(s) { return s.trim(); });
    baseFields.forEach(function(f) {
        if (f.name && f.name.indexOf("__ws_") === 0
            && existingWs.indexOf(f.name.replace("__ws_", "")) >= 0) {
            f.value = "1";
        }
    });

    data.items.forEach(function(item) {
        var id = item.FaultID;
        var desc = item.FaultDescription || '';

        baseFields.push({
            name: '__gf_desc_' + id,
            label: 'الأعطال والقصور',
            type: 'text',
            colCss: '6',
            readonly: true,
            value: desc
        });

        baseFields.push({
            name: '__gf_action_' + id,
            label: 'الإجراء التصحيحي',
            type: 'textarea',
            colCss: '6',
            required: true,
            value: item.CorrectiveAction || ''
        });
    });

    var formConfig = Object.assign({}, action.openForm || {});
    formConfig.fields = baseFields;
    action.openForm = formConfig;

    if (table && typeof table.openModal === 'function') {
        table.openModal(action, row);
    }

    setTimeout(function() {
        var p07 = document.querySelector('.sf-modal form [name="p07"]');
        if (p07) {
            var today = new Date();
            var yyyy = today.getFullYear();
            var mm = String(today.getMonth() + 1).padStart(2, '0');
            var dd = String(today.getDate()).padStart(2, '0');
            var todayStr = yyyy + '-' + mm + '-' + dd;
            if (p07._flatpickr) {
                p07._flatpickr.setDate(todayStr);
            } else {
                p07.value = todayStr;
            }
        }
    }, 300);
}

function sfSubmitGeneralClose(btn) {
    var form = btn.closest('form');
    if (!form) return;

    var closeDate = form.querySelector('[name="p07"]');
    if (closeDate && !closeDate.value) {
        if (typeof toastr !== 'undefined') toastr.error('تاريخ الإغلاق مطلوب');
        else alert('تاريخ الإغلاق مطلوب');
        return;
    }

    var actions = [];
    var textareas = form.querySelectorAll('[name^="__gf_action_"]');
    var missing = false;
    textareas.forEach(function(ta) {
        var id = ta.name.replace('__gf_action_', '');
        var val = (ta.value || '').trim();
        if (!val) missing = true;
        actions.push({ faultID: parseInt(id), correctiveAction: val });
    });

    if (missing) {
        if (typeof toastr !== 'undefined') toastr.error('يجب إدخال الإجراء التصحيحي لكل عطل');
        else alert('يجب إدخال الإجراء التصحيحي لكل عطل');
        return;
    }

    var p09 = form.querySelector('[name="p09"]');
    if (p09) p09.value = JSON.stringify(actions);

    // Implemented by 60014017 — collect workshop checkboxes into p08
    var wsIds = [];
    form.querySelectorAll('input[type="checkbox"][name^="__ws_"]').forEach(function(cb) {
        if (cb.checked) wsIds.push(cb.name.replace("__ws_", ""));
    });
    var p08 = form.querySelector('[name="p08"]');
    if (p08) p08.value = wsIds.join(",");

    form.querySelectorAll('select:disabled').forEach(function(sel) {
        sel.disabled = false;
    });

    var body = new FormData(form);
    var redirectUrl = body.get('redirectUrl') || '/Vehicle/GeneralMaintenance';

    btn.disabled = true;
    btn.innerHTML = '<i class="fa fa-spinner fa-spin"></i> جاري الإغلاق...';

    fetch('/crud/update', { method: 'POST', body: body, redirect: 'manual' })
        .then(function() {
            window.location.href = redirectUrl;
        })
        .catch(function(err) {
            btn.disabled = false;
            btn.innerHTML = '<i class="fa fa-lock"></i> إغلاق الأمر';
            if (typeof toastr !== 'undefined') toastr.error('خطأ: ' + err.message);
            else alert('خطأ: ' + err.message);
        });
}
