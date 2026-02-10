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
        themeManager: root.themeManager
        text: "قد"
        width: 70
        height: 35
        onClicked: heightSeries.visible = !heightSeries.visible}

    CButton {
        themeManager: root.themeManager
        text: "وزن"
        width: 70
        height: 35
        onClicked: weightSeries.visible = !weightSeries.visible
    }

    CButton {
        themeManager: root.themeManager
        text: "BP (S)"
        width: 70
        height: 35
        onClicked: bpSystolicSeries.visible = !bpSystolicSeries.visible
    }

    CButton {
        themeManager: root.themeManager
        text: "BP (D)"
        width: 70
        height: 35
        onClicked: bpDiastolicSeries.visible = !bpDiastolicSeries.visible
    }

    CButton {
        themeManager: root.themeManager
        text: "بروزرسانی نمودار"
        width: 120
        height: 35
        onClicked: updateRequested()
    }
}
