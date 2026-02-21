import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: root

    required property var themeManager

    signal confirmed(date selectedDateTime)
    signal cancelled()

    property int selectedYear:   new Date().getFullYear()
    property int selectedMonth:  new Date().getMonth() + 1
    property int selectedDay:    new Date().getDate()
    property int selectedHour:   new Date().getHours()
    property int selectedMinute: new Date().getMinutes()
    property int selectedSecond: new Date().getSeconds()

    // ── تابع ساخت Date از state فعلی ──
    function toDateTime() {
        return new Date(
            selectedYear,
            selectedMonth - 1,
            selectedDay,
            selectedHour,
            selectedMinute,
            selectedSecond
        )
    }

    // ── ریست به زمان حال ──
    function resetToNow() {
        var now = new Date()
        selectedYear   = now.getFullYear()
        selectedMonth  = now.getMonth() + 1
        selectedDay    = now.getDate()
        selectedHour   = now.getHours()
        selectedMinute = now.getMinutes()
        selectedSecond = now.getSeconds()
    }

    // ── باز کردن با تاریخ دلخواه (بدون reset به now) ──
    function openWithDate(d) {
        if (!d || !(d instanceof Date) || isNaN(d.getTime())) {
            resetToNow()
        } else {
            selectedYear   = d.getFullYear()
            selectedMonth  = d.getMonth() + 1
            selectedDay    = d.getDate()
            selectedHour   = d.getHours()
            selectedMinute = d.getMinutes()
            selectedSecond = d.getSeconds()
        }
        root.open()
    }

    // ── تعداد روزهای ماه ──
    function daysInMonth(year, month) {
        return new Date(year, month, 0).getDate()
    }

    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape
    anchors.centerIn: Overlay.overlay

    width:  Overlay.overlay ? Math.min(Overlay.overlay.width  * 0.92, 380) : 320
    height: Overlay.overlay ? Math.min(Overlay.overlay.height * 0.72, 500) : 460

    padding: 0
    topPadding: 0; bottomPadding: 0; leftPadding: 0; rightPadding: 0

    // ✅ Fix اصلی: animation رو null کن تا flicker نداشته باشیم
    enter: null
    exit:  null

    Overlay.modal: Rectangle {
        color: "#BB000000"
    }

    background: Rectangle {
        radius: 16
        border.width: 1
        color:        root.themeManager.isDarkMode ? "#FF1e1e2e" : "#FFffffff"
        border.color: root.themeManager.isDarkMode ? "#FF585b70" : "#FFbbbbbb"
    }

    contentItem: ColumnLayout {
        spacing: 0
        width:  root.width
        height: root.height

        Item { Layout.fillWidth: true; height: root.height * 0.035 }

        Text {
            text: "📅 انتخاب تاریخ و زمان"
            color: root.themeManager.primaryTextColor
            font.pixelSize: Math.max(12, root.width * 0.044)
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        Item { Layout.fillWidth: true; height: root.height * 0.025 }

        // ── تاریخ: سال / ماه / روز ──
        RowLayout {
            spacing: root.width * 0.02
            Layout.fillWidth: true
            Layout.leftMargin:  root.width * 0.04
            Layout.rightMargin: root.width * 0.04

            // سال
            ColumnLayout {
                spacing: 3; Layout.fillWidth: true
                Text { text: "سال"; color: root.themeManager.secondaryTextColor; font.pixelSize: Math.max(9, root.width * 0.031); Layout.alignment: Qt.AlignHCenter }
                SpinBox {
                    id: yearSpin
                    from: 2000; to: 2100; value: root.selectedYear
                    Layout.fillWidth: true; implicitHeight: root.height * 0.095
                    onValueChanged: root.selectedYear = value
                    contentItem: TextInput {
                        text: yearSpin.textFromValue(yearSpin.value, yearSpin.locale)
                        color: root.themeManager.primaryTextColor; font.pixelSize: Math.max(11, root.width * 0.036)
                        horizontalAlignment: Qt.AlignHCenter; verticalAlignment: Qt.AlignVCenter
                        readOnly: !yearSpin.editable; validator: yearSpin.validator
                    }
                    background: Rectangle { color: root.themeManager.isDarkMode ? "#FF313244" : "#FFf0f0f0"; radius: 8; border.color: root.themeManager.inputBorderColor; border.width: 1 }
                    up.indicator: Rectangle {
                        x: parent.width - width; width: root.width * 0.065; height: parent.height / 2
                        color: parent.up.pressed ? root.themeManager.accentPressed : root.themeManager.accentColor; radius: 4
                        Text { text: "▲"; font.pixelSize: 7; color: "#fff"; anchors.centerIn: parent }
                    }
                    down.indicator: Rectangle {
                        x: parent.width - width; y: parent.height / 2; width: root.width * 0.065; height: parent.height / 2
                        color: parent.down.pressed ? root.themeManager.accentPressed : root.themeManager.accentColor; radius: 4
                        Text { text: "▼"; font.pixelSize: 7; color: "#fff"; anchors.centerIn: parent }
                    }
                }
            }

            // ماه
            ColumnLayout {
                spacing: 3; Layout.fillWidth: true
                Text { text: "ماه"; color: root.themeManager.secondaryTextColor; font.pixelSize: Math.max(9, root.width * 0.031); Layout.alignment: Qt.AlignHCenter }
                SpinBox {
                    id: monthSpin
                    from: 1; to: 12; value: root.selectedMonth
                    Layout.fillWidth: true; implicitHeight: root.height * 0.095
                    onValueChanged: root.selectedMonth = value
                    contentItem: TextInput {
                        text: monthSpin.textFromValue(monthSpin.value, monthSpin.locale)
                        color: root.themeManager.primaryTextColor; font.pixelSize: Math.max(11, root.width * 0.036)
                        horizontalAlignment: Qt.AlignHCenter; verticalAlignment: Qt.AlignVCenter
                        readOnly: !monthSpin.editable; validator: monthSpin.validator
                    }
                    background: Rectangle { color: root.themeManager.isDarkMode ? "#FF313244" : "#FFf0f0f0"; radius: 8; border.color: root.themeManager.inputBorderColor; border.width: 1 }
                    up.indicator: Rectangle {
                        x: parent.width - width; width: root.width * 0.065; height: parent.height / 2
                        color: parent.up.pressed ? root.themeManager.accentPressed : root.themeManager.accentColor; radius: 4
                        Text { text: "▲"; font.pixelSize: 7; color: "#fff"; anchors.centerIn: parent }
                    }
                    down.indicator: Rectangle {
                        x: parent.width - width; y: parent.height / 2; width: root.width * 0.065; height: parent.height / 2
                        color: parent.down.pressed ? root.themeManager.accentPressed : root.themeManager.accentColor; radius: 4
                        Text { text: "▼"; font.pixelSize: 7; color: "#fff"; anchors.centerIn: parent }
                    }
                }
            }

            // روز
            ColumnLayout {
                spacing: 3; Layout.fillWidth: true
                Text { text: "روز"; color: root.themeManager.secondaryTextColor; font.pixelSize: Math.max(9, root.width * 0.031); Layout.alignment: Qt.AlignHCenter }
                SpinBox {
                    id: daySpin
                    from: 1; to: root.daysInMonth(root.selectedYear, root.selectedMonth); value: root.selectedDay
                    Layout.fillWidth: true; implicitHeight: root.height * 0.095
                    onValueChanged: root.selectedDay = value
                    contentItem: TextInput {
                        text: daySpin.textFromValue(daySpin.value, daySpin.locale)
                        color: root.themeManager.primaryTextColor; font.pixelSize: Math.max(11, root.width * 0.036)
                        horizontalAlignment: Qt.AlignHCenter; verticalAlignment: Qt.AlignVCenter
                        readOnly: !daySpin.editable; validator: daySpin.validator
                    }
                    background: Rectangle { color: root.themeManager.isDarkMode ? "#FF313244" : "#FFf0f0f0"; radius: 8; border.color: root.themeManager.inputBorderColor; border.width: 1 }
                    up.indicator: Rectangle {
                        x: parent.width - width; width: root.width * 0.065; height: parent.height / 2
                        color: parent.up.pressed ? root.themeManager.accentPressed : root.themeManager.accentColor; radius: 4
                        Text { text: "▲"; font.pixelSize: 7; color: "#fff"; anchors.centerIn: parent }
                    }
                    down.indicator: Rectangle {
                        x: parent.width - width; y: parent.height / 2; width: root.width * 0.065; height: parent.height / 2
                        color: parent.down.pressed ? root.themeManager.accentPressed : root.themeManager.accentColor; radius: 4
                        Text { text: "▼"; font.pixelSize: 7; color: "#fff"; anchors.centerIn: parent }
                    }
                }
            }
        }

        Item { Layout.fillWidth: true; height: root.height * 0.02 }

        // ── زمان: ساعت / دقیقه / ثانیه ──
        RowLayout {
            spacing: root.width * 0.015
            Layout.fillWidth: true
            Layout.leftMargin:  root.width * 0.04
            Layout.rightMargin: root.width * 0.04

            // ساعت
            ColumnLayout {
                spacing: 3; Layout.fillWidth: true
                Text { text: "ساعت"; color: root.themeManager.secondaryTextColor; font.pixelSize: Math.max(9, root.width * 0.031); Layout.alignment: Qt.AlignHCenter }
                SpinBox {
                    id: hourSpin
                    from: 0; to: 23; value: root.selectedHour
                    Layout.fillWidth: true; implicitHeight: root.height * 0.095
                    onValueChanged: root.selectedHour = value
                    textFromValue: function(v) { return String(v).padStart(2, "0") }
                    contentItem: TextInput {
                        text: hourSpin.textFromValue(hourSpin.value, hourSpin.locale)
                        color: root.themeManager.primaryTextColor; font.pixelSize: Math.max(11, root.width * 0.036)
                        horizontalAlignment: Qt.AlignHCenter; verticalAlignment: Qt.AlignVCenter
                        readOnly: !hourSpin.editable; validator: hourSpin.validator
                    }
                    background: Rectangle { color: root.themeManager.isDarkMode ? "#FF313244" : "#FFf0f0f0"; radius: 8; border.color: root.themeManager.inputBorderColor; border.width: 1 }
                    up.indicator: Rectangle {
                        x: parent.width - width; width: root.width * 0.065; height: parent.height / 2
                        color: parent.up.pressed ? root.themeManager.accentPressed : root.themeManager.accentColor; radius: 4
                        Text { text: "▲"; font.pixelSize: 7; color: "#fff"; anchors.centerIn: parent }
                    }
                    down.indicator: Rectangle {
                        x: parent.width - width; y: parent.height / 2; width: root.width * 0.065; height: parent.height / 2
                        color: parent.down.pressed ? root.themeManager.accentPressed : root.themeManager.accentColor; radius: 4
                        Text { text: "▼"; font.pixelSize: 7; color: "#fff"; anchors.centerIn: parent }
                    }
                }
            }

            Text { text: ":"; color: root.themeManager.primaryTextColor; font.pixelSize: root.height * 0.045; font.bold: true; Layout.alignment: Qt.AlignVCenter; bottomPadding: root.height * 0.005 }

            // دقیقه
            ColumnLayout {
                spacing: 3; Layout.fillWidth: true
                Text { text: "دقیقه"; color: root.themeManager.secondaryTextColor; font.pixelSize: Math.max(9, root.width * 0.031); Layout.alignment: Qt.AlignHCenter }
                SpinBox {
                    id: minuteSpin
                    from: 0; to: 59; value: root.selectedMinute
                    Layout.fillWidth: true; implicitHeight: root.height * 0.095
                    onValueChanged: root.selectedMinute = value
                    textFromValue: function(v) { return String(v).padStart(2, "0") }
                    contentItem: TextInput {
                        text: minuteSpin.textFromValue(minuteSpin.value, minuteSpin.locale)
                        color: root.themeManager.primaryTextColor; font.pixelSize: Math.max(11, root.width * 0.036)
                        horizontalAlignment: Qt.AlignHCenter; verticalAlignment: Qt.AlignVCenter
                        readOnly: !minuteSpin.editable; validator: minuteSpin.validator
                    }
                    background: Rectangle { color: root.themeManager.isDarkMode ? "#FF313244" : "#FFf0f0f0"; radius: 8; border.color: root.themeManager.inputBorderColor; border.width: 1 }
                    up.indicator: Rectangle {
                        x: parent.width - width; width: root.width * 0.065; height: parent.height / 2
                        color: parent.up.pressed ? root.themeManager.accentPressed : root.themeManager.accentColor; radius: 4
                        Text { text: "▲"; font.pixelSize: 7; color: "#fff"; anchors.centerIn: parent }
                    }
                    down.indicator: Rectangle {
                        x: parent.width - width; y: parent.height / 2; width: root.width * 0.065; height: parent.height / 2
                        color: parent.down.pressed ? root.themeManager.accentPressed : root.themeManager.accentColor; radius: 4
                        Text { text: "▼"; font.pixelSize: 7; color: "#fff"; anchors.centerIn: parent }
                    }
                }
            }

            Text { text: ":"; color: root.themeManager.primaryTextColor; font.pixelSize: root.height * 0.045; font.bold: true; Layout.alignment: Qt.AlignVCenter; bottomPadding: root.height * 0.005 }

            // ثانیه
            ColumnLayout {
                spacing: 3; Layout.fillWidth: true
                Text { text: "ثانیه"; color: root.themeManager.secondaryTextColor; font.pixelSize: Math.max(9, root.width * 0.031); Layout.alignment: Qt.AlignHCenter }
                SpinBox {
                    id: secondSpin
                    from: 0; to: 59; value: root.selectedSecond
                    Layout.fillWidth: true; implicitHeight: root.height * 0.095
                    onValueChanged: root.selectedSecond = value
                    textFromValue: function(v) { return String(v).padStart(2, "0") }
                    contentItem: TextInput {
                        text: secondSpin.textFromValue(secondSpin.value, secondSpin.locale)
                        color: root.themeManager.primaryTextColor; font.pixelSize: Math.max(11, root.width * 0.036)
                        horizontalAlignment: Qt.AlignHCenter; verticalAlignment: Qt.AlignVCenter
                        readOnly: !secondSpin.editable; validator: secondSpin.validator
                    }
                    background: Rectangle { color: root.themeManager.isDarkMode ? "#FF313244" : "#FFf0f0f0"; radius: 8; border.color: root.themeManager.inputBorderColor; border.width: 1 }
                    up.indicator: Rectangle {
                        x: parent.width - width; width: root.width * 0.065; height: parent.height / 2
                        color: parent.up.pressed ? root.themeManager.accentPressed : root.themeManager.accentColor; radius: 4
                        Text { text: "▲"; font.pixelSize: 7; color: "#fff"; anchors.centerIn: parent }
                    }
                    down.indicator: Rectangle {
                        x: parent.width - width; y: parent.height / 2; width: root.width * 0.065; height: parent.height / 2
                        color: parent.down.pressed ? root.themeManager.accentPressed : root.themeManager.accentColor; radius: 4
                        Text { text: "▼"; font.pixelSize: 7; color: "#fff"; anchors.centerIn: parent }
                    }
                }
            }
        }

        Item { Layout.fillWidth: true; height: root.height * 0.02 }

        // ── پیش‌نمایش ──
        RowLayout {
            spacing: root.width * 0.02
            Layout.fillWidth: true
            Layout.leftMargin:  root.width * 0.04
            Layout.rightMargin: root.width * 0.04

            Rectangle {
                Layout.fillWidth: true
                height: root.height * 0.09
                radius: 8
                color: root.themeManager.isDarkMode ? "#FF313244" : "#FFf0f0f0"
                border.color: root.themeManager.panelBorderColor
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: Qt.formatDateTime(root.toDateTime(), "yyyy/MM/dd   hh:mm:ss")
                    color: root.themeManager.accentColor
                    font.pixelSize: Math.max(12, root.width * 0.042)
                    font.bold: true
                }
            }

            // دکمه برو به زمان حال داخل DateTimePicker
            Item {
                id: pickerNowBtnWrapper
                width: root.width * 0.12
                height: root.height * 0.09

                Rectangle {
                    id: pickerNowBtn
                    anchors.fill: parent
                    radius: 8
                    color: pickerNowMa.pressed
                        ? root.themeManager.accentPressed
                        : (pickerNowMa.containsMouse ? root.themeManager.accentColor : "transparent")
                    border.color: root.themeManager.inputBorderColor
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: "📅"
                        font.pixelSize: Math.max(14, root.width * 0.048)
                    }

                    MouseArea {
                        id: pickerNowMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.resetToNow()
                    }
                }
            }
        }

        Item { Layout.fillWidth: true; height: root.height * 0.025 }

        // ── دکمه‌ها ──
        RowLayout {
            spacing: root.width * 0.03
            Layout.fillWidth: true
            Layout.leftMargin:  root.width * 0.04
            Layout.rightMargin: root.width * 0.04

            Rectangle {
                Layout.fillWidth: true
                height: root.height * 0.1
                radius: 10
                color: cancelMa.pressed
                    ? (root.themeManager.isDarkMode ? "#FF505050" : "#FFcccccc")
                    : (root.themeManager.isDarkMode ? "#FF3a3a3a" : "#FFe0e0e0")
                Behavior on color { ColorAnimation { duration: 120 } }
                border.color: root.themeManager.panelBorderColor; border.width: 1
                Text { anchors.centerIn: parent; text: "انصراف"; color: root.themeManager.primaryTextColor; font.pixelSize: Math.max(12, root.width * 0.04) }
                MouseArea { id: cancelMa; anchors.fill: parent; onClicked: { root.cancelled(); root.close() } }
            }

            Rectangle {
                Layout.fillWidth: true
                height: root.height * 0.1
                radius: 10
                color: confirmMa.pressed ? root.themeManager.accentPressed : root.themeManager.accentColor
                Behavior on color { ColorAnimation { duration: 120 } }
                Text { anchors.centerIn: parent; text: "تأیید"; color: "#ffffff"; font.pixelSize: Math.max(12, root.width * 0.04); font.bold: true }
                MouseArea { id: confirmMa; anchors.fill: parent; onClicked: { root.confirmed(root.toDateTime()); root.close() } }
            }
        }

        Item { Layout.fillWidth: true; height: root.height * 0.03 }
    }
}
