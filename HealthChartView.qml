import QtQuick
import QtCharts

Item {
    id: root

    // ── Properties قابل تنظیم از بیرون ──
    property var themeManager

    property alias heightSeries:            chartView.heightSeries
    property alias weightSeries:            chartView.weightSeries
    property alias bpSystolicSeries:        chartView.bpSystolicSeries
    property alias bpDiastolicSeries:       chartView.bpDiastolicSeries
    property alias heartRateSeries:         chartView.heartRateSeries
    property alias bloodGlucoseSeries:      chartView.bloodGlucoseSeries
    property alias oxygenSaturationSeries:  chartView.oxygenSaturationSeries

    property alias xAxis:       chartView.xAxis
    property alias heightAxis:  chartView.heightAxis
    property alias weightAxis:  chartView.weightAxis
    property alias bpAxis:      chartView.bpAxis
    property alias hrAxis:      chartView.hrAxis
    property alias bgAxis:      chartView.bgAxis
    property alias spo2Axis:    chartView.spo2Axis

    property alias plotArea: chartView.plotArea

    property alias heightAxisVisible:           chartView.heightAxisVisible
    property alias weightAxisVisible:           chartView.weightAxisVisible
    property alias bpAxisVisible:               chartView.bpAxisVisible
    property alias heartRateAxisVisible:        chartView.heartRateAxisVisible
    property alias bloodGlucoseAxisVisible:     chartView.bloodGlucoseAxisVisible
    property alias oxygenSaturationAxisVisible: chartView.oxygenSaturationAxisVisible

    property var menstruationPeriods: []

    function findClosestPoint(targetX) { return chartView.findClosestPoint(targetX) }
    function clearAll()                { chartView.clearAll() }

    // ── ChartView اصلی ──
    ChartView {
        id: chartView
        anchors.fill: parent

        property var themeManager: root.themeManager

        property alias heightSeries:            spLine1
        property alias weightSeries:            spLine2
        property alias bpSystolicSeries:        spLine3
        property alias bpDiastolicSeries:       spLine4
        property alias heartRateSeries:         spLine5
        property alias bloodGlucoseSeries:      spLine6
        property alias oxygenSaturationSeries:  spLine7

        property alias xAxis:      axisX
        property alias heightAxis: axisY1
        property alias weightAxis: axisY2
        property alias bpAxis:     axisY3
        property alias hrAxis:     axisY5
        property alias bgAxis:     axisY6
        property alias spo2Axis:   axisY7

        property bool heightAxisVisible:           false
        property bool weightAxisVisible:           false
        property bool bpAxisVisible:               false
        property bool heartRateAxisVisible:        false
        property bool bloodGlucoseAxisVisible:     false
        property bool oxygenSaturationAxisVisible: false

        property bool tooltipEnabled: true

        antialiasing: true
        animationOptions: ChartView.NoAnimation
        legend.alignment: Qt.AlignTop
        legend.visible: false

        backgroundColor: themeManager.cardColor
        titleColor: themeManager.primaryTextColor
        legend.color: themeManager.primaryTextColor
        legend.labelColor: themeManager.primaryTextColor

        Behavior on backgroundColor { ColorAnimation { duration: 300 } }

        // ===== محورها =====

        DateTimeAxis {
            id: axisX
            format: "yyyy/MM/dd hh:mm:ss"
            tickCount: 6
            min: new Date(Date.now())
            max: new Date(Date.now() + 10000)

            color: themeManager.axisColor
            labelsColor: themeManager.axisLabelColor
            gridLineColor: themeManager.gridColor

            labelsAngle: -45
            labelsFont.pixelSize: 8
            labelsFont.family: "Vazir"
            labelsFont.weight: Font.Normal
            labelsFont.italic: false

            Behavior on color { ColorAnimation { duration: 300 } }
            Behavior on labelsColor { ColorAnimation { duration: 300 } }
            Behavior on gridLineColor { ColorAnimation { duration: 300 } }
        }

        ValueAxis {
            id: axisY1
            min: 150
            max: 200
            tickCount: 5
            labelFormat: "%.1f"
            titleText: "قد (m)"
            visible: chartView.heightAxisVisible

            color: themeManager.chartHeightColor
            labelsColor: themeManager.chartHeightColor
            titleBrush: themeManager.chartHeightColor
            gridLineColor: themeManager.gridColor

            Behavior on color { ColorAnimation { duration: 300 } }
            Behavior on labelsColor { ColorAnimation { duration: 300 } }
            Behavior on gridLineColor { ColorAnimation { duration: 300 } }
        }

        ValueAxis {
            id: axisY2
            min: 40
            max: 50
            tickCount: 5
            labelFormat: "%.1f"
            titleText: "وزن (kg)"
            visible: chartView.weightAxisVisible

            color: themeManager.chartWeightColor
            labelsColor: themeManager.chartWeightColor
            titleBrush: themeManager.chartWeightColor
            gridLineColor: themeManager.gridColor

            Behavior on color { ColorAnimation { duration: 300 } }
            Behavior on labelsColor { ColorAnimation { duration: 300 } }
            Behavior on gridLineColor { ColorAnimation { duration: 300 } }
        }

        ValueAxis {
            id: axisY3
            min: 60
            max: 200
            tickCount: 8
            labelFormat: "%.0f"
            titleText: "فشار خون (mmHg)"
            visible: chartView.bpAxisVisible

            color: themeManager.chartBPSystolicColor
            labelsColor: themeManager.chartBPSystolicColor
            titleBrush: themeManager.chartBPSystolicColor
            gridLineColor: themeManager.gridColor

            Behavior on color { ColorAnimation { duration: 300 } }
            Behavior on labelsColor { ColorAnimation { duration: 300 } }
            Behavior on gridLineColor { ColorAnimation { duration: 300 } }
        }

        ValueAxis {
            id: axisY5
            min: 100
            max: 40
            tickCount: 5
            labelFormat: "%.0f"
            titleText: "ضربان قلب (bpm)"
            visible: chartView.heartRateAxisVisible

            color: themeManager.chartHeartRateColor
            labelsColor: themeManager.chartHeartRateColor
            titleBrush: themeManager.chartHeartRateColor
            gridLineColor: themeManager.gridColor

            Behavior on color { ColorAnimation { duration: 300 } }
            Behavior on labelsColor { ColorAnimation { duration: 300 } }
            Behavior on gridLineColor { ColorAnimation { duration: 300 } }
        }

        ValueAxis {
            id: axisY6
            min: 100
            max: 40
            tickCount: 5
            labelFormat: "%.1f"
            titleText: "قند خون (mg/dL)"
            visible: chartView.bloodGlucoseAxisVisible

            color: themeManager.chartBloodGlucoseColor
            labelsColor: themeManager.chartBloodGlucoseColor
            titleBrush: themeManager.chartBloodGlucoseColor
            gridLineColor: themeManager.gridColor

            Behavior on color { ColorAnimation { duration: 300 } }
            Behavior on labelsColor { ColorAnimation { duration: 300 } }
            Behavior on gridLineColor { ColorAnimation { duration: 300 } }
        }

        ValueAxis {
            id: axisY7
            min: 85.0
            max: 100.0
            tickCount: 4
            labelFormat: "%.1f"
            titleText: "اشباع اکسیژن (%)"
            visible: chartView.oxygenSaturationAxisVisible

            color: themeManager.chartOxygenSaturationColor
            labelsColor: themeManager.chartOxygenSaturationColor
            titleBrush: themeManager.chartOxygenSaturationColor
            gridLineColor: themeManager.gridColor

            Behavior on color { ColorAnimation { duration: 300 } }
            Behavior on labelsColor { ColorAnimation { duration: 300 } }
            Behavior on gridLineColor { ColorAnimation { duration: 300 } }
        }

        // ===== سری‌های داده =====

        LineSeries {
            id: spLine1
            name: "قد"
            useOpenGL: true
            axisX: axisX
            axisY: axisY1
            color: themeManager.chartHeightColor
            width: 2
            pointsVisible: true
            Behavior on color { ColorAnimation { duration: 300 } }
        }

        LineSeries {
            id: spLine2
            name: "وزن"
            useOpenGL: true
            axisX: axisX
            axisY: axisY2
            color: themeManager.chartWeightColor
            width: 2
            pointsVisible: true
            Behavior on color { ColorAnimation { duration: 300 } }
        }

        LineSeries {
            id: spLine3
            name: "فشار سیستولیک"
            useOpenGL: true
            width: 2
            axisX: axisX
            axisY: axisY3
            color: themeManager.chartBPSystolicColor
            pointsVisible: true
            Behavior on color { ColorAnimation { duration: 300 } }
        }

        LineSeries {
            id: spLine4
            name: "فشار دیاستولیک"
            useOpenGL: true
            width: 2
            axisX: axisX
            axisY: axisY3
            color: themeManager.chartBPDiastolicColor
            pointsVisible: true
            Behavior on color { ColorAnimation { duration: 300 } }
        }

        LineSeries {
            id: spLine5
            name: "ضربان قلب"
            useOpenGL: true
            axisX: axisX
            axisY: axisY5
            color: themeManager.chartHeartRateColor
            width: 2
            pointsVisible: true
            Behavior on color { ColorAnimation { duration: 300 } }
        }

        LineSeries {
            id: spLine6
            name: "قند خون"
            useOpenGL: true
            axisX: axisX
            axisY: axisY6
            color: themeManager.chartBloodGlucoseColor
            width: 2
            pointsVisible: true
            Behavior on color { ColorAnimation { duration: 300 } }
        }

        LineSeries {
            id: spLine7
            name: "اشباع اکسیژن"
            useOpenGL: true
            axisX: axisX
            axisY: axisY7
            color: themeManager.chartOxygenSaturationColor
            width: 2
            pointsVisible: true
            Behavior on color { ColorAnimation { duration: 300 } }
        }

        // ===== 🔥 تابع اصلی: پیدا کردن نزدیک‌ترین نقطه =====
        function findClosestPoint(targetX) {
            var result = {
                found: false,
                x: 0,
                value: 0,
                seriesName: "",
                unit: ""
            }

            var minDistance = Number.MAX_VALUE
            var threshold = (axisX.max.getTime() - axisX.min.getTime()) * 0.05

            var seriesList = [
                { series: spLine1, unit: "m",     name: "قد" },
                { series: spLine2, unit: "kg",    name: "وزن" },
                { series: spLine3, unit: "mmHg",  name: "فشار سیستولیک" },
                { series: spLine4, unit: "mmHg",  name: "فشار دیاستولیک" },
                { series: spLine5, unit: "bpm",   name: "ضربان قلب" },
                { series: spLine6, unit: "mg/dL", name: "قند خون" },
                { series: spLine7, unit: "%",     name: "اشباع اکسیژن" }
            ]

            for (var i = 0; i < seriesList.length; i++) {
                var s = seriesList[i].series
                for (var j = 0; j < s.count; j++) {
                    var pt = s.at(j)
                    var dist = Math.abs(pt.x - targetX)
                    if (dist < minDistance && dist < threshold) {
                        minDistance = dist
                        result.found      = true
                        result.x          = pt.x
                        result.value      = pt.y
                        result.seriesName = seriesList[i].name
                        result.unit       = seriesList[i].unit
                    }
                }
            }
            return result
        }

        function clearAll() {
            spLine1.clear()
            spLine2.clear()
            spLine3.clear()
            spLine4.clear()
            spLine5.clear()
            spLine6.clear()
            spLine7.clear()
        }

    } // end ChartView

    // ── PeriodTimebar روی plotArea ──
    PeriodTimebar {
        id: periodTimebar
        x:      chartView.plotArea.x
        y:      chartView.plotArea.y + chartView.plotArea.height - 14
        width:  chartView.plotArea.width
        height: 14
        z:      2

        xAxis:      chartView.xAxis
        periodData: root.menstruationPeriods

        // ── DEBUG border ──
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: "red"
            border.width: 1
            z: 99
        }
    }

    // Component.onCompleted: {
    //     var now = new Date().getTime()
    //     var day = 24 * 60 * 60 * 1000

    //     // ── تنظیم xAxis قبل از تزریق mock data ──
    //     // اطمینان از اینکه xAxis بازه معتبر دارد
    //     if (chartView.xAxis) {
    //         chartView.xAxis.min = new Date(now - 7 * day)
    //         chartView.xAxis.max = new Date(now)
    //         console.log("[HCV] xAxis forced:",
    //                     chartView.xAxis.min.toISOString(),
    //                     "→", chartView.xAxis.max.toISOString())
    //     }

    //     var mockData = [
    //         {
    //             start: now - 4 * day,
    //             end:   now - 1 * day,
    //             flows: [
    //                 { time: now - 4 * day,       level: 1 },
    //                 { time: now - 3 * day,       level: 2 },
    //                 { time: now - 2 * day,       level: 3 },
    //                 { time: now - 1.5 * day,     level: 2 }
    //             ]
    //         }
    //     ]

    //     console.log("=== Mock periodData injected ===")
    //     console.log("start:", new Date(mockData[0].start).toISOString())
    //     console.log("end:",   new Date(mockData[0].end).toISOString())
    //     console.log("xAxis.min:", chartView.xAxis ? chartView.xAxis.min : "NULL")
    //     console.log("xAxis.max:", chartView.xAxis ? chartView.xAxis.max : "NULL")

    //     menstruationPeriods = mockData

    //     // ── Force repaint پس از تزریق ──
    //     Qt.callLater(function() {
    //         periodTimebar.requestPaint()
    //         console.log("[HCV] forced repaint after mock inject")
    //     })
    // }

} // end Item
