import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: messageInput
    height: 90
    color: "#1A1A2E"
    
    signal sendMessage(string text)
    property bool canSend: true
    
    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#A78BFA" }
            GradientStop { position: 0.5; color: "#F472B6" }
            GradientStop { position: 1.0; color: "#A78BFA" }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12

        InputField {
            id: userInput
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            onReturnPressed: {
                if (messageInput.canSend) {
                    messageInput.sendMessage(userInput.text.trim())
                }
            }
        }

        SendButton {
            Layout.preferredWidth: 50
            Layout.preferredHeight: 50
            enabled: messageInput.canSend && userInput.text.trim() !== ""
            onClicked: {
                messageInput.sendMessage(userInput.text.trim())
            }
        }
    }
    
    function clear() {
        userInput.clear()
    }
}