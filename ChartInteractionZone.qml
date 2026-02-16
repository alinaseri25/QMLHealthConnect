import QtQuick

Rectangle {
    id: root

    // ارجاعات به محورها
    property var xAxis
    property var yAxes: []  // تمام محورهای Y
    property var chartView

    color: "transparent"

    // برای تشخیص جهت حرکت دو انگشتی
    property real initialHorizontalSpan: 0
    property real initialVerticalSpan: 0
    property bool isHorizontalPinch: false
    property bool isVerticalPinch: false

    PinchArea {
        anchors.fill: parent

        property real initialXRange
        property var initialYRanges: []

        onPinchStarted: (pinch) => {
            // ذخیره range های اولیه
            initialXRange = xAxis.max.getTime() - xAxis.min.getTime()
            initialYRanges = []
            for (let i = 0; i < yAxes.length; i++) {
                initialYRanges.push(yAxes[i].max - yAxes[i].min)
            }

            // محاسبه جهت حرکت اولیه
            initialHorizontalSpan = Math.abs(pinch.point1.x - pinch.point2.x)
            initialVerticalSpan = Math.abs(pinch.point1.y - pinch.point2.y)

            // تشخیص جهت غالب
            isHorizontalPinch = initialHorizontalSpan > initialVerticalSpan
            isVerticalPinch = initialVerticalSpan > initialHorizontalSpan
        }

        onPinchUpdated: (pinch) => {
            // محاسبه تغییرات افقی و عمودی
            let currentHorizontalSpan = Math.abs(pinch.point1.x - pinch.point2.x)
            let currentVerticalSpan = Math.abs(pinch.point1.y - pinch.point2.y)

            // اگر حرکت غالباً افقیه → زوم محور X
            if (isHorizontalPinch) {
                let scaleX = initialHorizontalSpan / currentHorizontalSpan
                let centerX = (xAxis.max.getTime() + xAxis.min.getTime()) / 2
                xAxis.min = new Date(centerX - (initialXRange * scaleX) / 2)
                xAxis.max = new Date(centerX + (initialXRange * scaleX) / 2)
            }

            // اگر حرکت غالباً عمودیه → زوم محورهای Y
            if (isVerticalPinch) {
                let scaleY = initialVerticalSpan / currentVerticalSpan
                for (let i = 0; i < yAxes.length; i++) {
                    let centerY = (yAxes[i].max + yAxes[i].min) / 2
                    yAxes[i].min = centerY - (initialYRanges[i] * scaleY) / 2
                    yAxes[i].max = centerY + (initialYRanges[i] * scaleY) / 2
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton

            property real dragStartX: 0
            property real dragStartY: 0
            property bool isDragging: false

            onPressed: (mouse) => {
                dragStartX = mouse.x
                dragStartY = mouse.y
                isDragging = true
            }

            onReleased: {
                isDragging = false
            }

            onPositionChanged: (mouse) => {
                if (isDragging && pressed) {
                    let dx = mouse.x - dragStartX
                    let dy = mouse.y - dragStartY

                    // اگر حرکت افقی بیشتر باشه → Pan محور X
                    if (Math.abs(dx) > Math.abs(dy)) {
                        let xRange = xAxis.max.getTime() - xAxis.min.getTime()
                        let xShift = -(dx / width) * xRange
                        xAxis.min = new Date(xAxis.min.getTime() + xShift)
                        xAxis.max = new Date(xAxis.max.getTime() + xShift)
                        dragStartX = mouse.x
                    }
                    // اگر حرکت عمودی بیشتر باشه → Pan محورهای Y
                    else {
                        for (let i = 0; i < yAxes.length; i++) {
                            let yRange = yAxes[i].max - yAxes[i].min
                            let yShift = (dy / height) * yRange
                            yAxes[i].min += yShift
                            yAxes[i].max += yShift
                        }
                        dragStartY = mouse.y
                    }
                }
            }

            // Wheel برای زوم (هم X هم Y با modifier key)
            onWheel: (wheel) => {
                let zoomFactor = wheel.angleDelta.y > 0 ? 0.9 : 1.1

                // اگر Ctrl فشرده نشده → زوم محور X
                if (!(wheel.modifiers & Qt.ControlModifier)) {
                    let xRange = xAxis.max.getTime() - xAxis.min.getTime()
                    let xCenter = (xAxis.max.getTime() + xAxis.min.getTime()) / 2
                    xAxis.min = new Date(xCenter - (xRange * zoomFactor) / 2)
                    xAxis.max = new Date(xCenter + (xRange * zoomFactor) / 2)
                }
                // اگر Ctrl فشرده شده → زوم محورهای Y
                else {
                    for (let i = 0; i < yAxes.length; i++) {
                        let yRange = yAxes[i].max - yAxes[i].min
                        let yCenter = (yAxes[i].max + yAxes[i].min) / 2
                        yAxes[i].min = yCenter - (yRange * zoomFactor) / 2
                        yAxes[i].max = yCenter + (yRange * zoomFactor) / 2
                    }
                }
            }
        }
    }
}
