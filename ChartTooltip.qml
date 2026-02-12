import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

Rectangle {
    id: tooltip

    property string labelText: ""
    property string valueText: ""

    visible: opacity > 0
    opacity: 0

    width: contentColumn.width + 20
    height: contentColumn.height + 16

    color: Qt.rgba(0, 0, 0, 0.85)
    radius: 8
    border.color: Qt.rgba(255, 255, 255, 0.3)
    border.width: 1

    // سایه با استفاده از layer
    layer.enabled: true
    layer.effect: DropShadow {
        horizontalOffset: 0
        verticalOffset: 2
        radius: 8.0
        samples: 17
        color: "#80000000"
        transparentBorder: true
    }

    Column {
        id: contentColumn
        anchors.centerIn: parent
        spacing: 4

        Text {
            text: tooltip.labelText
            color: "white"
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }

        Text {
            text: tooltip.valueText
            color: "#4FC3F7"
            font.pixelSize: 14
            font.weight: Font.Bold
        }
    }

    Behavior on opacity {
        NumberAnimation { duration: 150 }
    }

    function show(x, y, label, value) {
        labelText = label
        valueText = value
        tooltip.x = x + 15
        tooltip.y = y - height / 2
        opacity = 1
    }

    function hide() {
        opacity = 0
    }
}
