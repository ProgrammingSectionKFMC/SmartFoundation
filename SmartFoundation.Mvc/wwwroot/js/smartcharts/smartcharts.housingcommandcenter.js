(function () {
    'use strict';

    window.SmartCharts = window.SmartCharts || {};

    /* =========================================================
       Helpers
    ========================================================= */
    const $ = (id) => document.getElementById(id);

    const esc = (v) => String(v ?? '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');

    const has = (v) => v !== null && v !== undefined && String(v).trim() !== '';

    const num = (v, fb = 0) => {
        const n = Number(v);
        return Number.isFinite(n) ? n : fb;
    };

    const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));

    const sortByOrder = (arr) =>
        [...(arr || [])].sort((a, b) => num(a?.sortOrder, 0) - num(b?.sortOrder, 0));

    function parseCfg(cfgId) {
        const el = $(cfgId);
        if (!el) return null;
        try { return JSON.parse(el.textContent || '{}'); }
        catch { return null; }
    }

    function fmtNumber(value, digits = 0) {
        return num(value).toLocaleString('en-US', {
            numberingSystem: 'latn',
            minimumFractionDigits: digits,
            maximumFractionDigits: digits
        });
    }

    function fmtPercent(value, digits = 1) {
        return fmtNumber(value, digits) + '%';
    }

    function normalizeTone(tone) {
        const v = String(tone || '').toLowerCase();
        if (v === 'success' || v === 'warning' || v === 'danger' || v === 'info' || v === 'neutral') return v;
        return 'neutral';
    }

    // ── Government Official Color Tones ──────────────────────
    //    Deep Navy · Steel Blue · Official Gold · Forest Green
    // ─────────────────────────────────────────────────────────
    const TONES = {
        info: {
            bg: '#ffffff',
            soft: '#f0f4f8',
            border: '#ccd4e0',
            text: '#2d5282',
            accent: '#2d5282'
        },
        success: {
            bg: '#ffffff',
            soft: '#f0f5f2',
            border: '#c8d8cc',
            text: '#1a5c3a',
            accent: '#1a5c3a'
        },
        warning: {
            bg: '#ffffff',
            soft: '#f5f0e8',
            border: '#d4c090',
            text: '#7c5209',
            accent: '#8b6914'
        },
        danger: {
            bg: '#ffffff',
            soft: '#f5eeee',
            border: '#ccaaaa',
            text: '#8b1a1a',
            accent: '#8b1a1a'
        },
        neutral: {
            bg: '#ffffff',
            soft: '#f0f3f7',
            border: '#ccd4e0',
            text: '#3d5166',
            accent: '#3d5166'
        }
    };

    // ── Government Official Data Palette ─────────────────────
    const PALETTE = [
        '#1a3a5c',   // كحلي رسمي
        '#2d5282',   // فولاذي أزرق
        '#1a5c3a',   // أخضر غابي
        '#8b6914',   // ذهبي رسمي
        '#2e3f8f',   // نيلي رسمي
        '#1a4f5c',   // تيل داكن
        '#226b44',   // أخضر متوسط
        '#3d5166',   // رمادي فولاذي
        '#5c4a0a',   // زيتي ذهبي
        '#8b1a1a'    // أحمر داكن
    ];

    function toneStyle(tone, color, idx) {
        const t = TONES[normalizeTone(tone)] || TONES.neutral;
        const accent = has(color) ? color : (t.accent || PALETTE[idx % PALETTE.length]);
        return {
            bg: t.bg,
            soft: t.soft,
            border: t.border,
            text: t.text,
            accent
        };
    }

    function resolvePercent(item, opts) {
        const autoCalc = !!opts?.autoCalculatePercentages;

        if (item && item.completionPercent !== null && item.completionPercent !== undefined && item.completionPercent !== '') {
            return clamp(num(item.completionPercent), 0, 100);
        }

        if (autoCalc) {
            const actual = num(item?.actual, NaN);
            const target = num(item?.target, NaN);
            if (Number.isFinite(actual) && Number.isFinite(target) && target > 0) {
                return clamp((actual / target) * 100, 0, 100);
            }
        }

        return 0;
    }

    function getMetricMap(metrics) {
        const map = {};
        (metrics || []).forEach((m, i) => {
            map[String(m.key || '').trim()] = { ...m, __index: i };
        });
        return map;
    }

    function findDepartmentMetric(dep, metricKey) {
        if (!dep || !Array.isArray(dep.metrics)) return null;
        return dep.metrics.find(x => String(x.metricKey || '') === String(metricKey || '')) || null;
    }


    function hasExplicitPercent(item) {
    const value = item?.completionPercent;

    return value !== null &&
        value !== undefined &&
        value !== '' &&
        Number.isFinite(Number(value));
}

    function calcDepartmentOverall(dep, metricMap, opts) {

    // اعتماد النسبة المحسوبة مسبقًا في C#
    // بما فيها الصفر الحقيقي
    const published = dep?.overallCompletionPercent;

    if (
        published !== null &&
        published !== undefined &&
        published !== '' &&
        Number.isFinite(Number(published))
    ) {
        return clamp(Number(published), 0, 100);
    }

    // احتساب المؤشرات القابلة للتقييم فقط
    const scores = (dep?.metrics || [])
        .filter(x =>
            x &&
            x.metricKey !== 'm_waiting_list' &&
            metricMap[x.metricKey] &&
            hasExplicitPercent(x)
        )
        .map(x =>
            clamp(Number(x.completionPercent), 0, 100)
        );

    if (scores.length === 0) {
        return null;
    }

    return clamp(
        scores.reduce((sum, value) => sum + value, 0)
        / scores.length,
        0,
        100
    );
}

    function renderPercentRing(percent, accent) {
        const p = clamp(num(percent), 0, 100);
        const r = 21;
        const c = 2 * Math.PI * r;
        const dash = (p / 100) * c;

        return `
<svg class="sf-hccm-ring-svg" viewBox="0 0 52 52" aria-hidden="true">
    <circle cx="26" cy="26" r="${r}" class="sf-hccm-ring-track"></circle>
    <circle cx="26" cy="26" r="${r}" class="sf-hccm-ring-fill" style="stroke:${accent};stroke-dasharray:${dash} ${c};"></circle>
</svg>`;
    }

    /* =========================================================
       Top metric cards
    ========================================================= */

    function buildWaitingMetricCard(metric, opts, idx) {

    const s = toneStyle(
        metric.tone,
        metric.color,
        idx
    );

    const details = String(metric?.hint || '')
        .split('|')
        .map(x => x.trim())
        .filter(Boolean);

    const detailsHtml = details
        .map(x => `
            <div style="margin-bottom:6px">
                ${esc(x)}
            </div>
        `)
        .join('');

    return `
<div class="sf-hccm-metric-card"
     style="--mc-bg:${s.bg};--mc-soft:${s.soft};--mc-border:${s.border};--mc-text:${s.text};--mc-accent:${s.accent}">

    <div class="sf-hccm-metric-top">

        <div class="sf-hccm-metric-icon">
            <i class="fa-solid fa-list-ol"></i>
        </div>

        <span style="font-size:11px;font-weight:700;color:${s.accent}">
            بيانات إحصائية
        </span>

    </div>

    <div class="sf-hccm-metric-title">
        <span class="sf-hccm-title-dot"
              style="background:${s.accent}"></span>
        ${esc(metric.title || 'قوائم الانتظار')}
    </div>

    <div class="sf-hccm-metric-subtitle">
        لا تدخل في إجمالي كفاءة عمل الإدارة
    </div>

    <div class="sf-hccm-metric-meta">

        <span class="sf-hccm-mini-chip is-target">
            إجمالي السجلات:
            <strong>${esc(fmtNumber(metric.target, 0))}</strong>
        </span>

        <span class="sf-hccm-mini-chip is-actual">
            المنتظرون فعليًا:
            <strong>${esc(fmtNumber(metric.actual, 0))}</strong>
        </span>

    </div>

    <div class="sf-hccm-metric-hint">
        <span class="sf-hccm-metric-hint-text">
            ${detailsHtml}
        </span>
    </div>

</div>`;
}


    function buildMetricCard(metric, opts, idx) {

    // قوائم الانتظار بطاقة إحصائية وليست مؤشر أداء
    if (metric?.key === 'm_waiting_list') {
        return buildWaitingMetricCard(metric, opts, idx);
    }

    const s = toneStyle(metric.tone, metric.color, idx);
    const percent = resolvePercent(metric, opts);
        const actual = metric?.actual;
        const target = metric?.target;
        const unit = metric?.unit || '';
        const displayPercent = fmtPercent(percent, 1);

        const isProceduresKpi =
    metric?.key === 'm_housing_procedures';

        const actualLabel = has(metric?.actualLabel)
    ? metric.actualLabel
    : 'المنجز';

const targetLabel = has(metric?.targetLabel)
    ? metric.targetLabel
    : 'المستهدف';

const valueUnit =
    metric?.showValueUnit === false
        ? ''
        : unit;

        const iconHtml = has(metric?.emoji)
            ? `<span class="sf-hccm-metric-emoji">${esc(metric.emoji)}</span>`
            : has(metric?.icon)
                ? `<i class="${esc(metric.icon)}"></i>`
                : `<span class="sf-hccm-metric-emoji">📊</span>`;

        let metaHtml = '';

if (opts.showMetricTargetActual) {

    const actualHtml =
        actual !== null && actual !== undefined && actual !== ''
            ? `<span class="sf-hccm-mini-chip is-actual">
                   ${esc(actualLabel)}:
                   <strong>${esc(fmtNumber(actual, isProceduresKpi ? 1 : 0))}${has(valueUnit) ? ' ' + esc(valueUnit) : ''}</strong>
               </span>`
            : '';

    const targetHtml =
        target !== null && target !== undefined && target !== ''
            ? `<span class="sf-hccm-mini-chip is-target">
                   ${esc(targetLabel)}:
                   <strong>${esc(fmtNumber(target, 0))}${has(valueUnit) ? ' ' + esc(valueUnit) : ''}</strong>
               </span>`
            : '';

            
const gapHtml =
    isProceduresKpi &&
    actual !== null &&
    actual !== undefined &&
    target !== null &&
    target !== undefined
        ? `<span class="sf-hccm-mini-chip">
               الفجوة عن المستهدف:
               <strong>${esc(fmtNumber(
                   Math.max(0, num(target) - num(actual)), 1
               ))} نقطة مئوية</strong>
           </span>`
        : '';


    
metaHtml =
    (actualHtml || targetHtml || gapHtml)
        ? `<div class="sf-hccm-metric-meta">
               ${actualHtml}
               ${targetHtml}
               ${gapHtml}
           </div>`
        : '';

}

        const hrefOpen = has(metric?.href)
            ? `<a class="sf-hccm-metric-link-cover" href="${esc(metric.href)}" aria-label="${esc(metric.title || '')}"></a>`
            : '';

        return `
<div class="sf-hccm-metric-card"
     style="--mc-bg:${s.bg};--mc-soft:${s.soft};--mc-border:${s.border};--mc-text:${s.text};--mc-accent:${s.accent}">
    ${hrefOpen}
    <div class="sf-hccm-metric-top">
        <div class="sf-hccm-metric-icon">${iconHtml}</div>
        <div class="sf-hccm-metric-ring">
            ${renderPercentRing(percent, s.accent)}
            <div class="sf-hccm-metric-ring-center">${esc(displayPercent)}</div>
        </div>
    </div>

    <div class="sf-hccm-metric-title"><span class="sf-hccm-title-dot" style="background:${s.accent}"></span>${esc(metric?.title || '')}</div>
    ${has(metric?.subtitle) ? `<div class="sf-hccm-metric-subtitle">${esc(metric.subtitle)}</div>` : ''}

    ${metaHtml}

    ${opts.showMetricProgressBar ? `
    <div class="sf-hccm-metric-progress">
        <div class="sf-hccm-metric-progress-fill" style="width:${percent.toFixed(2)}%;background:${s.accent};"></div>
    </div>` : ''}

    ${has(metric?.hint) ? `<div class="sf-hccm-metric-hint">
        <span class="sf-hccm-metric-hint-icon">
            <svg viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg" width="18" height="18">
                <path d="M10 2C6.68629 2 4 4.68629 4 8C4 10.2208 5.20659 12.1599 7 13.1973V15C7 15.5523 7.44772 16 8 16H12C12.5523 16 13 15.5523 13 15V13.1973C14.7934 12.1599 16 10.2208 16 8C16 4.68629 13.3137 2 10 2Z" fill="#c9a227"/>
                <path d="M8 17H12V17.5C12 18.3284 11.3284 19 10.5 19H9.5C8.67157 19 8 18.3284 8 17.5V17Z" fill="#a88a1d"/>
                <circle cx="10" cy="7" r="2" fill="#fef3c7"/>
                <path d="M10 9V12" stroke="#fef3c7" stroke-width="1.5" stroke-linecap="round"/>
            </svg>
        </span>
        <span class="sf-hccm-metric-hint-text">${esc(metric.hint)}</span>
    </div>` : ''}

    ${(metric?.__best || metric?.__worst) ? `
    <div class="sf-hccm-metric-ranking">
        ${metric.__best ? `
        <div class="sf-hccm-ranking-row is-best">
            <span class="sf-hccm-ranking-icon">🏆</span>
            <span class="sf-hccm-ranking-label">الأعلى:</span>
            <span class="sf-hccm-ranking-name">${esc(metric.__best.name)}</span>
            <span class="sf-hccm-ranking-val">${esc(fmtPercent(metric.__best.percent, 1))}</span>
        </div>` : ''}
        ${metric.__worst ? `
        <div class="sf-hccm-ranking-row is-worst">
            <span class="sf-hccm-ranking-icon">⚠️</span>
            <span class="sf-hccm-ranking-label">الأدنى:</span>
            <span class="sf-hccm-ranking-name">-</span>
            <span class="sf-hccm-ranking-val">${esc(fmtPercent(metric.__worst.percent, 1))}</span>
        </div>` : ''}
    </div>` : ''}
</div>`;
    }

    /* =========================================================
       Matrix table helpers
       <span class="sf-hccm-ranking-name">${esc(metric.__worst.name)}</span>
    ========================================================= */
    function getPerfClass(percent) {
        const p = num(percent);
        if (p >= 85) return 'is-good';
        if (p >= 70) return 'is-warn';
        return 'is-bad';
    }

    function buildCellProgress(percent, accent) {
        return `
<div class="sf-hccm-tcell-progress">
    <div class="sf-hccm-tcell-progress-fill" style="width:${clamp(percent, 0, 100).toFixed(2)}%;background:${accent};"></div>
</div>`;
    }

    function buildMatrixMetricCell(depMetric, metric, opts, idx) {
        if (!depMetric) {
            return `
<td class="sf-hccm-matrix-td">
    <div class="sf-hccm-tcell is-empty">
        <div class="sf-hccm-tcell-empty">—</div>
    </div>
</td>`;
        }


        // قوائم الانتظار: عرض إحصائي دون نسبة أداء



if (metric?.key === 'm_waiting_list') {

    const s = toneStyle(
        depMetric.tone || metric.tone,
        depMetric.color || metric.color,
        idx
    );

    const details = String(depMetric.note || '')
        .split('|')
        .map(x => {
            const pos = x.indexOf(':');

            return {
                label: pos >= 0
                    ? x.slice(0, pos).trim()
                    : x.trim(),

                value: pos >= 0
                    ? x.slice(pos + 1).trim()
                    : ''
            };
        })
        .filter(x => x.label);

    function getDetail(...labels) {
        const item = details.find(
            x => labels.includes(x.label)
        );

        return item ? item.value : '—';
    }

    const rows = [
        {
            label: 'إجمالي السجلات',
            value: fmtNumber(depMetric.target, 0)
        },
        {
            label: 'المنتظرون فعليًا',
            value: fmtNumber(depMetric.actual, 0)
        },
        {
            label: 'القوائم الرئيسية',
            value: getDetail('القوائم الرئيسية')
        },
        {
            label: 'القوائم الجانبية',
            value: getDetail('القوائم الجانبية')
        },
        {
            label: 'في مرحلة التخصيص',
            value: getDetail(
                'في مرحلة التخصيص',
                'في مراحل التخصيص'
            )
        },
        {
            label: 'في مرحلة التسكين',
            value: getDetail(
                'في مرحلة التسكين',
                'في مراحل التسكين'
            )
        }
    ];

    const hrefOpen = has(depMetric.href)
        ? `<a class="sf-hccm-tcell-link-cover"
              href="${esc(depMetric.href)}"
              aria-label="عرض قوائم الانتظار"></a>`
        : '';

    
    const compactLabels = [
        'الإجمالي',
        'المنتظرون',
        'الرئيسية',
        'الجانبية',
        'التخصيص',
        'التسكين'
    ];

    return `
<td class="sf-hccm-matrix-td">

    <div class="sf-hccm-tcell"
         style="
            --tc-bg:${s.bg};
            --tc-soft:${s.soft};
            --tc-border:${s.border};
            --tc-text:${s.text};
            --tc-accent:${s.accent};
            height:auto;
            min-height:0;
            box-sizing:border-box;
            padding:9px 7px;
         ">

        ${hrefOpen}

        <div style="
            text-align:center;
            margin-bottom:7px;
            line-height:1.3;
        ">
            <div style="
                font-size:12px;
                font-weight:800;
                color:${s.accent};
            ">
                بيانات إحصائية
            </div>

            
        </div>

        <div style="
            display:grid;
            grid-template-columns:repeat(2,minmax(0,1fr));
            gap:4px 6px;
        ">

            ${rows.map((row, i) => `
                <div title="${esc(row.label)}"
                     style="
                        display:flex;
                        align-items:center;
                        justify-content:space-between;
                        gap:3px;
                        min-width:0;
                        padding:4px 3px;
                        background:#f1f3f5;
                        border-radius:4px;
                    ">

                    <span style="
                        font-size:9px;
                        color:#475569;
                        white-space:nowrap;
                    ">
                        ${esc(compactLabels[i])}
                    </span>

                    <strong style="
                        font-size:10px;
                        color:${s.accent};
                        white-space:nowrap;
                    ">
                        ${esc(row.value)}
                    </strong>

                </div>
            
            `).join('')}

        </div>

        <!-- النافذة الجانبية عند تمرير المؤشر -->
        <div class="sf-hccm-tcell-tooltip">

            <div class="sf-hccm-tooltip-title">
                تفاصيل قوائم الانتظار
            </div>

            <div class="sf-hccm-tooltip-body">

                ${rows.map(row => `
                    <div class="sf-hccm-tooltip-row">
                        <div class="sf-hccm-tooltip-dot"></div>
                        <span>
                            ${esc(row.label)}:
                            ${esc(row.value)}
                        </span>
                    </div>
                `).join('')}

            </div>

        </div>

    </div>

</td>`;
}






        if (
    [
        'm_housing_readiness',
        'm_housing_occupancy',
        'm_housing_procedures'
    ].includes(metric?.key) &&
    !hasExplicitPercent(depMetric)
) {
    const emptyLabel =
        metric.key === 'm_housing_procedures'
            ? 'لا توجد إجراءات إسكان'
            : (depMetric.displayText || 'البيانات غير متاحة');

    return `
<td class="sf-hccm-matrix-td">
    <div class="sf-hccm-tcell is-empty">
        <div class="sf-hccm-tcell-empty">
            ${esc(emptyLabel)}
        </div>
    </div>
</td>`;
}

// الكفاءة المالية غير القابلة للتقييم
if (
    metric?.key === 'm_finance_utilities' &&
    (
        depMetric.completionPercent === null ||
        depMetric.completionPercent === undefined ||
        depMetric.completionPercent === ''
    )
) {
    return `
<td class="sf-hccm-matrix-td">
    <div class="sf-hccm-tcell is-empty">
        <div class="sf-hccm-tcell-empty">
            لا توجد بيانات مالية
        </div>
    </div>
</td>`;
}


        const s = toneStyle(depMetric.tone || metric?.tone, depMetric.color || metric?.color, idx);
        const percent = resolvePercent(depMetric, opts);
        const perfCls = getPerfClass(percent);

        const actual = depMetric?.actual;
        const target = depMetric?.target;
        
        const remaining =
    metric?.key === 'm_allocation_balance'
        ? Math.max(num(actual) - num(target), 0)
        : metric?.key === 'm_finance_utilities'
            ? Math.abs(num(target) - num(actual))
            : Math.max(num(target) - num(actual), 0);



        const displayText = has(depMetric.displayText) ? depMetric.displayText : fmtPercent(percent, 1);

        const actualLabel = has(metric?.actualLabel)
    ? metric.actualLabel
    : 'منجز';

const targetLabel = has(metric?.targetLabel)
    ? metric.targetLabel
    : 'مستهدف';

const remainingLabel = has(metric?.remainingLabel)
    ? metric.remainingLabel
    : 'المتبقي';


    
const isProceduresKpi =
    metric?.key === 'm_housing_procedures';

const hasProceduresScore =
    actual !== null && actual !== undefined &&
    target !== null && target !== undefined;

const proceduresStatsHtml = isProceduresKpi
    ? `
      <div class="sf-hccm-tcell-stat-line is-actual-target">
          <span class="sf-hccm-tcell-stat-label"
                style="white-space:normal">
              كفاءة سرعة الإنجاز
          </span>
          <strong class="is-actual">
              ${hasProceduresScore
                  ? esc(fmtPercent(actual, 1))
                  : '—'}
          </strong>
      </div>

      <div class="sf-hccm-tcell-stat-line is-actual-target">
          <span class="sf-hccm-tcell-stat-label"
                style="white-space:normal">
              الكفاءة المستهدفة
          </span>
          <strong class="is-target">
              ${hasProceduresScore
                  ? esc(fmtPercent(target, 0))
                  : '—'}
          </strong>
      </div>

      <div class="sf-hccm-tcell-stat-line is-remaining">
          <span class="sf-hccm-tcell-stat-label"
                style="white-space:normal">
              الفجوة عن المستهدف
          </span>
          <strong style="white-space:normal;text-align:left">
              ${hasProceduresScore
                  ? esc(fmtNumber(
                      Math.max(0, num(target) - num(actual)), 1
                    )) + ' نقطة مئوية'
                  : '—'}
          </strong>
      </div>`
    : null;


        const noteHtml = has(depMetric?.note)
            ? `<div class="sf-hccm-tcell-tooltip">
        <div class="sf-hccm-tooltip-title">${esc(metric?.shortTitle || metric?.title || '')}</div>
        <div class="sf-hccm-tooltip-body">
            ${depMetric.note.split('|').map(s => s.trim()).filter(s => s).map(s =>
                `<div class="sf-hccm-tooltip-row">
    <div class="sf-hccm-tooltip-dot"></div>
    <span>${esc(s)}</span>
 </div>`
            ).join('')}
        </div>
       </div>`
            : '';


        const hrefOpen = has(depMetric?.href)
            ? `<a class="sf-hccm-tcell-link-cover" href="${esc(depMetric.href)}" aria-label="${esc(metric?.title || '')}"></a>`
            : '';

        return `
<td class="sf-hccm-matrix-td">
    <div class="sf-hccm-tcell ${perfCls}"
         style="--tc-bg:${s.bg};--tc-soft:${s.soft};--tc-border:${s.border};--tc-text:${s.text};--tc-accent:${s.accent}">
        ${hrefOpen}
        ${noteHtml}
        <div class="sf-hccm-tcell-top">
            <div class="sf-hccm-tcell-percent">${esc(displayText)}</div>
            <div class="sf-hccm-tcell-badge ${perfCls}">
                ${percent >= 85 ? '✓' : percent >= 70 ? '!' : '✕'}
            </div>
        </div>

        ${opts.showMetricProgressBar ? buildCellProgress(percent, s.accent) : ''}

        <div class="sf-hccm-tcell-stats">
        ${proceduresStatsHtml !== null ? proceduresStatsHtml : `

    <div class="sf-hccm-tcell-stat-line is-actual-target">

        <span class="sf-hccm-tcell-stat-label">
            <span class="is-actual">${esc(actualLabel)}</span>
            <span class="slash"> / </span>
            <span class="is-target">${esc(targetLabel)}</span>
        </span>

        <strong>
            <span class="is-actual">${esc(fmtNumber(actual, 0))}</span>
            <span class="slash"> / </span>
            <span class="is-target">${esc(fmtNumber(target, 0))}</span>
        </strong>

    </div>

    <div class="sf-hccm-tcell-stat-line is-remaining">
        <span class="sf-hccm-tcell-stat-label">${esc(remainingLabel)}</span>
        <strong>${esc(fmtNumber(remaining, 0))}</strong>
    </div>
    `}
</div>
</td>`;
    }

    function buildMatrixSummaryMetricCell(summaryMetric, metric, opts, idx) {
        if (!summaryMetric) {
            return `
<td class="sf-hccm-matrix-td">
    <div class="sf-hccm-tcell is-empty">
        <div class="sf-hccm-tcell-empty">—</div>
    </div>
</td>`;
        }

        const s = toneStyle(summaryMetric.tone || metric?.tone, summaryMetric.color || metric?.color, idx);
        const percent = resolvePercent(summaryMetric, opts);
        const perfCls = getPerfClass(percent);

        const actual = summaryMetric?.actual;
        const target = summaryMetric?.target;
        
        const remaining =
    metric?.key === 'm_allocation_balance'
        ? Math.max(num(actual) - num(target), 0)
        : metric?.key === 'm_finance_utilities'
            ? Math.abs(num(target) - num(actual))
            : Math.max(num(target) - num(actual), 0);

        const actualLabel = has(metric?.actualLabel)
    ? metric.actualLabel
    : 'منجز';

const targetLabel = has(metric?.targetLabel)
    ? metric.targetLabel
    : 'مستهدف';

const remainingLabel = has(metric?.remainingLabel)
    ? metric.remainingLabel
    : 'متبقي';

        const displayText = has(summaryMetric.displayText) ? summaryMetric.displayText : fmtPercent(percent, 1);

        // الأعلى والأدنى من الـ metric
        const bestHtml = '';
        const worstHtml = '';

        return `
<td class="sf-hccm-matrix-td">
    <div class="sf-hccm-tcell is-summary ${perfCls}"
         style="--tc-bg:${s.bg};--tc-soft:${s.soft};--tc-border:${s.border};--tc-text:${s.text};--tc-accent:${s.accent}">

        <div class="sf-hccm-tcell-top">
            <div class="sf-hccm-tcell-percent">${esc(displayText)}</div>
        </div>

        ${opts.showMetricProgressBar ? buildCellProgress(percent, s.accent) : ''}

        <div class="sf-hccm-sum-stats">
            <div class="sf-hccm-sum-stat">
                <span class="sf-hccm-sum-stat-label">${esc(actualLabel)}</span>
                <strong class="is-actual">${esc(fmtNumber(actual, 0))}</strong>
            </div>
            <div class="sf-hccm-sum-stat">
                <span class="sf-hccm-sum-stat-label">${esc(targetLabel)}</span>
                <strong class="is-target">${esc(fmtNumber(target, 0))}</strong>
            </div>
            <div class="sf-hccm-sum-stat">
                <span class="sf-hccm-sum-stat-label">${esc(remainingLabel)}</span>
                <strong class="is-remaining">${esc(fmtNumber(remaining, 0))}</strong>
            </div>
        </div>

        ${(bestHtml || worstHtml) ? `
        <div class="sf-hccm-sum-ranking">
            ${bestHtml}
            ${worstHtml}
        </div>` : ''}

    </div>
</td>`;
    }

    function buildGaugeSvg(percent, accent) {
        const p = clamp(num(percent), 0, 100);
        const trackColor = p >= 85 ? '#1a5c3a' : p >= 70 ? '#8b6914' : '#8b1a1a';
        const W = 120, H = 88;
        const cx = W / 2, cy = 62;
        const r = 46;
        const totalLen = Math.PI * r;
        const track = `M ${cx - r},${cy} a ${r},${r} 0 0,1 ${r * 2},0`;

        // زاوية العقرب: 0% = يسار (180°) ، 100% = يمين (0°)
        const angle = Math.PI - (p / 100) * Math.PI;
        const needleLen = r * 0.74;
        const nx = cx + needleLen * Math.cos(angle);
        const ny = cy - needleLen * Math.sin(angle);

        // علامات التدريج
        const ticks = [0, 25, 50, 75, 100].map(v => {
            const a = Math.PI - (v / 100) * Math.PI;
            const x1 = cx + (r - 6) * Math.cos(a);
            const y1 = cy - (r - 6) * Math.sin(a);
            const x2 = cx + (r + 2) * Math.cos(a);
            const y2 = cy - (r + 2) * Math.sin(a);
            return `<line x1="${x1.toFixed(1)}" y1="${y1.toFixed(1)}" x2="${x2.toFixed(1)}" y2="${y2.toFixed(1)}" stroke="#cbd5e1" stroke-width="1.2"/>`;
        }).join('');

        
        const segmentColors = ['#dc2626', '#f59e0b', '#84cc16', '#16a34a'];
        const segmentLen = totalLen / 4;
        const segments = segmentColors.map((color, i) => {
            const dashOffset = i * segmentLen;
            return `<path d="${track}"
                fill="none" stroke="${color}" stroke-width="10"
                stroke-linecap="butt"
                stroke-dasharray="${segmentLen * 0.96} ${totalLen}"
                stroke-dashoffset="-${dashOffset}"
                pathLength="${totalLen.toFixed(2)}"/>`;
        }).join('');

        return `
<svg viewBox="0 0 ${W} ${H}" class="sf-hccm-gauge-svg" aria-hidden="true">

  <!-- Track رمادي -->
  <path d="${track}"
    fill="none" stroke="#e8edf0" stroke-width="10"
    stroke-linecap="round"/>

  <!-- قطاعات ملونة -->
  ${segments}

  <!-- علامات التدريج -->
  ${ticks}

  <!-- ظل العقرب -->
  <line x1="${cx}" y1="${cy}"
        x2="${(nx + 0.6).toFixed(1)}" y2="${(ny + 0.6).toFixed(1)}"
        stroke="rgba(0,0,0,0.13)" stroke-width="3.2"
        stroke-linecap="round"/>

  <!-- العقرب -->
  <line x1="${cx}" y1="${cy}"
        x2="${nx.toFixed(1)}" y2="${ny.toFixed(1)}"
        stroke="#1e293b" stroke-width="2.4"
        stroke-linecap="round"/>

  <!-- مركز العقرب - الطبقات -->
  <circle cx="${cx}" cy="${cy}" r="6.5" fill="rgba(0,0,0,0.1)"/>
  <circle cx="${cx}" cy="${cy}" r="6" fill="#1e293b"/>
  <circle cx="${cx}" cy="${cy}" r="3.5" fill="#f8fafc"/>
  <circle cx="${cx}" cy="${cy}" r="1.5" fill="#1e293b"/>

  <!-- النسبة -->
  <text x="${cx}" y="${cy + 15}"
        text-anchor="middle"
        font-size="12.5" font-weight="900"
        fill="${trackColor}">${fmtPercent(p, 1)}</text>
</svg>`;
    }



    function buildMatrixOverallCell(dep, metricMap, opts, depIndex) {
        const depTone = toneStyle(dep?.tone, dep?.color, depIndex);
        const overall = calcDepartmentOverall(dep, metricMap, opts);

if (overall === null) {
    return `
<td class="sf-hccm-matrix-td is-overall-col">
    <div class="sf-hccm-overall-cell is-empty">
        <div class="sf-hccm-overall-caption">
            غير قابل للتقييم
        </div>
    </div>
</td>`;
}

const perfCls = getPerfClass(overall);

        return `
<td class="sf-hccm-matrix-td is-overall-col">
    <div class="sf-hccm-overall-cell ${perfCls}"
         style="--oc-bg:${depTone.bg};--oc-border:${depTone.border};--oc-accent:${depTone.accent}">
        ${buildGaugeSvg(overall, depTone.accent)}
        <div class="sf-hccm-overall-caption">متوسط أداء الإدارة</div>
    </div>
</td>`;
    }

    function buildMatrixDepartmentCell(dep, metricMap, opts, depIndex, depRank) {
        const depTone = toneStyle(dep?.tone, dep?.color, depIndex);
        const overall = calcDepartmentOverall(dep, metricMap, opts);
        const hasOverall = overall !== null;
const perfCls = hasOverall
    ? getPerfClass(overall)
    : 'is-empty';

        const barColor = depTone.accent;

        const chartIcon = `<svg viewBox="0 0 18 14" fill="none" xmlns="http://www.w3.org/2000/svg" width="16" height="12" style="flex-shrink:0">
    <rect x="0" y="7" width="4" height="7" rx="1.5" fill="#1a56db"/>
    <rect x="7" y="3" width="4" height="11" rx="1.5" fill="#057a55"/>
    <rect x="14" y="0" width="4" height="14" rx="1.5" fill="#d97706"/>
</svg>`;

        const detailsBtn = has(dep?.href)
            ? `<a class="sf-hccm-dep-card-btn" href="${esc(dep.href)}">${chartIcon}<span>التفاصيل</span></a>`
            : `<span class="sf-hccm-dep-card-btn is-disabled">${chartIcon}<span>التفاصيل</span></span>`;

        // عرض الميدالية للمراكز الثلاثة الأولى 
        const medalIcon = hasOverall
    ? getMedalIcon(depRank)
    : null;
        const medalHtml = medalIcon 
            ? `<div class="sf-hccm-dep-card-medal">${medalIcon}</div>`
            : `<div class="sf-hccm-dep-card-medal-placeholder"></div>`;

        return `
<td class="sf-hccm-matrix-td is-sticky-col is-department-col">
    <div class="sf-hccm-dep-card ${perfCls}" style="--dc-accent:${depTone.accent};--dc-bg:${depTone.bg};--dc-border:${depTone.border}">
        <div class="sf-hccm-dep-card-stripe"></div>
        <div class="sf-hccm-dep-card-inner">
            <div class="sf-hccm-dep-card-top">
                <div class="sf-hccm-dep-card-badge">${hasOverall ? depRank + 1 : '—'}</div>
                <div class="sf-hccm-dep-card-name">${esc(dep?.shortName || dep?.name || '')}</div>
            </div>
            <div class="sf-hccm-dep-card-track">
                ${hasOverall
    ? `<div class="sf-hccm-dep-card-fill" style="width:${overall.toFixed(1)}%;background:${barColor}"></div>`
    : ''}
            </div>
            <div class="sf-hccm-dep-card-foot">
                ${medalHtml}
                ${detailsBtn}
            </div>
        </div>
    </div>
</td>`;
    }

    function buildMatrixRow(dep, metrics, metricMap, opts, depIndex, depRank) {
        const metricCells = metrics.map((metric, i) => {
            const depMetric = findDepartmentMetric(dep, metric.key);
            return buildMatrixMetricCell(depMetric, metric, opts, i);
        }).join('');

        return `
<tr class="sf-hccm-matrix-tr">
    ${buildMatrixDepartmentCell(dep, metricMap, opts, depIndex, depRank)}
    ${metricCells}
    ${buildMatrixOverallCell(dep, metricMap, opts, depIndex)}
</tr>`;
    }

    function buildSummaryRow(summaryRow, metrics, opts) {
        if (!summaryRow) return '';

        const metricCells = metrics.map((metric, i) => {
            const sm = (summaryRow.metrics || []).find(x => String(x.metricKey || '') === String(metric.key || '')) || null;
            return buildMatrixSummaryMetricCell(sm, metric, opts, i);
        }).join('');

        const totals = (summaryRow.metrics || []).map(x => resolvePercent(x, opts));
        const overall = totals.length ? totals.reduce((a, b) => a + b, 0) / totals.length : 0;

        return `
<tr class="sf-hccm-summary-row">
    <td class="sf-hccm-matrix-td is-sticky-col is-department-col">
        <div class="sf-hccm-summary-sticky-cell">
            <div class="sf-hccm-summary-label">${esc(summaryRow.label || 'الإجمالي')}</div>
            <div class="sf-hccm-summary-sub">تجميع مؤشرات جميع الإدارات</div>
        </div>
    </td>

    ${metricCells}

    <td class="sf-hccm-matrix-td is-overall-col">
        <div class="sf-hccm-overall-cell is-summary ${getPerfClass(overall)}">
            <div class="sf-hccm-overall-percent">${esc(fmtPercent(overall, 1))}</div>
            <div class="sf-hccm-overall-progress">
                <div class="sf-hccm-overall-progress-fill" style="width:${overall.toFixed(2)}%;"></div>
            </div>
            <div class="sf-hccm-overall-caption">متوسط جميع الإدارات</div>
        </div>
    </td>
</tr>`;
    }

    // ── SVG Icons for Column Headers ──
    const COLUMN_SVG_ICONS = {
        // أيقونة الإدارة - هيكل تنظيمي
        department: `<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" style="width:14px;height:14px;margin-inline-start:6px;display:inline-block;vertical-align:middle">
            <rect x="9" y="2" width="6" height="5" rx="1.5" fill="#c9a227"/>
            <rect x="2" y="14" width="6" height="5" rx="1.5" fill="#2563eb"/>
            <rect x="9" y="14" width="6" height="5" rx="1.5" fill="#0f766e"/>
            <rect x="16" y="14" width="6" height="5" rx="1.5" fill="#7c3aed"/>
            <line x1="12" y1="7" x2="12" y2="11" stroke="#64748b" stroke-width="1.5"/>
            <line x1="5" y1="11" x2="19" y2="11" stroke="#64748b" stroke-width="1.5"/>
            <line x1="5" y1="11" x2="5" y2="14" stroke="#64748b" stroke-width="1.5"/>
            <line x1="12" y1="11" x2="12" y2="14" stroke="#64748b" stroke-width="1.5"/>
            <line x1="19" y1="11" x2="19" y2="14" stroke="#64748b" stroke-width="1.5"/>
        </svg>`,

        // أيقونة جاهزية السكن والأصول - مباني
        // الكارد الأول: منزل
housing: `<svg viewBox="0 0 24 24" fill="none"
    xmlns="http://www.w3.org/2000/svg"
    style="width:14px;height:14px;margin-inline-start:6px;display:inline-block;vertical-align:middle">
    <path d="M3 11.5L12 4L21 11.5"
          stroke="#2563eb"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"/>
    <path d="M5 10.5V20H19V10.5"
          fill="#0f766e"/>
    <rect x="9.5" y="14" width="5" height="6"
          rx="1"
          fill="#c9a227"/>
    <rect x="7" y="12.5" width="3" height="3"
          rx="0.5"
          fill="#93c5fd"/>
    <rect x="14" y="12.5" width="3" height="3"
          rx="0.5"
          fill="#6ee7b7"/>
</svg>`,

// الكارد الثاني: مستفيدون
occupancy: `<svg viewBox="0 0 24 24" fill="none"
    xmlns="http://www.w3.org/2000/svg"
    style="width:14px;height:14px;margin-inline-start:6px;display:inline-block;vertical-align:middle">
    <circle cx="9" cy="7" r="3"
            fill="#2563eb"/>
    <circle cx="16.5" cy="8" r="2.5"
            fill="#0f766e"/>
    <path d="M3.5 20C3.5 16.7 5.9 14 9 14C12.1 14 14.5 16.7 14.5 20"
          fill="#2563eb"/>
    <path d="M13 20C13 17.5 14.8 15.5 17 15.5C19.2 15.5 21 17.5 21 20"
          fill="#0f766e"/>
    <circle cx="18.5" cy="5" r="2"
            fill="#c9a227"/>
</svg>`,

// الكارد الثالث: أموال
// أيقونة المالية - رمز الريال السعودي
finance: `<svg viewBox="0 0 24 24"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
    style="width:14px;height:14px;margin-inline-start:6px;display:inline-block;vertical-align:middle">

    <path
        d="
        M16.94 1.25
        L14.11 3.38
        L14.11 11.07
        L11.36 11.61
        L11.29 0
        L8.48 2.10
        L8.46 12.15
        L2.15 13.36
        L1.32 16.08
        L8.45 14.74
        L8.46 17.98
        L0.81 19.44
        L0 22.18
        L9.10 20.19
        L11.21 17.48
        L11.37 14.18
        L14.11 13.68
        L14.12 18.83
        L23.17 17.11
        L23.99 14.37
        L16.94 15.70
        L16.94 13.14
        L23.17 11.94
        L23.99 9.33
        L16.94 10.54
        Z"
        fill="currentColor"/>

    <path
        d="
        M23.99 19.54
        L14.93 21.26
        L14.40 22.58
        L14.11 23.99
        L23.16 22.28
        L23.71 20.95
        Z"
        fill="currentColor"/>

</svg>`,

        // أيقونة الإشغال وقوائم الانتظار - أشخاص
        occupancy: `<svg viewBox="0 0 24 24" fill="none"
    xmlns="http://www.w3.org/2000/svg"
    style="width:14px;height:14px;margin-inline-start:6px;display:inline-block;vertical-align:middle">
    <circle cx="9" cy="7" r="3"
            fill="#2563eb"/>
    <circle cx="16.5" cy="8" r="2.5"
            fill="#0f766e"/>
    <path d="M3.5 20C3.5 16.7 5.9 14 9 14C12.1 14 14.5 16.7 14.5 20"
          fill="#2563eb"/>
    <path d="M13 20C13 17.5 14.8 15.5 17 15.5C19.2 15.5 21 17.5 21 20"
          fill="#0f766e"/>
    <circle cx="18.5" cy="5" r="2"
            fill="#c9a227"/>
</svg>`,

        // أيقونة الطلبات وSLA - مستند مع ساعة
        requests: `<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" style="width:14px;height:14px;margin-inline-start:6px;display:inline-block;vertical-align:middle">
            <rect x="4" y="3" width="16" height="18" rx="2" fill="#2563eb"/>
            <rect x="6" y="6" width="8" height="2" rx="1" fill="#fff"/>
            <rect x="6" y="10" width="12" height="1.5" rx="0.75" fill="#93c5fd"/>
            <rect x="6" y="13" width="10" height="1.5" rx="0.75" fill="#93c5fd"/>
            <circle cx="17" cy="17" r="5" fill="#c9a227"/>
            <path d="M17 14V17.5L19 19" stroke="#fff" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>`,

        // أيقونة الماليات والاستهلاك - محفظة
//        finance: `<svg viewBox="0 0 24 24" fill="none"
//     xmlns="http://www.w3.org/2000/svg"
//     style="width:14px;height:14px;margin-inline-start:6px;display:inline-block;vertical-align:middle">
//     <rect x="3" y="5" width="18" height="14"
//           rx="2"
//           fill="#0f766e"/>
//     <rect x="5" y="8" width="14" height="8"
//           rx="1"
//           fill="#ecfdf5"/>
//     <circle cx="12" cy="12" r="3"
//             fill="#c9a227"/>
//     <path d="M12 10V14"
//           stroke="#ffffff"
//           stroke-width="1.5"
//           stroke-linecap="round"/>
//     <path d="M10.5 11H13"
//           stroke="#ffffff"
//           stroke-width="1.2"
//           stroke-linecap="round"/>
//     <path d="M11 14H13.5"
//           stroke="#ffffff"
//           stroke-width="1.2"
//           stroke-linecap="round"/>
//     <rect x="5" y="10.5" width="2" height="3"
//           rx="0.5"
//           fill="#2563eb"/>
//     <rect x="17" y="10.5" width="2" height="3"
//           rx="0.5"
//           fill="#2563eb"/>
// </svg>`,

        // أيقونة الصيانة والجودة - مفتاح ربط مع علامة صح
        maintenance: `<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" style="width:14px;height:14px;margin-inline-start:6px;display:inline-block;vertical-align:middle">
            <path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z" fill="#dc2626" stroke="#991b1b" stroke-width="1"/>
            <circle cx="17" cy="17" r="5" fill="#c9a227"/>
            <path d="M15 17l1.5 1.5L19 15.5" stroke="#fff" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>`,

        // أيقونة الإجمالي - دائرة مقسمة (الأصلية)
        total: `<svg viewBox="0 0 16 16" width="14" height="14" style="margin-inline-start:6px;display:inline-block;vertical-align:middle">
            <path d="M8 0a8 8 0 1 0 0 16A8 8 0 0 0 8 0z" fill="#e5e7eb"/>
            <path d="M8 0v8h8a8 8 0 0 0-8-8z" fill="#1a56db"/>
            <path d="M8 8v8a8 8 0 0 0 8-8H8z" fill="#057a55"/>
            <path d="M8 8H0a8 8 0 0 0 8 8V8z" fill="#d97706"/>
        </svg>`,

        // أيقونة افتراضية - رسم بياني
        default: `<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" style="width:14px;height:14px;margin-inline-start:6px;display:inline-block;vertical-align:middle">
            <rect x="3" y="14" width="4" height="7" rx="1" fill="#2563eb"/>
            <rect x="10" y="10" width="4" height="11" rx="1" fill="#0f766e"/>
            <rect x="17" y="6" width="4" height="15" rx="1" fill="#c9a227"/>
        </svg>`,

        // أيقونة النسبة المئوية - دائرة تقدم مع علامة %
        percent: `<svg viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg" style="width:13px;height:13px;display:inline-block;vertical-align:middle">
            <circle cx="10" cy="10" r="8" stroke="#cbd5e1" stroke-width="2" fill="none"/>
            <path d="M10 2a8 8 0 0 1 6.93 12" stroke="#2563eb" stroke-width="2" stroke-linecap="round" fill="none"/>
            <circle cx="6.5" cy="7" r="1.8" fill="#0f766e"/>
            <circle cx="13.5" cy="13" r="1.8" fill="#c9a227"/>
            <line x1="14" y1="6" x2="6" y2="14" stroke="#64748b" stroke-width="1.5" stroke-linecap="round"/>
        </svg>`
    };

    // ── أيقونات الميداليات للمراكز الأولى ──
    const MEDAL_ICONS = {
        // ميدالية ذهبية - المركز الأول
        gold: `<svg viewBox="0 0 32 40" fill="none" xmlns="http://www.w3.org/2000/svg" class="sf-hccm-medal-svg">
            <path d="M10 0h12l2 8H8l2-8z" fill="#dc2626"/>
            <path d="M12 0h8l1.5 8h-11L12 0z" fill="#ef4444"/>
            <circle cx="16" cy="24" r="14" fill="#fbbf24"/>
            <circle cx="16" cy="24" r="11" fill="#f59e0b"/>
            <circle cx="16" cy="24" r="8" fill="#fbbf24"/>
            <text x="16" y="28" text-anchor="middle" font-size="10" font-weight="900" fill="#92400e">1</text>
            <ellipse cx="12" cy="18" rx="2" ry="1" fill="#fef3c7" opacity="0.6"/>
        </svg>`,

        // ميدالية فضية - المركز الثاني
        silver: `<svg viewBox="0 0 32 40" fill="none" xmlns="http://www.w3.org/2000/svg" class="sf-hccm-medal-svg">
            <path d="M10 0h12l2 8H8l2-8z" fill="#2563eb"/>
            <path d="M12 0h8l1.5 8h-11L12 0z" fill="#3b82f6"/>
            <circle cx="16" cy="24" r="14" fill="#d1d5db"/>
            <circle cx="16" cy="24" r="11" fill="#9ca3af"/>
            <circle cx="16" cy="24" r="8" fill="#d1d5db"/>
            <text x="16" y="28" text-anchor="middle" font-size="10" font-weight="900" fill="#4b5563">2</text>
            <ellipse cx="12" cy="18" rx="2" ry="1" fill="#fff" opacity="0.6"/>
        </svg>`,

        // ميدالية برونزية - المركز الثالث
        bronze: `<svg viewBox="0 0 32 40" fill="none" xmlns="http://www.w3.org/2000/svg" class="sf-hccm-medal-svg">
            <path d="M10 0h12l2 8H8l2-8z" fill="#0f766e"/>
            <path d="M12 0h8l1.5 8h-11L12 0z" fill="#14b8a6"/>
            <circle cx="16" cy="24" r="14" fill="#d97706"/>
            <circle cx="16" cy="24" r="11" fill="#b45309"/>
            <circle cx="16" cy="24" r="8" fill="#d97706"/>
            <text x="16" y="28" text-anchor="middle" font-size="10" font-weight="900" fill="#78350f">3</text>
            <ellipse cx="12" cy="18" rx="2" ry="1" fill="#fef3c7" opacity="0.5"/>
        </svg>`
    };

    // دالة للحصول على ميدالية حسب الترتيب
    function getMedalIcon(rank) {
        if (rank === 0) return MEDAL_ICONS.gold;
        if (rank === 1) return MEDAL_ICONS.silver;
        if (rank === 2) return MEDAL_ICONS.bronze;
        return null;
    }

    // دالة للحصول على أيقونة SVG بناءً على مفتاح المعيار
    function getMetricSvgIcon(metricKey) {
    const key = String(metricKey || '').toLowerCase();

    if (key === 'm_housing_readiness') {
        return COLUMN_SVG_ICONS.housing;
    }

    if (key === 'm_allocation_balance') {
        return COLUMN_SVG_ICONS.occupancy;
    }

    if (key === 'm_housing_procedures') {
    return COLUMN_SVG_ICONS.requests;
    }

    if (key === 'm_finance_utilities') {
        return COLUMN_SVG_ICONS.finance;
    }

    if (key === 'm_maintenance_quality') {
        return COLUMN_SVG_ICONS.maintenance;
    }

    return COLUMN_SVG_ICONS.default;
}

    
    function formatSubtitleWithIcon(text) {
        const trimmed = String(text || '').trim();
        if (trimmed === '%' || trimmed === '٪' || trimmed.toLowerCase() === 'percent' || trimmed === 'نسبة') {
            return COLUMN_SVG_ICONS.percent;
        }
        return esc(trimmed);
    }

   function buildDynamicHead(metrics) {

    return `
<tr>

    <th class="is-sticky-col is-department-col">

        <div class="sf-hccm-th-main">
            ${COLUMN_SVG_ICONS.department}
            الإدارة
        </div>

        <div class="sf-hccm-th-sub">
            اسم الإدارة
        </div>

    </th>


    ${metrics.map((metric, i) => {

        const s =
            toneStyle(
                metric.tone,
                metric.color,
                i);

        const svgIcon =
            getMetricSvgIcon(
                metric.key,
                i);

        const formulaText =
            String(
                metric.formulaText || ''
            ).trim();


        const formulaHelp =
    formulaText
        ? `
            <span class="sf-hccm-th-help"
                  tabindex="0"
                  role="button"
                  aria-label="طريقة احتساب المؤشر"
                  data-tooltip-title="طريقة احتساب المؤشر"
                  data-tooltip-text="${esc(formulaText)}">

                <i class="fa-solid fa-circle-info"></i>

            </span>`
        : '';


        return `
        <th>

            <div class="sf-hccm-th-main"
                 style="color:${s.accent}">

                ${svgIcon}

                ${esc(
                    metric.shortTitle ||
                    metric.title ||
                    ''
                )}

                ${formulaHelp}

            </div>

        </th>`;

    }).join('')}


    <th class="is-summary-col">

        <div class="sf-hccm-th-main">

            ${COLUMN_SVG_ICONS.total}

            الإجمالي

            <span class="sf-hccm-th-help"
      tabindex="0"
      role="button"
      aria-label="طريقة احتساب متوسط أداء الإدارة"
      data-tooltip-title="طريقة احتساب متوسط أداء الإدارة"
      data-tooltip-text="يتم احتساب أداء الإدارة من متوسط نسب المؤشرات المتاحة لها.">

    <i class="fa-solid fa-circle-info"></i>

</span>

        </div>

    </th>

</tr>`;
}

    /* =========================================================
       Main render
    ========================================================= */
    function renderHousingCommandCenter(hostId, cfgId) {
        const host = $(hostId);
        if (!host) return;

        const cfg = parseCfg(cfgId);
        if (!cfg) return;

        const opts = {
            titleText: cfg?.boardOptions?.titleText || cfg?.title || '',
            subtitleText: cfg?.boardOptions?.subtitleText || cfg?.subtitle || '',
            showHeader: cfg?.boardOptions?.showHeader !== false,
            showSummaryRow: cfg?.boardOptions?.showSummaryRow !== false,
            showDepartmentRanking: cfg?.boardOptions?.showDepartmentRanking === true,
            showMetricProgressBar: cfg?.boardOptions?.showMetricProgressBar !== false,
            showMetricTargetActual: cfg?.boardOptions?.showMetricTargetActual !== false,
            autoCalculatePercentages: cfg?.boardOptions?.autoCalculatePercentages !== false,
            preferredCardsPerRow: Math.max(1, num(cfg?.boardOptions?.preferredCardsPerRow, 5))
        };

        const metrics = sortByOrder(cfg.metrics || []);
        const departments = sortByOrder(cfg.departments || []);
        const metricMap = getMetricMap(metrics);

        const titleEl = host.querySelector('[data-hccm-title]');
        const subtitleEl = host.querySelector('[data-hccm-subtitle]');
        const metricsBox = host.querySelector('[data-hccm-metrics]');
        const matrixHead = host.querySelector('[data-hccm-matrix-head]');
        const matrixBody = host.querySelector('[data-hccm-matrix-body]');
        const summaryTbody = host.querySelector('[data-hccm-summary-row]');
        const header = host.querySelector('[data-hccm-header]');

        if (!metricsBox || !matrixBody || !matrixHead) return;

        const metricColumns =
    Math.max(
        1,
        Math.min(
            metrics.length,
            opts.preferredCardsPerRow
        )
    );

host.style.setProperty(
    '--hccm-metric-cols',
    String(metricColumns)
);

        // host.style.setProperty('--hccm-metric-cols', String(opts.preferredCardsPerRow));

        if (titleEl) titleEl.textContent = opts.titleText || '';
        if (subtitleEl) subtitleEl.textContent = opts.subtitleText || '';
        if (header) header.hidden = !opts.showHeader;

        if (!metrics.length) {
            metricsBox.innerHTML = `<div class="sf-hccm-empty">لا توجد معايير معرفة</div>`;
            matrixHead.innerHTML = '';
            matrixBody.innerHTML = `
<tr>
    <td colspan="2">
        <div class="sf-hccm-empty">لا توجد معايير معرفة</div>
    </td>
</tr>`;
            if (summaryTbody) {
                summaryTbody.innerHTML = '';
                summaryTbody.hidden = true;
            }
            return;
        }

        // احسب الأعلى والأدنى لمؤشرات الأداء فقط
// الأعلى والأدنى للمؤشرات القابلة للتقييم فقط
metrics.forEach(metric => {

    metric.__best = null;
    metric.__worst = null;

    // قوائم الانتظار ليست مؤشر كفاءة حاليًا
    if (metric.key === 'm_waiting_list') {
        return;
    }

    const vals = departments
        .map(dep => {

            const dm = findDepartmentMetric(
                dep,
                metric.key
            );

            if (!hasExplicitPercent(dm)) {
                return null;
            }

            return {
                name: dep.shortName || dep.name || '',
                percent: clamp(
                    Number(dm.completionPercent),
                    0,
                    100
                )
            };
        })
        .filter(x => x !== null)
        .sort((a, b) => b.percent - a.percent);

    if (vals.length > 0) {
        metric.__best = vals[0];
    }

    if (vals.length > 1) {
        metric.__worst = vals[vals.length - 1];
    }
});

        metricsBox.innerHTML = metrics.map((metric, i) => buildMetricCard(metric, opts, i)).join('');
        matrixHead.innerHTML = buildDynamicHead(metrics);

        if (!departments.length) {
            matrixBody.innerHTML = `
<tr>
    <td colspan="${metrics.length + 2}">
        <div class="sf-hccm-empty">لا توجد إدارات معرفة</div>
    </td>
</tr>`;
        } else {
            // ترتيب الإدارات من الأعلى نسبة للأقل
            const sortedDepartments = [...departments].map((dep, originalIndex) => ({
                dep,
                originalIndex,
                overall: calcDepartmentOverall(dep, metricMap, opts)
            })).sort((a, b) => {

    if (a.overall === null) {
        return b.overall === null ? 0 : 1;
    }

    if (b.overall === null) {
        return -1;
    }

    return b.overall - a.overall;
});

            matrixBody.innerHTML = sortedDepartments
                .map((item, rank) => buildMatrixRow(item.dep, metrics, metricMap, opts, item.originalIndex, rank))
                .join('');
        }

        if (summaryTbody) {
            if (opts.showSummaryRow && cfg.summaryRow) {
                summaryTbody.innerHTML = buildSummaryRow(cfg.summaryRow, metrics, opts);
                summaryTbody.hidden = false;
            } else {
                summaryTbody.innerHTML = '';
                summaryTbody.hidden = true;
            }
        }
    }

  

//==========================================================
// Header tooltip
//==========================================================



//==========================================================
// Header formula tooltip
// Tooltip واحد مستقل خارج الجدول
//==========================================================

function getHeaderTooltip() {

    let tooltip =
        document.getElementById(
            'sf-hccm-header-tooltip-global'
        );


    if (tooltip)
        return tooltip;


    tooltip =
        document.createElement('div');


    tooltip.id =
        'sf-hccm-header-tooltip-global';


    tooltip.className =
        'sf-hccm-header-tooltip-global';


    tooltip.innerHTML = `
        <div class="sf-hccm-tooltip-title"></div>

        <div class="sf-hccm-tooltip-body">

            <div class="sf-hccm-tooltip-row">

                <div class="sf-hccm-tooltip-dot"></div>

                <span class="sf-hccm-header-tooltip-text"></span>

            </div>

        </div>
    `;


    document.body.appendChild(
        tooltip
    );


    return tooltip;
}


function showHeaderTooltip(trigger) {

    if (!trigger)
        return;


    const text =
        trigger.dataset.tooltipText || '';


    if (!text)
        return;


    const title =
        trigger.dataset.tooltipTitle ||
        'طريقة احتساب المؤشر';


    const tooltip =
        getHeaderTooltip();


    const titleElement =
        tooltip.querySelector(
            '.sf-hccm-tooltip-title'
        );


    const textElement =
        tooltip.querySelector(
            '.sf-hccm-header-tooltip-text'
        );


    if (titleElement) {
        titleElement.textContent =
            title;
    }


    if (textElement) {
        textElement.textContent =
            text;
    }


    //------------------------------------------------------
    // إظهار مؤقت حتى نستطيع قياس الحجم الحقيقي
    //------------------------------------------------------
    tooltip.classList.add(
        'is-visible'
    );


    const triggerRect =
        trigger.getBoundingClientRect();


    const tooltipRect =
        tooltip.getBoundingClientRect();


    const margin = 12;
    const gap = 9;


    //------------------------------------------------------
    // المنتصف الحقيقي لنفس أيقونة المعلومات
    //------------------------------------------------------
    let left =
        triggerRect.left +
        (triggerRect.width / 2) -
        (tooltipRect.width / 2);


    let top =
        triggerRect.bottom +
        gap;


    //------------------------------------------------------
    // منع الخروج من يسار الشاشة
    //------------------------------------------------------
    if (left < margin) {
        left = margin;
    }


    //------------------------------------------------------
    // منع الخروج من يمين الشاشة
    //------------------------------------------------------
    if (
        left +
        tooltipRect.width >
        window.innerWidth -
        margin
    ) {
        left =
            window.innerWidth -
            tooltipRect.width -
            margin;
    }


    //------------------------------------------------------
    // إذا لم توجد مساحة أسفل الأيقونة
    // يظهر فوقها
    //------------------------------------------------------
    if (
        top +
        tooltipRect.height >
        window.innerHeight -
        margin
    ) {
        top =
            triggerRect.top -
            tooltipRect.height -
            gap;
    }


    if (top < margin) {
        top = margin;
    }


    tooltip.style.left =
        Math.round(left) +
        'px';


    tooltip.style.top =
        Math.round(top) +
        'px';
}


function hideHeaderTooltip() {

    const tooltip =
        document.getElementById(
            'sf-hccm-header-tooltip-global'
        );


    if (!tooltip)
        return;


    tooltip.classList.remove(
        'is-visible'
    );
}


//----------------------------------------------------------
// Mouse
//----------------------------------------------------------

document.addEventListener(
    'mouseover',
    function (e) {

        const trigger =
            e.target.closest(
                '.sf-hccm-th-help'
            );


        if (!trigger)
            return;


        const previous =
            e.relatedTarget;


        if (
            previous &&
            trigger.contains(previous)
        ) {
            return;
        }


        showHeaderTooltip(
            trigger
        );
    });


document.addEventListener(
    'mouseout',
    function (e) {

        const trigger =
            e.target.closest(
                '.sf-hccm-th-help'
            );


        if (!trigger)
            return;


        const next =
            e.relatedTarget;


        if (
            next &&
            trigger.contains(next)
        ) {
            return;
        }


        hideHeaderTooltip();
    });


//----------------------------------------------------------
// Keyboard / touch focus
//----------------------------------------------------------

document.addEventListener(
    'focusin',
    function (e) {

        const trigger =
            e.target.closest(
                '.sf-hccm-th-help'
            );


        if (!trigger)
            return;


        showHeaderTooltip(
            trigger
        );
    });


document.addEventListener(
    'focusout',
    function (e) {

        if (
            !e.target.closest(
                '.sf-hccm-th-help'
            )
        ) {
            return;
        }


        hideHeaderTooltip();
    });

//==========================================================
// Existing table-cell tooltip
// يبقى يتحرك مع مؤشر الماوس
//==========================================================

document.addEventListener(
    'mousemove',
    function (e) {

        const tooltip =
            document.querySelector(
                '.sf-hccm-tcell:hover .sf-hccm-tcell-tooltip'
            );


        if (!tooltip)
            return;


        const tooltipWidth = 360;
        const margin = 12;


        let left =
            e.clientX -
            tooltipWidth -
            margin;


        let top =
            e.clientY +
            margin;


        if (left < margin) {

            left =
                e.clientX +
                margin;
        }


        if (
            left +
            tooltipWidth >
            window.innerWidth -
            margin
        ) {
            left =
                window.innerWidth -
                tooltipWidth -
                margin;
        }


        const tooltipHeight =
            tooltip.offsetHeight;


        if (
            top +
            tooltipHeight >
            window.innerHeight -
            margin
        ) {
            top =
                e.clientY -
                tooltipHeight -
                margin;
        }


        if (top < margin) {

            top = margin;
        }


        tooltip.style.left =
            left + 'px';

        tooltip.style.top =
            top + 'px';
    });

    window.SmartCharts.renderHousingCommandCenter = renderHousingCommandCenter;

    document.addEventListener('DOMContentLoaded', function () {
        document.querySelectorAll('.sf-hccm').forEach(host => {
            if (!host.id) return;
            const cfgScript = host.querySelector('script[type="application/json"]');
            if (!cfgScript || !cfgScript.id) return;
            renderHousingCommandCenter(host.id, cfgScript.id);
        });
    });
})();