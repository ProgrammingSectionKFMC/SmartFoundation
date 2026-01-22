(function () {
    'use strict';

    let currentAbortController = null;

    const btn = document.getElementById("sf-ai-btn");
    const panel = document.getElementById("sf-ai-panel");
    const closeBtn = document.getElementById("sf-ai-close");
    const messages = document.getElementById("sf-ai-messages");
    const input = document.getElementById("sf-ai-input");
    const sendBtn = document.getElementById("sf-ai-send");

    function updatePanelPlacement() {
        const root = document.getElementById("sf-ai");
        const panel = document.getElementById("sf-ai-panel");
        if (!root || !panel) return;

        const gap = 12;
        const offset = 70;

        const rect = root.getBoundingClientRect();

        const maxPanelW = Math.max(260, window.innerWidth - (gap * 2));
        const panelW = Math.min(360, maxPanelW);
        panel.style.width = panelW + "px";

        const spaceAbove = rect.top - gap;
        const spaceBelow = (window.innerHeight - rect.bottom) - gap;

        const panelH = panel.offsetHeight || 520;

        const openDown = (spaceAbove < panelH + offset) && (spaceBelow > spaceAbove);
        root.classList.toggle("open-down", openDown);

        const availableH = openDown ? (spaceBelow - offset) : (spaceAbove - offset);
        panel.style.maxHeight = Math.max(220, Math.floor(availableH)) + "px";

        const spaceLeft = rect.left - gap;
        const spaceRight = (window.innerWidth - rect.right) - gap;

        const needOpenRight = (spaceLeft < panelW - rect.width) && (spaceRight > spaceLeft);
        root.classList.toggle("open-left", needOpenRight);
    }


    window.addEventListener("resize", () => {
        if (panel && panel.classList.contains("open")) {
            updatePanelPlacement();
        }
    });

    // =========================
    // DRAG: move whole widget (#sf-ai)
    // =========================

    const root = document.getElementById("sf-ai");
    const STORAGE_KEY = "sf_ai_pos_v1";
    /*const DEFAULT_POS = { right: 18, bottom: 18 }; */
    const DEFAULT_POS = { left: 18, bottom: 18 };

    (function enableDrag() {
        if (!root) return;
        localStorage.removeItem(STORAGE_KEY);
        applyDefaultPosition();

        //const STORAGE_KEY = "sf_ai_pos_v1";
        //try {
        //    const saved = JSON.parse(localStorage.getItem(STORAGE_KEY) || "null");
        //    if (saved && typeof saved.x === "number" && typeof saved.y === "number") {
        //        root.style.left = saved.x + "px";
        //        root.style.top = saved.y + "px";
        //        root.style.right = "auto";
        //        root.style.bottom = "auto";
        //    }
        //} catch { /* ignore */ }

        function applyDefaultPosition() {
            root.style.top = "auto";
            root.style.right = "auto";
            root.style.left = DEFAULT_POS.left + "px";
            root.style.bottom = DEFAULT_POS.bottom + "px";
        }


        function applySavedPositionIfAny() {
            try {
                const saved = JSON.parse(localStorage.getItem(STORAGE_KEY) || "null");
                if (saved && typeof saved.x === "number" && typeof saved.y === "number") {
                    root.style.left = saved.x + "px";
                    root.style.top = saved.y + "px";
                    root.style.right = "auto";
                    root.style.bottom = "auto";
                    return true;
                }
            } catch { }
            return false;
        }

        if (!applySavedPositionIfAny()) {
            applyDefaultPosition();
        }


        let dragging = false;
        let maybeDrag = false;
        let startX = 0, startY = 0;
        let startLeft = 0, startTop = 0;
        const DRAG_THRESHOLD = 6; // px
        function getCurrentLeftTop() {
            const rect = root.getBoundingClientRect();
            return { left: rect.left, top: rect.top };
        }

        function clamp(v, min, max) {
            return Math.min(max, Math.max(min, v));
        }
        function onPointerDown(e) {
            const fromHeader = e.target.closest(".sf-ai-header");
            const fromButton = e.target.closest("#sf-ai-btn");
            if (!fromHeader && !fromButton) return;
            if (e.target.closest("#sf-ai-close, #sf-ai-send, #sf-ai-input")) return;
            maybeDrag = true;
            dragging = false;
            const { left, top } = getCurrentLeftTop();
            startLeft = left;
            startTop = top;

            startX = e.clientX;
            startY = e.clientY;
        }

        function onPointerMove(e) {
            if (!maybeDrag) return;
            const dx0 = e.clientX - startX;
            const dy0 = e.clientY - startY;
            if (!dragging) {
                if (Math.abs(dx0) < DRAG_THRESHOLD && Math.abs(dy0) < DRAG_THRESHOLD) return;
                dragging = true;
                root.classList.add("dragging");
                root.style.left = startLeft + "px";
                root.style.top = startTop + "px";
                root.style.right = "auto";
                root.style.bottom = "auto";
                if (root.setPointerCapture) root.setPointerCapture(e.pointerId);
            }

            e.preventDefault();

            const dx = e.clientX - startX;
            const dy = e.clientY - startY;
            const margin = 8;
            const rootRect = root.getBoundingClientRect();
            const maxLeft = window.innerWidth - rootRect.width - margin;
            const maxTop = window.innerHeight - rootRect.height - margin;
            const newLeft = clamp(startLeft + dx, margin, maxLeft);
            const newTop = clamp(startTop + dy, margin, maxTop);
            root.style.left = newLeft + "px";
            root.style.top = newTop + "px";
        }

        function onPointerUp() {
            if (!maybeDrag) return;
            maybeDrag = false;

            if (!dragging) return;

            dragging = false;
            root.classList.remove("dragging");

            const rect = root.getBoundingClientRect();
            try {
                /*localStorage.setItem(STORAGE_KEY, JSON.stringify({ x: rect.left, y: rect.top }));*/
                updatePanelPlacement();
            } catch { /* ignore */ }
        }

        document.addEventListener("pointermove", onPointerMove, { passive: false });
        document.addEventListener("pointerup", onPointerUp, { passive: true });
        root.addEventListener("pointerdown", onPointerDown, { passive: false });
    })();

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

            updatePanelPlacement(); // جديد

            panel.setAttribute("aria-hidden", "false");

            if (messages.childElementCount === 0) {
                addMessage(
                    "bot",
                    "هلا 👋\nأنا وحيد مساعدك الذكي داخل النظام.\nاسألني: كيف أضيف مستفيد؟ كيف أطبع؟ أين أجد التقرير؟\nملاحظة: المساعد الذكي لازال تحت التدريب في مرحلة الاطلاق التجريبي تأكد من صحة الأجوبة قبل الاعتماد عليها كلياً",
                    [],
                    0
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
