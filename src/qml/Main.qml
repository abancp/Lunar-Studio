import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: window
    width: 800
    height: 600
    visible: true
    title: "Lunar Studio"

StackView {
    id: stack
    anchors.fill: parent
    // use absolute QRC path — prefer this while debugging
    initialItem: "qrc:/LunarStudioUI/src/qml/pages/LoadingPage.qml"
}

    function goToChat() {
        stack.replace(Qt.resolvedUrl("pages/ChatPage.qml"))
    }
}
