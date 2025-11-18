import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Button {
    preferredHeight: 32
    preferredWidth: 110
    
    background: Rectangle {
        radius: 8
        color: parent.hovered ? "#BE185D" : "#DB2777"
        
        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }

    contentItem: RowLayout {
        spacing: 6
        anchors.centerIn: parent
        
        Text {
            text: "↓"
            font.pixelSize: 16
            color: "white"
            font.bold: true
        }
        
        Text {
            text: "Load Model"
            font.pixelSize: 12
            color: "white"
            font.weight: Font.Medium
        }
    }
}