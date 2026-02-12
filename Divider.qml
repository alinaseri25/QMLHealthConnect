import QtQuick

Rectangle {
    id: divider

    required property var themeManager

    property real dividerOpacity: 0.3
    property int dividerHeight: 1
    property int dividerWidth: parent.width
    property color dividerColor: themeManager.panelBorderColor

    width: dividerWidth
    height: dividerHeight
    color: dividerColor
    opacity: dividerOpacity

    Behavior on color {
        ColorAnimation { duration: 300 }
    }
}
