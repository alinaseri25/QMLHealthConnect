import QtQuick
import QtQuick.Controls
import QtCharts

Item {
    width: 640
    height: 480
    visible: true

    signal updateSignal()
    signal setHeight(double value)
    signal setWeight(double value)
    signal setBloodPressure(int systolic, int diastolic)

    ChartView {
        id: chartView
        title: "نمودار سلامت"

        x: 0
        y: 50
        width: parent.width - inputPanel.width
        height: parent.height - 50

        antialiasing: true
        animationOptions: ChartView.NoAnimation
        legend.alignment: Qt.AlignTop

        // ===== محورها =====

        DateTimeAxis {
            id: axisX
            format: "hh:mm:ss"
            tickCount: 6
            titleText: "زمان"
            min: new Date(Date.now())
            max: new Date(Date.now() + 10000)
        }

        ValueAxis {
            id: axisY1
            min: -10
            max: 10
            tickCount: 5
            labelFormat: "%.1f"
            titleText: "قد (m)"
        }

        ValueAxis {
            id: axisY2
            min: 40
            max: 50
            tickCount: 5
            labelFormat: "%.1f"
            titleText: "وزن (kg)"
        }

        ValueAxis {
            id: axisY3
            min: 60
            max: 200
            tickCount: 8
            labelFormat: "%.0f"
            titleText: "فشار خون (mmHg)"
            color: "#d32f2f"
        }

        // ===== سری‌های داده =====

        SplineSeries {
            id: spLine1
            name: "قد"
            useOpenGL: true
            axisX: axisX
            axisY: axisY1
        }

        SplineSeries {
            id: spLine2
            name: "وزن"
            useOpenGL: true
            axisX: axisX
            axisY: axisY2
        }

        LineSeries {
            id: spLine3
            name: "فشار سیستولیک"
            useOpenGL: true
            color: "#d32f2f"
            width: 2
            axisX: axisX
            axisY: axisY3
        }

        LineSeries {
            id: spLine4
            name: "فشار دیاستولیک"
            useOpenGL: true
            color: "#1976d2"
            width: 2
            axisX: axisX
            axisY: axisY3
        }
    }

    // ===== 🎯 ISOLATED AXIS ZONES (کاملاً مستقل) =====

    // 1️⃣ محور X (پایین نمودار)
    Rectangle {
        id: xAxisZone
        x: chartView.x + chartView.plotArea.x
        y: chartView.y + chartView.plotArea.y + chartView.plotArea.height
        width: chartView.plotArea.width
        height: 60
        color: "transparent"
        z: 20

        // Pinch برای X (دو انگشتی افقی)
        PinchArea {
            anchors.fill: parent
            property real initialXRange

            onPinchStarted: {
                initialXRange = axisX.max.getTime() - axisX.min.getTime()
            }

            onPinchUpdated: (pinch) => {
                let scale = 1.0 / pinch.scale
                let xCenter = (axisX.max.getTime() + axisX.min.getTime()) / 2
                axisX.min = new Date(xCenter - (initialXRange * scale) / 2)
                axisX.max = new Date(xCenter + (initialXRange * scale) / 2)
            }

            // MouseArea برای Scroll + Drag
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.SizeHorCursor

                // Scroll → Zoom X
                onWheel: (wheel) => {
                    let zoomFactor = wheel.angleDelta.y > 0 ? 0.9 : 1.1
                    let xRange = axisX.max.getTime() - axisX.min.getTime()
                    let xCenter = (axisX.max.getTime() + axisX.min.getTime()) / 2
                    axisX.min = new Date(xCenter - (xRange * zoomFactor) / 2)
                    axisX.max = new Date(xCenter + (xRange * zoomFactor) / 2)
                }

                // Drag → Pan X
                property real dragStartX: 0
                onPressed: (mouse) => { dragStartX = mouse.x }
                onPositionChanged: (mouse) => {
                    if (pressed) {
                        let dx = mouse.x - dragStartX
                        let xRange = axisX.max.getTime() - axisX.min.getTime()
                        let xShift = -(dx / width) * xRange
                        axisX.min = new Date(axisX.min.getTime() + xShift)
                        axisX.max = new Date(axisX.max.getTime() + xShift)
                        dragStartX = mouse.x
                    }
                }

                // Double-click → Reset X
                onDoubleClicked: {
                    axisX.min = new Date(Date.now() - 10000)
                    axisX.max = new Date(Date.now())
                }
            }
        }
    }

    // 2️⃣ محور Y1 (چپ نمودار - قد)
    Rectangle {
        id: y1AxisZone
        x: chartView.x
        y: chartView.y + chartView.plotArea.y
        width: chartView.plotArea.x
        height: chartView.plotArea.height / 3
        color: "transparent"
        z: 20

        PinchArea {
            anchors.fill: parent
            property real initialY1Range

            onPinchStarted: {
                initialY1Range = axisY1.max - axisY1.min
            }

            onPinchUpdated: (pinch) => {
                let scale = 1.0 / pinch.scale
                let y1Center = (axisY1.max + axisY1.min) / 2
                axisY1.min = y1Center - (initialY1Range * scale) / 2
                axisY1.max = y1Center + (initialY1Range * scale) / 2
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.SizeVerCursor

                onWheel: (wheel) => {
                    let zoomFactor = wheel.angleDelta.y > 0 ? 0.9 : 1.1
                    let y1Range = axisY1.max - axisY1.min
                    let y1Center = (axisY1.max + axisY1.min) / 2
                    axisY1.min = y1Center - (y1Range * zoomFactor) / 2
                    axisY1.max = y1Center + (y1Range * zoomFactor) / 2
                }

                property real dragStartY: 0
                onPressed: (mouse) => { dragStartY = mouse.y }
                onPositionChanged: (mouse) => {
                    if (pressed) {
                        let dy = mouse.y - dragStartY
                        let y1Range = axisY1.max - axisY1.min
                        let y1Shift = -(dy / height) * y1Range
                        axisY1.min += y1Shift
                        axisY1.max += y1Shift
                        dragStartY = mouse.y
                    }
                }

                onDoubleClicked: {
                    axisY1.min = -10
                    axisY1.max = 10
                }
            }
        }
    }

    // 3️⃣ محور Y2 (راست نمودار - وزن)
    Rectangle {
        id: y2AxisZone
        x: chartView.x + chartView.plotArea.x + chartView.plotArea.width
        y: chartView.y + chartView.plotArea.y
        width: 70
        height: chartView.plotArea.height / 3
        color: "transparent"
        z: 20

        PinchArea {
            anchors.fill: parent
            property real initialY2Range

            onPinchStarted: {
                initialY2Range = axisY2.max - axisY2.min
            }

            onPinchUpdated: (pinch) => {
                let scale = 1.0 / pinch.scale
                let y2Center = (axisY2.max + axisY2.min) / 2
                axisY2.min = y2Center - (initialY2Range * scale) / 2
                axisY2.max = y2Center + (initialY2Range * scale) / 2
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.SizeVerCursor

                onWheel: (wheel) => {
                    let zoomFactor = wheel.angleDelta.y > 0 ? 0.9 : 1.1
                    let y2Range = axisY2.max - axisY2.min
                    let y2Center = (axisY2.max + axisY2.min) / 2
                    axisY2.min = y2Center - (y2Range * zoomFactor) / 2
                    axisY2.max = y2Center + (y2Range * zoomFactor) / 2
                }

                property real dragStartY: 0
                onPressed: (mouse) => { dragStartY = mouse.y }
                onPositionChanged: (mouse) => {
                    if (pressed) {
                        let dy = mouse.y - dragStartY
                        let y2Range = axisY2.max - axisY2.min
                        let y2Shift = -(dy / height) * y2Range
                        axisY2.min += y2Shift
                        axisY2.max += y2Shift
                        dragStartY = mouse.y
                    }
                }

                onDoubleClicked: {
                    axisY2.min = 40
                    axisY2.max = 50
                }
            }
        }
    }

    // 4️⃣ محور Y3 (راست نمودار - فشار خون)
    Rectangle {
        id: y3AxisZone
        x: chartView.x + chartView.plotArea.x + chartView.plotArea.width
        y: chartView.y + chartView.plotArea.y + (chartView.plotArea.height / 3)
        width: 70
        height: chartView.plotArea.height / 3
        color: "transparent"
        z: 20

        PinchArea {
            anchors.fill: parent
            property real initialY3Range

            onPinchStarted: {
                initialY3Range = axisY3.max - axisY3.min
            }

            onPinchUpdated: (pinch) => {
                let scale = 1.0 / pinch.scale
                let y3Center = (axisY3.max + axisY3.min) / 2
                axisY3.min = y3Center - (initialY3Range * scale) / 2
                axisY3.max = y3Center + (initialY3Range * scale) / 2
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.SizeVerCursor

                onWheel: (wheel) => {
                    let zoomFactor = wheel.angleDelta.y > 0 ? 0.9 : 1.1
                    let y3Range = axisY3.max - axisY3.min
                    let y3Center = (axisY3.max + axisY3.min) / 2
                    axisY3.min = y3Center - (y3Range * zoomFactor) / 2
                    axisY3.max = y3Center + (y3Range * zoomFactor) / 2
                }

                property real dragStartY: 0
                onPressed: (mouse) => { dragStartY = mouse.y }
                onPositionChanged: (mouse) => {
                    if (pressed) {
                        let dy = mouse.y - dragStartY
                        let y3Range = axisY3.max - axisY3.min
                        let y3Shift = -(dy / height) * y3Range
                        axisY3.min += y3Shift
                        axisY3.max += y3Shift
                        dragStartY = mouse.y
                    }
                }

                onDoubleClicked: {
                    axisY3.min = 60
                    axisY3.max = 200
                }
            }
        }
    }

    // ===== دکمه باز/بسته پنل =====

    CButton {
        id: togglePanelBtn
        text: inputPanel.expanded ? "◀" : "▶"
        width: 30
        height: 30
        x: parent.width - (inputPanel.width + 100)
        y: 10
        z: 1

        onClicked: {
            inputPanel.expanded = !inputPanel.expanded
        }
    }

    // ===== پنل ورودی =====

    Rectangle {
        id: inputPanel
        property bool expanded: true
        z: 100

        width: expanded ? 330 : 0
        height: parent.height
        anchors.right: parent.right
        color: "#f0f0f0"
        border.color: "#bbbbbb"
        border.width: expanded ? 1 : 0
        clip: true

        Behavior on width {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        ScrollView {
            id: scrollView
            anchors.fill: parent
            anchors.margins: 0
            visible: expanded
            clip: true

            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            Column {
                width: scrollView.width - 20
                spacing: 12
                padding: 10

                Text {
                    text: "ثبت اطلاعات سلامت"
                    font.pixelSize: 14
                    font.bold: true
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    color: "#333333"
                }

                Rectangle { width: parent.width; height: 1; color: "#ccc" }

                // ===== قد =====
                Column {
                    width: parent.width
                    spacing: 6

                    Text { text: "قد (متر)"; font.pixelSize: 13; color: "#444" }

                    TextField {
                        id: heightInput
                        width: parent.width
                        height: 32
                        placeholderText: "مثال: 1.75"
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                        validator: DoubleValidator { bottom: 0.1; top: 3; decimals: 2 }
                        background: Rectangle {
                            color: "white"
                            border.color: "#aaa"
                            border.width: 1
                            radius: 3
                        }
                    }

                    CButton {
                        text: "ثبت قد"
                        width: parent.width
                        height: 32
                        enabled: heightInput.text.length > 0
                        bgColor: "#4caf50"
                        bgPressed: "#43a047"
                        onClicked: {
                            let value = parseFloat(heightInput.text)
                            if (isNaN(value) || value < 0.1 || value > 3) {
                                heightStatus.text = "مقدار باید بین 0.1 تا 3 باشد"
                                heightStatus.color = "#c00"
                                return
                            }
                            heightStatus.text = "در حال ثبت..."
                            heightStatus.color = "#c80"
                            setHeight(value)
                        }
                    }

                    Text {
                        id: heightStatus
                        width: parent.width
                        wrapMode: Text.WordWrap
                        font.pixelSize: 11
                        color: "gray"
                    }
                }

                Rectangle { width: parent.width; height: 1; color: "#ccc" }

                // ===== وزن =====
                Column {
                    width: parent.width
                    spacing: 6

                    Text { text: "وزن (کیلوگرم)"; font.pixelSize: 13; color: "#444" }

                    TextField {
                        id: weightInput
                        width: parent.width
                        height: 32
                        placeholderText: "مثال: 70.5"
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                        validator: DoubleValidator { bottom: 0.1; top: 300; decimals: 2 }
                        background: Rectangle {
                            color: "white"
                            border.color: "#aaa"
                            border.width: 1
                            radius: 3
                        }
                    }

                    CButton {
                        text: "ثبت وزن"
                        width: parent.width
                        height: 32
                        enabled: weightInput.text.length > 0
                        bgColor: "#4caf50"
                        bgPressed: "#43a047"
                        onClicked: {
                            let value = parseFloat(weightInput.text)
                            if (isNaN(value) || value < 0.1 || value > 300) {
                                weightStatus.text = "مقدار باید بین 0.1 تا 300 باشد"
                                weightStatus.color = "#c00"
                                return
                            }
                            weightStatus.text = "در حال ثبت..."
                            weightStatus.color = "#c80"
                            setWeight(value)
                        }
                    }

                    Text {
                        id: weightStatus
                        width: parent.width
                        wrapMode: Text.WordWrap
                        font.pixelSize: 11
                        color: "gray"
                    }
                }

                Rectangle { width: parent.width; height: 1; color: "#ccc" }

                // ===== فشار خون =====
                Column {
                    width: parent.width
                    spacing: 6

                    Text {
                        text: "فشار خون"
                        font.pixelSize: 13
                        color: "#444"
                        font.bold: true
                    }

                    Text { text: "سیستولیک (mmHg)"; font.pixelSize: 12; color: "#666" }
                    TextField {
                        id: systolicInput
                        width: parent.width
                        height: 32
                        placeholderText: "مثال: 120"
                        inputMethodHints: Qt.ImhDigitsOnly
                        validator: IntValidator { bottom: 80; top: 200 }
                        background: Rectangle {
                            color: "white"
                            border.color: "#aaa"
                            border.width: 1
                            radius: 3
                        }
                    }

                    Text { text: "دیاستولیک (mmHg)"; font.pixelSize: 12; color: "#666" }
                    TextField {
                        id: diastolicInput
                        width: parent.width
                        height: 32
                        placeholderText: "مثال: 80"
                        inputMethodHints: Qt.ImhDigitsOnly
                        validator: IntValidator { bottom: 40; top: 130 }
                        background: Rectangle {
                            color: "white"
                            border.color: "#aaa"
                            border.width: 1
                            radius: 3
                        }
                    }

                    CButton {
                        text: "ثبت فشار خون"
                        width: parent.width
                        height: 32
                        enabled: systolicInput.text.length > 0 && diastolicInput.text.length > 0
                        bgColor: "#d32f2f"
                        bgPressed: "#b71c1c"
                        onClicked: {
                            let sys = parseInt(systolicInput.text)
                            let dia = parseInt(diastolicInput.text)
                            if (isNaN(sys) || sys < 80 || sys > 200) {
                                bpStatus.text = "سیستولیک باید بین 80 تا 200 باشد"
                                bpStatus.color = "#c00"
                                return
                            }
                            if (isNaN(dia) || dia < 40 || dia > 130) {
                                bpStatus.text = "دیاستولیک باید بین 40 تا 130 باشد"
                                bpStatus.color = "#c00"
                                return
                            }
                            if (sys <= dia) {
                                bpStatus.text = "سیستولیک باید بزرگتر از دیاستولیک باشد"
                                bpStatus.color = "#c00"
                                return
                            }
                            bpStatus.text = "در حال ثبت..."
                            bpStatus.color = "#c80"
                            setBloodPressure(sys, dia)
                        }
                    }

                    Text {
                        id: bpStatus
                        width: parent.width
                        wrapMode: Text.WordWrap
                        font.pixelSize: 11
                        color: "gray"
                    }
                }
            }
        }
    }

    // ===== دکمه‌های نمایش/مخفی =====

    Row {
        x: (parent.width / 2) - 220
        y: 10
        spacing: 10

        CButton { id: sBtn1; text: "قد"; width: 70; height: 35; onClicked: spLine1.visible = !spLine1.visible }
        CButton { id: sBtn2; text: "وزن"; width: 70; height: 35; onClicked: spLine2.visible = !spLine2.visible }
        CButton { id: sBtn3; text: "BP (S)"; width: 70; height: 35; onClicked: spLine3.visible = !spLine3.visible }
        CButton { id: sBtn4; text: "BP (D)"; width: 70; height: 35; onClicked: spLine4.visible = !spLine4.visible }
        CButton { id: sBtn5;text: "بروزرسانی نمودار"; width: 100; height: 35; onClicked: updateSignal()}
    }

    // ===== اتصالات =====

    Component.onCompleted: {
        updateSignal.connect(myBackend.onUpdateRequest)
        setHeight.connect(myBackend.writeHeight)
        setWeight.connect(myBackend.writeWeight)
        setBloodPressure.connect(myBackend.writeBloodPressure)
    }

    Connections {
        target: myBackend

        function onHeightWritten(success, message) {
            if (success) {
                heightStatus.text = "✅ قد ثبت شد"
                heightStatus.color = "green"
                heightInput.text = ""
                Qt.callLater(updateSignal)
            } else {
                heightStatus.text = "❌ " + message
                heightStatus.color = "red"
            }
        }

        function onWeightWritten(success, message) {
            if (success) {
                weightStatus.text = "✅ وزن ثبت شد"
                weightStatus.color = "green"
                weightInput.text = ""
                Qt.callLater(updateSignal)
            } else {
                weightStatus.text = "❌ " + message
                weightStatus.color = "red"
            }
        }

        function onBloodPressureWritten(success, message) {
            if (success) {
                bpStatus.text = "✅ فشار خون ثبت شد"
                bpStatus.color = "green"
                systolicInput.text = ""
                diastolicInput.text = ""
                Qt.callLater(updateSignal)
            } else {
                bpStatus.text = "❌ " + message
                bpStatus.color = "red"
            }
        }

        function onNewDataRead(hList, wList, bpSystolicList, bpDiastolicList) {
            spLine1.clear()
            spLine2.clear()
            spLine3.clear()
            spLine4.clear()

            if (hList.length === 0 && wList.length === 0 && bpList.length === 0) return

            let minTime = hList[0].x
            if(wList[0].x << minTime){
                minTime = wList[0].x
            }
            if(bpSystolicList[0].x << minTime){
                minTime = bpSystolicList[0].x
            }

            let minH = Number.MAX_VALUE, maxH = Number.MIN_VALUE
            let minW = Number.MAX_VALUE, maxW = Number.MIN_VALUE
            let minBP = Number.MAX_VALUE, maxBP = Number.MIN_VALUE

            for (let i = 0; i < hList.length; i++) {
                let t = new Date(hList[i].x).getTime()
                spLine1.append(t, hList[i].y)
                minH = Math.min(minH, hList[i].y)
                maxH = Math.max(maxH, hList[i].y)
            }

            for (let i = 0; i < wList.length; i++) {
                let t = new Date(wList[i].x).getTime()
                spLine2.append(t, wList[i].y)
                minW = Math.min(minW, wList[i].y)
                maxW = Math.max(maxW, wList[i].y)
            }

            for (let i = 0; i < bpSystolicList.length; i++) {
                let t = new Date(bpSystolicList[i].x).getTime()
                spLine3.append(t, bpSystolicList[i].y)
                spLine4.append(t, bpDiastolicList[i].y)
                minBP = Math.min(minBP, bpDiastolicList[i].y)
                maxBP = Math.max(maxBP, bpSystolicList[i].y)
            }

            if (minTime !== Number.MAX_VALUE) {
                let maxTime = Date.now()
                let tPad = Math.max((maxTime - minTime) * 0.05, 1000)
                axisX.min = new Date(minTime - tPad)
                axisX.max = new Date(maxTime + tPad)
            }

            if (minH !== Number.MAX_VALUE) {
                let hPad = Math.max((maxH - minH) * 0.1, 0.1)
                axisY1.min = minH - hPad
                axisY1.max = maxH + hPad
            }

            if (minW !== Number.MAX_VALUE) {
                let wPad = Math.max((maxW - minW) * 0.1, 1)
                axisY2.min = minW - wPad
                axisY2.max = maxW + wPad
            }

            if (minBP !== Number.MAX_VALUE) {
                let bpPad = Math.max((maxBP - minBP) * 0.1, 10)
                axisY3.min = Math.max(40, minBP - bpPad)
                axisY3.max = Math.min(200, maxBP + bpPad)
            }
        }

        function onNewPoint(dp1, dp2) {
            let t = new Date(dp1.x).getTime()
            spLine1.append(t, dp1.y)
            spLine2.append(t, dp2.y)
            if (t > axisX.max.getTime() - 1000) {
                let range = axisX.max.getTime() - axisX.min.getTime()
                axisX.min = new Date(t - range + 1000)
                axisX.max = new Date(t + 1000)
            }
        }
    }
}
