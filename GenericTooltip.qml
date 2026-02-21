import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

Rectangle {
    id: tooltip

    // ── themeManager ──
    property var themeManager: null

    // ✅ دو حالت: تک‌خطی یا دو‌خطی
    property string text: ""
    property string labelText: ""
    property string valueText: ""
    property bool isMultiLine: labelText.length > 0 && valueText.length > 0

    // ✅ تنظیمات ظاهری — binding به themeManager
    property color backgroundColor: themeManager
        ? (themeManager.isDarkMode ? Qt.rgba(0.08, 0.08, 0.12, 0.93) : Qt.rgba(0.12, 0.12, 0.18, 0.90))
        : Qt.rgba(0, 0, 0, 0.85)

    property color borderColor: themeManager
        ? (themeManager.isDarkMode ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.38))
        : Qt.rgba(255, 255, 255, 0.3)

    property color textColor: "white"

    property color valueColor: themeManager ? themeManager.accentColor : "#4FC3F7"

    property int textSize: 12
    property int valueSize: 14

    // ✅ رفتار
    property int autoHideDelay: 0
    property bool followMouse: false

    visible: opacity > 0
    opacity: 0

    width: isMultiLine ? multiLineContent.width + 20 : singleLineContent.width + 20
    height: isMultiLine ? multiLineContent.height + 16 : singleLineContent.height + 16

    color: backgroundColor
    radius: 8
    border.color: borderColor
    border.width: 1
    z: 10000

    layer.enabled: true
    layer.effect: DropShadow {
        horizontalOffset: 0
        verticalOffset: 2
        radius: 8.0
        samples: 17
        color: "#80000000"
        transparentBorder: true
    }

    // ✅ محتوای تک‌خطی (برای دکمه‌ها)
    Text {
        id: singleLineContent
        visible: !tooltip.isMultiLine
        anchors.centerIn: parent
        text: tooltip.text
        color: tooltip.textColor
        font.pixelSize: tooltip.textSize
        font.weight: Font.DemiBold
        font.family: "Vazir"
    }

    // ✅ محتوای دو‌خطی (برای نمودار)
    Column {
        id: multiLineContent
        visible: tooltip.isMultiLine
        anchors.centerIn: parent
        spacing: 4

        Text {
            text: tooltip.labelText
            color: tooltip.textColor
            font.pixelSize: tooltip.textSize
            font.weight: Font.DemiBold
            font.family: "Vazir"
        }

        Text {
            text: tooltip.valueText
            color: tooltip.valueColor
            font.pixelSize: tooltip.valueSize
            font.weight: Font.Bold
            font.family: "Vazir"
        }
    }

    Behavior on opacity {
        NumberAnimation { duration: 150 }
    }

    Behavior on x {
        enabled: followMouse
        NumberAnimation { duration: 50 }
    }

    Behavior on y {
        enabled: followMouse
        NumberAnimation { duration: 50 }
    }

    Timer {
        id: autoHideTimer
        interval: tooltip.autoHideDelay
        running: false
        repeat: false
        onTriggered: tooltip.hide()
    }

    // ✅ API: نمایش ساده (یک خط متن)
    function showSimple(x, y, message) {
        text = message
        labelText = ""
        valueText = ""
        positionTooltip(x, y)
        opacity = 1
        if (autoHideDelay > 0) autoHideTimer.restart()
    }

    // ✅ API: نمایش دو‌خطی (برای نمودار)
    function showChart(x, y, label, value) {
        labelText = label
        valueText = value
        text = ""
        positionTooltip(x, y)
        opacity = 1
        if (autoHideDelay > 0) autoHideTimer.restart()
    }

    // ✅ API: نمایش نسبت به یک المان
    function showFor(targetItem, message, position = "auto") {
        text = message
        labelText = ""
        valueText = ""

        if (!targetItem || !tooltip.parent) {
            console.warn("GenericTooltip: targetItem or parent is null")
            return
        }

        let globalPos = targetItem.mapToItem(tooltip.parent, 0, 0)
        let finalX = globalPos.x
        let finalY = globalPos.y

        switch(position) {
        case "top":
            finalX = globalPos.x + targetItem.width/2 - tooltip.width/2
            finalY = globalPos.y - tooltip.height - 10
            break
        case "bottom":
            finalX = globalPos.x + targetItem.width/2 - tooltip.width/2
            finalY = globalPos.y + targetItem.height + 10
            break
        case "left":
            finalX = globalPos.x - tooltip.width - 10
            finalY = globalPos.y + targetItem.height/2 - tooltip.height/2
            break
        case "right":
            finalX = globalPos.x + targetItem.width + 10
            finalY = globalPos.y + targetItem.height/2 - tooltip.height/2
            break
        case "auto":
        default:
            let spaceRight = tooltip.parent.width - (globalPos.x + targetItem.width)
            let spaceBottom = tooltip.parent.height - (globalPos.y + targetItem.height)

            if (spaceRight >= tooltip.width + 20) {
                finalX = globalPos.x + targetItem.width + 10
                finalY = globalPos.y + targetItem.height/2 - tooltip.height/2
            } else if (spaceBottom >= tooltip.height + 20) {
                finalX = globalPos.x + targetItem.width/2 - tooltip.width/2
                finalY = globalPos.y + targetItem.height + 10
            } else {
                finalX = globalPos.x + targetItem.width/2 - tooltip.width/2
                finalY = globalPos.y - tooltip.height - 10
            }
        }

        positionTooltip(finalX, finalY)
        opacity = 1
        if (autoHideDelay > 0) autoHideTimer.restart()
    }

    // ✅ تابع داخلی موقعیت‌یابی با boundary check
    function positionTooltip(x, y) {
        tooltip.x = x
        tooltip.y = y

        if (tooltip.parent) {
            if (tooltip.x < 0) tooltip.x = 10
            if (tooltip.y < 0) tooltip.y = 10
            if (tooltip.x + tooltip.width > tooltip.parent.width)
                tooltip.x = tooltip.parent.width - tooltip.width - 10
            if (tooltip.y + tooltip.height > tooltip.parent.height)
                tooltip.y = tooltip.parent.height - tooltip.height - 10
        }
    }

    function hide() {
        opacity = 0
        autoHideTimer.stop()
    }
}
