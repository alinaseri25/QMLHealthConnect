import QtQuick

Rectangle {
    id: root

    // Properties
    property var targetAxis
    property string axisType: "x" // "x", "y"
    property var chartView

    color: "transparent"

    PinchArea {
        anchors.fill: parent
        property real initialRange

        onPinchStarted: {
            if (axisType === "x") {
                initialRange = targetAxis.max.getTime() - targetAxis.min.getTime()
            } else {
                initialRange = targetAxis.max - targetAxis.min
            }
        }

        onPinchUpdated: (pinch) => {
            let scale = 1.0 / pinch.scale

            if (axisType === "x") {
                let center = (targetAxis.max.getTime() + targetAxis.min.getTime()) / 2
                targetAxis.min = new Date(center - (initialRange * scale) / 2)
                targetAxis.max = new Date(center + (initialRange * scale) / 2)
            } else {
                let center = (targetAxis.max + targetAxis.min) / 2
                targetAxis.min = center - (initialRange * scale) / 2
                targetAxis.max = center + (initialRange * scale) / 2
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: axisType === "x" ? Qt.SizeHorCursor : Qt.SizeVerCursor

            // Scroll → Zoom
            onWheel: (wheel) => {
                let zoomFactor = wheel.angleDelta.y > 0 ? 0.9 : 1.1
                if (axisType === "x") {
                    let range = targetAxis.max.getTime() - targetAxis.min.getTime()
                    let center = (targetAxis.max.getTime() + targetAxis.min.getTime()) / 2
                    targetAxis.min = new Date(center - (range * zoomFactor) / 2)
                    targetAxis.max = new Date(center + (range * zoomFactor) / 2)
                } else {
                    let range = targetAxis.max - targetAxis.min
                    let center = (targetAxis.max + targetAxis.min) / 2
                    targetAxis.min = center - (range * zoomFactor) / 2
                    targetAxis.max = center + (range * zoomFactor) / 2
                }
            }

            // Drag → Pan
            property real dragStart: 0

            onPressed: (mouse) => {
                dragStart = axisType === "x" ? mouse.x : mouse.y
            }

            onPositionChanged: (mouse) => {
                if (pressed) {
                    if (axisType === "x") {
                        let dx = mouse.x - dragStart
                        let range = targetAxis.max.getTime() - targetAxis.min.getTime()
                        let shift = -(dx / width) * range
                        targetAxis.min = new Date(targetAxis.min.getTime() + shift)
                        targetAxis.max = new Date(targetAxis.max.getTime() + shift)
                        dragStart = mouse.x
                    } else {
                        let dy = mouse.y - dragStart
                        let range = targetAxis.max - targetAxis.min
                        let shift = (dy / height) * range
                        targetAxis.min += shift
                        targetAxis.max += shift
                        dragStart = mouse.y
                    }
                }
            }

            // Double-click → Reset
            onDoubleClicked: {
                if (axisType === "x") {
                    targetAxis.min = new Date(Date.now() - 10000)
                    targetAxis.max = new Date(Date.now())
                } else {
                    // Reset به مقادیر اولیه (باید از بیرون تنظیم شود)
                }
            }
        }
    }
}
