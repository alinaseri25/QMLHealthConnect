import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    width: 60
    height: 32
    radius: 16

    // ✅ دسترسی به themeManager از parent
    property var themeManager: appTheme

    color: themeManager.surfaceColor
    border.color: themeManager.panelBorderColor
    border.width: 1

    Behavior on color {
        ColorAnimation { duration: 300 }
    }

    Rectangle {
        id: toggleCircle
        width: 25
        height: 25
        radius: 12
        anchors.verticalCenter: parent.verticalCenter
        x: themeManager.isDarkMode ? parent.width - width - 3 : 3

        color: themeManager.accentColor

        Behavior on x {
            NumberAnimation {
                duration: 200
                easing.type: Easing.InOutQuad
            }
        }

        Behavior on color {
            ColorAnimation { duration: 300 }
        }

        // آیکون خورشید/ماه
        Text {
            anchors.centerIn: parent
            text: themeManager.isDarkMode ? "🌙" : "☀️"
            font.pixelSize: 14
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            themeManager.toggleTheme()
        }
    }
}
