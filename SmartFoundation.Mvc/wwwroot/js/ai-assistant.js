(function () {
    const btn = document.getElementById("sf-ai-btn");
    const panel = document.getElementById("sf-ai-panel");
    const closeBtn = document.getElementById("sf-ai-close");
    const messages = document.getElementById("sf-ai-messages");
    const input = document.getElementById("sf-ai-input");
    const sendBtn = document.getElementById("sf-ai-send");

    if (!btn || !panel || !closeBtn || !messages || !input || !sendBtn) return;

    // subtle pulse on first load
    setTimeout(() => {
        btn.classList.add("sf-ai-pulse");
        setTimeout(() => btn.classList.remove("sf-ai-pulse"), 3500);
    }, 600);


    // ✅ اقرأ userId من hidden input (يجي من Session)
    const userIdEl = document.getElementById("sf-ai-userid");
    const userId = userIdEl ? (userIdEl.value || "").trim() : "";


    // ✅ امنع أي submit إذا كان الودجت داخل form
    const form = sendBtn.closest("form") || input.closest("form");
    if (form) {
        form.addEventListener("submit", (e) => {
            e.preventDefault();
            e.stopPropagation();
            doSend();
        }, true);
    }

    function escapeHtml(str) {
        return String(str)
            .replaceAll("&", "&amp;")
            .replaceAll("<", "&lt;")
            .replaceAll(">", "&gt;")
            .replaceAll('"', "&quot;")
            .replaceAll("'", "&#39;");
    }

    function scrollToBottom() {
        messages.scrollTop = messages.scrollHeight;
    }

    function addMessage(role, text, citations) {
        const msg = document.createElement("div");
        msg.className = "sf-ai-msg";

        const avatar = document.createElement("div");
        avatar.className = "sf-ai-avatar " + (role === "user" ? "user" : "bot");
        avatar.textContent = role === "user" ? "👤" : "🤖";

        const bubble = document.createElement("div");
        bubble.className = "sf-ai-bubble " + (role === "user" ? "user" : "bot");
        bubble.innerHTML = escapeHtml(text || "");

        msg.appendChild(avatar);
        msg.appendChild(bubble);

        messages.appendChild(msg);
        scrollToBottom();
    }

    function setOpen(isOpen) {
        if (isOpen) {
            panel.classList.add("open");
            panel.setAttribute("aria-hidden", "false");

            if (messages.childElementCount === 0) {
                addMessage("bot",
                    "هلا 👋\nأنا وحيد مساعدك الذكي داخل النظام.\nاسألني: كيف أضيف مستفيد؟ كيف أطبع؟ أين أجد التقرير؟\nملاحظة: المساعد الذكي لازال تحت التدريب في مرحلة الاطلاق التجريبي تأكد من صحة الأجوبة قبل الاعتماد عليها كلياً",
                    []
                );
            }

            setTimeout(() => input.focus(), 80);
        } else {
            panel.classList.remove("open");
            panel.setAttribute("aria-hidden", "true");
        }
    }

    btn.addEventListener("click", () => setOpen(!panel.classList.contains("open")));
    closeBtn.addEventListener("click", () => setOpen(false));

    document.addEventListener("keydown", (e) => {
        if (e.key === "Escape" && panel.classList.contains("open")) {
            setOpen(false);
        }
    });

    // Send on Enter
    input.addEventListener("keydown", (e) => {
        if (e.key === "Enter" && !e.shiftKey) {
            e.preventDefault();
            e.stopPropagation();
            doSend();
        }
    });

    // ✅ امنع default في click (لتفادي submit/navigation)
    sendBtn.addEventListener("click", (e) => {
        e.preventDefault();
        e.stopPropagation();
        doSend();
    });

    async function doSend() {
        const text = (input.value || "").trim();
        if (!text) return;

        input.value = "";
        addMessage("user", text);

        sendBtn.disabled = true;
        input.disabled = true;

        const loadingId = "sf-ai-loading-" + Date.now();
        const loadingMsg = document.createElement("div");
        loadingMsg.className = "sf-ai-msg";
        loadingMsg.id = loadingId;

        const avatar = document.createElement("div");
        avatar.className = "sf-ai-avatar bot";
        avatar.text = "hgfkf";
        avatar.textContent = "🤖";

        const bubble = document.createElement("div");
        bubble.className = "sf-ai-bubble bot";
        bubble.textContent = "جاري التفكير...";

        loadingMsg.appendChild(avatar);
        loadingMsg.appendChild(bubble);
        messages.appendChild(loadingMsg);
        scrollToBottom();

        try {
            const payload = {
                message: text,
                pageTitle: document.title || null,
                pageUrl: window.location.pathname + window.location.search,
                pageName: window.location.pathname.split("/").filter(Boolean).pop() || null,
                culture: (document.documentElement.lang || "ar"),
                userId: userId
            };

            const res = await fetch("/api/ai/chat", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify(payload)
            });

            const loadingEl = document.getElementById(loadingId);
            if (loadingEl) loadingEl.remove();

            if (!res.ok) {
                let msg = "تعذر الاتصال بالمساعد. تأكد أن الخدمة مفعلة وأن نموذج الذكاء المحلي يعمل.";
                try {
                    const t = await res.text();
                    if (t) msg += "\n\n" + t.slice(0, 400);
                } catch { }
                addMessage("bot", msg, []);
                return;
            }

            const data = await res.json();
            const answer = (data && data.answer) ? data.answer : "لم يتم استلام رد.";
            addMessage("bot", answer, (data && data.citations) ? data.citations : []);

        } catch (err) {
            const loadingEl = document.getElementById(loadingId);
            if (loadingEl) loadingEl.remove();

            addMessage("bot",
                "حصل خطأ أثناء إرسال السؤال.\nتأكد أن السيرفر شغال وأن Endpoint /api/ai/chat متاح.",
                []
            );
            try { console.error(err); } catch { }
        } finally {
            sendBtn.disabled = false;
            input.disabled = false;
            input.focus();
        }
    }
})();
