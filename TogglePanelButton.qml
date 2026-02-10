import QtQuick

CButton {
    id: root

    property bool panelExpanded: true
    text: panelExpanded ? "◀" : "▶"
    width: 30
    height: 30
    signal togglePanel()

    onClicked: {
        togglePanel()
    }
}
