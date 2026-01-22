// SmartFoundation\SmartFoundation.Mvc\wwwroot\js\smartprint\smartprint-a4portrait.js
window.SmartPrint = window.SmartPrint || {};
(function (api) {
    
    function initAll() {
        console.log('تهيئة SmartPrint A4 Portrait');
        document.querySelectorAll(".smart-a4p__page-num").forEach(el => {
            el.textContent = '';
        });
    }
    // تشغيل عند التحميل
    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", function() {
            setTimeout(initAll, 200);
        });
    } else {
        setTimeout(initAll, 200);
    }
    
    api.initA4Portrait = initAll;
    
})(window.SmartPrint);