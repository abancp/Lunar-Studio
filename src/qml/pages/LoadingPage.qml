import QtQuick
import QtQuick.Controls

Item {
    id: root

    Rectangle {
        anchors.fill: parent
        color: "#121212"

        Column {
            anchors.centerIn: parent
            spacing: 20

            BusyIndicator {
                running: true
                width: 60
                height: 60
            }

            Text {
                text: "Loading Local LLM..."
                color: "white"
                font.pixelSize: 20
            }
        }
    }

    Timer {
        id: loader
        interval: 1800
        repeat: false
        running: true
        onTriggered: {
            window.goToChat()
        }
    }
}
