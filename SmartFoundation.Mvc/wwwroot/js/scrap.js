(function () {
    "use strict";

    var reasonHeader = "بعد الكشف على العربة الموضح بياناتها أعلاه وجد بها الأعطال التالية:\n\n";

    function showError(message, table) {
        if (table && typeof table.showToast === "function") table.showToast(message, "error");
        else if (window.toastr?.error) window.toastr.error(message);
        else window.alert(message);
    }

    function getConfig(action) {
        var meta = action?.meta ?? action?.Meta ?? {};
        return meta.smartDynamicFields ?? meta.SmartDynamicFields ?? null;
    }

    async function sfOpenScrapInsertModal(row, action, table) {
        try {
            if (!window.SmartDynamicFields) throw new Error("لم يتم تحميل مكوّن الحقول الديناميكية");
            if (!table || typeof table.openModal !== "function") throw new Error("تعذر فتح نموذج الإتلاف");

            var config = getConfig(action);
            if (!config) throw new Error("إعدادات أسباب الإتلاف غير موجودة");

            await table.openModal(action, row || {});
            await window.SmartDynamicFields.mountInFormWhenReady("InsertScrapForm", config);
        } catch (error) {
            console.error("sfOpenScrapInsertModal failed:", error);
            showError(error?.message || "فشل فتح نموذج الإتلاف", table);
        }
    }

    function sfSubmitScrapInsert(button) {
        try {
            var form = button?.closest("form");
            if (!form) throw new Error("تعذر العثور على نموذج الإتلاف");

            var instance = window.SmartDynamicFields?.getInstance("scrap-reasons");
            if (!instance) throw new Error("مكوّن أسباب الإتلاف غير مهيأ");
            if (!instance.validate({ report: true })) return;

            var reasons = instance.getRows().map(function (item) {
                return String(item.reasonDescription || "").trim();
            }).filter(Boolean);

            var reasonText = reasonHeader + reasons.join("\n");
            if (reasonText.length > 800) {
                showError("إجمالي نص أسباب الإتلاف يجب ألا يتجاوز 800 حرف");
                return;
            }

            var hidden = form.querySelector('[name="p06"]');
            if (!hidden) throw new Error("حقل حفظ أسباب الإتلاف غير موجود");
            hidden.value = reasonText;

            form.querySelectorAll("select:disabled").forEach(function (select) {
                select.disabled = false;
            });

            var body = new FormData(form);

            // Preserve the previous request shape. The gateway contract remains p06 text.
            reasons.forEach(function (reason, index) {
                body.append("__reason_" + (index + 1), reason);
            });

            var redirectUrl = body.get("redirectUrl") || "/Vehicle/Scrap";
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
            console.error("sfSubmitScrapInsert failed:", error);
            showError(error?.message || "فشل حفظ محضر الإتلاف");
        }
    }

    window.sfOpenScrapInsertModal = sfOpenScrapInsertModal;
    window.sfSubmitScrapInsert = sfSubmitScrapInsert;
})();
