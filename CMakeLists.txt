cmake_minimum_required(VERSION 3.16)

file(STRINGS "${CMAKE_SOURCE_DIR}/VERSION" APP_VERSION)
project(QMLHealthConnect VERSION ${APP_VERSION} LANGUAGES CXX)

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
        QT_ANDROID_PACKAGE_SOURCE_DIR
            ${CMAKE_CURRENT_SOURCE_DIR}/android
    )
endif()

include(GNUInstallDirs)
install(TARGETS QMLHealthConnect
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
