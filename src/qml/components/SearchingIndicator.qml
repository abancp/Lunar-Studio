import QtQuick
import QtQuick.Layouts

Rectangle {
    id: searchingIndicator
    Layout.fillWidth: true
    Layout.preferredHeight: 40
    radius: 20
    color: "#1E1530"
    border.color: "#C084FC"
    border.width: 1.5
    
    RowLayout {
        anchors.centerIn: parent
        spacing: 8
        
        Text {
            text: "🔍"
            font.pixelSize: 16
            
            SequentialAnimation on opacity {
                running: true
                loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 0.3; duration: 800 }
                NumberAnimation { from: 0.3; to: 1.0; duration: 800 }
            }
        }
        
        Text {
            text: "Searching..."
            font.pixelSize: 13
            color: "#C084FC"
            
            SequentialAnimation on opacity {
                running: true
                loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 0.5; duration: 1000 }
                NumberAnimation { from: 0.5; to: 1.0; duration: 1000 }
            }
        }
    }
}