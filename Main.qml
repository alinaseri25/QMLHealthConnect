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

    property int statusResetDelay: 7000

    // ===== Signals =====
    signal updateSignal(bool height,bool weight,bool bp,bool bg,bool hr,bool oxygenSaturation)
    signal setHeight(double value)
    signal setWeight(double value)
    signal setBloodPressure(int systolic, int diastolic)
    signal setHeartRate(double bpm)
    signal setBloodGlucose(double glucoseMgDl, int specimenSource, int mealType, int relationToMeal)
    signal setOxygenSaturation(double value)

    // ✅ یک tooltip سراسری برای کل برنامه
    GenericTooltip {
        id: globalTooltip
        z: 10000
        parent: mainView  // مهم: parent باید root باشه
    }

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

    // ✅ ناحیه تعامل روی خود چارت
    ChartInteractionZone {
        id: chartInteractionZone
        x: chartView.x + chartView.plotArea.x
        y: chartView.y + chartView.plotArea.y
        width: chartView.plotArea.width
        height: chartView.plotArea.height
        z: 5  // بالاتر از همه چیز

        xAxis: chartView.xAxis
        yAxes: [
            chartView.heightAxis,
            chartView.weightAxis,
            chartView.bpAxis,
            chartView.hrAxis,
            chartView.bgAxis,
            chartView.spo2Axis
        ]
        chartView: chartView
        tooltipEnabled: true

        tooltip: globalTooltip
    }

    // ✅ ناحیه محور X (زیر چارت)
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

    // ✅ ناحیه تمام محورهای Y (سمت راست چارت)
    // این یک ناحیه واحد برای تمام محورهای Y است
    AxisInteractionZone {
        id: allYAxesZone
        x: chartView.x + chartView.plotArea.x + chartView.plotArea.width
        y: chartView.y + chartView.plotArea.y
        width: 240  // عرض کل فضای محورهای Y
        height: chartView.plotArea.height
        z: 1

        targetAxes: [
            chartView.heightAxis,
            chartView.weightAxis,
            chartView.bpAxis,
            chartView.hrAxis,
            chartView.bgAxis,
            chartView.spo2Axis
        ]
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
        oxygenSaturationSeries: chartView.oxygenSaturationSeries

        onUpdateRequested: {
            mainView.updateSignal(chartView.heightAxisVisible,chartView.weightAxisVisible,chartView.bpAxisVisible,
                                  chartView.bloodGlucoseAxisVisible,chartView.heartRateAxisVisible,chartView.oxygenSaturationAxisVisible)
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

        onOxygenSaturationSubmitted:(value)=>{
            setOxygenSaturation(value)
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

    // ===== Timers برای ریست وضعیت =====
    Timer {
        id: heightStatusTimer
        interval: parent.statusResetDelay
        repeat: false
        onTriggered: {
            inputPanel.heightStatusText = ""
            inputPanel.heightStatusColor = "gray"
        }
    }

    Timer {
        id: weightStatusTimer
        interval: parent.statusResetDelay
        repeat: false
        onTriggered: {
            inputPanel.weightStatusText = ""
            inputPanel.weightStatusColor = "gray"
        }
    }

    Timer {
        id: bpStatusTimer
        interval: parent.statusResetDelay
        repeat: false
        onTriggered: {
            inputPanel.bpStatusText = ""
            inputPanel.bpStatusColor = "gray"
        }
    }

    Timer {
        id: heartRateStatusTimer
        interval: parent.statusResetDelay
        repeat: false
        onTriggered: {
            inputPanel.heartRateStatusText = ""
            inputPanel.heartRateStatusColor = "gray"
        }
    }

    Timer {
        id: bloodGlucoseStatusTimer
        interval: parent.statusResetDelay
        repeat: false
        onTriggered: {
            inputPanel.bloodGlucoseStatusText = ""
            inputPanel.bloodGlucoseStatusColor = "gray"
        }
    }

    Timer {
        id: oxygenSaturationTimer
        interval: parent.statusResetDelay
        repeat: false
        onTriggered: {
            inputPanel.oxygenSaturationStatusText = ""
            inputPanel.oxygenSaturationStatusColor = "gray"
        }
    }

    // ===== اتصالات Backend =====
    Component.onCompleted: {
        updateSignal.connect(myBackend.onUpdateRequest)
        setHeight.connect(myBackend.writeHeight)
        setWeight.connect(myBackend.writeWeight)
        setBloodPressure.connect(myBackend.writeBloodPressure)
        setHeartRate.connect(myBackend.writeHeartRate)
        setBloodGlucose.connect(myBackend.writeBloodGlucose)
        setOxygenSaturation.connect(myBackend.writeOxygenSaturation)

        controlButtons.setInitialVisibility(false,true,true,false,true,true)
    }

    Connections {
        target: myBackend

        function onHeightWritten(success, message) {
            if (success) {
                inputPanel.heightStatusText = "✅ قد " + message + " ثبت شد"
                inputPanel.heightStatusColor = "green"
                mainView.updateSignal(chartView.heightAxisVisible,chartView.weightAxisVisible,chartView.bpAxisVisible,chartView.bloodGlucoseAxisVisible,
                                      chartView.heartRateAxisVisible,chartView.oxygenSaturationAxisVisible)
            } else {
                inputPanel.heightStatusText = "❌ " + message
                inputPanel.heightStatusColor = "red"
            }
            heightStatusTimer.restart()  // ← در هر دو حالت تایمر استارت میشه
        }

        function onWeightWritten(success, message) {
            if (success) {
                inputPanel.weightStatusText = "✅ وزن " + message + " ثبت شد"
                inputPanel.weightStatusColor = "green"
                mainView.updateSignal(chartView.heightAxisVisible,chartView.weightAxisVisible,chartView.bpAxisVisible,chartView.bloodGlucoseAxisVisible,
                                      chartView.heartRateAxisVisible,chartView.oxygenSaturationAxisVisible)
            } else {
                inputPanel.weightStatusText = "❌ " + message
                inputPanel.weightStatusColor = "red"
            }
            weightStatusTimer.restart()
        }

        function onBloodPressureWritten(success, message) {
            if (success) {
                inputPanel.bpStatusText = "✅ فشار خون " + message + " ثبت شد"
                inputPanel.bpStatusColor = "green"
                mainView.updateSignal(chartView.heightAxisVisible,chartView.weightAxisVisible,chartView.bpAxisVisible,chartView.bloodGlucoseAxisVisible,
                                      chartView.heartRateAxisVisible,chartView.oxygenSaturationAxisVisible)
            } else {
                inputPanel.bpStatusText = "❌ " + message
                inputPanel.bpStatusColor = "red"
            }
            bpStatusTimer.restart()
        }

        function onHeartRateWritten(success, message) {
            if (success) {
                inputPanel.heartRateStatusText = "✅ ضربان قلب " + message + " ثبت شد"
                inputPanel.heartRateStatusColor = "green"
                mainView.updateSignal(chartView.heightAxisVisible,chartView.weightAxisVisible,chartView.bpAxisVisible,chartView.bloodGlucoseAxisVisible,
                                      chartView.heartRateAxisVisible,chartView.oxygenSaturationAxisVisible)
            } else {
                inputPanel.heartRateStatusText = "❌ " + message
                inputPanel.heartRateStatusColor = "red"
            }
            heartRateStatusTimer.restart()
        }

        function onBloodGlucoseWritten(success, message) {
            if (success) {
                inputPanel.bloodGlucoseStatusText = "✅ قند خون " + message + " ثبت شد"
                inputPanel.bloodGlucoseStatusColor = "green"
                mainView.updateSignal(chartView.heightAxisVisible,chartView.weightAxisVisible,chartView.bpAxisVisible,chartView.bloodGlucoseAxisVisible,
                                      chartView.heartRateAxisVisible,chartView.oxygenSaturationAxisVisible)
            } else {
                inputPanel.bloodGlucoseStatusText = "❌ " + message
                inputPanel.bloodGlucoseStatusColor = "red"
            }
            bloodGlucoseStatusTimer.restart()
        }

        function onOxygenSaturationWritten(success, message) {
            if (success) {
                inputPanel.oxygenSaturationStatusText = "✅ اکسیژن خون " + message + " ثبت شد"
                inputPanel.oxygenSaturationStatusColor = "green"
                mainView.updateSignal(chartView.heightAxisVisible,chartView.weightAxisVisible,chartView.bpAxisVisible,chartView.bloodGlucoseAxisVisible,
                                      chartView.heartRateAxisVisible,chartView.oxygenSaturationAxisVisible)
            } else {
                inputPanel.oxygenSaturationStatusText = "❌ " + message
                inputPanel.oxygenSaturationStatusColor = "red"
            }
            oxygenSaturationTimer.restart()
        }

        function onNewDataRead(hList, wList, bpSystolicList, bpDiastolicList, heartRateList, bloodGlucoseList, oxygenSaturationList) {
            chartView.heightSeries.clear()
            chartView.weightSeries.clear()
            chartView.bpSystolicSeries.clear()
            chartView.bpDiastolicSeries.clear()
            chartView.heartRateSeries.clear()
            chartView.bloodGlucoseSeries.clear()
            chartView.oxygenSaturationSeries.clear()

            // ✅ تعریف متغیرها با مقادیر پیش‌فرض
            let minH = 140, maxH = 200
            let minW = 50, maxW = 120
            let minBP = 60, maxBP = 140
            let minHR = 50, maxHR = 120
            let minBG = 70, maxBG = 200
            let minSpo2 = 85, maxSpo2 = 100

            // محاسبه minTime
            let minTime = Number.MAX_VALUE
            if (hList.length > 0)
            {
                if(hList[0].x < minTime) minTime = hList[0].x
                minH = hList[0].y - 10
                maxH = hList[0].y + 10
            }
            if (wList.length > 0)
            {
                if(wList[0].x < minTime) minTime = wList[0].x
                minW = wList[0].y - 1
                maxW = wList[0].y + 1
            }
            if (bpSystolicList.length > 0)
            {
                if(bpSystolicList[0].x < minTime) minTime = bpSystolicList[0].x
            }
            if (heartRateList.length > 0)
            {
                if(heartRateList[0].x < minTime) minTime = heartRateList[0].x
            }
            if (bloodGlucoseList.length > 0)
            {
                if(bloodGlucoseList[0].x < minTime) minTime = bloodGlucoseList[0].x
            }
            if (oxygenSaturationList.length > 0 && oxygenSaturationList[0].x < minTime)
            {
                minTime = oxygenSaturationList[0].x
                minSpo2 = oxygenSaturationList[0].y - 1
                maxSpo2 = oxygenSaturationList[0].y + 1
            }

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
            if (oxygenSaturationList.length > 0) {
                minH = (oxygenSaturationList[0].y * 100) - 10
                maxH = (oxygenSaturationList[0].y * 100) + 10
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

            console.log("oxygenSaturationList siz : " + oxygenSaturationList.length)
            // پردازش داده‌های SPO2
            for (let i = 0; i < oxygenSaturationList.length; i++) {
                let Spoi = oxygenSaturationList[i].y
                chartView.oxygenSaturationSeries.append(oxygenSaturationList[i].x, Spoi)
                if (Spoi < minSpo2) minSpo2 = Spoi - 1
                if (Spoi > maxSpo2) maxSpo2 = Spoi + 1
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

            chartView.spo2Axis.min = minSpo2
            chartView.spo2Axis.max = maxSpo2

            chartView.xAxis.min = new Date(minTime)
            chartView.xAxis.max = new Date(Date.now())
        }
    }
}
