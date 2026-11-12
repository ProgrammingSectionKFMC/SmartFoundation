/*
 * SmartFoundation - SmartDynamicFields
 * Reusable, root-scoped repeated-field component.
 * Business formatting, authorization and form submission remain with the page.
 */
(function () {
    "use strict";

    if (window.SmartDynamicFields) return;

    const instancesByRoot = new WeakMap();
    const instancesById = new Map();

    function valueOf(source, camelName, pascalName, fallback) {
        if (source && source[camelName] !== undefined && source[camelName] !== null) {
            return source[camelName];
        }
        if (source && source[pascalName] !== undefined && source[pascalName] !== null) {
            return source[pascalName];
        }
        return fallback;
    }

    function asBoolean(value, fallback) {
        if (value === true || value === false) return value;
        if (value === "true" || value === "1" || value === 1) return true;
        if (value === "false" || value === "0" || value === 0) return false;
        return fallback;
    }

    function asInteger(value, fallback) {
        const number = Number.parseInt(value, 10);
        return Number.isFinite(number) ? number : fallback;
    }

    function normalizeOption(option) {
        return {
            value: String(valueOf(option, "value", "Value", "")),
            text: String(valueOf(option, "text", "Text", "")),
            disabled: asBoolean(valueOf(option, "disabled", "Disabled", false), false)
        };
    }

    function normalizeField(field) {
        const type = String(valueOf(field, "type", "Type", "text")).toLowerCase();
        const allowedTypes = new Set(["hidden", "text", "textarea", "number", "date", "select", "checkbox"]);

        return {
            name: String(valueOf(field, "name", "Name", "")).trim(),
            label: String(valueOf(field, "label", "Label", "")).trim(),
            type: allowedTypes.has(type) ? type : "text",
            placeholder: String(valueOf(field, "placeholder", "Placeholder", "") || ""),
            helpText: String(valueOf(field, "helpText", "HelpText", "") || ""),
            colCss: String(valueOf(field, "colCss", "ColCss", "col-span-12") || "col-span-12"),
            required: asBoolean(valueOf(field, "required", "Required", false), false),
            readonly: asBoolean(valueOf(field, "readonly", "Readonly", false), false),
            disabled: asBoolean(valueOf(field, "disabled", "Disabled", false), false),
            min: valueOf(field, "min", "Min", null),
            max: valueOf(field, "max", "Max", null),
            maxLength: valueOf(field, "maxLength", "MaxLength", null),
            options: (valueOf(field, "options", "Options", []) || []).map(normalizeOption)
        };
    }

    function normalizeConfig(config) {
        const minRows = Math.max(0, asInteger(valueOf(config, "minRows", "MinRows", 1), 1));
        const maxRows = Math.max(1, asInteger(valueOf(config, "maxRows", "MaxRows", 16), 16));
        const fields = (valueOf(config, "fields", "Fields", []) || []).map(normalizeField);

        if (!fields.length || fields.some(field => !field.name)) {
            throw new Error("SmartDynamicFields requires named field definitions.");
        }

        if (maxRows < minRows) {
            throw new Error("SmartDynamicFields MaxRows cannot be less than MinRows.");
        }

        return {
            id: String(valueOf(config, "id", "Id", "")).trim(),
            formId: String(valueOf(config, "formId", "FormId", "") || "").trim(),
            title: String(valueOf(config, "title", "Title", "") || ""),
            description: String(valueOf(config, "description", "Description", "") || ""),
            outputName: String(valueOf(config, "outputName", "OutputName", "") || "").trim(),
            renderOutputInput: asBoolean(valueOf(config, "renderOutputInput", "RenderOutputInput", true), true),
            syncOutputOnChange: asBoolean(valueOf(config, "syncOutputOnChange", "SyncOutputOnChange", true), true),
            rowNumberProperty: String(valueOf(config, "rowNumberProperty", "RowNumberProperty", "") || "").trim(),
            minRows,
            maxRows,
            allowAdd: asBoolean(valueOf(config, "allowAdd", "AllowAdd", true), true),
            allowRemove: asBoolean(valueOf(config, "allowRemove", "AllowRemove", true), true),
            allowReorder: asBoolean(valueOf(config, "allowReorder", "AllowReorder", false), false),
            readonly: asBoolean(valueOf(config, "readonly", "Readonly", false), false),
            disabled: asBoolean(valueOf(config, "disabled", "Disabled", false), false),
            direction: String(valueOf(config, "direction", "Direction", "rtl")).toLowerCase() === "ltr" ? "ltr" : "rtl",
            addButtonText: String(valueOf(config, "addButtonText", "AddButtonText", "إضافة")),
            removeButtonText: String(valueOf(config, "removeButtonText", "RemoveButtonText", "حذف")),
            moveUpText: String(valueOf(config, "moveUpText", "MoveUpText", "تحريك لأعلى")),
            moveDownText: String(valueOf(config, "moveDownText", "MoveDownText", "تحريك لأسفل")),
            emptyValidationMessage: String(valueOf(config, "emptyValidationMessage", "EmptyValidationMessage", "يجب إدخال صف واحد على الأقل")),
            maxRowsMessage: String(valueOf(config, "maxRowsMessage", "MaxRowsMessage", "تم الوصول إلى الحد الأقصى")),
            fields,
            initialRows: valueOf(config, "initialRows", "InitialRows", []) || []
        };
    }

    function createElement(tagName, className, text) {
        const element = document.createElement(tagName);
        if (className) element.className = className;
        if (text !== undefined && text !== null) element.textContent = String(text);
        return element;
    }

    function cssEscape(value) {
        if (window.CSS && typeof window.CSS.escape === "function") return window.CSS.escape(value);
        return String(value).replace(/["\\]/g, "\\$&");
    }

    function resolveRoot(target) {
        if (target instanceof Element) return target;
        if (typeof target !== "string" || !target.trim()) return null;

        const raw = target.trim();
        const byId = document.getElementById(raw.replace(/^#/, ""));
        if (byId) return byId;

        try { return document.querySelector(raw); }
        catch { return null; }
    }

    function resolveForm(target) {
        const element = resolveRoot(target);
        return element instanceof HTMLFormElement ? element : null;
    }

    function dispatch(root, name, detail) {
        root.dispatchEvent(new CustomEvent(name, {
            bubbles: true,
            detail
        }));
    }

    function readInitialValue(row, fieldName) {
        if (!row || typeof row !== "object") return "";
        if (Object.prototype.hasOwnProperty.call(row, fieldName)) return row[fieldName];

        const wanted = fieldName.toLowerCase();
        const key = Object.keys(row).find(candidate => candidate.toLowerCase() === wanted);
        return key ? row[key] : "";
    }

    function getControlValue(control, field) {
        if (field.type === "checkbox") return !!control.checked;
        return String(control.value ?? "").trim();
    }

    function rowHasValue(row, fields) {
        return fields.some(field => {
            const value = row[field.name];
            return field.type === "checkbox" ? value === true : String(value ?? "").trim() !== "";
        });
    }

    function buildControl(instance, field, rowIndex, initialValue) {
        const inputId = `${instance.config.id}-${rowIndex + 1}-${field.name}`;
        let control;

        if (field.type === "textarea") {
            control = document.createElement("textarea");
            control.rows = 3;
        } else if (field.type === "select") {
            control = document.createElement("select");
            const placeholder = createElement("option", "", field.placeholder || "الرجاء الاختيار");
            placeholder.value = "";
            placeholder.disabled = field.required;
            control.appendChild(placeholder);

            field.options.forEach(option => {
                const optionElement = createElement("option", "", option.text);
                optionElement.value = option.value;
                optionElement.disabled = option.disabled;
                control.appendChild(optionElement);
            });
        } else {
            control = document.createElement("input");
            control.type = field.type === "checkbox" ? "checkbox" : field.type;
        }

        control.id = inputId;
        control.className = field.type === "checkbox"
            ? "sf-dynamic-fields__checkbox"
            : "sf-dynamic-fields__input";
        control.dataset.sfDynamicField = field.name;
        control.required = field.required;
        control.readOnly = field.readonly || instance.config.readonly;
        control.disabled = field.disabled || instance.config.disabled;

        if (field.placeholder && field.type !== "select" && field.type !== "checkbox") {
            control.placeholder = field.placeholder;
        }
        if (field.maxLength && field.type !== "number" && field.type !== "checkbox") {
            control.maxLength = Number(field.maxLength);
        }
        if (field.min !== null && field.min !== undefined && "min" in control) control.min = String(field.min);
        if (field.max !== null && field.max !== undefined && "max" in control) control.max = String(field.max);

        if (field.type === "checkbox") control.checked = initialValue === true || initialValue === "true" || initialValue === 1 || initialValue === "1";
        else control.value = initialValue === null || initialValue === undefined ? "" : String(initialValue);

        const onChanged = () => {
            instance.setError("");
            if (instance.config.syncOutputOnChange) instance.sync();
            dispatch(instance.root, "sf-dynamic-fields:changed", {
                id: instance.config.id,
                rows: instance.getRows()
            });
        };

        control.addEventListener("input", onChanged);
        control.addEventListener("change", onChanged);
        return control;
    }

    function buildField(instance, field, rowIndex, initialRow) {
        const initialValue = readInitialValue(initialRow, field.name);
        const control = buildControl(instance, field, rowIndex, initialValue);

        if (field.type === "hidden") return control;

        const group = createElement("div", `sf-dynamic-fields__field ${field.colCss}`);
        group.dataset.fieldName = field.name;

        if (field.type === "checkbox") {
            const checkboxLabel = createElement("label", "sf-dynamic-fields__checkbox-label");
            checkboxLabel.htmlFor = control.id;
            checkboxLabel.appendChild(control);
            checkboxLabel.appendChild(createElement("span", "", field.label));
            group.appendChild(checkboxLabel);
        } else {
            const labelText = instance.config.fields.length === 1
                ? `${field.label} ${rowIndex + 1}`
                : field.label;
            const label = createElement("label", "sf-dynamic-fields__label", labelText);
            label.htmlFor = control.id;
            if (field.required) {
                const required = createElement("span", "sf-dynamic-fields__required", "*");
                required.setAttribute("aria-hidden", "true");
                label.appendChild(document.createTextNode(" "));
                label.appendChild(required);
            }
            group.appendChild(label);
            group.appendChild(control);
        }

        if (field.helpText) group.appendChild(createElement("p", "sf-dynamic-fields__help", field.helpText));
        return group;
    }

    function buildActionButton(className, title, text) {
        const button = createElement("button", className, text);
        button.type = "button";
        button.title = title;
        button.setAttribute("aria-label", title);
        return button;
    }

    function buildRow(instance, initialRow) {
        const rowIndex = instance.rowsHost.children.length;
        const row = createElement("div", "sf-dynamic-fields__row");
        row.dataset.sfDynamicFieldsRow = "";

        if (instance.config.fields.length > 1) {
            row.appendChild(createElement("div", "sf-dynamic-fields__row-number", String(rowIndex + 1)));
        }

        const fieldsHost = createElement("div", "sf-dynamic-fields__row-fields");
        instance.config.fields.forEach(field => fieldsHost.appendChild(buildField(instance, field, rowIndex, initialRow)));
        row.appendChild(fieldsHost);

        if (!instance.config.readonly && !instance.config.disabled && (instance.config.allowRemove || instance.config.allowReorder)) {
            const actions = createElement("div", "sf-dynamic-fields__row-actions");

            if (instance.config.allowReorder) {
                const up = buildActionButton("sf-dynamic-fields__icon-button", instance.config.moveUpText, "↑");
                up.dataset.sfDynamicFieldsMove = "up";
                up.addEventListener("click", () => instance.moveRow(row, -1));
                actions.appendChild(up);

                const down = buildActionButton("sf-dynamic-fields__icon-button", instance.config.moveDownText, "↓");
                down.dataset.sfDynamicFieldsMove = "down";
                down.addEventListener("click", () => instance.moveRow(row, 1));
                actions.appendChild(down);
            }

            if (instance.config.allowRemove) {
                const remove = buildActionButton("sf-dynamic-fields__icon-button is-danger", instance.config.removeButtonText, "−");
                remove.dataset.sfDynamicFieldsRemove = "";
                remove.addEventListener("click", () => instance.removeRow(row));
                actions.appendChild(remove);
            }

            row.appendChild(actions);
        }

        return row;
    }

    function createInstance(root, config) {
        const instance = {
            root,
            config,
            rowsHost: null,
            addButton: null,
            errorHost: null,
            output: null,

            getRows(options) {
                const includeEmpty = !!options?.includeEmpty;
                const rows = [];

                Array.from(this.rowsHost.children).forEach((rowElement, index) => {
                    const row = {};
                    if (this.config.rowNumberProperty) row[this.config.rowNumberProperty] = index + 1;

                    this.config.fields.forEach(field => {
                        const control = rowElement.querySelector(`[data-sf-dynamic-field="${cssEscape(field.name)}"]`);
                        row[field.name] = control ? getControlValue(control, field) : "";
                    });

                    if (includeEmpty || rowHasValue(row, this.config.fields)) rows.push(row);
                });

                return rows;
            },

            setRows(rows) {
                const source = Array.isArray(rows) ? rows.slice(0, this.config.maxRows) : [];
                this.rowsHost.replaceChildren();

                const count = Math.max(this.config.minRows, source.length);
                for (let index = 0; index < count; index++) {
                    this.rowsHost.appendChild(buildRow(this, source[index] || {}));
                }

                this.updateState();
                this.sync();
            },

            addRow(initialRow) {
                if (this.rowsHost.children.length >= this.config.maxRows) {
                    this.setError(this.config.maxRowsMessage);
                    return null;
                }

                const row = buildRow(this, initialRow || {});
                this.rowsHost.appendChild(row);
                this.updateState();
                this.sync();
                dispatch(this.root, "sf-dynamic-fields:row-added", {
                    id: this.config.id,
                    index: this.rowsHost.children.length - 1,
                    rows: this.getRows()
                });

                row.querySelector("input:not([type=checkbox]), textarea, select")?.focus();
                return row;
            },

            removeRow(row) {
                if (!(row instanceof Element) || !this.rowsHost.contains(row)) return false;
                if (this.rowsHost.children.length <= this.config.minRows) {
                    this.setError(this.config.emptyValidationMessage);
                    return false;
                }

                const index = Array.from(this.rowsHost.children).indexOf(row);
                row.remove();
                this.updateState();
                this.sync();
                dispatch(this.root, "sf-dynamic-fields:row-removed", {
                    id: this.config.id,
                    index,
                    rows: this.getRows()
                });
                return true;
            },

            moveRow(row, direction) {
                if (!(row instanceof Element) || !this.rowsHost.contains(row)) return false;
                const sibling = direction < 0 ? row.previousElementSibling : row.nextElementSibling;
                if (!sibling) return false;

                if (direction < 0) this.rowsHost.insertBefore(row, sibling);
                else this.rowsHost.insertBefore(sibling, row);

                this.updateState();
                this.sync();
                dispatch(this.root, "sf-dynamic-fields:row-moved", {
                    id: this.config.id,
                    rows: this.getRows()
                });
                return true;
            },

            updateState() {
                const rows = Array.from(this.rowsHost.children);
                rows.forEach((row, index) => {
                    row.dataset.rowIndex = String(index);
                    row.querySelector(".sf-dynamic-fields__row-number")?.replaceChildren(document.createTextNode(String(index + 1)));

                    this.config.fields.forEach(field => {
                        const control = row.querySelector(`[data-sf-dynamic-field="${cssEscape(field.name)}"]`);
                        const label = control ? row.querySelector(`label[for="${cssEscape(control.id)}"]`) : null;
                        if (control) control.id = `${this.config.id}-${index + 1}-${field.name}`;
                        if (label && this.config.fields.length === 1) {
                            const required = field.required;
                            label.replaceChildren(document.createTextNode(`${field.label} ${index + 1}`));
                            if (required) {
                                label.appendChild(document.createTextNode(" "));
                                label.appendChild(createElement("span", "sf-dynamic-fields__required", "*"));
                            }
                            label.htmlFor = control.id;
                        } else if (label && control) {
                            label.htmlFor = control.id;
                        }
                    });

                    const up = row.querySelector('[data-sf-dynamic-fields-move="up"]');
                    const down = row.querySelector('[data-sf-dynamic-fields-move="down"]');
                    if (up) up.disabled = index === 0;
                    if (down) down.disabled = index === rows.length - 1;

                    const remove = row.querySelector("[data-sf-dynamic-fields-remove]");
                    if (remove) remove.disabled = rows.length <= this.config.minRows;
                });

                if (this.addButton) {
                    const atMax = rows.length >= this.config.maxRows;
                    this.addButton.disabled = atMax;
                    this.addButton.hidden = atMax;
                }
            },

            findOutput() {
                if (!this.config.outputName) return null;
                const form = this.config.formId
                    ? document.getElementById(this.config.formId)
                    : this.root.closest("form");
                const scope = form || this.root;
                return scope.querySelector(`[name="${cssEscape(this.config.outputName)}"]`);
            },

            sync() {
                this.output = this.findOutput();
                const json = JSON.stringify(this.getRows());
                if (this.output) {
                    this.output.value = json;
                    this.output.dispatchEvent(new Event("input", { bubbles: true }));
                }
                return json;
            },

            validate(options) {
                const report = options?.report !== false;
                const rows = this.getRows();
                const errors = [];
                let firstInvalid = null;

                if (rows.length < this.config.minRows) errors.push(this.config.emptyValidationMessage);

                this.rowsHost.querySelectorAll("input, textarea, select").forEach(control => {
                    if (!control.checkValidity()) {
                        firstInvalid ||= control;
                        errors.push(control.validationMessage || this.config.emptyValidationMessage);
                    }
                });

                if (errors.length) {
                    this.setError(errors[0]);
                    if (report) firstInvalid?.reportValidity();
                    dispatch(this.root, "sf-dynamic-fields:validation-failed", {
                        id: this.config.id,
                        errors: [...new Set(errors)]
                    });
                    return false;
                }

                this.setError("");
                this.sync();
                return true;
            },

            setError(message) {
                if (!this.errorHost) return;
                this.errorHost.textContent = message || "";
                this.errorHost.hidden = !message;
            },

            destroy() {
                instancesByRoot.delete(this.root);
                if (instancesById.get(this.config.id) === this) instancesById.delete(this.config.id);
                this.root.replaceChildren();
                this.root.removeAttribute("data-sf-dynamic-fields-ready");
            }
        };

        return instance;
    }

    function render(instance) {
        const root = instance.root;
        const existingOutput = instance.config.outputName
            ? root.querySelector(`[name="${cssEscape(instance.config.outputName)}"]`)
            : null;

        root.replaceChildren();
        root.classList.add("sf-dynamic-fields");
        root.dataset.sfDynamicFields = "";
        root.dataset.sfDynamicFieldsReady = "true";
        root.dir = instance.config.direction;

        if (existingOutput) root.appendChild(existingOutput);
        else if (instance.config.renderOutputInput && instance.config.outputName) {
            const output = document.createElement("input");
            output.type = "hidden";
            output.name = instance.config.outputName;
            output.dataset.sfDynamicFieldsOutput = "";
            root.appendChild(output);
        }

        if (instance.config.title || instance.config.description) {
            const header = createElement("header", "sf-dynamic-fields__header");
            if (instance.config.title) header.appendChild(createElement("h3", "sf-dynamic-fields__title", instance.config.title));
            if (instance.config.description) header.appendChild(createElement("p", "sf-dynamic-fields__description", instance.config.description));
            root.appendChild(header);
        }

        instance.rowsHost = createElement("div", "sf-dynamic-fields__rows");
        instance.rowsHost.dataset.sfDynamicFieldsRows = "";
        root.appendChild(instance.rowsHost);

        const footer = createElement("div", "sf-dynamic-fields__footer");
        if (instance.config.allowAdd && !instance.config.readonly && !instance.config.disabled) {
            instance.addButton = buildActionButton("sf-dynamic-fields__add", instance.config.addButtonText, `+ ${instance.config.addButtonText}`);
            instance.addButton.dataset.sfDynamicFieldsAdd = "";
            instance.addButton.addEventListener("click", () => instance.addRow({}));
            footer.appendChild(instance.addButton);
        }

        instance.errorHost = createElement("p", "sf-dynamic-fields__error");
        instance.errorHost.hidden = true;
        instance.errorHost.setAttribute("role", "alert");
        footer.appendChild(instance.errorHost);
        root.appendChild(footer);

        instance.setRows(instance.config.initialRows);
    }

    function mount(target, rawConfig) {
        const root = resolveRoot(target);
        if (!root) throw new Error("SmartDynamicFields mount target was not found.");

        const config = normalizeConfig(rawConfig || {});
        if (!config.id) config.id = root.id || `sf-dynamic-fields-${Date.now()}`;

        const duplicate = instancesById.get(config.id);
        if (duplicate && duplicate.root !== root && duplicate.root.isConnected) {
            throw new Error(`SmartDynamicFields id '${config.id}' is already in use.`);
        }

        instancesByRoot.get(root)?.destroy();
        root.id = config.id;

        const instance = createInstance(root, config);
        instancesByRoot.set(root, instance);
        instancesById.set(config.id, instance);
        render(instance);

        dispatch(root, "sf-dynamic-fields:ready", {
            id: config.id,
            instance
        });
        return instance;
    }

    function parseElementConfig(root) {
        const json = root.getAttribute("data-sf-dynamic-fields-config");
        if (!json) return null;
        try { return JSON.parse(json); }
        catch (error) {
            console.error("SmartDynamicFields config is invalid JSON.", error);
            return null;
        }
    }

    function init(target) {
        const root = resolveRoot(target);
        if (!root) return null;
        if (instancesByRoot.has(root)) return instancesByRoot.get(root);

        const config = parseElementConfig(root);
        return config ? mount(root, config) : null;
    }

    function initAll(scope) {
        const root = scope instanceof Element || scope instanceof Document ? scope : document;
        const nodes = [];
        if (root instanceof Element && root.matches("[data-sf-dynamic-fields]")) nodes.push(root);
        root.querySelectorAll?.("[data-sf-dynamic-fields]").forEach(node => nodes.push(node));
        return nodes.map(init).filter(Boolean);
    }

    function getInstance(target) {
        if (target && target.root && target.config) return target;
        const root = resolveRoot(target);
        if (root && instancesByRoot.has(root)) return instancesByRoot.get(root);
        if (typeof target === "string") return instancesById.get(target.replace(/^#/, "")) || null;
        return null;
    }

    function mountInForm(formTarget, rawConfig) {
        const form = resolveForm(formTarget);
        if (!form) throw new Error("SmartDynamicFields form was not found.");

        const config = normalizeConfig(rawConfig || {});
        if (!config.id) throw new Error("SmartDynamicFields config requires an Id.");
        config.formId = config.formId || form.id;

        const grid = form.querySelector(".grid") || form;
        let host = document.getElementById(config.id);
        if (!host || !form.contains(host)) {
            host = createElement("section", "sf-dynamic-fields col-span-12");
            host.id = config.id;
            host.dataset.sfDynamicFields = "";

            const actionRow = Array.from(grid.children).find(child => child.querySelector?.("button"));
            if (actionRow) grid.insertBefore(host, actionRow);
            else grid.appendChild(host);
        }

        return mount(host, config);
    }

    function mountInFormWhenReady(formTarget, rawConfig, options) {
        const timeoutMs = Math.max(250, asInteger(options?.timeoutMs, 5000));
        const immediate = resolveForm(formTarget);
        if (immediate) return Promise.resolve(mountInForm(immediate, rawConfig));

        return new Promise((resolve, reject) => {
            let completed = false;
            const finish = (callback) => {
                if (completed) return;
                completed = true;
                observer.disconnect();
                clearTimeout(timer);
                callback();
            };

            const observer = new MutationObserver(() => {
                const form = resolveForm(formTarget);
                if (form) finish(() => resolve(mountInForm(form, rawConfig)));
            });

            const timer = setTimeout(() => {
                finish(() => reject(new Error("SmartDynamicFields timed out waiting for the form.")));
            }, timeoutMs);

            observer.observe(document.body, { childList: true, subtree: true });
        });
    }

    function destroy(target) {
        const instance = getInstance(target);
        if (!instance) return false;
        instance.destroy();
        return true;
    }

    const api = Object.freeze({
        init,
        initAll,
        mount,
        mountInForm,
        mountInFormWhenReady,
        destroy,
        getInstance,
        getRows: target => getInstance(target)?.getRows() || [],
        setRows: (target, rows) => getInstance(target)?.setRows(rows),
        addRow: (target, row) => getInstance(target)?.addRow(row),
        removeRow: (target, row) => getInstance(target)?.removeRow(row),
        validate: (target, options) => getInstance(target)?.validate(options) ?? false,
        sync: target => getInstance(target)?.sync() ?? null
    });

    window.SmartDynamicFields = api;

    const boot = () => api.initAll(document);
    if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", boot, { once: true });
    else boot();

    const observer = new MutationObserver(mutations => {
        mutations.forEach(mutation => mutation.addedNodes.forEach(node => {
            if (node instanceof Element) api.initAll(node);
        }));
    });
    observer.observe(document.documentElement, { childList: true, subtree: true });
})();
