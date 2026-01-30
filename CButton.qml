import QtQuick
import QtQuick.Controls

Rectangle {
    id: root

    // رنگ‌ها و propertyهای قابل تنظیم
    property color bgColor: "#4caf50"
    property color bgPressed: "#43a047"
    property string text: "Button"
    property color textColor: "white"
    property font userFont
    property int btnWidth: 40
    property int btnHeight: 25
    property int btnRadius: 4

    width: btnWidth
    height: btnHeight
    radius: btnRadius
    color: bgColor

    Text {
        anchors.centerIn: parent
        text: root.text
        color: root.textColor
        font: root.userFont
    }

    MouseArea {
        anchors.fill: parent
        onPressed: root.color = bgPressed
        onReleased: root.color = bgColor
        onClicked: root.clicked()
    }

    signal clicked()
}
