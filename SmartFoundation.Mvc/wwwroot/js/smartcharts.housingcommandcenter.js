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

    const TONES = {
        info: {
            bg: '#eff6ff',
            soft: '#dbeafe',
            border: '#bfdbfe',
            text: '#1d4ed8',
            accent: '#2563eb'
        },
        success: {
            bg: '#f0fdf4',
            soft: '#dcfce7',
            border: '#bbf7d0',
            text: '#15803d',
            accent: '#16a34a'
        },
        warning: {
            bg: '#fffbeb',
            soft: '#fef3c7',
            border: '#fde68a',
            text: '#b45309',
            accent: '#d97706'
        },
        danger: {
            bg: '#fef2f2',
            soft: '#fee2e2',
            border: '#fecaca',
            text: '#b91c1c',
            accent: '#dc2626'
        },
        neutral: {
            bg: '#f8fafc',
            soft: '#f1f5f9',
            border: '#e2e8f0',
            text: '#475569',
            accent: '#64748b'
        }
    };

    const PALETTE = [
        '#0f766e',
        '#2563eb',
        '#d97706',
        '#dc2626',
        '#7c3aed',
        '#0891b2',
        '#16a34a',
        '#db2777',
        '#ea580c',
        '#4f46e5'
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

    function calcDepartmentOverall(dep, metricMap, opts) {
        if (dep?.overallCompletionPercent !== null && 
            dep?.overallCompletionPercent !== undefined && 
            dep?.overallCompletionPercent !== '' &&
            num(dep.overallCompletionPercent) > 0) {
            return clamp(num(dep.overallCompletionPercent), 0, 100);
        }

        const items = (dep?.metrics || [])
            .filter(x => has(x.metricKey) && metricMap[x.metricKey]);

        if (!items.length) return 0;

        const total = items.reduce((s, x) => s + resolvePercent(x, opts), 0);
        return clamp(total / items.length, 0, 100);
    }

    function renderPercentRing(percent, accent) {
        const p = clamp(num(percent), 0, 100);
        const r = 24;
        const c = 2 * Math.PI * r;
        const dash = (p / 100) * c;

        return `
<svg class="sf-hccm-ring-svg" viewBox="0 0 64 64" aria-hidden="true">
    <circle cx="32" cy="32" r="${r}" class="sf-hccm-ring-track"></circle>
    <circle cx="32" cy="32" r="${r}" class="sf-hccm-ring-fill" style="stroke:${accent};stroke-dasharray:${dash} ${c};"></circle>
</svg>`;
    }

    /* =========================================================
       Top metric cards
    ========================================================= */
    function buildMetricCard(metric, opts, idx) {
        const s = toneStyle(metric.tone, metric.color, idx);
        const percent = resolvePercent(metric, opts);
        const actual = metric?.actual;
        const target = metric?.target;
        const unit = metric?.unit || '';
        const displayPercent = fmtPercent(percent, 1);

        const iconHtml = has(metric?.emoji)
            ? `<span class="sf-hccm-metric-emoji">${esc(metric.emoji)}</span>`
            : has(metric?.icon)
                ? `<i class="${esc(metric.icon)}"></i>`
                : `<span class="sf-hccm-metric-emoji">📊</span>`;

        let metaHtml = '';
        if (opts.showMetricTargetActual) {
            const actualHtml = actual !== null && actual !== undefined && actual !== ''
                ? `<span class="sf-hccm-mini-chip is-actual">المنجز: <strong>${esc(fmtNumber(actual, 0))}${has(unit) ? ' ' + esc(unit) : ''}</strong></span>`
                : '';

            const targetHtml = target !== null && target !== undefined && target !== ''
                ? `<span class="sf-hccm-mini-chip is-target">المستهدف: <strong>${esc(fmtNumber(target, 0))}${has(unit) ? ' ' + esc(unit) : ''}</strong></span>`
                : '';

            metaHtml = (actualHtml || targetHtml)
                ? `<div class="sf-hccm-metric-meta">${actualHtml}${targetHtml}</div>`
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

    <div class="sf-hccm-metric-title">${esc(metric?.title || '')}</div>
    ${has(metric?.subtitle) ? `<div class="sf-hccm-metric-subtitle">${esc(metric.subtitle)}</div>` : ''}

    ${metaHtml}

    ${opts.showMetricProgressBar ? `
    <div class="sf-hccm-metric-progress">
        <div class="sf-hccm-metric-progress-fill" style="width:${percent.toFixed(2)}%;background:${s.accent};"></div>
    </div>` : ''}

    ${has(metric?.hint) ? `<div class="sf-hccm-metric-hint">${esc(metric.hint)}</div>` : ''}

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

        const s = toneStyle(depMetric.tone || metric?.tone, depMetric.color || metric?.color, idx);
        const percent = resolvePercent(depMetric, opts);
        const perfCls = getPerfClass(percent);

        const actual = depMetric?.actual;
        const target = depMetric?.target;
        const remaining = Math.max(num(target) - num(actual), 0);
        const displayText = has(depMetric.displayText) ? depMetric.displayText : fmtPercent(percent, 1);
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
    <div class="sf-hccm-tcell-stat-line is-actual-target">
        <span class="sf-hccm-tcell-stat-label">
            <span class="is-actual">منجز</span>
            <span class="slash"> / </span>
            <span class="is-target">مستهدف</span>
        </span>
        <strong>
            <span class="is-actual">${esc(fmtNumber(actual, 0))}</span>
            <span class="slash"> / </span>
            <span class="is-target">${esc(fmtNumber(target, 0))}</span>
        </strong>
    </div>
    <div class="sf-hccm-tcell-stat-line is-remaining">
        <span class="sf-hccm-tcell-stat-label">المتبقي</span>
        <strong>${esc(fmtNumber(remaining, 0))}</strong>
    </div>
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
        const remaining = Math.max(num(target) - num(actual), 0);
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
                <span class="sf-hccm-sum-stat-label">منجز</span>
                <strong class="is-actual">${esc(fmtNumber(actual, 0))}</strong>
            </div>
            <div class="sf-hccm-sum-stat">
                <span class="sf-hccm-sum-stat-label">مستهدف</span>
                <strong class="is-target">${esc(fmtNumber(target, 0))}</strong>
            </div>
            <div class="sf-hccm-sum-stat">
                <span class="sf-hccm-sum-stat-label">متبقي</span>
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
        const trackColor = p >= 85 ? '#15803d' : p >= 70 ? '#d97706' : '#dc2626';
        const W = 120, H = 88;
        const cx = W / 2, cy = 62;
        const r = 46;
        const totalLen = Math.PI * r;
        const filled = (p / 100) * totalLen;
        const track = `M ${cx - r},${cy} a ${r},${r} 0 0,1 ${r * 2},0`;
        const gid = `hg${Math.round(p * 10)}`;

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

        return `
<svg viewBox="0 0 ${W} ${H}" class="sf-hccm-gauge-svg" aria-hidden="true">
  <defs>
    <linearGradient id="${gid}" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%"   stop-color="#dc2626"/>
      <stop offset="38%"  stop-color="#f59e0b"/>
      <stop offset="68%"  stop-color="#84cc16"/>
      <stop offset="100%" stop-color="#16a34a"/>
    </linearGradient>
  </defs>

  <!-- Track رمادي -->
  <path d="${track}"
    fill="none" stroke="#e8edf0" stroke-width="10"
    stroke-linecap="round"/>

  <!-- Fill ملون بتدرج -->
  <path d="${track}"
    fill="none" stroke="url(#${gid})" stroke-width="10"
    stroke-linecap="round"
    stroke-dasharray="${filled.toFixed(2)} ${totalLen.toFixed(2)}"
    pathLength="${totalLen.toFixed(2)}"/>

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

    function buildMatrixDepartmentCell(dep, metricMap, opts, depIndex) {
        const depTone = toneStyle(dep?.tone, dep?.color, depIndex);
        const overall = calcDepartmentOverall(dep, metricMap, opts);

        const iconHtml = has(dep?.emoji)
            ? `<span class="sf-hccm-dep-chip-emoji">${esc(dep.emoji)}</span>`
            : has(dep?.icon)
                ? `<i class="${esc(dep.icon)}"></i>`
                : `<span class="sf-hccm-dep-chip-emoji">🏢</span>`;

        return `
<td class="sf-hccm-matrix-td is-sticky-col is-department-col">
    <div class="sf-hccm-dep-cell"
         style="--dc-bg:${depTone.bg};--dc-soft:${depTone.soft};--dc-border:${depTone.border};--dc-text:${depTone.text};--dc-accent:${depTone.accent}">
        <div class="sf-hccm-dep-cell-top">
            <div class="sf-hccm-dep-chip">${iconHtml}</div>
            <div class="sf-hccm-dep-cell-copy">
                <div class="sf-hccm-dep-cell-name">${esc(dep?.name || '')}</div>
                ${has(dep?.hint) ? `<div class="sf-hccm-dep-cell-hint">${esc(dep.hint)}</div>` : ''}
            </div>
        </div>

        <div class="sf-hccm-dep-cell-foot">
            <span class="sf-hccm-dep-cell-foot-label">الإجمالي: ${esc(fmtPercent(overall, 1))}</span>
            ${has(dep?.href)
                ? `<a class="sf-hccm-dep-details-btn" href="${esc(dep.href)}">
                       <i class="fa-solid fa-chart-column"></i> التفاصيل
                   </a>`
                : `<span class="sf-hccm-dep-details-btn is-disabled">لا يوجد رابط</span>`
            }
        </div>
    </div>
</td>`;
    }

    function buildMatrixRow(dep, metrics, metricMap, opts, depIndex) {
        const metricCells = metrics.map((metric, i) => {
            const depMetric = findDepartmentMetric(dep, metric.key);
            return buildMatrixMetricCell(depMetric, metric, opts, i);
        }).join('');

        return `
<tr class="sf-hccm-matrix-tr">
    ${buildMatrixDepartmentCell(dep, metricMap, opts, depIndex)}
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

    function buildDynamicHead(metrics) {
        return `
<tr>
    <th class="is-sticky-col is-department-col">
        <div class="sf-hccm-th-main">الإدارة</div>
        <div class="sf-hccm-th-sub">اسم الإدارة والإجمالي العام</div>
    </th>
    ${metrics.map(metric => `
        <th>
            <div class="sf-hccm-th-main">${esc(metric.shortTitle || metric.title || '')}</div>
            <div class="sf-hccm-th-sub">${esc(metric.unit || metric.subtitle || '')}</div>
        </th>
    `).join('')}
    <th class="is-summary-col">
        <div class="sf-hccm-th-main">الإجمالي</div>
        <div class="sf-hccm-th-sub">متوسط أداء الإدارة</div>
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

        host.style.setProperty('--hccm-metric-cols', String(opts.preferredCardsPerRow));

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

                    // احسب الأعلى والأدنى لكل معيار
                    metrics.forEach(metric => {
                        const vals = departments
                            .map(dep => {
                                const dm = findDepartmentMetric(dep, metric.key);
                                if (!dm) return null;
                                return {
                                    name: dep.shortName || dep.name || '',
                                    percent: resolvePercent(dm, opts)
                                };
                            })
                            .filter(x => x !== null);

                        if (vals.length) {
                            vals.sort((a, b) => b.percent - a.percent);
                            metric.__best = vals[0];
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
            matrixBody.innerHTML = departments
                .map((dep, i) => buildMatrixRow(dep, metrics, metricMap, opts, i))
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

    // Tooltip follow mouse
    document.addEventListener('mousemove', function(e) {
        const tooltip = document.querySelector('.sf-hccm-tcell:hover .sf-hccm-tcell-tooltip');
        if (!tooltip) return;

        const tw = 360;
        const margin = 12;
        let left = e.clientX - tw - margin;
        let top = e.clientY - margin;

        
        if (left < margin) left = e.clientX + margin;

        // لو خرج من الأسفل
        if (top + tooltip.offsetHeight > window.innerHeight - margin) {
            top = window.innerHeight - tooltip.offsetHeight - margin;
        }

        tooltip.style.left = left + 'px';
        tooltip.style.top = top + 'px';
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