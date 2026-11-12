(function () {
    "use strict";

    function showError(message, table) {
        if (table && typeof table.showToast === "function") table.showToast(message, "error");
        else if (window.toastr?.error) window.toastr.error(message);
        else window.alert(message);
    }

    function getConfig(action) {
        var meta = action?.meta ?? action?.Meta ?? {};
        return meta.smartDynamicFields ?? meta.SmartDynamicFields ?? null;
    }

    async function sfOpenGeneralInsertModal(row, action, table) {
        try {
            if (!window.SmartDynamicFields) throw new Error("لم يتم تحميل مكوّن الحقول الديناميكية");
            if (!table || typeof table.openModal !== "function") throw new Error("تعذر فتح نموذج الصيانة العامة");

            var config = getConfig(action);
            if (!config) throw new Error("إعدادات أعطال الصيانة العامة غير موجودة");

            await table.openModal(action, row || {});
            await window.SmartDynamicFields.mountInFormWhenReady("generalInsertForm", config);
        } catch (error) {
            console.error("sfOpenGeneralInsertModal failed:", error);
            showError(error?.message || "فشل فتح نموذج الصيانة العامة", table);
        }
    }

    function getOrderId(row) {
        return row?.MaintOrdID ?? row?.maintOrdID ?? row?.p01 ?? null;
    }

    async function loadGeneralFaults(orderId) {
        var response = await fetch("/Vehicle/GetGeneralFaults?maintOrdID=" + encodeURIComponent(orderId), {
            method: "GET",
            headers: { "X-Requested-With": "XMLHttpRequest" }
        });

        var payload;
        try {
            payload = await response.json();
        } catch (_) {
            throw new Error("استجابة تحميل الأعطال غير صالحة");
        }

        if (!response.ok || payload?.success !== true) {
            throw new Error(payload?.message || "تعذر تحميل أعطال أمر الصيانة");
        }

        return (payload.items || []).map(function (item) {
            return {
                faultId: item.FaultID ?? item.faultID ?? item.faultId ?? "",
                faultDescription: item.FaultDescription ?? item.faultDescription ?? ""
            };
        });
    }

    async function sfOpenGeneralEditModal(row, action, table) {
        try {
            if (!window.SmartDynamicFields) throw new Error("لم يتم تحميل مكوّن الحقول الديناميكية");
            if (!table || typeof table.openModal !== "function") throw new Error("تعذر فتح نموذج تعديل الصيانة العامة");

            var orderId = getOrderId(row);
            if (!orderId) throw new Error("رقم أمر الصيانة غير متوفر");

            var baseConfig = getConfig(action);
            if (!baseConfig) throw new Error("إعدادات تعديل الأعطال غير موجودة");

            var faults = await loadGeneralFaults(orderId);
            var config = JSON.parse(JSON.stringify(baseConfig));
            config.initialRows = faults;

            await table.openModal(action, row || {});
            await window.SmartDynamicFields.mountInFormWhenReady("generalEditForm", config);
        } catch (error) {
            console.error("sfOpenGeneralEditModal failed:", error);
            showError(error?.message || "فشل فتح نموذج تعديل الصيانة العامة", table);
        }
    }

    // Compatibility name retained for callers from the previous implementation.
    function sfRenumberFaults() {
        var instance = window.SmartDynamicFields?.getInstance("general-maintenance-faults");
        instance?.updateState();
        instance?.sync();
    }

    function sfSubmitGeneralInsert(button) {
        try {
            var form = button?.closest("form");
            if (!form) throw new Error("تعذر العثور على نموذج الصيانة العامة");

            var instance = window.SmartDynamicFields?.getInstance("general-maintenance-faults");
            if (!instance) throw new Error("مكوّن الأعطال غير مهيأ");
            if (!instance.validate({ report: true })) return;

            var items = instance.getRows();
            instance.sync();

            form.querySelectorAll("select:disabled").forEach(function (select) {
                select.disabled = false;
            });

            var body = new FormData(form);

            // Preserve the previous request shape. The gateway contract remains p09 JSON.
            items.forEach(function (item, index) {
                body.append("__fault_" + (index + 1), item.faultDescription || "");
            });

            var redirectUrl = body.get("redirectUrl") || "/Vehicle/GeneralMaintenance";
            button.disabled = true;
            button.innerHTML = '<i class="fa fa-spinner fa-spin"></i> جاري الحفظ...';

            fetch("/crud/insert", { method: "POST", body: body, redirect: "manual" })
                .then(function () {
                    window.location.href = redirectUrl;
                })
                .catch(function (error) {
                    button.disabled = false;
                    button.textContent = "حفظ";
                    showError("خطأ: " + error.message);
                });
        } catch (error) {
            console.error("sfSubmitGeneralInsert failed:", error);
            showError(error?.message || "فشل حفظ أمر الصيانة العامة");
        }
    }

    function sfSubmitGeneralEdit(button) {
        try {
            var form = button?.closest("form");
            if (!form) throw new Error("تعذر العثور على نموذج تعديل الصيانة العامة");

            var instance = window.SmartDynamicFields?.getInstance("general-maintenance-edit-faults");
            if (!instance) throw new Error("مكوّن تعديل الأعطال غير مهيأ");
            if (!instance.validate({ report: true })) return;

            var faults = instance.getRows().map(function (item, index) {
                var rawId = String(item.faultId ?? "").trim();
                return {
                    faultId: rawId ? Number(rawId) : null,
                    lineNo: index + 1,
                    faultDescription: String(item.faultDescription || "").trim()
                };
            });

            var output = form.querySelector('[name="p09"]');
            if (!output) throw new Error("حقل حفظ الأعطال غير موجود");
            output.value = JSON.stringify(faults);

            form.querySelectorAll("select:disabled").forEach(function (select) {
                select.disabled = false;
            });

            button.disabled = true;
            button.innerHTML = '<i class="fa fa-spinner fa-spin"></i> جاري الحفظ...';
            form.submit();
        } catch (error) {
            console.error("sfSubmitGeneralEdit failed:", error);
            showError(error?.message || "فشل تعديل أمر الصيانة العامة");
        }
    }

    window.sfOpenGeneralInsertModal = sfOpenGeneralInsertModal;
    window.sfOpenGeneralEditModal = sfOpenGeneralEditModal;
    window.sfRenumberFaults = sfRenumberFaults;
    window.sfSubmitGeneralInsert = sfSubmitGeneralInsert;
    window.sfSubmitGeneralEdit = sfSubmitGeneralEdit;
})();
