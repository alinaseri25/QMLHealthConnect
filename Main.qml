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
        z: 20

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
        z: 20

        targetAxis: chartView.y1Axis
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
        z: 20

        targetAxis: chartView.y2Axis
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
        z: 20

        targetAxis: chartView.y3Axis
        axisType: "y"
        chartView: chartView
    }

    // ===== دکمه‌های کنترل نمودار =====
    ChartControlButtons {
        themeManager: appTheme
        id: controlButtons
        x: (parent.width / 2) - 220
        y: 10

        heightSeries: chartView.heightSeries
        weightSeries: chartView.weightSeries
        bpSystolicSeries: chartView.bpSystolicSeries
        bpDiastolicSeries: chartView.bpDiastolicSeries

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
        z: 101

        onTogglePanel: {
            inputPanel.expanded = !inputPanel.expanded
        }
    }

    // ===== پنل ورودی =====
    InputPanel {
        id: inputPanel
        themeManager: appTheme
        anchors.right: parent.right
        z: 100

        onHeightSubmitted: (value) => {
            mainView.setHeight(value)
        }

        onWeightSubmitted: (value) => {
            mainView.setWeight(value)
        }

        onBloodPressureSubmitted: (systolic, diastolic) => {
            mainView.setBloodPressure(systolic, diastolic)
        }
    }

    // ===== دکمه تغییر تم =====
    ThemeToggle {
        themeManager: appTheme
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 16
        z: 10000  // ✅ z-index بالاتر
    }

    // ===== اتصالات Backend =====
    Component.onCompleted: {
        updateSignal.connect(myBackend.onUpdateRequest)
        setHeight.connect(myBackend.writeHeight)
        setWeight.connect(myBackend.writeWeight)
        setBloodPressure.connect(myBackend.writeBloodPressure)
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

        function onNewDataRead(hList, wList, bpSystolicList, bpDiastolicList) {
            chartView.heightSeries.clear()
            chartView.weightSeries.clear()
            chartView.bpSystolicSeries.clear()
            chartView.bpDiastolicSeries.clear()

            let minTime = hList[0].x
            if (wList[0].x < minTime) minTime = wList[0].x
            if (bpSystolicList[0].x < minTime) minTime = bpSystolicList[0].x

            let minH = ((hList[0].y * 100) - 10), maxH = ((hList[0].y * 100) + 10)
            let minW = (wList[0].y - 1), maxW = (wList[0].y + 1)
            let minBP = (bpDiastolicList[0].y - 1), maxBP = (bpSystolicList[0].y)

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

            // تنظیم محدوده محورها
            chartView.y1Axis.min = minH
            chartView.y1Axis.max = maxH

            chartView.y2Axis.min = minW
            chartView.y2Axis.max = maxW

            let bpMargin = (maxBP - minBP) * 0.1
            chartView.y3Axis.min = minBP - bpMargin
            chartView.y3Axis.max = maxBP + bpMargin

            chartView.xAxis.min = new Date(minTime)
            chartView.xAxis.max = new Date(Date.now())
        }
    }
}
