import QtQuick

Row {
    id: root

    spacing: 10

    // Properties برای دسترسی به سری‌ها
    property var heightSeries
    property var weightSeries
    property var bpSystolicSeries
    property var bpDiastolicSeries
    property var themeManager

    signal updateRequested()

    CButton {
        themeManager: themeManager
        text: "قد"
        width: 70
        height: 35
        onClicked: heightSeries.visible = !heightSeries.visible}

    CButton {
        themeManager: themeManager
        text: "وزن"
        width: 70
        height: 35
        onClicked: weightSeries.visible = !weightSeries.visible
    }

    CButton {
        themeManager: themeManager
        text: "BP (S)"
        width: 70
        height: 35
        onClicked: bpSystolicSeries.visible = !bpSystolicSeries.visible
    }

    CButton {
        themeManager: themeManager
        text: "BP (D)"
        width: 70
        height: 35
        onClicked: bpDiastolicSeries.visible = !bpDiastolicSeries.visible
    }

    CButton {
        themeManager: themeManager
        text: "بروزرسانی نمودار"
        width: 100
        height: 35
        onClicked: updateRequested()
    }
}
