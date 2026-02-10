import QtQuick
import QtCharts

ChartView {
    id: chartView
    // Properties قابل تنظیم از بیرون
    property var themeManager
    property alias heightSeries: spLine1
    property alias weightSeries: spLine2
    property alias bpSystolicSeries: spLine3
    property alias bpDiastolicSeries: spLine4
    property alias xAxis: axisX
    property alias y1Axis: axisY1
    property alias y2Axis: axisY2
    property alias y3Axis: axisY3

    title: "نمودار سلامت"
    antialiasing: true
    animationOptions: ChartView.NoAnimation
    legend.alignment: Qt.AlignTop

    // استفاده از تم
    backgroundColor: themeManager.cardColor
    titleColor: themeManager.primaryTextColor
    legend.color: themeManager.primaryTextColor
    legend.labelColor: themeManager.primaryTextColor

    Behavior on backgroundColor { ColorAnimation { duration: 300 } }

    // ===== محورها =====

    DateTimeAxis {
        id: axisX
        format: "hh:mm:ss"
        tickCount: 6
        titleText: "زمان"
        min: new Date(Date.now())
        max: new Date(Date.now() + 10000)

        color: themeManager.axisColor
        labelsColor: themeManager.axisLabelColor
        gridLineColor: themeManager.gridColor

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

        color: themeManager.chartHeightColor
        labelsColor: themeManager.axisLabelColor
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

        color: themeManager.chartWeightColor
        labelsColor: themeManager.axisLabelColor
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

        color: themeManager.chartBPSystolicColor
        labelsColor: themeManager.axisLabelColor
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

        Behavior on color { ColorAnimation { duration: 300 } }
    }
}
