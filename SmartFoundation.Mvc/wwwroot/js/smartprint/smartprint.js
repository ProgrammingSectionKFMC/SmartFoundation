// SmartFoundation\SmartFoundation.Mvc\wwwroot\js\smartprint\smartprint.js
// Core: فتح تقرير محدد في نافذة مستقلة + انتظار CSS + طباعة

window.SmartPrint = window.SmartPrint || {};

(function (api) {

    function waitForStyles(win, timeoutMs) {
        return new Promise((resolve) => {
            const doc = win.document;
            const links = Array.from(doc.querySelectorAll("link[rel='stylesheet']"));

            if (links.length === 0) {
                setTimeout(resolve, 50);
                return;
            }

            let done = false;
            let remaining = links.length;

            const finish = () => {
                if (done) return;
                done = true;
                setTimeout(resolve, 200);
            };

            const oneLoaded = () => {
                remaining--;
                if (remaining <= 0) finish();
            };

            links.forEach(l => {
                l.addEventListener("load", oneLoaded, { once: true });
                l.addEventListener("error", oneLoaded, { once: true });
                setTimeout(oneLoaded, Math.min(1500, timeoutMs || 1500));
            });

            
            setTimeout(finish, 1500);
        });
    }

    async function printDom(hostId) {
        const host = document.getElementById(hostId);
        if (!host) {
            console.error('لم يتم العثور على عنصر التقرير:', hostId);
            return;
        }

        const w = window.open("", "_blank");
        if (!w) {
            alert('يرجى السماح بفتح النوافذ المنبثقة للطباعة');
            return;
        }

        const doc = w.document;

        const links = Array.from(document.querySelectorAll("link[rel='stylesheet']"))
            .map(l => l.outerHTML)
            .join("\n");
        
        
        const scripts = Array.from(document.querySelectorAll("script[src*='smartprint']"))
            .map(s => s.outerHTML)
            .join("\n");

        doc.open();
        doc.write(`<!doctype html>
                <html lang="ar" dir="${host.getAttribute("dir") || "rtl"}">
                <head>
                  <meta charset="utf-8" />
                  <meta name="viewport" content="width=device-width,initial-scale=1" />
                  ${links}
                  <title>Print</title>
                  <style>
                    body { background: #fff !important; margin: 0; padding: 0; }
                  </style>
                </head>
                <body>
                  ${host.outerHTML}
                  ${scripts}
                </body>
                </html>`);
        doc.close();
        
        try { 
            await waitForStyles(w, 3000); 
            console.log('تم تحميل الأنماط');
        } catch (e) { 
            console.error('خطأ في انتظار الأنماط:', e);
        }

        try { w.focus(); } catch (e) { }

        w.requestIdleCallback
            ? w.requestIdleCallback(() => {
                console.log('بدء الطباعة - requestIdleCallback');
                try { w.print(); } catch (e) { console.error('خطأ في الطباعة:', e); }
            }, { timeout: 2000 })
            : setTimeout(() => {
                console.log('بدء الطباعة - fallback timeout');
                try { w.print(); } catch (e) { console.error('خطأ في الطباعة:', e); }
            }, 500);


    }
    
    api.printDom = printDom;
})(window.SmartPrint);
