import QtQuick

Rectangle {
    id: root

    // Properties
    property var targetAxis  // برای محور X (تک محور)
    property var targetAxes: []  // ✅ برای محورهای Y (چند محور)
    property string axisType: "x" // "x" یا "y"
    property var chartView

    color: "transparent"

    PinchArea {
        anchors.fill: parent
        property real initialRange
        property var initialRanges: []  // ✅ برای ذخیره range های اولیه

        onPinchStarted: {
            if (axisType === "x") {
                initialRange = targetAxis.max.getTime() - targetAxis.min.getTime()
            } else {
                // ✅ ذخیره range اولیه همه محورها
                initialRanges = []
                for (let i = 0; i < targetAxes.length; i++) {
                    initialRanges.push(targetAxes[i].max - targetAxes[i].min)
                }
            }
        }

        onPinchUpdated: (pinch) => {
            let scale = 1.0 / pinch.scale

            if (axisType === "x") {
                let center = (targetAxis.max.getTime() + targetAxis.min.getTime()) / 2
                targetAxis.min = new Date(center - (initialRange * scale) / 2)
                targetAxis.max = new Date(center + (initialRange * scale) / 2)
            } else {
                // ✅ اعمال zoom به همه محورها
                for (let i = 0; i < targetAxes.length; i++) {
                    let center = (targetAxes[i].max + targetAxes[i].min) / 2
                    targetAxes[i].min = center - (initialRanges[i] * scale) / 2
                    targetAxes[i].max = center + (initialRanges[i] * scale) / 2
                }
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
                    // ✅ زوم همزمان همه محورها
                    for (let i = 0; i < targetAxes.length; i++) {
                        let range = targetAxes[i].max - targetAxes[i].min
                        let center = (targetAxes[i].max + targetAxes[i].min) / 2
                        targetAxes[i].min = center - (range * zoomFactor) / 2
                        targetAxes[i].max = center + (range * zoomFactor) / 2
                    }
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
                        // ✅ جابجایی همزمان همه محورها
                        let dy = mouse.y - dragStart
                        for (let i = 0; i < targetAxes.length; i++) {
                            let range = targetAxes[i].max - targetAxes[i].min
                            let shift = (dy / height) * range
                            targetAxes[i].min += shift
                            targetAxes[i].max += shift
                        }
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
                    // ✅ Reset همه محورها به مقادیر پیش‌فرض
                    // این بخش رو باید بر اساس نیازت تنظیم کنی
                    console.log("Y-axes reset requested")
                }
            }
        }
    }
}
