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
    signal setBloodPressure(double systolic, double diastolic)

    ChartView {
        id: chartView
        title: "Spline Chart"

        x: 0
        y: 50
        width: parent.width - inputPanel.width
        height: parent.height - 50

        antialiasing: true
        animationOptions: ChartView.NoAnimation
        legend.alignment: Qt.AlignTop

        // ✅ محور X را DateTime تعریف می‌کنیم
        DateTimeAxis {
            id: axisX
            format: "hh:mm:ss"          // فرمت نمایش: ساعت:دقیقه:ثانیه
            tickCount: 6                // تعداد برچسب‌ها
            titleText: "زمان"

            // محدوده زمانی اولیه (10 ثانیه گذشته تا الان)
            min: new Date(Date.now())
            max: new Date(Date.now() + 10000)  // 100 ثانیه بعد
        }

        // // تعریف محور X
        // ValueAxis {
        //     id: axisX
        //     min: 0              // حداقل مقدار
        //     max: 100            // حداکثر مقدار
        //     tickCount: 11       // تعداد tick marks (0, 10, 20, ..., 100)
        //     labelFormat: "%.0f" // فرمت نمایش اعداد (بدون اعشار)
        //     titleText: "زمان (ثانیه)"
        // }

        // تعریف محور Y
        ValueAxis {
            id: axisY1
            min: -10
            max: 10
            tickCount: 5
            labelFormat: "%.1f"  // یک رقم اعشار
            titleText: "قد"
        }

        ValueAxis {
            id: axisY2
            min: 40
            max: 50
            tickCount: 5
            labelFormat: "%.1f"  // یک رقم اعشار
            titleText: "وزن"
        }

        ValueAxis {
            id: axisY3
            min: 60        // حداقل واقع‌گرایانه
            max: 200       // حداکثر واقع‌گرایانه
            tickCount: 8   // تقسیم‌بندی مناسب (60, 80, 100, 120, 140, 160, 180, 200)
            labelFormat: "%.0f"  // بدون اعشار (چون mmHg عدد صحیح هست)
            titleText: "فشار خون (mmHg)"
            color: "#d32f2f"  // رنگ قرمز برای تشخیص آسان
        }

        SplineSeries {
        //LineSeries {
            id: spLine1
            name: "قد"
            useOpenGL: true

            axisX: axisX
            axisY: axisY1
        }

        SplineSeries {
        //LineSeries {
            id: spLine2
            name: "وزن"
            useOpenGL: true

            axisX: axisX
            axisY: axisY2
        }

        // ✅ Systolic Blood Pressure (فشار سیستولیک)
        LineSeries {
            id: spLine3
            name: "فشار سیستولیک"
            useOpenGL: true
            color: "#d32f2f"      // قرمز تیره
            width: 2

            axisX: axisX
            axisY: axisY3
        }

        // ✅ Diastolic Blood Pressure (فشار دیاستولیک)
        LineSeries {
            id: spLine4
            name: "فشار دیاستولیک"
            useOpenGL: true
            color: "#1976d2"      // آبی تیره
            width: 2

            axisX: axisX
            axisY: axisY3
        }

        // PinchArea و MouseArea همون‌طوری که قبلاً بود...
        PinchArea {
            id: pinchArea
            anchors.fill: parent

            property real initialXMin
            property real initialXMax
            property real initialY1Min
            property real initialY1Max
            property real initialY2Min
            property real initialY2Max

            onPinchStarted: {
                initialXMin = axisX.min.getTime()
                initialXMax = axisX.max.getTime()
                initialY1Min = axisY1.min
                initialY1Max = axisY1.max
                initialY2Min = axisY2.min
                initialY2Max = axisY2.max
            }

            onPinchUpdated: (pinch) => {
                let scale = 1.0 / pinch.scale

                // Zoom محور X
                let xRange = initialXMax - initialXMin
                let xCenter = (initialXMax + initialXMin) / 2
                axisX.min = new Date(xCenter - (xRange * scale) / 2)
                axisX.max = new Date(xCenter + (xRange * scale) / 2)

                // Zoom محور Y1 (قد)
                let y1Range = initialY1Max - initialY1Min
                let y1Center = (initialY1Max + initialY1Min) / 2
                axisY1.min = y1Center - (y1Range * scale) / 2
                axisY1.max = y1Center + (y1Range * scale) / 2

                // Zoom محور Y2 (وزن)
                let y2Range = initialY2Max - initialY2Min
                let y2Center = (initialY2Max + initialY2Min) / 2
                axisY2.min = y2Center - (y2Range * scale) / 2
                axisY2.max = y2Center + (y2Range * scale) / 2
            }

            MouseArea {
                id: chartMouseArea
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton

                property real lastX: 0
                property real lastY: 0
                property bool isPanning: false

                onWheel: (wheel) => {
                    let zoomFactor = wheel.angleDelta.y > 0 ? 0.9 : 1.1

                    // Zoom محور X
                    let xRange = axisX.max.getTime() - axisX.min.getTime()
                    let xCenter = (axisX.max.getTime() + axisX.min.getTime()) / 2
                    axisX.min = new Date(xCenter - (xRange * zoomFactor) / 2)
                    axisX.max = new Date(xCenter + (xRange * zoomFactor) / 2)

                    // Zoom محور Y1
                    let y1Range = axisY1.max - axisY1.min
                    let y1Center = (axisY1.max + axisY1.min) / 2
                    axisY1.min = y1Center - (y1Range * zoomFactor) / 2
                    axisY1.max = y1Center + (y1Range * zoomFactor) / 2

                    // Zoom محور Y2
                    let y2Range = axisY2.max - axisY2.min
                    let y2Center = (axisY2.max + axisY2.min) / 2
                    axisY2.min = y2Center - (y2Range * zoomFactor) / 2
                    axisY2.max = y2Center + (y2Range * zoomFactor) / 2
                }

                onPressed: (mouse) => {
                    isPanning = true
                    lastX = mouse.x
                    lastY = mouse.y
                }

                onPositionChanged: (mouse) => {
                    if (isPanning) {
                        let dx = mouse.x - lastX
                        let dy = mouse.y - lastY

                        // Pan محور X
                        let xRange = axisX.max.getTime() - axisX.min.getTime()
                        let xShift = -(dx / chartView.plotArea.width) * xRange
                        axisX.min = new Date(axisX.min.getTime() + xShift)
                        axisX.max = new Date(axisX.max.getTime() + xShift)

                        // Pan محور Y1
                        let y1Range = axisY1.max - axisY1.min
                        let y1Shift = (dy / chartView.plotArea.height) * y1Range
                        axisY1.min += y1Shift
                        axisY1.max += y1Shift

                        // Pan محور Y2
                        let y2Range = axisY2.max - axisY2.min
                        let y2Shift = (dy / chartView.plotArea.height) * y2Range
                        axisY2.min += y2Shift
                        axisY2.max += y2Shift

                        lastX = mouse.x
                        lastY = mouse.y
                    }
                }

                onReleased: {
                    isPanning = false
                }

                onDoubleClicked: {
                    // Reset به مقادیر پیش‌فرض
                    axisX.min = new Date(Date.now() - 10000)
                    axisX.max = new Date(Date.now())
                    axisY1.min = -10
                    axisY1.max = 10
                    axisY2.min = 40
                    axisY2.max = 50
                }
            }
        }
    }

    // ===== قسمت inputPanel و دکمه باز/بسته آن =====

    // دکمه باز/بسته پنل - بذار بالای پنل خودش باشه
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

    Rectangle {
        id: inputPanel
        property bool expanded: true

        width: expanded ? 220 : 0
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

        // ✅ اضافه کردن ScrollView
        ScrollView {
            id: scrollView
            anchors.fill: parent
            anchors.margins: 0
            visible: expanded
            clip: true

            // تنظیمات اسکرول بار
            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            Column {
                width: scrollView.width - 20 // فاصله برای اسکرول بار
                spacing: 12
                padding: 10

                // عنوان
                Text {
                    text: "ثبت اطلاعات سلامت"
                    font.pixelSize: 14
                    font.bold: true
                    width: parent.width - 20
                    horizontalAlignment: Text.AlignHCenter
                    color: "#333333"
                }

                Rectangle { width: parent.width - 20; height: 1; color: "#cccccc" }

                // ===== قد =====
                Column {
                    width: parent.width - 20
                    spacing: 6

                    Text {
                        text: "قد (متر)"
                        font.pixelSize: 13
                        color: "#444444"
                    }

                    TextField {
                        id: heightInput
                        width: parent.width
                        height: 32
                        placeholderText: "مثال: 1.75"
                        inputMethodHints: Qt.ImhFormattedNumbersOnly

                        validator: DoubleValidator {
                            bottom: 0.1
                            top: 3
                            decimals: 2
                        }

                        background: Rectangle {
                            color: "white"
                            border.color: "#aaaaaa"
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
                                heightStatus.text = "مقدار باید بین 0.5 تا 2.5 باشد"
                                heightStatus.color = "#cc0000"
                                return
                            }
                            heightStatus.text = "در حال ثبت..."
                            heightStatus.color = "#cc8800"
                            setHeight(value)
                        }
                    }

                    Text {
                        id: heightStatus
                        width: parent.width
                        wrapMode: Text.WordWrap
                        font.pixelSize: 11
                        color: "gray"
                        text: ""
                    }
                }

                Rectangle { width: parent.width - 20; height: 1; color: "#cccccc" }

                // ===== وزن =====
                Column {
                    width: parent.width - 20
                    spacing: 6

                    Text {
                        text: "وزن (کیلوگرم)"
                        font.pixelSize: 13
                        color: "#444444"
                    }

                    TextField {
                        id: weightInput
                        width: parent.width
                        height: 32
                        placeholderText: "مثال: 70.5"
                        inputMethodHints: Qt.ImhFormattedNumbersOnly

                        validator: DoubleValidator {
                            bottom: 0.1
                            top: 300.0
                            decimals: 2
                        }

                        background: Rectangle {
                            color: "white"
                            border.color: "#aaaaaa"
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
                            if (isNaN(value) || value < 0.1 || value > 300.0) {
                                weightStatus.text = "مقدار باید بین 20 تا 300 باشد"
                                weightStatus.color = "#cc0000"
                                return
                            }
                            weightStatus.text = "در حال ثبت..."
                            weightStatus.color = "#cc8800"
                            setWeight(value)
                        }
                    }

                    Text {
                        id: weightStatus
                        width: parent.width
                        wrapMode: Text.WordWrap
                        font.pixelSize: 11
                        color: "gray"
                        text: ""
                    }
                }

                Rectangle { width: parent.width - 20; height: 1; color: "#cccccc" }

                // ===== 🩸 فشار خون (بخش جدید) =====
                Column {
                    width: parent.width - 20
                    spacing: 6

                    Text {
                        text: "فشار خون"
                        font.pixelSize: 13
                        font.bold: true
                        color: "#cc0000"
                    }

                    // Systolic
                    Text {
                        text: "سیستولیک (mmHg)"
                        font.pixelSize: 12
                        color: "#444444"
                    }

                    TextField {
                        id: systolicInput
                        width: parent.width
                        height: 32
                        placeholderText: "مثال: 120"
                        inputMethodHints: Qt.ImhFormattedNumbersOnly

                        validator: DoubleValidator {
                            bottom: 80
                            top: 200
                            decimals: 1
                        }

                        background: Rectangle {
                            color: "white"
                            border.color: "#aaaaaa"
                            border.width: 1
                            radius: 3
                        }
                    }

                    // Diastolic
                    Text {
                        text: "دیاستولیک (mmHg)"
                        font.pixelSize: 12
                        color: "#444444"
                    }

                    TextField {
                        id: diastolicInput
                        width: parent.width
                        height: 32
                        placeholderText: "مثال: 80"
                        inputMethodHints: Qt.ImhFormattedNumbersOnly

                        validator: DoubleValidator {
                            bottom: 40
                            top: 130
                            decimals: 1
                        }

                        background: Rectangle {
                            color: "white"
                            border.color: "#aaaaaa"
                            border.width: 1
                            radius: 3
                        }
                    }

                    CButton {
                        text: "ثبت فشار خون"
                        width: parent.width
                        height: 32
                        enabled: systolicInput.text.length > 0 && diastolicInput.text.length > 0
                        bgColor: "#f44336"
                        bgPressed: "#d32f2f"

                        onClicked: {
                            let sys = parseFloat(systolicInput.text)
                            let dia = parseFloat(diastolicInput.text)

                            // اعتبارسنجی محدوده
                            if (isNaN(sys) || sys < 80 || sys > 200) {
                                bpStatus.text = "سیستولیک باید بین 80 تا 200 باشد"
                                bpStatus.color = "#cc0000"
                                return
                            }
                            if (isNaN(dia) || dia < 40 || dia > 130) {
                                bpStatus.text = "دیاستولیک باید بین 40 تا 130 باشد"
                                bpStatus.color = "#cc0000"
                                return
                            }

                            // اعتبارسنجی رابطه
                            if (sys <= dia) {
                                bpStatus.text = "سیستولیک باید از دیاستولیک بیشتر باشد"
                                bpStatus.color = "#cc0000"
                                return
                            }

                            bpStatus.text = "در حال ثبت..."
                            bpStatus.color = "#cc8800"
                            setBloodPressure(sys, dia)
                        }
                    }

                    Text {
                        id: bpStatus
                        width: parent.width
                        wrapMode: Text.WordWrap
                        font.pixelSize: 11
                        color: "gray"
                        text: ""
                    }
                }

                Rectangle { width: parent.width - 20; height: 1; color: "#cccccc" }

                // دکمه بروزرسانی
                CButton {
                    text: "بروزرسانی نمودار"
                    btnWidth: parent.width - 20
                    btnHeight: 32
                    bgColor: "#757575"
                    bgPressed: "#616161"
                    onClicked: updateSignal()
                }
            }
        }
    }

    CButton{
        id: sBtn1
        text: "قد"

        width: 100
        height: 40

        x: (parent.width / 2) - 150
        y: 10


        onClicked: {
            spLine1.visible = !spLine1.visible
        }
    }

    CButton{
        id: sBtn2
        text: "وزن"

        width: 100
        height: 40

        x: (parent.width / 2) - 40
        y: 10


        onClicked: {
            spLine2.visible = !spLine2.visible
        }
    }

    // ✅ دکمه Toggle فشار خون
    CButton{
        id: sBtn3
        text: "فشار خون"
        width: 110
        height: 40
        x: (parent.width / 2) + 70  // کنار دکمه وزن
        y: 10
        bgColor: "#d32f2f"
        bgPressed: "#b71c1c"

        onClicked: {
            spLine3.visible = !spLine3.visible
            spLine4.visible = !spLine4.visible
        }
    }

    Component.onCompleted: {
        updateSignal.connect(myBackend.onUpdateRequest)
        setHeight.connect(myBackend.writeHeight)
        setWeight.connect(myBackend.writeWeight)
        setBloodPressure.connect(myBackend.writeBloodPressure)
    }

    Connections{
        target: myBackend

        function onStateChanged(state){
            if(state)
            {
                //startStopButton.text = "stop"
            }
            else
            {
                //startStopButton.text = "start"
            }
        }

        // ✅ سیگنال جدید: نتیجه ثبت قد
        function onHeightWritten(success, message) {
            if (success) {
                heightStatus.text = "✅ قد با موفقیت ثبت شد"
                heightStatus.color = "green"
                heightInput.text = ""

                // بروزرسانی خودکار نمودار بعد از 500ms
                Qt.callLater(function() {
                    updateSignal()
                })
            } else {
                heightStatus.text = "❌ خطا: " + message
                heightStatus.color = "red"
            }
        }

        // ✅ سیگنال جدید: نتیجه ثبت وزن
        function onWeightWritten(success, message) {
            if (success) {
                weightStatus.text = "✅ وزن با موفقیت ثبت شد"
                weightStatus.color = "green"
                weightInput.text = ""

                // بروزرسانی خودکار نمودار بعد از 500ms
                Qt.callLater(function() {
                    updateSignal()
                })
            } else {
                weightStatus.text = "❌ خطا: " + message
                weightStatus.color = "red"
            }
        }

        // ✅ سیگنال جدید: نتیجه ثبت فشار خون
        function onBloodPressureWritten(success, message) {
                if (success) {
                    bpStatus.text = "✅ فشار خون با موفقیت ثبت شد"
                    bpStatus.color = "green"
                    systolicInput.text = ""
                    diastolicInput.text = ""

                    Qt.callLater(function() {
                        updateSignal()
                    })
                } else {
                    bpStatus.text = "❌ خطا: " + message
                    bpStatus.color = "red"
                }
            }

        function onNewDataRead(hList, wList, bpSystolicList, bpDiastolicList) {
            console.log("📊 داده‌های دریافتی - قد:", hList.length, "وزن:", wList.length,
                        "فشار سیستولیک:", bpSystolicList.length, "فشار دیاستولیک:", bpDiastolicList.length)

            spLine1.clear()
            spLine2.clear()
            spLine3.clear()  // ✅ اضافه
            spLine4.clear()  // ✅ اضافه

            // بررسی خالی بودن
            if (hList.length === 0 && wList.length === 0 && bpSystolicList.length === 0) {
                console.warn("⚠️ هیچ داده‌ای دریافت نشد!")
                return
            }

            // مقادیر اولیه
            let minTime = Number.MAX_VALUE
            let maxTime = Number.MIN_VALUE
            let minHeight = Number.MAX_VALUE
            let maxHeight = Number.MIN_VALUE
            let minWeight = Number.MAX_VALUE
            let maxWeight = Number.MIN_VALUE
            let minBP = Number.MAX_VALUE      // ✅ اضافه
            let maxBP = Number.MIN_VALUE      // ✅ اضافه

            // ... پردازش Height و Weight مثل قبل ...

            // ✅ پردازش Systolic BP
            for (let si = 0; si < bpSystolicList.length; si++) {
                let dateTime = new Date(bpSystolicList[si].x)
                let timestamp = dateTime.getTime()
                let systolic = bpSystolicList[si].y

                spLine3.append(timestamp, systolic)

                minTime = Math.min(minTime, timestamp)
                maxTime = Math.max(maxTime, timestamp)
                minBP = Math.min(minBP, systolic)
                maxBP = Math.max(maxBP, systolic)
            }

            // ✅ پردازش Diastolic BP
            for (let di = 0; di < bpDiastolicList.length; di++) {
                let dateTime = new Date(bpDiastolicList[di].x)
                let timestamp = dateTime.getTime()
                let diastolic = bpDiastolicList[di].y

                spLine4.append(timestamp, diastolic)

                minTime = Math.min(minTime, timestamp)
                maxTime = Math.max(maxTime, timestamp)
                minBP = Math.min(minBP, diastolic)
                maxBP = Math.max(maxBP, diastolic)
            }

            // ... تنظیم axisX, axisY1, axisY2 مثل قبل ...

            // ✅ تنظیم محور Y3 (فشار خون)
            if (bpSystolicList.length > 0 || bpDiastolicList.length > 0) {
                let bpRange = maxBP - minBP
                let bpPadding = Math.max(bpRange * 0.15, 10)  // حداقل 10 mmHg padding

                axisY3.min = Math.max(60, minBP - bpPadding)   // حداقل 60
                axisY3.max = Math.min(200, maxBP + bpPadding)  // حداکثر 200
            }

            console.log("✅ نمودار بروزرسانی شد:")
            console.log("   زمان:", new Date(minTime).toLocaleString(), "→", new Date(maxTime).toLocaleString())
            console.log("   قد:", minHeight.toFixed(2), "→", maxHeight.toFixed(2))
            console.log("   وزن:", minWeight.toFixed(2), "→", maxWeight.toFixed(2))
            console.log("   فشار خون:", minBP.toFixed(0), "→", maxBP.toFixed(0), "mmHg")  // ✅ اضافه
        }

        function onNewPoint(dataPoint1,dataPoint2){
            let dateTime = new Date(dataPoint1.x)
            spLine1.append(dateTime.getTime(),dataPoint1.y)
            spLine2.append(dateTime.getTime(),dataPoint2.y)
            //debugText.text = dateTime.getTime() + " -- data : " + dataPoint.y

            // ✅ Auto-scroll: وقتی از محدوده خارج شد، محور رو shift بده
            if (dateTime.getTime() > (axisX.max.getTime() - 1000)) {
                let range = axisX.max.getTime() - axisX.min.getTime()
                axisX.min = new Date(dateTime.getTime() - range + 1000)
                axisX.max = new Date(dateTime.getTime() + 1000)
            }

        }
    }
}
