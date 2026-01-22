//// wwwroot/js/sf-select.js
//(function () {
//    const register = () => {
//        Alpine.data('sfSelect', (cfg) => ({
//            name: cfg.name,
//            placeholder: cfg.placeholder || 'اختر...',
//            multiple: !!cfg.multiple,
//            disabled: !!cfg.disabled,
//            readonly: !!cfg.readonly,
//            onchangeJs: cfg.onchangeJs || '', //  Store OnChangeJs globally
//            lockedByDependency: false,
//            open: false,
//            q: '',
//            options: [],
//            selected: [],
//            panelStyle: '',
//            listStyle: '',
//            _repositionBound: null,

//            init() {
//                // تجهيز الخيارات
//                this.options = (cfg.options || []).map(o => ({
//                    value: String(o.Value ?? o.value ?? ''),
//                    text: String(o.Text ?? o.text ?? ''),
//                    disabled: !!(o.Disabled ?? o.disabled),
//                    selected: !!(o.Selected ?? o.selected)
//                }));

//                // اختيار ابتدائي
//                const initial = (cfg.initial || '').trim();
//                if (initial) {
//                    const vals = this.multiple ? initial.split(',') : [initial];
//                    this.selected = this.options.filter(o => vals.includes(o.value));
//                } else {
//                    this.selected = this.options.filter(o => o.selected);
//                }
//                this.syncHidden();



//                // ✅ ربط القوائم المعتمدة (DependsOn / DependsUrl)
//                const dependsOn = this.$el.dataset.dependson;
//                const dependsUrl = this.$el.dataset.dependsurl;

//                if (dependsOn && dependsUrl) {
//                    // الأب: input hidden الخاص بـ sfSelect يحمل name=DependsOn
//                    const parentHidden = document.querySelector(`input[name="${dependsOn}"]`);

//                    if (parentHidden) {
//                        parentHidden.addEventListener("change", async () => {
//                            const parentVal = (parentHidden.value || "").trim();

//                            // إذا ما فيه قيمة: فضّي خيارات الابن
//                            if (!parentVal || parentVal === "-1") {
//                                this.options = [];
//                                this.selected = [];
//                                this.syncHidden();
//                                return;
//                            }

//                            // جهز الرابط وأضف قيمة الأب
//                            let url = dependsUrl;
//                            url += (url.includes("?") ? "&" : "?") + "value=" + encodeURIComponent(parentVal);
//                            /*url += (url.includes("?") ? "&" : "?") + "id=" + encodeURIComponent(parentVal);*/


//                            try {
//                                const res = await fetch(url, {
//                                    headers: { "X-Requested-With": "XMLHttpRequest" }
//                                });

//                                const data = await res.json();

//                                // توقع JSON مثل: [{value:'1', text:'..'}] أو [{Value:'1',Text:'..'}]
//                                this.options = (data || []).map(o => ({
//                                    value: String(o.Value ?? o.value ?? ''),
//                                    text: String(o.Text ?? o.text ?? ''),
//                                    disabled: !!(o.Disabled ?? o.disabled),
//                                    selected: false
//                                }));

//                                // صفّر اختيار الابن بعد التحديث
//                                this.selected = [];
//                                this.syncHidden();
//                                this.q = '';
//                            } catch (e) {
//                                console.error("Depends load error:", e, "URL:", url);
//                            }
//                        });
//                    }
//                }


//                // نسخة مربوطة من reposition حتى لا نفقد this داخل event listeners
//                this._repositionBound = this.reposition.bind(this);

//                // تنظيف تلقائي عند تدمير المكوّن
//                this.$el.addEventListener('alpine:destroy', () => this._detachListeners());
//            },

//            // فتح/إغلاق مع إدارة المستمعات
//            togglePanel() {
//                if (this.disabled || this.readonly) return;
//                /*if (this.disabled || this.readonly || this.lockedByDependency) return;*/

//                this.open = !this.open;
//                if (this.open) {
//                    this.$nextTick(() => {
//                        this._repositionBound();
//                        this._attachListeners();
//                    });
//                } else {
//                    this._detachListeners();
//                }
//            },

//            _attachListeners() {
//                window.addEventListener('resize', this._repositionBound, { passive: true });
//                window.addEventListener('scroll', this._repositionBound, true);
//            },
            
//            _detachListeners() {
//                window.removeEventListener('resize', this._repositionBound, { passive: true });
//                window.removeEventListener('scroll', this._repositionBound, true);
//            },

//            reposition() {
//                const a = this.$refs.anchor;
//                const p = this.$refs.panel;
//                if (!a) return;

//                const r = a.getBoundingClientRect();
//                const vw = window.innerWidth || document.documentElement.clientWidth;
//                const vh = window.innerHeight || document.documentElement.clientHeight;

//                const width = r.width;
//                const left = Math.min(Math.max(8, r.left), vw - width - 8);

//                const spaceBelow = vh - r.bottom - 8;
//                const spaceAbove = r.top - 8;

//                const desiredMax = 320;
//                let maxH = Math.min(desiredMax, Math.max(180, spaceBelow));

//                let top = r.bottom + 8;

//                if (spaceBelow < 180 && spaceAbove > spaceBelow) {
//                    maxH = Math.min(desiredMax, Math.max(180, spaceAbove));
//                    const panelH = (p ? p.offsetHeight : Math.min(desiredMax, spaceAbove));
//                    top = Math.max(8, r.top - panelH - 8);
//                }

//                this.panelStyle = `position:fixed;top:${top}px;left:${left}px;width:${width}px;`;
//                this.listStyle = `max-height:${maxH}px;`;
//            },

//            filtered() {
//                if (!this.q) return this.options;
//                const q = this.q.toLowerCase();
//                return this.options.filter(o => (o.text || '').toLowerCase().includes(q));
//            },

//            isSelected(opt) { 
//                return this.selected.some(s => s.value === opt.value); 
//            },

//            toggle(opt) {
//                if (opt.disabled || this.disabled || this.readonly) return;
//                /*if (opt.disabled || this.disabled || this.readonly || this.lockedByDependency) return;*/

//                if (this.multiple) {
//                    this.isSelected(opt)
//                        ? this.selected = this.selected.filter(s => s.value !== opt.value)
//                        : this.selected.push({ value: opt.value, text: opt.text });
//                } else {
//                    this.selected = [{ value: opt.value, text: opt.text }];
//                    this.open = false;
//                    this._detachListeners();
//                }
//                this.syncHidden();
//                this.emitChange();
//            },

//            clear() {
//                if (this.disabled || this.readonly) return;
//                /*if (this.disabled || this.readonly || this.lockedByDependency) return;*/

//                this.selected = [];
//                this.syncHidden();
//                this.emitChange();
//            },

//            displayText() {
//                return this.selected.length ? this.selected.map(s => s.text).join('، ') : this.placeholder;
//            },

//            serialize() {
//                return this.multiple
//                    ? this.selected.map(s => s.value).join(',')
//                    : (this.selected[0]?.value || '');
//            },

//            syncHidden() { 
//                if (this.$refs.hidden) this.$refs.hidden.value = this.serialize(); 
//            },

//            emitChange() { 
//                this.$dispatch('change', { name: this.name, value: this.serialize() });
                
//                // ✅ Trigger native change event
//                if (this.$refs.hidden) {
//                    this.$refs.hidden.dispatchEvent(new Event('change', { bubbles: true }));
//                }
                
//                // ✅ Execute OnChangeJs
//                if (this.onchangeJs && this.onchangeJs.trim()) {
//                    try {
//                        const fn = new Function('value', 'text', this.onchangeJs);
//                        fn.call(this.$refs.hidden, this.serialize(), this.displayText());
//                    } catch(e) {
//                        console.error('OnChangeJs execution error:', e, '\nCode:', this.onchangeJs);
//                    }
//                }
//            }
//        }));
//    };
    
//    if (window.Alpine) register();
//    else document.addEventListener('alpine:init', register);
//})();
