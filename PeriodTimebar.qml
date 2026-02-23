import QtQuick
import QtCharts

Canvas {
    id: root

    // ── ورودی‌ها ──────────────────────────────────────────────
    property var xAxis: null          // DateTimeAxis
    property var periodData: []       // آرایه آبجکت‌های {start, end, flows:[{time,level}]}

    // ── ظاهر ──────────────────────────────────────────────────
    property real barHeight:  10
    property real barRadius:  3
    property real bottomMargin: 2

    // رنگ‌ها بر اساس flow level
    readonly property var flowColors: [
        "#00000000",    // 0 = UNKNOWN → شفاف
        "#55F48FB1",    // 1 = LIGHT   → صورتی کم‌رنگ
        "#99E91E8C",    // 2 = MEDIUM  → صورتی متوسط
        "#DDC2185A"     // 3 = HEAVY   → قرمز تیره
    ]

    // ── wiring ────────────────────────────────────────────────
    anchors.fill: parent

    Connections {
        target: root.xAxis
        function onMinChanged() { root.requestPaint() }
        function onMaxChanged() { root.requestPaint() }
    }

    onPeriodDataChanged: requestPaint()
    onWidthChanged:      requestPaint()
    onHeightChanged:     requestPaint()

    // ── رسم ───────────────────────────────────────────────────
    onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)

        if (!xAxis || !periodData || periodData.length === 0) return

        var xMin   = xAxis.min.getTime()
        var xMax   = xAxis.max.getTime()
        var xRange = xMax - xMin
        if (xRange <= 0) return

        var barY = height - barHeight - bottomMargin

        for (var i = 0; i < periodData.length; i++) {
            var period = periodData[i]

            var pStart = period.start   // msec
            var pEnd   = period.end     // msec

            // کلا خارج از بازه؟ رد کن
            if (pEnd < xMin || pStart > xMax) continue

            var flows = period.flows   // [{time, level}, ...]

            if (!flows || flows.length === 0) {
                // بدون flow data → خطکش خاکستری کم‌رنگ
                var cs = Math.max(pStart, xMin)
                var ce = Math.min(pEnd,   xMax)
                ctx.fillStyle = "#33808080"
                ctx.beginPath()
                ctx.roundRect(
                    (cs - xMin) / xRange * width,
                    barY,
                    Math.max((ce - cs) / xRange * width, 4),
                    barHeight,
                    barRadius
                )
                ctx.fill()
                continue
            }

            // ── رسم flow به صورت segment‌های رنگی ────────────
            // هر flow record یک نقطه زمانی است
            // بازه هر segment: از time[i] تا time[i+1] (یا pEnd)
            for (var j = 0; j < flows.length; j++) {
                var segStart = flows[j].time
                var segEnd   = (j + 1 < flows.length)
                               ? flows[j + 1].time
                               : pEnd

                // کلیپ به بازه نمایشی
                var cStart = Math.max(segStart, xMin)
                var cEnd   = Math.min(segEnd,   xMax)
                if (cEnd <= cStart) continue

                var x1 = (cStart - xMin) / xRange * width
                var x2 = (cEnd   - xMin) / xRange * width
                var w  = Math.max(x2 - x1, 3)

                var level = Math.min(Math.max(flows[j].level, 0), 3)
                ctx.fillStyle = root.flowColors[level]

                ctx.beginPath()
                ctx.roundRect(x1, barY, w, barHeight, barRadius)
                ctx.fill()
            }
        }
    }
}
