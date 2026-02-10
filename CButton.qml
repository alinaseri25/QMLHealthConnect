import QtQuick
import QtQuick.Controls

Button {
    id: control

    // ✅ دسترسی به themeManager از parent
    property var themeManager

    property color bgColor: themeManager.accentColor
    property color bgPressed: themeManager.accentPressed
    property color textColor: themeManager.primaryTextColor

    background: Rectangle {
        implicitWidth: 100
        implicitHeight: 40
        color: control.pressed ? control.bgPressed : control.bgColor
        radius: 8

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }

    contentItem: Text {
        text: control.text
        font.pixelSize: 16
        font.bold: true
        color: control.textColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        Behavior on color {
            ColorAnimation { duration: 300 }
        }
    }
}
