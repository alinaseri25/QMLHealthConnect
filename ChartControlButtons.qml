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
    required property var oxygenSaturationSeries

    // ✅ اضافه کردن property برای دسترسی به محورها
    property var chartView: null

    signal updateRequested()

    /**
     * ✅ تنظیم visibility اولیه برای تمام سری‌ها و محورها
     *
     * @param showHeight نمایش قد
     * @param showWeight نمایش وزن
     * @param showBP نمایش فشار خون
     * @param showHR نمایش ضربان قلب
     * @param showBG نمایش قند خون
     * @param showSpO2 نمایش اشباع اکسیژن (جدید)
     */
    function setInitialVisibility(showHeight, showWeight, showBP, showHR, showBG, showSpO2) {
        // ✅ تنظیم visibility سری‌ها
        heightSeries.visible = showHeight
        weightSeries.visible = showWeight
        bpSystolicSeries.visible = showBP
        bpDiastolicSeries.visible = showBP
        heartRateSeries.visible = showHR
        bloodGlucoseSeries.visible = showBG
        oxygenSaturationSeries.visible = showSpO2

        // ✅ تنظیم visibility محورها
        if (root.chartView) {
            root.chartView.heightAxisVisible = showHeight
            root.chartView.weightAxisVisible = showWeight
            root.chartView.bpAxisVisible = showBP
            root.chartView.heartRateAxisVisible = showHR
            root.chartView.bloodGlucoseAxisVisible = showBG
            root.chartView.oxygenSaturationAxisVisible = showSpO2
        }
    }

    // ═════════════════════════════════════════════════════════════
    // 🔘 دکمه‌های کنترل نمایش داده‌ها
    // ═════════════════════════════════════════════════════════════

    CButton {
        themeManager: root.themeManager
        text: "HR"
        width: 50
        height: 35

        // ✅ نشانگر وضعیت فعال/غیرفعال
        opacity: heartRateSeries.visible ? 1.0 : 0.5

        onClicked: {
            heartRateSeries.visible = !heartRateSeries.visible

            // ✅ کنترل محور
            if (root.chartView) {
                root.chartView.heartRateAxisVisible = heartRateSeries.visible
            }
        }

        Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    CButton {
        themeManager: root.themeManager
        text: "BG"
        width: 50
        height: 35

        opacity: bloodGlucoseSeries.visible ? 1.0 : 0.5

        onClicked: {
            bloodGlucoseSeries.visible = !bloodGlucoseSeries.visible

            // ✅ کنترل محور
            if (root.chartView) {
                root.chartView.bloodGlucoseAxisVisible = bloodGlucoseSeries.visible
            }
        }

        Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    // ✅ دکمه جدید SpO₂
    CButton {
        themeManager: root.themeManager
        text: "SpO₂"
        width: 60
        height: 35

        opacity: oxygenSaturationSeries.visible ? 1.0 : 0.5

        onClicked: {
            oxygenSaturationSeries.visible = !oxygenSaturationSeries.visible

            // ✅ کنترل محور
            if (root.chartView) {
                root.chartView.oxygenSaturationAxisVisible = oxygenSaturationSeries.visible
            }
        }

        Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    CButton {
        themeManager: root.themeManager
        text: "Height"
        width: 70
        height: 35

        opacity: heightSeries.visible ? 1.0 : 0.5

        onClicked: {
            heightSeries.visible = !heightSeries.visible

            // ✅ کنترل محور
            if (root.chartView) {
                root.chartView.heightAxisVisible = heightSeries.visible
            }
        }

        Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    CButton {
        themeManager: root.themeManager
        text: "Weight"
        width: 70
        height: 35

        opacity: weightSeries.visible ? 1.0 : 0.5

        onClicked: {
            weightSeries.visible = !weightSeries.visible

            // ✅ کنترل محور
            if (root.chartView) {
                root.chartView.weightAxisVisible = weightSeries.visible
            }
        }

        Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    CButton {
        themeManager: root.themeManager
        text: "BP (S)"
        width: 70
        height: 35

        opacity: bpSystolicSeries.visible ? 1.0 : 0.5

        onClicked: {
            bpSystolicSeries.visible = !bpSystolicSeries.visible

            // ✅ کنترل محور فشار خون (فقط وقتی هر دو مخفی باشند)
            updateBPAxisVisibility()
        }

        Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    CButton {
        themeManager: root.themeManager
        text: "BP (D)"
        width: 70
        height: 35

        opacity: bpDiastolicSeries.visible ? 1.0 : 0.5

        onClicked: {
            bpDiastolicSeries.visible = !bpDiastolicSeries.visible

            // ✅ کنترل محور فشار خون (فقط وقتی هر دو مخفی باشند)
            updateBPAxisVisibility()
        }

        Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    CButton {
        themeManager: root.themeManager
        text: "Update"
        width: 80
        height: 35

        // ✅ استایل متفاوت برای دکمه Update
        // می‌توانید در CButton.qml یک property برای highlighted اضافه کنید

        onClicked: updateRequested()
    }

    // ═════════════════════════════════════════════════════════════
    // 🔧 توابع کمکی
    // ═════════════════════════════════════════════════════════════

    /**
     * ✅ تابع برای کنترل visibility محور فشار خون
     * محور فقط وقتی مخفی می‌شود که هر دو سری (سیستولیک و دیاستولیک) مخفی باشند
     */
    function updateBPAxisVisibility() {
        if (root.chartView) {
            // محور نمایش داده شود اگر حداقل یکی از سری‌ها visible باشد
            root.chartView.bpAxisVisible = bpSystolicSeries.visible || bpDiastolicSeries.visible
        }
    }

    /**
     * ✅ تابع کمکی: مخفی کردن تمام سری‌ها
     */
    function hideAll() {
        heightSeries.visible = false
        weightSeries.visible = false
        bpSystolicSeries.visible = false
        bpDiastolicSeries.visible = false
        heartRateSeries.visible = false
        bloodGlucoseSeries.visible = false
        oxygenSaturationSeries.visible = false

        if (root.chartView) {
            root.chartView.heightAxisVisible = false
            root.chartView.weightAxisVisible = false
            root.chartView.bpAxisVisible = false
            root.chartView.heartRateAxisVisible = false
            root.chartView.bloodGlucoseAxisVisible = false
            root.chartView.oxygenSaturationAxisVisible = false
        }
    }

    /**
     * ✅ تابع کمکی: نمایش تمام سری‌ها
     */
    function showAll() {
        heightSeries.visible = true
        weightSeries.visible = true
        bpSystolicSeries.visible = true
        bpDiastolicSeries.visible = true
        heartRateSeries.visible = true
        bloodGlucoseSeries.visible = true
        oxygenSaturationSeries.visible = true

        if (root.chartView) {
            root.chartView.heightAxisVisible = true
            root.chartView.weightAxisVisible = true
            root.chartView.bpAxisVisible = true
            root.chartView.heartRateAxisVisible = true
            root.chartView.bloodGlucoseAxisVisible = true
            root.chartView.oxygenSaturationAxisVisible = true
        }
    }

    /**
     * ✅ تابع کمکی: toggle وضعیت یک سری خاص
     */
    function toggleSeries(seriesName) {
        switch(seriesName.toLowerCase()) {
            case "height":
                heightSeries.visible = !heightSeries.visible
                if (root.chartView) root.chartView.heightAxisVisible = heightSeries.visible
                break
            case "weight":
                weightSeries.visible = !weightSeries.visible
                if (root.chartView) root.chartView.weightAxisVisible = weightSeries.visible
                break
            case "bp":
                bpSystolicSeries.visible = !bpSystolicSeries.visible
                bpDiastolicSeries.visible = !bpDiastolicSeries.visible
                updateBPAxisVisibility()
                break
            case "hr":
                heartRateSeries.visible = !heartRateSeries.visible
                if (root.chartView) root.chartView.heartRateAxisVisible = heartRateSeries.visible
                break
            case "bg":
                bloodGlucoseSeries.visible = !bloodGlucoseSeries.visible
                if (root.chartView) root.chartView.bloodGlucoseAxisVisible = bloodGlucoseSeries.visible
                break
            case "spo2":
                oxygenSaturationSeries.visible = !oxygenSaturationSeries.visible
                if (root.chartView) root.chartView.oxygenSaturationAxisVisible = oxygenSaturationSeries.visible
                break
            default:
                console.warn("❌ Unknown series:", seriesName)
        }
    }

    /**
     * ✅ دریافت تعداد سری‌های visible
     */
    function getVisibleSeriesCount() {
        let count = 0
        if (heightSeries.visible) count++
        if (weightSeries.visible) count++
        if (bpSystolicSeries.visible || bpDiastolicSeries.visible) count++
        if (heartRateSeries.visible) count++
        if (bloodGlucoseSeries.visible) count++
        if (oxygenSaturationSeries.visible) count++
        return count
    }

    Component.onCompleted: {
        // ✅ تنظیم وضعیت اولیه بلافاصله بعد از بارگذاری
        setInitialVisibility(
            false,  // Height
            true,  // Weight
            true,  // BP
            false,   // Heart Rate (مثلاً فقط این یکی نمایش داده شود)
            false,  // Blood Glucose
            false   // SpO2
        )
    }
}
