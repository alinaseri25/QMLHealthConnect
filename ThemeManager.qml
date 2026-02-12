import QtQuick

QtObject {
    id: themeManager

    property bool isDarkMode: Qt.styleHints.colorScheme === Qt.ColorScheme.Dark

    // رنگ‌های پس‌زمینه
    property color backgroundColor: isDarkMode ? "#1a1a1a" : "#f5f5f5"
    property color surfaceColor: isDarkMode ? "#2d2d2d" : "#ffffff"
    property color cardColor: isDarkMode ? "#383838" : "#ffffff"

    // رنگ‌های متن
    property color primaryTextColor: isDarkMode ? "#e0e0e0" : "#212121"
    property color secondaryTextColor: isDarkMode ? "#b0b0b0" : "#757575"
    property color hintTextColor: isDarkMode ? "#808080" : "#9e9e9e"

    // رنگ‌های دکمه
    property color accentColor: "#4caf50"
    property color accentPressed: "#43a047"

    // ===== رنگ‌های نمودار (جدید و متمایز) =====
    property color chartHeightColor: "#42A5F5"//isDarkMode ? "#42A5F5" : "#1976D2"        // آبی
    property color chartWeightColor: "#66BB6A"//isDarkMode ? "#66BB6A" : "#388E3C"        // سبز
    property color chartBPSystolicColor: "#EF5350"//isDarkMode ? "#EF5350" : "#D32F2F"    // قرمز
    property color chartBPDiastolicColor: isDarkMode ? "#FF9800" : "#F57C00"   // نارنجی
    property color chartHeartRateColor: isDarkMode ? "#AB47BC" : "#7B1FA2"    // بنفش - ضربان قلب
    property color chartBloodGlucoseColor: isDarkMode ? "#FFCA28" : "#F9A825" // زرد طلایی - قند خون

    // رنگ‌های محور
    property color axisColor: isDarkMode ? "#505050" : "#666666"
    property color axisLabelColor: isDarkMode ? "#b0b0b0" : "#444444"
    property color gridColor: isDarkMode ? "#404040" : "#e0e0e0"

    // رنگ‌های input
    property color inputBorderColor: isDarkMode ? "#505050" : "#aaaaaa"
    property color inputBackgroundColor: isDarkMode ? "#2d2d2d" : "#ffffff"
    property color inputPlaceholderColor: isDarkMode ? "#808080" : "#9e9e9e"

    // رنگ‌های وضعیت
    property color successColor: isDarkMode ? "#66bb6a" : "green"
    property color errorColor: isDarkMode ? "#ef5350" : "#cc0000"
    property color warningColor: isDarkMode ? "#ffa726" : "#cc8800"

    // رنگ‌های border
    property color panelBorderColor: isDarkMode ? "#505050" : "#bbbbbb"
    property color separatorColor: isDarkMode ? "#404040" : "#cccccc"

    function toggleTheme() {
        isDarkMode = !isDarkMode
        console.log("Theme changed to:", isDarkMode ? "Dark" : "Light")
    }
}
