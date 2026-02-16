import QtQuick

Rectangle {
    id: root
    color: "transparent"

    property var xAxis
    property var yAxes: []
    property var chartView
    property bool tooltipEnabled: true

    // ✅ tooltip از بیرون تزریق می‌شود
    property var tooltip: null

    // ✅ آستانه تشخیص drag
    property real dragThreshold: 10

    // Pinch state
    property real initialXRange
    property var initialYRanges: []
    property real startHSpan
    property real startVSpan
    property bool pinchHorizontal
    property bool pinchVertical

    PinchArea {
        anchors.fill: parent

        onPinchStarted: (p) => {
            if (tooltip) tooltip.hide()

            initialXRange = xAxis.max.getTime() - xAxis.min.getTime()
            initialYRanges = []
            for (let a of yAxes)
                initialYRanges.push(a.max - a.min)

            startHSpan = Math.abs(p.point1.x - p.point2.x)
            startVSpan = Math.abs(p.point1.y - p.point2.y)
            pinchHorizontal = startHSpan > startVSpan
            pinchVertical = startVSpan > startHSpan
        }

        onPinchUpdated: (p) => {
            if (pinchHorizontal) {
                let scale = startHSpan / Math.abs(p.point1.x - p.point2.x)
                let c = (xAxis.max.getTime() + xAxis.min.getTime()) / 2
                xAxis.min = new Date(c - initialXRange * scale / 2)
                xAxis.max = new Date(c + initialXRange * scale / 2)
            }

            if (pinchVertical) {
                let scale = startVSpan / Math.abs(p.point1.y - p.point2.y)
                for (let i = 0; i < yAxes.length; i++) {
                    let c = (yAxes[i].max + yAxes[i].min) / 2
                    yAxes[i].min = c - initialYRanges[i] * scale / 2
                    yAxes[i].max = c + initialYRanges[i] * scale / 2
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.NoButton

            property real sx
            property real sy
            property bool isDragging: false

            onPressed: (m) => {
                if (tooltip) tooltip.hide()
                sx = m.x
                sy = m.y
                isDragging = false  // ✅ فقط موقع شروع حرکت واقعی true می‌شود
            }

            onReleased: (m) => {
                // ✅ اگر drag نشد = Tap بوده
                if (!isDragging && tooltipEnabled) {
                    updateTooltip(m.x, m.y)
                }
                isDragging = false
            }

            onPositionChanged: (m) => {
                let dx = m.x - sx
                let dy = m.y - sy

                // ✅ تشخیص drag واقعی
                if (pressed && !isDragging &&
                    (Math.abs(dx) > dragThreshold || Math.abs(dy) > dragThreshold)) {
                    isDragging = true
                    if (tooltip) tooltip.hide()
                }

                if (pressed && isDragging) {
                    // ✅ Drag logic
                    if (Math.abs(dx) > Math.abs(dy)) {
                        let r = xAxis.max.getTime() - xAxis.min.getTime()
                        let s = -(dx / width) * r
                        xAxis.min = new Date(xAxis.min.getTime() + s)
                        xAxis.max = new Date(xAxis.max.getTime() + s)
                        sx = m.x
                    } else {
                        for (let a of yAxes) {
                            let r = a.max - a.min
                            let s = (dy / height) * r
                            a.min += s
                            a.max += s
                        }
                        sy = m.y
                    }
                }
                // ✅ Hover برای Desktop
                else if (!pressed && tooltipEnabled) {
                    updateTooltip(m.x, m.y)
                }
            }

            onExited: {
                if (tooltip) tooltip.hide()
            }

            onWheel: (w) => {
                if (tooltip) tooltip.hide()

                let z = w.angleDelta.y > 0 ? 0.9 : 1.1

                if (w.modifiers & Qt.ControlModifier) {
                    for (let a of yAxes) {
                        let r = a.max - a.min
                        let c = (a.max + a.min) / 2
                        a.min = c - r * z / 2
                        a.max = c + r * z / 2
                    }
                } else {
                    let r = xAxis.max.getTime() - xAxis.min.getTime()
                    let c = (xAxis.max.getTime() + xAxis.min.getTime()) / 2
                    xAxis.min = new Date(c - r * z / 2)
                    xAxis.max = new Date(c + r * z / 2)
                }
            }

            // ✅ تابع tooltip - حالا از tooltip سراسری استفاده می‌کند
            function updateTooltip(mouseX, mouseY) {
                if (!chartView || !tooltip) return

                let chartPoint = chartView.mapToValue(Qt.point(mouseX, mouseY), chartView.heightSeries)
                let closestPoint = findClosestPoint(chartPoint.x)

                if (closestPoint.found) {
                    let dateStr = Qt.formatDateTime(new Date(closestPoint.x), "yyyy/MM/dd hh:mm")

                    // ✅ استفاده از API جدید
                    tooltip.showChart(
                        root.mapToItem(tooltip.parent, mouseX, mouseY).x + 15,
                        root.mapToItem(tooltip.parent, mouseX, mouseY).y,
                        closestPoint.seriesName + " - " + dateStr,
                        closestPoint.value.toFixed(2) + " " + closestPoint.unit
                    )
                } else {
                    tooltip.hide()
                }
            }

            // ✅ منطق findClosestPoint داخلی (جلوگیری از خطای function not found)
            function findClosestPoint(targetX) {
                if (!chartView) return { found: false }

                let series = [
                    { data: chartView.heightSeries, name: "قد", unit: "cm", axis: chartView.heightAxis },
                    { data: chartView.weightSeries, name: "وزن", unit: "kg", axis: chartView.weightAxis },
                    { data: chartView.bpSystolicSeries, name: "فشار سیستولیک", unit: "mmHg", axis: chartView.bpAxis },
                    { data: chartView.bpDiastolicSeries, name: "فشار دیاستولیک", unit: "mmHg", axis: chartView.bpAxis },
                    { data: chartView.heartRateSeries, name: "ضربان قلب", unit: "bpm", axis: chartView.y5Axis },
                    { data: chartView.bloodGlucoseSeries, name: "قند خون", unit: "mg/dL", axis: chartView.y6Axis }
                ]

                let closest = null
                let minDist = Number.MAX_VALUE

                for (let s of series) {
                    if (!s.data.visible) continue

                    for (let i = 0; i < s.data.count; i++) {
                        let pt = s.data.at(i)
                        let dist = Math.abs(pt.x - targetX)

                        if (dist < minDist) {
                            minDist = dist
                            closest = {
                                found: true,
                                x: pt.x,
                                value: pt.y,
                                seriesName: s.name,
                                unit: s.unit
                            }
                        }
                    }
                }

                return closest || { found: false }
            }
        }
    }
}
