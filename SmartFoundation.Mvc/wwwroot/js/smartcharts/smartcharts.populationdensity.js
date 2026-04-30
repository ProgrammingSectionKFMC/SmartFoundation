(function () {
    'use strict';

    window.SmartCharts = window.SmartCharts || {};

    function $(root, sel) { return root ? root.querySelector(sel) : null; }

    function parseCfg(cfgId) {
        var el = document.getElementById(cfgId);
        if (!el) return null;
        try { return JSON.parse(el.textContent || '{}'); }
        catch { return null; }
    }

    function num(v, fb) {
        var n = Number(v);
        return Number.isFinite(n) ? n : (fb || 0);
    }

    function pct(part, total) {
        if (!total || total <= 0) return 0;
        return (part / total) * 100;
    }

    function fmt(v, digits) {
        return num(v, 0).toLocaleString('en-US', {
            minimumFractionDigits: digits || 0,
            maximumFractionDigits: digits || 0
        });
    }

    function shortLabel(text, max) {
        if (!text) return '';
        if (text.length <= max) return text;
        return text.substring(0, Math.max(1, max - 1)) + '…';
    }

    function mkChart(canvas, cfg) {
        if (!canvas || typeof Chart === 'undefined') return;
        cfg.options = cfg.options || {};
        cfg.options.responsive = true;
        cfg.options.maintainAspectRatio = false;
        new Chart(canvas, cfg);
    }

    function setBarCanvasHeight(canvas, rowsCount) {
        if (!canvas) return;
        var h = Math.max(265, num(rowsCount, 0) * 22);
        canvas.style.height = h + 'px';
    }

    function hbar(labels, data, colors) {
        return {
            type: 'bar',
            plugins: (typeof ChartDataLabels !== 'undefined') ? [ChartDataLabels] : [],
            data: {
                labels: labels,
                datasets: [{
                    data: data,
                    backgroundColor: colors,
                    borderRadius: 5,
                    borderSkipped: false,
                    barThickness: 13,
                    maxBarThickness: 17
                }]
            },
            options: {
                indexAxis: 'y',
                plugins: {
                    legend: { display: false },
                    datalabels: (typeof ChartDataLabels === 'undefined') ? { display: false } : {
                        display: function (ctx) {
                            return num(ctx.raw, 0) >= 20;
                        },
                        anchor: 'end',
                        align: 'right',
                        offset: 6,
                        color: '#1f2937',
                        backgroundColor: 'rgba(255,255,255,0.96)',
                        borderColor: 'rgba(148,163,184,0.45)',
                        borderWidth: 1,
                        borderRadius: 4,
                        font: { size: 10, weight: '700', lineHeight: 1 },
                        padding: { top: 2, bottom: 2, left: 4, right: 4 },
                        textAlign: 'center',
                        clamp: true,
                        clip: false,
                        formatter: function (v) { return Number(v).toLocaleString('en-US'); }
                    }
                },
                scales: {
                    x: {
                        beginAtZero: true,
                        grace: '10%',
                        grid: { color: 'rgba(0,0,0,.04)', drawBorder: false },
                        ticks: { font: { size: 10, weight: '500' } }
                    },
                    y: {
                        grid: { display: false },
                        ticks: {
                            font: { size: 11, weight: '500' },
                            color: '#1f2937',
                            autoSkip: false,
                            mirror: false,
                            padding: 8
                        }
                    }
                }
            }
        };
    }

    function donut(labels, values, colors) {
        var total = values.reduce(function (a, b) { return a + b; }, 0);
        return {
            type: 'doughnut',
            plugins: (typeof ChartDataLabels !== 'undefined') ? [ChartDataLabels] : [],
            data: {
                labels: labels,
                datasets: [{
                    data: values,
                    backgroundColor: colors,
                    borderColor: '#ffffff',
                    borderWidth: 2
                }]
            },
            options: {
                cutout: '66%',
                plugins: {
                    legend: {
                        position: 'bottom',
                        labels: {
                            usePointStyle: true,
                            pointStyle: 'circle',
                            boxWidth: 8,
                            boxHeight: 8,
                            padding: 10,
                            font: { size: 11, weight: '700' },
                            color: '#334155'
                        }
                    },
                    datalabels: { display: false }
                }
            }
        };
    }

    function buildStats(rows, opts) {
        opts = opts || {};

        var rawTotalPopulation = rows.reduce(function (s, x) { return s + num(x.population); }, 0);
        var totalHousing = rows.reduce(function (s, x) { return s + num(x.housingUnits); }, 0);
        var rawTotalMale = rows.reduce(function (s, x) { return s + num(x.malePopulation); }, 0);
        var rawTotalFemale = rows.reduce(function (s, x) { return s + num(x.femalePopulation); }, 0);

        var totalPopulation = num(opts.totalPopulationOverride, 0) > 0 ? num(opts.totalPopulationOverride, 0) : rawTotalPopulation;
        var totalMale = num(opts.totalMaleOverride, 0) > 0 ? num(opts.totalMaleOverride, 0) : rawTotalMale;
        var totalFemale = num(opts.totalFemaleOverride, 0) > 0 ? num(opts.totalFemaleOverride, 0) : rawTotalFemale;
        var avgDensity = totalHousing > 0 ? totalPopulation / totalHousing : 0;

        var withDensity = rows.map(function (x) {
            return {
                name: x.name,
                population: num(x.population),
                housingUnits: num(x.housingUnits),
                density: num(x.housingUnits) > 0 ? num(x.population) / num(x.housingUnits) : 0
            };
        });

        var maxDensity = withDensity.slice().sort(function (a, b) { return b.density - a.density; })[0];
        var minDensity = withDensity.slice().sort(function (a, b) { return a.density - b.density; })[0];
        var crowding = Math.min(99.9, (avgDensity / 5.75) * 100);

        return {
            totalPopulation: totalPopulation,
            totalHousing: totalHousing,
            totalMale: totalMale,
            totalFemale: totalFemale,
            avgDensity: avgDensity,
            maxDensity: maxDensity,
            minDensity: minDensity,
            crowding: crowding,
            withDensity: withDensity
        };
    }

    function normalizeDisplayName(name) {
        var v = String(name || '').trim();
        if (v === 'السكن الجديد قادة') {
            return 'السكن الجديد ضباط الصف';
        }
        return v;
    }

    function renderPopulationDensity(hostId, cfgId) {
        var host = document.getElementById(hostId);
        if (!host) return;

        var cfg = parseCfg(cfgId);
        if (!cfg) return;

        var rows = Array.isArray(cfg.neighborhoods) ? cfg.neighborhoods : [];
        var opts = cfg.boardOptions || {};

        if (typeof Chart !== 'undefined') {
            var baseFont = (window.getComputedStyle(document.body).fontFamily || '').trim();
            if (baseFont) {
                Chart.defaults.font.family = baseFont;
            }
            Chart.defaults.font.size = 12;
            Chart.defaults.plugins.legend.labels.font = { size: 11, weight: '700' };
            Chart.defaults.plugins.legend.labels.color = '#334155';
        }

        var header = $(host, '[data-pdm-header]');
        var title = $(host, '[data-pdm-title]');
        var subtitle = $(host, '[data-pdm-subtitle]');
        if (title) title.textContent = opts.titleText || cfg.title || '';
        if (subtitle) subtitle.textContent = opts.subtitleText || cfg.subtitle || '';
        if (header) header.hidden = opts.showHeader === false;

        if (!rows.length) {
            var k = $(host, '[data-pdm-kpis]');
            if (k) k.innerHTML = '<div class="sf-pdm-empty">لا توجد بيانات</div>';
            return;
        }

        var stats = buildStats(rows, opts);
        var kpisBox = $(host, '[data-pdm-kpis]');

        if (kpisBox) {
            kpisBox.innerHTML = [
                ['fa-solid fa-map-location-dot', rows.length + ' حي', 'النطاق السكني', '#0f766e'],
                ['fa-solid fa-users', fmt(stats.totalPopulation, 0), 'المؤشرات العامة: إجمالي السكان', '#2563eb'],
                ['fa-solid fa-house', fmt(stats.totalHousing, 0), 'إجمالي المساكن', '#1d4ed8'],
                ['fa-solid fa-gauge-high', fmt(stats.avgDensity, 2), 'متوسط الكثافة (فرد/مسكن)', '#0369a1'],
                ['fa-solid fa-arrow-up-right-dots', stats.maxDensity ? normalizeDisplayName(stats.maxDensity.name) : '-', 'أعلى كثافة', '#059669'],
                ['fa-solid fa-arrow-down-wide-short', stats.minDensity ? stats.minDensity.name : '-', 'أقل كثافة', '#b45309'],
                ['fa-solid fa-traffic-light', fmt(stats.crowding, 1) + '%', 'مؤشرات الازدحام السكني', '#dc2626']
            ].map(function (x) {
                return '<div class="sf-pdm-kpi" style="--kpi-accent:' + x[3] + '"><i class="' + x[0] + '"></i><div><strong>' + x[1] + '</strong><span>' + x[2] + '</span></div></div>';
            }).join('');
        }

        var summary = $(host, '[data-pdm-summary]');
        if (summary) {
            var malePct = pct(stats.totalMale, stats.totalPopulation);
            var femalePct = pct(stats.totalFemale, stats.totalPopulation);
            summary.innerHTML = [
                ['إجمالي السكان', fmt(stats.totalPopulation, 0)],
                ['إجمالي المساكن', fmt(stats.totalHousing, 0)],
                ['متوسط الكثافة', fmt(stats.avgDensity, 2)],
                ['أعلى كثافة', stats.maxDensity ? normalizeDisplayName(stats.maxDensity.name) : '-'],
                ['أقل كثافة', stats.minDensity ? stats.minDensity.name : '-'],
                ['ذكور / إناث', fmt(malePct, 1) + '% / ' + fmt(femalePct, 1) + '%']
            ].map(function (x) {
                return '<li><span>' + x[0] + '</span><b>' + x[1] + '</b></li>';
            }).join('');
        }

        var palette = ['#1e3a5f', '#2b6cb0', '#c05621', '#9b2c2c', '#553c9a', '#086f83', '#276749', '#c9a227', '#64748b', '#1f4b99'];

        var topPopulation = rows.slice().sort(function (a, b) { return num(b.population) - num(a.population); }).slice(0, Math.max(1, num(opts.topPopulationCount, 10)));
        var topHousing = rows.slice().sort(function (a, b) { return num(b.housingUnits) - num(a.housingUnits); }).slice(0, Math.max(1, num(opts.topHousingCount, 10)));

        var populationCanvas = $(host, '[data-pdm-canvas="population"]');
        setBarCanvasHeight(populationCanvas, topPopulation.length);
        mkChart(populationCanvas, hbar(
            topPopulation.map(function (x) { return x.name; }),
            topPopulation.map(function (x) { return num(x.population); }),
            palette
        ));

        var housingCanvas = $(host, '[data-pdm-canvas="housing"]');
        setBarCanvasHeight(housingCanvas, topHousing.length);
        mkChart(housingCanvas, hbar(
            topHousing.map(function (x) { return x.name; }),
            topHousing.map(function (x) { return num(x.housingUnits); }),
            palette
        ));

        var top5 = rows.slice().sort(function (a, b) { return num(b.population) - num(a.population); }).slice(0, 5);
        var top5Total = top5.reduce(function (s, x) { return s + num(x.population); }, 0);
        var other = Math.max(0, stats.totalPopulation - top5Total);
        var top5Pct = pct(top5Total, stats.totalPopulation);
        var otherPct = 100 - top5Pct;

        var shareColors = ['#1e3a5f', '#2b6cb0', '#c05621', '#276749', '#553c9a', '#94a3b8'];
        var shareCfg = donut(
            top5.map(function (x) {
                return x.name + ' ' + fmt(pct(num(x.population), stats.totalPopulation), 1) + '%';
            }).concat(['أحياء أخرى ' + fmt(otherPct, 1) + '%']),
            top5.map(function (x) { return num(x.population); }).concat([other]),
            shareColors
        );
        shareCfg.options.plugins.legend.display = false;
        mkChart($(host, '[data-pdm-canvas="share"]'), shareCfg);

        var shareCenter = $(host, '[data-pdm-center="share"]');
        if (shareCenter) {
            shareCenter.innerHTML = '<strong>' + fmt(top5Pct, 1) + '%</strong><span>حصة أعلى 5 أحياء</span>';
        }

        var shareDetails = $(host, '[data-pdm-share-details]');
        if (shareDetails) {
            shareDetails.innerHTML = '<ul class="sf-pdm-share-list">' +
                top5.map(function (x, i) {
                    return '<li class="sf-pdm-share-item">' +
                        '<span class="sf-pdm-share-name"><i class="sf-pdm-share-dot" style="background:' + shareColors[i] + '"></i>' + x.name + '</span>' +
                        '<b>' + fmt(pct(num(x.population), stats.totalPopulation), 1) + '%</b>' +
                        '</li>';
                }).join('') +
                '<li class="sf-pdm-share-item">' +
                    '<span class="sf-pdm-share-name"><i class="sf-pdm-share-dot" style="background:' + shareColors[5] + '"></i>أحياء أخرى</span>' +
                    '<b>' + fmt(otherPct, 1) + '%</b>' +
                '</li>' +
                '</ul>';
        }

        var shareMeta = $(host, '[data-pdm-meta="share"]');
        if (shareMeta) {
            shareMeta.textContent = 'أعلى 5 أحياء: ' + fmt(top5Pct, 1) + '% | أحياء أخرى: ' + fmt(otherPct, 1) + '%';
        }

        var footer = $(host, '[data-pdm-footer]');
        if (footer) {
            footer.hidden = opts.showFooter === false;
            footer.innerHTML =
                '🎯 الخلاصة التنفيذية: أعلى كثافة في <b>' + (stats.maxDensity ? normalizeDisplayName(stats.maxDensity.name) : '-') + '</b>، ' +
                'وأقل كثافة في <b>' + (stats.minDensity ? stats.minDensity.name : '-') + '</b>، ' +
                'إجمالي الذكور <b>' + fmt(stats.totalMale, 0) + '</b> | إجمالي الإناث <b>' + fmt(stats.totalFemale, 0) + '</b>';
        }
    }

    window.SmartCharts.renderPopulationDensity = renderPopulationDensity;

    document.addEventListener('DOMContentLoaded', function () {
        document.querySelectorAll('.sf-pdm').forEach(function (host) {
            if (!host.id) return;
            var cfgScript = host.querySelector('script[type="application/json"]');
            if (!cfgScript || !cfgScript.id) return;
            renderPopulationDensity(host.id, cfgScript.id);
        });
    });
})();
