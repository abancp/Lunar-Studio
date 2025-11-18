import QtQuick
import QtQuick.Controls

Button {
    id: sendButton
    
    background: Rectangle {
        radius: 25
        gradient: Gradient {
            GradientStop { 
                position: 0.0
                color: sendButton.hovered ? "#BE185D" : "#EC4899"
            }
            GradientStop { 
                position: 1.0
                color: sendButton.hovered ? "#7C3AED" : "#8B5CF6"
            }
        }
    }

    contentItem: Text {
        text: "→"
        font.pixelSize: 24
        color: "white"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.bold: true
        opacity: sendButton.enabled ? 1.0 : 0.5
    }
}