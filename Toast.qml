import QtQuick

Rectangle {
    id: root

    // ===== API =====
    // showMessage برای هر پیام دلخواه
    function showMessage(success, msg) {
        root.isSuccess = success
        toastText.text = (success ? "✅ " : "❌ ") + msg
        toastAnim.restart()
    }

    // ===== Props =====
    required property var themeManager
    property bool isSuccess: true

    // ===== Layout =====
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 28
    z: 200

    width: toastText.implicitWidth + 48
    height: 48
    radius: 24

    opacity: 0
    visible: opacity > 0

    // رنگ پس‌زمینه بر اساس تم و وضعیت
    color: {
        if (isSuccess) {
            return themeManager.isDarkMode ? "#2E7D32" : "#388E3C"
        } else {
            return themeManager.isDarkMode ? "#C62828" : "#D32F2F"
        }
    }

    // سایه برای خوانایی بهتر روی هر پس‌زمینه‌ای
    layer.enabled: true
    layer.effect: null  // در صورت نیاز می‌توان DropShadow اضافه کرد

    Behavior on color { ColorAnimation { duration: 250 } }
    Behavior on width { NumberAnimation { duration: 150 } }

    // خط رنگی بالای toast (accent bar)
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 3
        radius: parent.radius
        color: isSuccess
            ? Qt.lighter(root.color, 1.4)
            : Qt.lighter(root.color, 1.3)
        opacity: 0.7
    }

    Text {
        id: toastText
        anchors.centerIn: parent
        font.pixelSize: 14
        font.family: "Vazir"
        font.weight: Font.Medium
        color: "#FFFFFF"
        horizontalAlignment: Text.AlignHCenter
    }

    SequentialAnimation {
        id: toastAnim

        NumberAnimation {
            target: root
            property: "opacity"
            to: 0.96
            duration: 250
            easing.type: Easing.OutCubic
        }
        PauseAnimation { duration: 2500 }
        NumberAnimation {
            target: root
            property: "opacity"
            to: 0
            duration: 400
            easing.type: Easing.InCubic
        }
    }
}
