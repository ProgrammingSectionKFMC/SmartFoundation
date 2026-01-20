(function () {
    'use strict';

    let currentAbortController = null;

    const btn = document.getElementById("sf-ai-btn");
    const panel = document.getElementById("sf-ai-panel");
    const closeBtn = document.getElementById("sf-ai-close");
    const messages = document.getElementById("sf-ai-messages");
    const input = document.getElementById("sf-ai-input");
    const sendBtn = document.getElementById("sf-ai-send");

    if (!btn || !panel || !closeBtn || !messages || !input || !sendBtn) return;

    setTimeout(() => {
        btn.classList.add("sf-ai-pulse");
        setTimeout(() => btn.classList.remove("sf-ai-pulse"), 3500);
    }, 600);

    const userIdEl = document.getElementById("sf-ai-userid");
    const userId = userIdEl ? (userIdEl.value || "").trim() : "";

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

    // ✅ تحديث: إضافة chatId
    function addMessage(role, text, citations, chatId = 0) {
        const msg = document.createElement("div");
        msg.className = "sf-ai-msg";

        const avatar = document.createElement("div");
        avatar.className = "sf-ai-avatar " + (role === "user" ? "user" : "bot");
        avatar.textContent = role === "user" ? "👤" : "🤖";

        const bubble = document.createElement("div");
        bubble.className = "sf-ai-bubble " + (role === "user" ? "user" : role === "system" ? "system" : "bot");
        bubble.innerHTML = escapeHtml(text || "");

        // ✅ إضافة أزرار التقييم للإجابات فقط
        if (role === "bot" && chatId > 0) {
            const feedbackDiv = document.createElement("div");
            feedbackDiv.className = "sf-ai-feedback";
            feedbackDiv.innerHTML = `
                <button class="sf-ai-feedback-btn" data-chatid="${chatId}" data-feedback="1" title="مفيد">👍</button>
                <button class="sf-ai-feedback-btn" data-chatid="${chatId}" data-feedback="-1" title="غير مفيد">👎</button>
            `;
            
            bubble.appendChild(feedbackDiv);
            
            feedbackDiv.querySelectorAll('.sf-ai-feedback-btn').forEach(btn => {
                btn.addEventListener('click', async (e) => {
                    e.preventDefault();
                    const cid = btn.dataset.chatid;
                    const feedback = parseInt(btn.dataset.feedback);
                    
                    await sendFeedback(cid, feedback);
                    
                    feedbackDiv.querySelectorAll('.sf-ai-feedback-btn').forEach(b => {
                        b.disabled = true;
                        b.style.opacity = '0.4';
                    });
                    
                    btn.style.opacity = '1';
                    btn.style.transform = 'scale(1.2)';
                });
            });
        }

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
                    [], 0
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

    input.addEventListener("keydown", (e) => {
        if (e.key === "Enter" && !e.shiftKey) {
            e.preventDefault();
            e.stopPropagation();
            doSend();
        }
    });

    sendBtn.addEventListener("click", (e) => {
        e.preventDefault();
        e.stopPropagation();
        doSend();
    });

    function cancelCurrentRequest() {
        if (currentAbortController) {
            currentAbortController.abort();
            currentAbortController = null;
        }
    }

    function showThinking() {
        const thinkingId = "sf-ai-thinking-" + Date.now();
        const startTime = Date.now();

        const msg = document.createElement("div");
        msg.className = "sf-ai-msg thinking";
        msg.id = thinkingId;

        const avatar = document.createElement("div");
        avatar.className = "sf-ai-avatar bot";
        avatar.textContent = "🤖";

        const bubble = document.createElement("div");
        bubble.className = "sf-ai-bubble bot";

        const indicator = document.createElement("div");
        indicator.className = "sf-ai-thinking-indicator";
        indicator.innerHTML = "<span></span><span></span><span></span>";

        const textSpan = document.createElement("span");
        textSpan.className = "sf-ai-thinking-text";
        textSpan.textContent = "جاري التفكير...";

        const timerSpan = document.createElement("span");
        timerSpan.className = "sf-ai-thinking-timer";
        timerSpan.id = thinkingId + "-timer";
        timerSpan.textContent = "0s";

        const stopBtn = document.createElement("button");
        stopBtn.className = "sf-ai-stop-btn";
        stopBtn.type = "button";
        stopBtn.title = "إيقاف";
        stopBtn.innerHTML = `
            <svg width="12" height="12" viewBox="0 0 16 16" fill="currentColor">
                <rect x="4" y="4" width="8" height="8" rx="1"/>
            </svg>
            إيقاف
        `;
        stopBtn.onclick = cancelCurrentRequest;

        bubble.appendChild(indicator);
        bubble.appendChild(textSpan);
        bubble.appendChild(timerSpan);
        bubble.appendChild(stopBtn);

        msg.appendChild(avatar);
        msg.appendChild(bubble);

        messages.appendChild(msg);
        scrollToBottom();

        const timerId = setInterval(() => {
            const timerEl = document.getElementById(thinkingId + "-timer");
            if (timerEl) {
                const elapsed = Math.floor((Date.now() - startTime) / 1000);
                timerEl.textContent = elapsed + "s";
            } else {
                clearInterval(timerId);
            }
        }, 1000);

        return thinkingId;
    }

    function removeThinking(thinkingId) {
        const el = document.getElementById(thinkingId);
        if (el) el.remove();
    }

    async function doSend() {
        const text = (input.value || "").trim();
        if (!text) return;

        input.value = "";
        addMessage("user", text, [], 0);

        sendBtn.disabled = true;
        input.disabled = true;

        currentAbortController = new AbortController();

        const thinkingId = showThinking();

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
                body: JSON.stringify(payload),
                signal: currentAbortController.signal
            });

            removeThinking(thinkingId);

            if (!res.ok) {
                let msg = "تعذر الاتصال بالمساعد. تأكد أن الخدمة مفعلة وأن نموذج الذكاء المحلي يعمل.";
                try {
                    const t = await res.text();
                    if (t) msg += "\n\n" + t.slice(0, 400);
                } catch { }
                addMessage("bot", msg, [], 0);
                return;
            }

            const data = await res.json();
            const answer = (data && data.answer) ? data.answer : "لم يتم استلام رد.";
            const chatId = (data && data.chatId) ? data.chatId : 0; // ✅ إضافة
            
            addMessage("bot", answer, (data && data.citations) ? data.citations : [], chatId); // ✅ تمرير chatId

        } catch (err) {
            removeThinking(thinkingId);

            if (err.name === 'AbortError') {
                addMessage("system", "تم إيقاف العملية.", [], 0);
            } else {
                addMessage("bot",
                    "حصل خطأ أثناء إرسال السؤال.\nتأكد أن السيرفر شغال وأن Endpoint /api/ai/chat متاح.",
                    [], 0
                );
                console.error(err);
            }
        } finally {
            sendBtn.disabled = false;
            input.disabled = false;
            input.focus();
            currentAbortController = null;
        }
    }

    // ✅ دالة إرسال التقييم
    async function sendFeedback(chatId, feedback) {
        try {
            const res = await fetch("/api/ai/feedback", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ 
                    chatId: parseInt(chatId), 
                    feedback: feedback 
                })
            });
            
            if (res.ok) {
                console.log(`✅ Feedback sent: ChatId=${chatId}, Feedback=${feedback}`);
            } else {
                console.error('❌ Feedback failed:', await res.text());
            }
        } catch (err) {
            console.error("❌ Failed to send feedback:", err);
        }
    }

    window.aiAssistant = {
        cancelRequest: cancelCurrentRequest
    };
})();
