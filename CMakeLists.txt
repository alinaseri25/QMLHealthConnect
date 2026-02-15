cmake_minimum_required(VERSION 3.16)

# ✅ خواندن VERSION از فایل
file(READ "${CMAKE_SOURCE_DIR}/VERSION" VERSION_STRING)
string(STRIP "${VERSION_STRING}" VERSION_STRING)

# ✅ تجزیه version به اجزای MAJOR.MINOR.PATCH
string(REPLACE "." ";" VERSION_LIST ${VERSION_STRING})
list(GET VERSION_LIST 0 VERSION_MAJOR)
list(GET VERSION_LIST 1 VERSION_MINOR)
list(GET VERSION_LIST 2 VERSION_PATCH)

# ✅ محاسبه versionCode (مثلاً: 1.3.0 → 10300)
math(EXPR VERSION_CODE "${VERSION_MAJOR} * 10000 + ${VERSION_MINOR} * 100 + ${VERSION_PATCH}")

project(QMLHealthConnect VERSION ${VERSION_STRING} LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Charts Core Gui Qml Quick Xml)

add_subdirectory(../../QXlsx/QXlsx QXlsx_build)

qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(QMLHealthConnect
    main.cpp
    backend.h backend.cpp
)

# ✅ استفاده از qt6_add_resources بجای qt_add_qml_module
qt6_add_resources(QMLHealthConnect "qmlchartsgallery"
    PREFIX "/"
    FILES
        Main.qml
        CButton.qml
        ThemeToggle.qml
        ThemeManager.qml
        HealthChartView.qml
        AxisInteractionZone.qml
        TogglePanelButton.qml
        ChartControlButtons.qml
        InputPanel.qml
        Divider.qml
        ChartTooltip.qml
)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(QMLHealthConnect PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.QMLHealthConnect
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(QMLHealthConnect PRIVATE
    Qt6::Charts
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::Xml
    QXlsx::QXlsx
)

if(ANDROID)
    set_target_properties(QMLHealthConnect PROPERTIES
        QT_ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/android"
        QT_ANDROID_VERSION_NAME "${VERSION_STRING}"
        QT_ANDROID_VERSION_CODE "${VERSION_CODE}"
    )

    # ✅ پیام debug
    message(STATUS "Android Version Name: ${VERSION_STRING}")
    message(STATUS "Android Version Code: ${VERSION_CODE}")
endif()

set_target_properties(QMLHealthConnect PROPERTIES
    MACOSX_BUNDLE_GUI_IDENTIFIER org.verya.QMLHealthConnect
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

include(GNUInstallDirs)
install(TARGETS QMLHealthConnect
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
