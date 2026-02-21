import QtQuick
import QtQuick.Controls

Rectangle {
    id: root

    property bool expanded: false

    // ✅ FIX: استفاده از required برای اطمینان از ارسال themeManager
    required property var themeManager

    // Signals برای ارسال داده
    signal heightSubmitted(double value)
    signal weightSubmitted(double value)
    signal bloodPressureSubmitted(int systolic, int diastolic)
    signal heartRateSubmitted(double bpm)
    signal bloodGlucoseSubmitted(double glucoseMgDl, int specimenSource, int mealType, int relationToMeal)
    signal oxygenSaturationSubmitted(double value)

    // ── بازه زمانی ──
    signal dateRangePickerRequested(string target, var initialDate)

    property var fromDateTime: {
        var d = new Date()
        d.setMonth(d.getMonth() - 1)
        return d
    }
    property var toDateTime: new Date()
    property string _activeDateTarget: "from"

    function applySelectedDate(selectedDate) {
        if (_activeDateTarget === "from") {
            fromDateTime = selectedDate
            fromLabel.text = Qt.formatDateTime(selectedDate, "yyyy/MM/dd  HH:mm:ss")
        } else {
            toDateTime = selectedDate
            toLabel.text = Qt.formatDateTime(selectedDate, "yyyy/MM/dd  HH:mm:ss")
        }
    }

    function parseDateTime(text) {
        var regex = /^(\d{4})\/(\d{2})\/(\d{2})\s+(\d{2}):(\d{2}):(\d{2})$/
        var match = text.match(regex)
        if (!match) return new Date()
        return new Date(parseInt(match[1]), parseInt(match[2])-1,
                        parseInt(match[3]), parseInt(match[4]), parseInt(match[5]), parseInt(match[6]))
    }

    function formatDate(d) {
        if (!d || !(d instanceof Date) || isNaN(d.getTime())) {
            return Qt.formatDateTime(new Date(), "yyyy/MM/dd  hh:mm:ss")
        }
        return Qt.formatDateTime(d, "yyyy/MM/dd  hh:mm:ss")
    }

    function getFromDate() { return parseDateTime(fromLabel.text) }
    function getToDate()   { return parseDateTime(toLabel.text)   }

    // Properties برای نمایش وضعیت
    property alias heightStatusText: heightStatus.text
    property alias heightStatusColor: heightStatus.color
    property alias weightStatusText: weightStatus.text
    property alias weightStatusColor: weightStatus.color
    property alias bpStatusText: bpStatus.text
    property alias bpStatusColor: bpStatus.color
    property alias heartRateStatusText: heartRateStatus.text
    property alias heartRateStatusColor: heartRateStatus.color
    property alias bloodGlucoseStatusText: bloodGlucoseStatus.text
    property alias bloodGlucoseStatusColor: bloodGlucoseStatus.color
    property alias oxygenSaturationStatusText: oxygenSaturationStatus.text
    property alias oxygenSaturationStatusColor: oxygenSaturationStatus.color

    width: expanded ? (parent.width / 3) : 0

    // ✅ FIX: اطمینان از استفاده درست از themeManager
    color: root.themeManager.surfaceColor
    border.color: root.themeManager.panelBorderColor
    border.width: expanded ? 1 : 0
    clip: true

    Behavior on width {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }
    }

    Behavior on border.color { ColorAnimation { duration: 300 } }

    ScrollView {
        anchors.fill: parent
        visible: expanded
        clip: true

        background: Rectangle {
            color: root.themeManager.cardColor
        }

        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        Column {
            width: root.width - 20
            spacing: 20
            padding: 15

            // ===== بخش بازه زمانی خواندن داده =====
            Column {
                width: parent.width
                spacing: 8

                Text {
                    text: "📆 بازه زمانی نمایش"
                    font.pixelSize: 16
                    font.bold: true
                    color: root.themeManager.primaryTextColor
                    Behavior on color { ColorAnimation { duration: 300 } }
                }

                // ─── از ───
                Text {
                    text: "از:"
                    font.pixelSize: 12
                    color: root.themeManager.secondaryTextColor
                    Behavior on color { ColorAnimation { duration: 300 } }
                }

                Rectangle {
                    width: parent.width
                    height: 44
                    radius: 6
                    color: root.themeManager.inputBackgroundColor
                    border.color: fromHover.containsMouse
                                  ? root.themeManager.accentColor
                                  : root.themeManager.inputBorderColor
                    border.width: 1

                    Behavior on color       { ColorAnimation { duration: 200 } }
                    Behavior on border.color { ColorAnimation { duration: 200 } }

                    Row {
                        spacing: 7

                        Text {
                            anchors.centerIn: parent
                            text: "📅"
                            font.pixelSize: 16

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.fromDateTime = new Date()
                                    fromLabel.text = formatDate(root.fromDateTime)
                                }
                            }
                        }

                        Text {
                            id: fromLabel
                            font.pixelSize: 13
                            color: root.themeManager.primaryTextColor
                            text : formatDate(root.fromDateTime)
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: 300 } }

                            MouseArea {
                                id: fromHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root._activeDateTarget = "from"
                                    root.dateRangePickerRequested("from", root.fromDateTime)
                                }
                            }
                        }
                    }
                }

                // ─── تا ───
                Text {
                    text: "تا:"
                    font.pixelSize: 12
                    color: root.themeManager.secondaryTextColor
                    Behavior on color { ColorAnimation { duration: 300 } }
                }

                Rectangle {
                    width: parent.width
                    height: 44
                    radius: 6
                    color: root.themeManager.inputBackgroundColor
                    border.color: toHover.containsMouse
                                  ? root.themeManager.accentColor
                                  : root.themeManager.inputBorderColor
                    border.width: 1

                    Behavior on color       { ColorAnimation { duration: 200 } }
                    Behavior on border.color { ColorAnimation { duration: 200 } }

                    Row {
                        spacing: 7

                        Text {
                            anchors.centerIn: parent
                            text: "📅"
                            font.pixelSize: 16

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.toDateTime = new Date()
                                    toLabel.text = formatDate(root.toDateTime)
                                }
                            }
                        }

                        Text {
                            id: toLabel
                            font.pixelSize: 13
                            text: formatDate(root.toDateTime)
                            color: root.themeManager.primaryTextColor
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: 300 } }

                            MouseArea {
                                id: toHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root._activeDateTarget = "to"
                                    root.dateRangePickerRequested("to", root.toDateTime)
                                }
                            }
                        }
                    }

                }
            }

            Divider {
                themeManager: root.themeManager
            }


            // ===== بخش قد =====
            Column {
                width: parent.width
                spacing: 10

                Text {
                    text: "📏 قد (متر)"
                    font.pixelSize: 16
                    font.bold: true
                    color: root.themeManager.primaryTextColor
                    Behavior on color { ColorAnimation { duration: 300 } }
                }

                TextField {
                    id: heightInput
                    width: parent.width
                    placeholderText: "مثال: 1.75"
                    placeholderTextColor: root.themeManager.inputPlaceholderColor

                    background: Rectangle {
                        color: root.themeManager.inputBackgroundColor
                        border.color: root.themeManager.inputBorderColor
                        border.width: 1
                        radius: 4

                        Behavior on color { ColorAnimation { duration: 300 } }
                        Behavior on border.color { ColorAnimation { duration: 300 } }
                    }

                    color: root.themeManager.primaryTextColor
                    Behavior on color { ColorAnimation { duration: 300 } }

                    KeyNavigation.tab: heightRegister
                }

                CButton {
                    id: heightRegister
                    text: "ثبت قد"
                    width: parent.width
                    height: 40
                    themeManager: root.themeManager  // ✅ ارسال theme به دکمه

                    onClicked: {
                        let value = parseFloat(heightInput.text)
                        if (!isNaN(value) && value > 0) {
                            root.heightSubmitted(value)
                        } else {
                            heightStatus.text = "❌ مقدار نامعتبر"
                            heightStatus.color = "red"
                        }
                        heightInput.text = ""
                    }

                    KeyNavigation.tab: weightInput
                }

                Text {
                    id: heightStatus
                    width: parent.width
                    wrapMode: Text.WordWrap
                    font.pixelSize: 11
                    color: "gray"
                }
            }

            Divider {
                themeManager: root.themeManager
            }

            // ===== بخش وزن =====
            Column {
                width: parent.width
                spacing: 10

                Text {
                    text: "⚖️ وزن (کیلوگرم)"
                    font.pixelSize: 16
                    font.bold: true
                    color: root.themeManager.primaryTextColor

                    Behavior on color { ColorAnimation { duration: 300 } }
                }

                TextField {
                    id: weightInput
                    width: parent.width
                    placeholderText: "مثال: 70.5"
                    placeholderTextColor: root.themeManager.inputPlaceholderColor

                    background: Rectangle {
                        color:  root.themeManager.inputBackgroundColor
                        border.color: root.themeManager.inputBorderColor
                        border.width: 1
                        radius: 4

                        Behavior on color { ColorAnimation { duration: 300 } }
                        Behavior on border.color { ColorAnimation { duration: 300 } }
                    }

                    color: root.themeManager.primaryTextColor

                    Behavior on color { ColorAnimation { duration: 300 } }
                    KeyNavigation.tab: weightRegister
                }

                CButton {
                    id: weightRegister
                    text: "ثبت وزن"
                    width: parent.width
                    height: 40
                    themeManager: root.themeManager  // ✅ ارسال theme به دکمه

                    onClicked: {
                        let value = parseFloat(weightInput.text)
                        if (!isNaN(value) && value > 0) {
                            root.weightSubmitted(value)
                        } else {
                            weightStatus.text = "❌ مقدار نامعتبر"
                            weightStatus.color = "red"
                        }
                        weightInput.text = ""
                    }
                    KeyNavigation.tab: systolicInput
                }

                Text {
                    id: weightStatus
                    width: parent.width
                    wrapMode: Text.WordWrap
                    font.pixelSize: 11
                    color: "gray"
                }
            }

            Divider {
                themeManager: root.themeManager
            }

            // ===== بخش فشار خون =====
            Column {
                width: parent.width
                spacing: 10

                Text {
                    text: "💉 فشار خون (mmHg)"
                    font.pixelSize: 16
                    font.bold: true
                    color: root.themeManager.primaryTextColor

                    Behavior on color { ColorAnimation { duration: 300 } }
                }

                Row {
                    width: parent.width
                    spacing: 10

                    TextField {
                        id: diastolicInput
                        width: (parent.width - 10) / 2
                        placeholderText: "دیاستولیک (80)"
                        placeholderTextColor: root.themeManager.inputPlaceholderColor

                        background: Rectangle {
                            color: root.themeManager.inputBackgroundColor
                            border.color: root.themeManager.inputBorderColor
                            border.width: 2
                            radius: 4

                            Behavior on color { ColorAnimation { duration: 300 } }
                            Behavior on border.color { ColorAnimation { duration: 300 } }
                        }

                        color: root.themeManager.primaryTextColor

                        Behavior on color { ColorAnimation { duration: 300 } }
                        KeyNavigation.tab: persureRegister
                    }

                    TextField {
                        id: systolicInput
                        width: (parent.width - 10) / 2
                        placeholderText: "سیستولیک (120)"
                        placeholderTextColor: root.themeManager.inputPlaceholderColor

                        background: Rectangle {
                            color: root.themeManager.inputBackgroundColor
                            border.color: root.themeManager.inputBorderColor
                            border.width: 2
                            radius: 4

                            Behavior on color { ColorAnimation { duration: 300 } }
                            Behavior on border.color { ColorAnimation { duration: 300 } }
                        }

                        color: root.themeManager.primaryTextColor

                        Behavior on color { ColorAnimation { duration: 300 } }
                        KeyNavigation.tab: diastolicInput
                    }
                }

                CButton {
                    id: persureRegister
                    text: "ثبت فشار خون"
                    width: parent.width
                    height: 40
                    themeManager: root.themeManager  // ✅ ارسال theme به دکمه

                    onClicked: {
                        let sys = parseInt(systolicInput.text)
                        let dia = parseInt(diastolicInput.text)

                        if (!isNaN(sys) && !isNaN(dia) && sys > 0 && dia > 0) {
                            root.bloodPressureSubmitted(sys, dia)
                        } else {
                            bpStatus.text = "❌ مقادیر نامعتبر"
                            bpStatus.color = "red"
                        }
                        systolicInput.text = ""
                        diastolicInput.text = ""
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

            Divider {
                themeManager: root.themeManager
            }

            // ===== بخش ضربان قلب =====
            Column {
                width: parent.width
                spacing: 10

                Text {
                    text: "💓 ضربان قلب (BPM)"
                    font.pixelSize: 16
                    font.bold: true
                    color: root.themeManager.primaryTextColor
                    Behavior on color { ColorAnimation { duration: 300 } }
                }

                TextField {
                    id: heartRateInput
                    width: parent.width
                    placeholderText: "مثال: 75"
                    placeholderTextColor: root.themeManager.inputPlaceholderColor

                    background: Rectangle {
                        color: root.themeManager.inputBackgroundColor
                        border.color: root.themeManager.inputBorderColor
                        border.width: 1
                        radius: 4
                        Behavior on color { ColorAnimation { duration: 300 } }
                        Behavior on border.color { ColorAnimation { duration: 300 } }
                    }

                    color: root.themeManager.primaryTextColor
                    Behavior on color { ColorAnimation { duration: 300 } }
                    KeyNavigation.tab: heartRateRegister
                }

                CButton {
                    id: heartRateRegister
                    text: "ثبت ضربان قلب"
                    width: parent.width
                    height: 40
                    themeManager: root.themeManager

                    onClicked: {
                        let value = parseFloat(heartRateInput.text)
                        if (!isNaN(value) && value > 0 && value < 300) {
                            root.heartRateSubmitted(value)
                        } else {
                            heartRateStatus.text = "❌ مقدار نامعتبر (1-300)"
                            heartRateStatus.color = "red"
                        }
                        heartRateInput.text = ""
                    }
                    KeyNavigation.tab: bloodGlucoseInput
                }

                Text {
                    id: heartRateStatus
                    width: parent.width
                    wrapMode: Text.WordWrap
                    font.pixelSize: 11
                    color: "gray"
                }
            }

            Divider {
                themeManager: root.themeManager
            }

            // ===== بخش قند خون =====
            Column {
                width: parent.width
                spacing: 10

                Text {
                    text: "🩸 قند خون (mg/dL)"
                    font.pixelSize: 16
                    font.bold: true
                    color: root.themeManager.primaryTextColor
                    Behavior on color { ColorAnimation { duration: 300 } }
                }

                TextField {
                    id: bloodGlucoseInput
                    width: parent.width
                    placeholderText: "مثال: 95"
                    placeholderTextColor: root.themeManager.inputPlaceholderColor

                    background: Rectangle {
                        color: root.themeManager.inputBackgroundColor
                        border.color: root.themeManager.inputBorderColor
                        border.width: 1
                        radius: 4
                        Behavior on color { ColorAnimation { duration: 300 } }
                        Behavior on border.color { ColorAnimation { duration: 300 } }
                    }

                    color: root.themeManager.primaryTextColor
                    Behavior on color { ColorAnimation { duration: 300 } }
                    KeyNavigation.tab: specimenSourceCombo
                }

                // نوع نمونه
                Text {
                    text: "نوع نمونه:"
                    font.pixelSize: 14
                    color: root.themeManager.secondaryTextColor
                    Behavior on color { ColorAnimation { duration: 300 } }
                }

                ComboBox {
                    id: specimenSourceCombo
                    width: parent.width
                    model: [
                        "خون مویرگی (انگشت)",
                        "خون وریدی",
                        "خون شریانی",
                        "پلاسمای مویرگی",
                        "پلاسمای وریدی",
                        "سرم",
                        "اشک",
                        "مایع بینابینی"
                    ]

                    // مقدار پیش‌فرض
                    currentIndex: 0

                    background: Rectangle {
                        color: root.themeManager.inputBackgroundColor
                        border.color: root.themeManager.inputBorderColor
                        border.width: 1
                        radius: 4
                        Behavior on color { ColorAnimation { duration: 300 } }
                        Behavior on border.color { ColorAnimation { duration: 300 } }
                    }

                    contentItem: Text {
                        text: specimenSourceCombo.displayText
                        font.pixelSize: 14
                        color: root.themeManager.primaryTextColor
                        verticalAlignment: Text.AlignVCenter
                        rightPadding: 30
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }

                    KeyNavigation.tab: mealTypeCombo
                }

                // نوع وعده غذایی
                Text {
                    text: "نوع وعده:"
                    font.pixelSize: 14
                    color: root.themeManager.secondaryTextColor
                    Behavior on color { ColorAnimation { duration: 300 } }
                }

                ComboBox {
                    id: mealTypeCombo
                    width: parent.width
                    model: [
                        "نامشخص",
                        "صبحانه",
                        "ناهار",
                        "شام",
                        "میان‌وعده"
                    ]

                    currentIndex: 0

                    background: Rectangle {
                        color: root.themeManager.inputBackgroundColor
                        border.color: root.themeManager.inputBorderColor
                        border.width: 1
                        radius: 4
                        Behavior on color { ColorAnimation { duration: 300 } }
                        Behavior on border.color { ColorAnimation { duration: 300 } }
                    }

                    contentItem: Text {
                        text: mealTypeCombo.displayText
                        font.pixelSize: 14
                        color: root.themeManager.primaryTextColor
                        verticalAlignment: Text.AlignVCenter
                        rightPadding: 30
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }

                    KeyNavigation.tab: relationToMealCombo
                }

                // زمان‌بندی نسبت به وعده
                Text {
                    text: "زمان‌بندی:"
                    font.pixelSize: 14
                    color: root.themeManager.secondaryTextColor
                    Behavior on color { ColorAnimation { duration: 300 } }
                }

                ComboBox {
                    id: relationToMealCombo
                    width: parent.width
                    model: [
                        "عمومی",
                        "ناشتا",
                        "قبل از غذا",
                        "بعد از غذا",
                        "۳۰ دقیقه بعد از غذا",
                        "۶۰ دقیقه بعد از غذا",
                        "۹۰ دقیقه بعد از غذا",
                        "۱۲۰ دقیقه بعد از غذا"
                    ]

                    currentIndex: 0

                    background: Rectangle {
                        color: root.themeManager.inputBackgroundColor
                        border.color: root.themeManager.inputBorderColor
                        border.width: 1
                        radius: 4
                        Behavior on color { ColorAnimation { duration: 300 } }
                        Behavior on border.color { ColorAnimation { duration: 300 } }
                    }

                    contentItem: Text {
                        text: relationToMealCombo.displayText
                        font.pixelSize: 14
                        color: root.themeManager.primaryTextColor
                        verticalAlignment: Text.AlignVCenter
                        rightPadding: 30
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }

                    KeyNavigation.tab: bloodGlucoseRegister
                }

                CButton {
                    id: bloodGlucoseRegister
                    text: "ثبت قند خون"
                    width: parent.width
                    height: 40
                    themeManager: root.themeManager

                    onClicked: {
                        let value = parseFloat(bloodGlucoseInput.text)
                        if (!isNaN(value) && value > 0 && value < 600) {
                            // تبدیل index به مقدار واقعی
                            let specimenMap = [1, 2, 3, 4, 5, 6, 7, 8] // مطابق Android Health Connect
                            let mealMap = [0, 1, 2, 3, 4] // UNKNOWN=0, BREAKFAST=1, ...
                            let relationMap = [0, 1, 2, 3, 4, 5, 6, 7] // GENERAL=0, FASTING=1, ...

                            root.bloodGlucoseSubmitted(
                                        value,
                                        specimenMap[specimenSourceCombo.currentIndex],
                                        mealMap[mealTypeCombo.currentIndex],
                                        relationMap[relationToMealCombo.currentIndex]
                                        )
                        } else {
                            bloodGlucoseStatus.text = "❌ مقدار نامعتبر (1-600)"
                            bloodGlucoseStatus.color = "red"
                        }
                        bloodGlucoseInput.text = ""
                        specimenSourceCombo.currentIndex = 0
                        mealTypeCombo.currentIndex = 0
                        relationToMealCombo.currentIndex = 0
                    }
                }

                Text {
                    id: bloodGlucoseStatus
                    width: parent.width
                    wrapMode: Text.WordWrap
                    font.pixelSize: 11
                    color: "gray"
                }
            }

            Divider {
                themeManager: root.themeManager
            }

            // ===== بخش اشباع اکسیژن خون (SpO₂) =====
            Column {
                width: parent.width
                spacing: 10

                Text {
                    text: "🫁 اشباع اکسیژن خون (SpO₂ %)"
                    font.pixelSize: 16
                    font.bold: true
                    color: root.themeManager.primaryTextColor
                    Behavior on color { ColorAnimation { duration: 300 } }
                }

                TextField {
                    id: oxygenSaturationInput
                    width: parent.width
                    placeholderText: "مثال: 98"
                    placeholderTextColor: root.themeManager.inputPlaceholderColor

                    background: Rectangle {
                        color: root.themeManager.inputBackgroundColor
                        border.color: root.themeManager.inputBorderColor
                        border.width: 1
                        radius: 4
                        Behavior on color { ColorAnimation { duration: 300 } }
                        Behavior on border.color { ColorAnimation { duration: 300 } }
                    }

                    color: root.themeManager.primaryTextColor
                    Behavior on color { ColorAnimation { duration: 300 } }
                    KeyNavigation.tab: oxygenSaturationRegister

                    // اعتبارسنجی ورودی: فقط اعداد و نقطه
                    validator: RegularExpressionValidator {
                        regularExpression: /^(100(\.0{1,2})?|[1-9]?\d(\.\d{1,2})?)$/
                    }
                }

                // راهنما برای محدوده طبیعی
                Text {
                    text: "محدوده طبیعی: 95-100%"
                    font.pixelSize: 12
                    color: root.themeManager.secondaryTextColor
                    Behavior on color { ColorAnimation { duration: 300 } }
                }

                CButton {
                    id: oxygenSaturationRegister
                    text: "ثبت اشباع اکسیژن"
                    width: parent.width
                    height: 40
                    themeManager: root.themeManager

                    onClicked: {
                        let value = parseFloat(oxygenSaturationInput.text)

                        // اعتبارسنجی دقیق
                        if (!isNaN(value) && value >= 0 && value <= 100) {
                            root.oxygenSaturationSubmitted(value)
                            oxygenSaturationInput.text = ""

                            // پیام هشدار برای مقادیر غیرطبیعی
                            if (value < 90) {
                                oxygenSaturationStatus.text = "⚠️ هشدار: مقدار پایین‌تر از حد طبیعی!"
                                oxygenSaturationStatus.color = "red"
                            } else if (value < 95) {
                                oxygenSaturationStatus.text = "⚡ توجه: مقدار کمتر از حد مطلوب"
                                oxygenSaturationStatus.color = "orange"
                            }
                        } else {
                            oxygenSaturationStatus.text = "❌ مقدار باید بین 0 تا 100 باشد"
                            oxygenSaturationStatus.color = "red"
                        }
                    }

                    // کلید Enter برای ثبت سریع
                    Keys.onReturnPressed: clicked()
                    Keys.onEnterPressed: clicked()
                }

                Text {
                    id: oxygenSaturationStatus
                    width: parent.width
                    wrapMode: Text.WordWrap
                    font.pixelSize: 11
                    color: "gray"
                }

                // اطلاعات اضافی
                Rectangle {
                    width: parent.width
                    height: infoColumn.height + 16
                    color: root.themeManager.infoBoxColor || Qt.rgba(0.5, 0.7, 1.0, 0.1)
                    radius: 6
                    border.color: root.themeManager.infoBorderColor || Qt.rgba(0.3, 0.5, 0.8, 0.3)
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 300 } }
                    Behavior on border.color { ColorAnimation { duration: 300 } }

                    Column {
                        id: infoColumn
                        anchors.centerIn: parent
                        width: parent.width - 16
                        spacing: 4

                        Text {
                            text: "ℹ️ راهنما:"
                            font.pixelSize: 11
                            font.bold: true
                            color: root.themeManager.primaryTextColor
                            Behavior on color { ColorAnimation { duration: 300 } }
                        }

                        Text {
                            text: "• 95-100%: طبیعی"
                            font.pixelSize: 10
                            color: root.themeManager.secondaryTextColor
                            Behavior on color { ColorAnimation { duration: 300 } }
                        }

                        Text {
                            text: "• 90-95%: نیاز به توجه"
                            font.pixelSize: 10
                            color: root.themeManager.secondaryTextColor
                            Behavior on color { ColorAnimation { duration: 300 } }
                        }

                        Text {
                            text: "• <90%: مراجعه به پزشک"
                            font.pixelSize: 10
                            color: root.themeManager.secondaryTextColor
                            Behavior on color { ColorAnimation { duration: 300 } }
                        }
                    }
                }
            }
        }
    }

}
