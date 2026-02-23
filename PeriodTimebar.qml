import QtQuick
import QtCharts

Canvas {
    id: root

    // ── ورودی‌ها ──────────────────────────────────────────────
    property var xAxis: null
    property var periodData: []

    // ── ظاهر ──────────────────────────────────────────────────
    property real barHeight:    10
    property real barRadius:    4
    property real bottomMargin: 2

    readonly property var flowColors: [
        "#00000000",
        "#55F48FB1",
        "#99E91E8C",
        "#DDC2185A"
    ]

    // ── wiring ────────────────────────────────────────────────
    Connections {
        target: root.xAxis
        function onMinChanged() { root.requestPaint() }
        function onMaxChanged() { root.requestPaint() }
    }

    onPeriodDataChanged: {
        console.log("[PTB] periodData changed, length=",
                    periodData ? periodData.length : "null")
        requestPaint()
    }
    onWidthChanged:  requestPaint()
    onHeightChanged: requestPaint()

    // ── تابع کمکی: رسم مستطیل گوشه‌گرد ──────────────────────
    function drawRoundRect(ctx, x, y, w, h, r) {
        // اگر عرض یا ارتفاع خیلی کم است، radius را محدود کن
        r = Math.min(r, w / 2, h / 2)
        if (r < 0) r = 0

        ctx.beginPath()
        ctx.moveTo(x + r, y)
        ctx.lineTo(x + w - r, y)
        ctx.arcTo(x + w, y,     x + w, y + r,     r)
        ctx.lineTo(x + w, y + h - r)
        ctx.arcTo(x + w, y + h, x + w - r, y + h, r)
        ctx.lineTo(x + r, y + h)
        ctx.arcTo(x,     y + h, x,     y + h - r, r)
        ctx.lineTo(x,     y + r)
        ctx.arcTo(x,     y,     x + r, y,         r)
        ctx.closePath()
    }

    // ── رسم ───────────────────────────────────────────────────
    onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)

        // ── Guard 1: xAxis ──
        if (!xAxis) {
            console.warn("[PTB] SKIP: xAxis is null")
            return
        }

        // ── Guard 2: periodData ──
        if (!periodData || periodData.length === 0) {
            console.warn("[PTB] SKIP: periodData empty")
            return
        }

        // ── Guard 3: ابعاد ──
        if (width <= 0 || height <= 0) {
            console.warn("[PTB] SKIP: canvas size invalid", width, height)
            return
        }

        // ── محاسبه xRange ──
        var xMin = xAxis.min instanceof Date
                   ? xAxis.min.getTime()
                   : Number(xAxis.min)
        var xMax = xAxis.max instanceof Date
                   ? xAxis.max.getTime()
                   : Number(xAxis.max)

        console.log("[PTB] xMin ms =", xMin, "→", new Date(xMin).toISOString())
        console.log("[PTB] xMax ms =", xMax, "→", new Date(xMax).toISOString())

        // ── Guard 4: xRange ──
        var xRange = xMax - xMin
        if (xRange <= 0) {
            console.warn("[PTB] SKIP: xRange <= 0 →", xRange)
            return
        }

        var barY = height - barHeight - bottomMargin

        // ── رسم دوره‌ها ──
        for (var i = 0; i < periodData.length; i++) {
            var period = periodData[i]

            var pStart = (period.start instanceof Date)
                         ? period.start.getTime()
                         : Number(period.start)
            var pEnd   = (period.end instanceof Date)
                         ? period.end.getTime()
                         : Number(period.end)

            console.log("[PTB] period[" + i + "]:",
                        new Date(pStart).toISOString(), "→",
                        new Date(pEnd).toISOString())

            if (isNaN(pStart) || isNaN(pEnd)) {
                console.warn("[PTB] NaN! start=", period.start, "end=", period.end)
                continue
            }

            if (pEnd < xMin || pStart > xMax) {
                console.warn("[PTB] period[" + i + "] OUT OF RANGE")
                continue
            }

            var flows = period.flows

            // ── بدون flow: رنگ پیش‌فرض ──
            if (!flows || flows.length === 0) {
                var cs  = Math.max(pStart, xMin)
                var ce  = Math.min(pEnd,   xMax)
                var rx  = (cs - xMin) / xRange * width
                var rw  = Math.max((ce - cs) / xRange * width, 4)

                ctx.fillStyle = "#88E91E8C"
                drawRoundRect(ctx, rx, barY, rw, barHeight, barRadius)
                ctx.fill()
                continue
            }

            // ── رسم بخش‌های flow ──
            for (var j = 0; j < flows.length; j++) {
                var segStart = (j === 0)
                               ? pStart
                               : Number(flows[j - 1].time)
                var segEnd   = (j === flows.length - 1)
                               ? pEnd
                               : Number(flows[j].time)
                var level    = Math.min(Math.max(Number(flows[j].level), 0), 3)

                var cs2 = Math.max(segStart, xMin)
                var ce2 = Math.min(segEnd,   xMax)
                if (ce2 <= cs2) continue

                var sx = (cs2 - xMin) / xRange * width
                var sw = Math.max((ce2 - cs2) / xRange * width, 2)

                ctx.fillStyle = flowColors[level]
                drawRoundRect(ctx, sx, barY, sw, barHeight, barRadius)
                ctx.fill()
            }
        }

        console.log("[PTB] paint done ✅")
    }
}
