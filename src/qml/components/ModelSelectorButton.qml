import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Button {
    id: modelSelector
    preferredHeight: 32
    preferredWidth: 180
    
    property string currentModel: "Gemma 3 270M"
    
    background: Rectangle {
        radius: 8
        color: parent.hovered ? "#7C3AED" : "#6D28D9"
        border.color: "#A78BFA"
        border.width: 1
        
        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }

    contentItem: RowLayout {
        spacing: 8
        
        Text {
            text: "📦"
            font.pixelSize: 16
        }
        
        Text {
            Layout.fillWidth: true
            text: modelSelector.currentModel
            font.pixelSize: 13
            color: "white"
            elide: Text.ElideRight
        }
        
        Text {
            text: "▼"
            font.pixelSize: 10
            color: "#E9D5FF"
        }
    }
}