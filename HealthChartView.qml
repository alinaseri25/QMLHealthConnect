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
    property alias heartRateSeries: spLine5
    property alias bloodGlucoseSeries: spLine6
    property alias xAxis: axisX
    property alias heightAxis: axisY1
    property alias weightAxis: axisY2
    property alias bpAxis: axisY3
    property alias hrAxis: axisY5
    property alias bgAxis: axisY6

    // ✅ Property‌های جدید برای کنترل visibility
    property bool heightAxisVisible: true
    property bool weightAxisVisible: true
    property bool bpAxisVisible: true
    property bool heartRateAxisVisible: true
    property bool bloodGlucoseAxisVisible: true

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
        format: "yyyy/MM/dd hh:mm:ss"
        tickCount: 6
        min: new Date(Date.now())
        max: new Date(Date.now() + 10000)

        color: themeManager.axisColor
        labelsColor: themeManager.axisLabelColor
        gridLineColor: themeManager.gridColor

        labelsAngle: -45
        // تنظیمات فونت لیبل‌ها
        labelsFont.pixelSize: 8     // اندازه فونت
        labelsFont.family: "Vazir"   // فونت فارسی
        labelsFont.weight: Font.Normal  // ضخامت (Light, Normal, DemiBold, Bold, Black)
        labelsFont.italic: false     // ایتالیک

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
        visible: chartView.weightAxisVisible

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
        visible: chartView.bpAxisVisible

        color: themeManager.chartBPSystolicColor
        labelsColor: themeManager.axisLabelColor
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
        labelsColor: themeManager.axisLabelColor
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

    LineSeries {
        id: spLine5
        name: "ضربان قلب"
        useOpenGL: true
        axisX: axisX
        axisY: axisY5
        color: themeManager.chartHeartRateColor
        width: 2

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

        Behavior on color { ColorAnimation { duration: 300 } }
    }
}
