import QtQuick
import QtQuick.Controls

Rectangle {
    id: mainView
    width: 640
    height: 480

    // ===== ThemeManager =====
    ThemeManager {
        id: appTheme
    }

    color: appTheme.backgroundColor  // ✅ از instance استفاده کنید نه Singleton

    Behavior on color {
        ColorAnimation { duration: 300 }
    }

    // ===== Signals =====
    signal updateSignal()
    signal setHeight(double value)
    signal setWeight(double value)
    signal setBloodPressure(int systolic, int diastolic)
    signal setHeartRate(double bpm)
    signal setBloodGlucose(double glucoseMgDl, int specimenSource, int mealType, int relationToMeal)

    // ===== نمودار اصلی =====
    HealthChartView {
        id: chartView
        themeManager: appTheme

        x: 0
        y: 50
        width: parent.width - inputPanel.width
        height: parent.height - 50

        Behavior on width {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
    }

    // ===== نواحی تعامل با محورها =====

    // محور X
    AxisInteractionZone {
        id: xAxisZone
        x: chartView.x + chartView.plotArea.x
        y: chartView.y + chartView.plotArea.y + chartView.plotArea.height
        width: chartView.plotArea.width
        height: 60
        z: 1

        targetAxis: chartView.xAxis
        axisType: "x"
        chartView: chartView
    }

    // محور Y1
    AxisInteractionZone {
        id: y1AxisZone
        x: chartView.x
        y: chartView.y + chartView.plotArea.y
        width: chartView.plotArea.x
        height: chartView.plotArea.height
        z: 1

        targetAxis: chartView.heightAxis
        axisType: "y"
        chartView: chartView
    }

    // محور Y2
    AxisInteractionZone {
        id: y2AxisZone
        x: chartView.x + chartView.plotArea.x + chartView.plotArea.width
        y: chartView.y + chartView.plotArea.y
        width: 60
        height: chartView.plotArea.height
        z: 1

        targetAxis: chartView.weightAxis
        axisType: "y"
        chartView: chartView
    }

    // محور Y3
    AxisInteractionZone {
        id: y3AxisZone
        x: chartView.x + chartView.plotArea.x + chartView.plotArea.width + 60
        y: chartView.y + chartView.plotArea.y
        width: 60
        height: chartView.plotArea.height
        z: 1

        targetAxis: chartView.bpAxis
        axisType: "y"
        chartView: chartView
    }

    // ✅ محور Y5 - ضربان قلب
    AxisInteractionZone {
        id: y5AxisZone
        x: chartView.x + chartView.plotArea.x + chartView.plotArea.width + 120
        y: chartView.y + chartView.plotArea.y
        width: 60
        height: chartView.plotArea.height
        z: 1

        targetAxis: chartView.y5Axis
        axisType: "y"
        chartView: chartView
    }

    // ✅ محور Y6 - قند خون
    AxisInteractionZone {
        id: y6AxisZone
        x: chartView.x + chartView.plotArea.x + chartView.plotArea.width + 180
        y: chartView.y + chartView.plotArea.y
        width: 60
        height: chartView.plotArea.height
        z: 1

        targetAxis: chartView.y6Axis
        axisType: "y"
        chartView: chartView
    }

    // ===== دکمه‌های کنترل نمودار =====
    ChartControlButtons {
        themeManager: appTheme
        id: controlButtons
        x: (parent.width / 2) - 350
        y: 10

        chartView: chartView

        heightSeries: chartView.heightSeries
        weightSeries: chartView.weightSeries
        bpSystolicSeries: chartView.bpSystolicSeries
        bpDiastolicSeries: chartView.bpDiastolicSeries
        heartRateSeries: chartView.heartRateSeries
        bloodGlucoseSeries: chartView.bloodGlucoseSeries

        onUpdateRequested: {
            mainView.updateSignal()
        }
    }

    // ===== دکمه باز/بسته پنل =====
    TogglePanelButton {
        themeManager: appTheme
        id: togglePanelBtn
        panelExpanded: inputPanel.expanded
        x: parent.width - (togglePanelBtn.width + 50)
        y: 10
        z: 3

        onTogglePanel: {
            inputPanel.expanded = !inputPanel.expanded
        }
    }

    // ===== پنل ورودی =====
    InputPanel {
        id: inputPanel
        themeManager: appTheme
        anchors.right: parent.right
        z: 2

        onHeightSubmitted: (value) => {
            mainView.setHeight(value)
        }

        onWeightSubmitted: (value) => {
            mainView.setWeight(value)
        }

        onBloodPressureSubmitted: (systolic, diastolic) => {
            mainView.setBloodPressure(systolic, diastolic)
        }

        onHeartRateSubmitted: (value) => {
            mainView.setHeartRate(value)
        }

        onBloodGlucoseSubmitted: (glucoseMgDl, specimenSource, mealType, relationToMeal) => {
            mainView.setBloodGlucose(glucoseMgDl, specimenSource, mealType, relationToMeal)
        }
    }

    // ===== دکمه تغییر تم =====
    ThemeToggle {
        themeManager: appTheme
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 16
        z: 3  // ✅ z-index بالاتر
    }

    // ===== اتصالات Backend =====
    Component.onCompleted: {
        updateSignal.connect(myBackend.onUpdateRequest)
        setHeight.connect(myBackend.writeHeight)
        setWeight.connect(myBackend.writeWeight)
        setBloodPressure.connect(myBackend.writeBloodPressure)
        setHeartRate.connect(myBackend.writeHeartRate)
        setBloodGlucose.connect(myBackend.writeBloodGlucose)

        controlButtons.setInitialVisibility(false,true,true,false,true)
    }

    Connections {
        target: myBackend

        function onHeightWritten(success, message) {
            if (success) {
                inputPanel.heightStatusText = "✅ قد ثبت شد"
                inputPanel.heightStatusColor = "green"
                Qt.callLater(updateSignal)
            } else {
                inputPanel.heightStatusText = "❌ " + message
                inputPanel.heightStatusColor = "red"
            }
        }

        function onWeightWritten(success, message) {
            if (success) {
                inputPanel.weightStatusText = "✅ وزن ثبت شد"
                inputPanel.weightStatusColor = "green"
                Qt.callLater(updateSignal)
            } else {
                inputPanel.weightStatusText = "❌ " + message
                inputPanel.weightStatusColor = "red"
            }
        }

        function onBloodPressureWritten(success, message) {
            if (success) {
                inputPanel.bpStatusText = "✅ فشار خون ثبت شد"
                inputPanel.bpStatusColor = "green"
                Qt.callLater(updateSignal)
            } else {
                inputPanel.bpStatusText = "❌ " + message
                inputPanel.bpStatusColor = "red"
            }
        }

        function onHeartRateWritten(success, message) {
            if (success) {
                inputPanel.heartRateStatusText = "✅ ضربان قلب ثبت شد"
                inputPanel.heartRateStatusColor = "green"
                Qt.callLater(updateSignal)
            } else {
                inputPanel.heartRateStatusText = "❌ " + message
                inputPanel.heartRateStatusColor = "red"
            }
        }

        function onBloodGlucoseWritten(success, message) {
            if (success) {
                inputPanel.bloodGlucoseStatusText = "✅ قند خون ثبت شد"
                inputPanel.bloodGlucoseStatusColor = "green"
                Qt.callLater(updateSignal)
            } else {
                inputPanel.bloodGlucoseStatusText = "❌ " + message
                inputPanel.bloodGlucoseStatusColor = "red"
            }
        }

        function onNewDataRead(hList, wList, bpSystolicList, bpDiastolicList, heartRateList, bloodGlucoseList) {
            chartView.heightSeries.clear()
            chartView.weightSeries.clear()
            chartView.bpSystolicSeries.clear()
            chartView.bpDiastolicSeries.clear()
            chartView.heartRateSeries.clear()
            chartView.bloodGlucoseSeries.clear()

            // ✅ تعریف متغیرها با مقادیر پیش‌فرض
            let minH = 140, maxH = 200
            let minW = 50, maxW = 120
            let minBP = 60, maxBP = 140
            let minHR = 50, maxHR = 120
            let minBG = 70, maxBG = 200

            // محاسبه minTime
            let minTime = Number.MAX_VALUE
            if (hList.length > 0 && hList[0].x < minTime) minTime = hList[0].x
            if (wList.length > 0 && wList[0].x < minTime) minTime = wList[0].x
            if (bpSystolicList.length > 0 && bpSystolicList[0].x < minTime) minTime = bpSystolicList[0].x
            if (heartRateList.length > 0 && heartRateList[0].x < minTime) minTime = heartRateList[0].x
            if (bloodGlucoseList.length > 0 && bloodGlucoseList[0].x < minTime) minTime = bloodGlucoseList[0].x

            if (hList.length > 0) {
                minH = (hList[0].y * 100) - 10
                maxH = (hList[0].y * 100) + 10
            }
            if (wList.length > 0) {
                minW = wList[0].y - 1
                maxW = wList[0].y + 1
            }
            if (bpDiastolicList.length > 0) {
                minBP = bpDiastolicList[0].y - 1
                maxBP = bpSystolicList[0].y + 1
            }
            if (heartRateList.length > 0) {
                minHR = heartRateList[0].y - 1
                maxHR = heartRateList[0].y + 1
            }
            if (bloodGlucoseList.length > 0) {
                minBG = bloodGlucoseList[0].y - 1
                maxBG = bloodGlucoseList[0].y + 1
            }

            // پردازش داده‌های قد
            for (let i = 0; i < hList.length; i++) {
                let hi = hList[i].y * 100
                chartView.heightSeries.append(hList[i].x, hi)
                if (hi < minH) minH = hi - 10
                if (hi > maxH) maxH = hi + 10
            }

            // پردازش داده‌های وزن
            for (let i = 0; i < wList.length; i++) {
                let wi = wList[i].y
                chartView.weightSeries.append(wList[i].x, wi)
                if (wi < minW) minW = wi - 1
                if (wi > maxW) maxW = wi + 1
            }

            // پردازش داده‌های فشار خون
            for (let i = 0; i < bpSystolicList.length; i++) {
                chartView.bpSystolicSeries.append(bpSystolicList[i].x, bpSystolicList[i].y)
                chartView.bpDiastolicSeries.append(bpDiastolicList[i].x, bpDiastolicList[i].y)

                if (bpSystolicList[i].y < minBP) minBP = bpSystolicList[i].y
                if (bpSystolicList[i].y > maxBP) maxBP = bpSystolicList[i].y
                if (bpDiastolicList[i].y < minBP) minBP = bpDiastolicList[i].y
                if (bpDiastolicList[i].y > maxBP) maxBP = bpDiastolicList[i].y
            }

            // === پردازش ضربان قلب ===
            for (let i = 0; i < heartRateList.length; i++) {
                let hr = heartRateList[i].y
                chartView.heartRateSeries.append(heartRateList[i].x, hr)
                if (hr < minHR) minHR = hr - 1
                if (hr > maxHR) maxHR = hr + 1
            }

            // === پردازش قند خون ===
            for (let i = 0; i < bloodGlucoseList.length; i++) {
                let bg = bloodGlucoseList[i].y
                chartView.bloodGlucoseSeries.append(bloodGlucoseList[i].x, bg)
                if (bg < minBG) minBG = bg - 2
                if (bg > maxBG) maxBG = bg + 2
            }

            // تنظیم محدوده محورها
            chartView.heightAxis.min = minH
            chartView.heightAxis.max = maxH

            chartView.weightAxis.min = minW
            chartView.weightAxis.max = maxW

            let bpMargin = (maxBP - minBP) * 0.1
            chartView.bpAxis.min = minBP - bpMargin
            chartView.bpAxis.max = maxBP + bpMargin

            chartView.hrAxis.min = minHR
            chartView.hrAxis.max = maxHR

            chartView.bgAxis.min = minBG
            chartView.bgAxis.max = maxBG

            chartView.xAxis.min = new Date(minTime)
            chartView.xAxis.max = new Date(Date.now())
        }
    }
}
