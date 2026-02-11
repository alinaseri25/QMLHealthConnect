import QtQuick
import QtQuick.Controls

Rectangle {
    id: root

    property bool expanded: true

    // ✅ FIX: استفاده از required برای اطمینان از ارسال themeManager
    required property var themeManager

    // Signals برای ارسال داده
    signal heightSubmitted(double value)
    signal weightSubmitted(double value)
    signal bloodPressureSubmitted(int systolic, int diastolic)

    // Properties برای نمایش وضعیت
    property alias heightStatusText: heightStatus.text
    property alias heightStatusColor: heightStatus.color
    property alias weightStatusText: weightStatus.text
    property alias weightStatusColor: weightStatus.color
    property alias bpStatusText: bpStatus.text
    property alias bpStatusColor: bpStatus.color

    width: expanded ? 330 : 0
    height: parent.height

    // ✅ FIX: اطمینان از استفاده درست از themeManager
    color: root.themeManager.surfaceColor
    border.color: root.themeManager.panelBorderColor
    border.width: expanded ? 1 : 0
    clip: true

    Behavior on width {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }
    }

    Behavior on border.color { ColorAnimation { duration: 300 } }

    ScrollView {
        anchors.fill: parent
        visible: expanded
        clip: true

        background: Rectangle {
                color: root.themeManager.cardColor
            }

        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        Column {
            width: root.width - 20
            spacing: 20
            padding: 15

            // ===== بخش قد =====
            Column {
                width: parent.width
                spacing: 10

                Text {
                    text: "📏 قد (متر)"
                    font.pixelSize: 16
                    font.bold: true
                    color: root.themeManager.primaryTextColor
                    Behavior on color { ColorAnimation { duration: 300 } }
                }

                TextField {
                    id: heightInput
                    width: parent.width
                    placeholderText: "مثال: 1.75"
                    placeholderTextColor: root.themeManager.inputPlaceholderColor

                    background: Rectangle {
                        color: root.themeManager.inputBackgroundColor
                        border.color: root.themeManager.inputBorderColor
                        border.width: 1
                        radius: 4

                        Behavior on color { ColorAnimation { duration: 300 } }
                        Behavior on border.color { ColorAnimation { duration: 300 } }
                    }

                    color: root.themeManager.primaryTextColor
                    Behavior on color { ColorAnimation { duration: 300 } }

                    KeyNavigation.tab: heightRegister
                }

                CButton {
                    id: heightRegister
                    text: "ثبت قد"
                    width: parent.width
                    height: 40
                    themeManager: root.themeManager  // ✅ ارسال theme به دکمه

                    onClicked: {
                        let value = parseFloat(heightInput.text)
                        if (!isNaN(value) && value > 0) {
                            root.heightSubmitted(value)
                        } else {
                            heightStatus.text = "❌ مقدار نامعتبر"
                            heightStatus.color = "red"
                        }
                    }

                    KeyNavigation.tab: weightInput
                }

                Text {
                    id: heightStatus
                    width: parent.width
                    wrapMode: Text.WordWrap
                    font.pixelSize: 11
                    color: "gray"
                }
            }

            // ===== بخش وزن =====
            Column {
                width: parent.width
                spacing: 10

                Text {
                    text: "⚖️ وزن (کیلوگرم)"
                    font.pixelSize: 16
                    font.bold: true
                    color: root.themeManager.primaryTextColor

                    Behavior on color { ColorAnimation { duration: 300 } }
                }

                TextField {
                    id: weightInput
                    width: parent.width
                    placeholderText: "مثال: 70.5"
                    placeholderTextColor: root.themeManager.inputPlaceholderColor

                    background: Rectangle {
                        color:  root.themeManager.inputBackgroundColor
                        border.color: root.themeManager.inputBorderColor
                        border.width: 1
                        radius: 4

                        Behavior on color { ColorAnimation { duration: 300 } }
                        Behavior on border.color { ColorAnimation { duration: 300 } }
                    }

                    color: root.themeManager.primaryTextColor

                    Behavior on color { ColorAnimation { duration: 300 } }
                    KeyNavigation.tab: weightRegister
                }

                CButton {
                    id: weightRegister
                    text: "ثبت وزن"
                    width: parent.width
                    height: 40
                    themeManager: root.themeManager  // ✅ ارسال theme به دکمه

                    onClicked: {
                        let value = parseFloat(weightInput.text)
                        if (!isNaN(value) && value > 0) {
                            root.weightSubmitted(value)
                        } else {
                            weightStatus.text = "❌ مقدار نامعتبر"
                            weightStatus.color = "red"
                        }
                    }
                    KeyNavigation.tab: systolicInput
                }

                Text {
                    id: weightStatus
                    width: parent.width
                    wrapMode: Text.WordWrap
                    font.pixelSize: 11
                    color: "gray"
                }
            }

            // ===== بخش فشار خون =====
            Column {
                width: parent.width
                spacing: 10

                Text {
                    text: "💉 فشار خون (mmHg)"
                    font.pixelSize: 16
                    font.bold: true
                    color: root.themeManager.primaryTextColor

                    Behavior on color { ColorAnimation { duration: 300 } }
                }

                Row {
                    width: parent.width
                    spacing: 10

                    TextField {
                        id: diastolicInput
                        width: (parent.width - 10) / 2
                        placeholderText: "دیاستولیک (80)"
                        placeholderTextColor: root.themeManager.inputPlaceholderColor

                        background: Rectangle {
                            color: root.themeManager.inputBackgroundColor
                            border.color: root.themeManager.inputBorderColor
                            border.width: 2
                            radius: 4

                            Behavior on color { ColorAnimation { duration: 300 } }
                            Behavior on border.color { ColorAnimation { duration: 300 } }
                        }

                        color: root.themeManager.primaryTextColor

                        Behavior on color { ColorAnimation { duration: 300 } }
                        KeyNavigation.tab: persureRegister
                    }

                    TextField {
                        id: systolicInput
                        width: (parent.width - 10) / 2
                        placeholderText: "سیستولیک (120)"
                        placeholderTextColor: root.themeManager.inputPlaceholderColor

                        background: Rectangle {
                            color: root.themeManager.inputBackgroundColor
                            border.color: root.themeManager.inputBorderColor
                            border.width: 2
                            radius: 4

                            Behavior on color { ColorAnimation { duration: 300 } }
                            Behavior on border.color { ColorAnimation { duration: 300 } }
                        }

                        color: root.themeManager.primaryTextColor

                        Behavior on color { ColorAnimation { duration: 300 } }
                        KeyNavigation.tab: diastolicInput
                    }
                }

                CButton {
                    id: persureRegister
                    text: "ثبت فشار خون"
                    width: parent.width
                    height: 40
                    themeManager: root.themeManager  // ✅ ارسال theme به دکمه

                    onClicked: {
                        let sys = parseInt(systolicInput.text)
                        let dia = parseInt(diastolicInput.text)

                        if (!isNaN(sys) && !isNaN(dia) && sys > 0 && dia > 0) {
                            root.bloodPressureSubmitted(sys, dia)
                        } else {
                            bpStatus.text = "❌ مقادیر نامعتبر"
                            bpStatus.color = "red"
                        }
                    }
                }

                Text {
                    id: bpStatus
                    width: parent.width
                    wrapMode: Text.WordWrap
                    font.pixelSize: 11
                    color: "gray"
                }
            }
        }
    }
}
