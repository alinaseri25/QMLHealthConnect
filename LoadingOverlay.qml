import QtQuick

Rectangle {
    id: root

    // ===== API =====
    function show(msg) {
        loadingText.text = msg || "در حال پردازش..."
        root.visible = true
    }

    function hide() {
        root.visible = false
    }

    // ===== Props =====
    required property var themeManager

    anchors.fill: parent
    z: 100
    visible: false
    color: themeManager.isDarkMode ? "#80000000" : "#80FFFFFF"

    Behavior on color { ColorAnimation { duration: 300 } }

    // بلاک کردن تمام کلیک‌های پشتی
    MouseArea {
        anchors.fill: parent
        enabled: root.visible
    }

    // کارت مرکزی
    Rectangle {
        anchors.centerIn: parent
        width: 170
        height: 125
        radius: 16
        color: root.themeManager.cardColor
        border.color: root.themeManager.panelBorderColor
        border.width: 1

        Behavior on color { ColorAnimation { duration: 300 } }
        Behavior on border.color { ColorAnimation { duration: 300 } }

        Column {
            anchors.centerIn: parent
            spacing: 16

            // اسپینر
            Item {
                width: 48
                height: 48
                anchors.horizontalCenter: parent.horizontalCenter

                // track (دایره خاکستری پشت)
                Rectangle {
                    anchors.fill: parent
                    radius: 24
                    color: "transparent"
                    border.color: root.themeManager.isDarkMode ? "#333333" : "#DDDDDD"
                    border.width: 4

                    Behavior on border.color { ColorAnimation { duration: 300 } }
                }

                // arc (کمان رنگی دوار)
                Rectangle {
                    id: spinnerArc
                    anchors.fill: parent
                    radius: 24
                    color: "transparent"
                    border.color: root.themeManager.accentColor
                    border.width: 4

                    Behavior on border.color { ColorAnimation { duration: 300 } }

                    // نیمه‌پوش برای شبیه‌سازی arc
                    Rectangle {
                        width: 24
                        height: 48
                        anchors.right: parent.right
                        color: root.themeManager.cardColor

                        Behavior on color { ColorAnimation { duration: 300 } }
                    }

                    RotationAnimator {
                        target: spinnerArc
                        from: 0
                        to: 360
                        duration: 900
                        loops: Animation.Infinite
                        running: root.visible
                    }
                }
            }

            Text {
                id: loadingText
                text: "در حال پردازش..."
                font.pixelSize: 13
                font.family: "Vazir"
                color: root.themeManager.primaryTextColor
                anchors.horizontalCenter: parent.horizontalCenter

                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }
    }
}
