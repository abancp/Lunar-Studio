import QtQuick
import QtQuick.Layouts

Rectangle {
    Layout.preferredWidth: searchedLabel.width + 16
    Layout.preferredHeight: 24
    radius: 12
    color: "#1E1530"
    border.color: "#10B981"
    border.width: 1
    
    RowLayout {
        anchors.centerIn: parent
        spacing: 4
        
        Text {
            text: "✓"
            font.pixelSize: 11
            color: "#10B981"
            font.bold: true
        }
        
        Text {
            id: searchedLabel
            text: "Searched"
            font.pixelSize: 11
            color: "#10B981"
        }
    }
}