import QtQuick
import QtQuick.Controls

Rectangle {
    id: inputField
    radius: 25
    color: "#0F0F1E"
    border.color: inputField.activeFocus ? "#C084FC" : "#8B5CF6"
    border.width: inputField.activeFocus ? 2 : 1.5
    
    signal returnPressed()
    
    Behavior on border.color {
        ColorAnimation { duration: 200 }
    }

    TextField {
        id: textField
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        placeholderText: "Type your message..."
        font.pixelSize: 15
        background: Item {}
        color: "#E9D5FF"
        
        Keys.onReturnPressed: {
            inputField.returnPressed()
        }
    }
    
    function clear() {
        textField.text = ""
    }
    
    property alias text: textField.text
}