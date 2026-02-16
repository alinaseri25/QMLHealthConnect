import QtQuick
import QtQuick.Controls

Button {
    id: control

    property var themeManager
    property color bgColor: themeManager.accentColor
    property color bgPressed: themeManager.accentPressed
    property color textColor: themeManager.primaryTextColor

    // ✅ پشتیبانی tooltip
    property string tooltipText: ""
    property var tooltipTarget: null  // به tooltip سراسری وصل می‌شود

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
        font.family: "Vazir"
        color: control.textColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    // ✅ HoverHandler
    HoverHandler {
        id: hoverHandler
        enabled: control.tooltipText.length > 0 && control.tooltipTarget !== null

        onHoveredChanged: {
            if (hovered && control.tooltipTarget) {
                control.tooltipTarget.showFor(control, control.tooltipText, "auto")
            } else if (control.tooltipTarget) {
                control.tooltipTarget.hide()
            }
        }
    }
}
