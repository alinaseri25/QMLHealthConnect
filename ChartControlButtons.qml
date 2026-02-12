import QtQuick

Row {
    id: root

    spacing: 10

    required property var themeManager

    required property var heightSeries
    required property var weightSeries
    required property var bpSystolicSeries
    required property var bpDiastolicSeries
    required property var heartRateSeries
    required property var bloodGlucoseSeries

    // ✅ اضافه کردن property برای دسترسی به محورها
    property var chartView: null

    signal updateRequested()

    function setInitialVisibility(showHeight, showWeight, showBP, showHR, showBG) {
        heightSeries.visible = showHeight
        weightSeries.visible = showWeight
        bpSystolicSeries.visible = showBP
        bpDiastolicSeries.visible = showBP
        heartRateSeries.visible = showHR
        bloodGlucoseSeries.visible = showBG

        if (root.chartView) {
            root.chartView.heightAxisVisible = showHeight
            root.chartView.weightAxisVisible = showWeight
            root.chartView.bpAxisVisible = showBP
            root.chartView.heartRateAxisVisible = showHR
            root.chartView.bloodGlucoseAxisVisible = showBG
        }
    }

    CButton {
        themeManager: root.themeManager
        text: "HR"
        width: 50
        height: 35
        onClicked: {
            heartRateSeries.visible = !heartRateSeries.visible
            // ✅ کنترل محور
            if (root.chartView) {
                root.chartView.heartRateAxisVisible = heartRateSeries.visible
            }
        }
    }

    CButton {
        themeManager: root.themeManager
        text: "BG"
        width: 50
        height: 35
        onClicked: {
            bloodGlucoseSeries.visible = !bloodGlucoseSeries.visible
            // ✅ کنترل محور
            if (root.chartView) {
                root.chartView.bloodGlucoseAxisVisible = bloodGlucoseSeries.visible
            }
        }
    }

    CButton {
        themeManager: root.themeManager
        text: "Height"
        width: 70
        height: 35
        onClicked: {
            heightSeries.visible = !heightSeries.visible
            // ✅ کنترل محور
            if (root.chartView) {
                root.chartView.heightAxisVisible = heightSeries.visible
            }
        }
    }

    CButton {
        themeManager: root.themeManager
        text: "Weight"
        width: 70
        height: 35
        onClicked: {
            weightSeries.visible = !weightSeries.visible
            // ✅ کنترل محور
            if (root.chartView) {
                root.chartView.weightAxisVisible = weightSeries.visible
            }
        }
    }

    CButton {
        themeManager: root.themeManager
        text: "BP (S)"
        width: 70
        height: 35
        onClicked: {
            bpSystolicSeries.visible = !bpSystolicSeries.visible
            // ✅ کنترل محور فشار خون (فقط وقتی هر دو مخفی باشن)
            updateBPAxisVisibility()
        }
    }

    CButton {
        themeManager: root.themeManager
        text: "BP (D)"
        width: 70
        height: 35
        onClicked: {
            bpDiastolicSeries.visible = !bpDiastolicSeries.visible
            // ✅ کنترل محور فشار خون (فقط وقتی هر دو مخفی باشن)
            updateBPAxisVisibility()
        }
    }

    CButton {
        themeManager: root.themeManager
        text: "Update"
        width: 80
        height: 35
        onClicked: updateRequested()
    }

    // ✅ تابع برای کنترل visibility محور فشار خون
    function updateBPAxisVisibility() {
        if (root.chartView) {
            // محور فقط وقتی مخفی می‌شه که هر دو سری مخفی باشن
            root.chartView.bpAxisVisible = bpSystolicSeries.visible || bpDiastolicSeries.visible
        }
    }
}
