import QtQuick
import QtQuick.Controls

Button {
    id: iconBtn
    preferredHeight: 32
    preferredWidth: 32
    
    property string icon: "⚡"
    property string tooltip: ""
    
    background: Rectangle {
        radius: 8
        color: parent.hovered ? "#7C3AED" : "transparent"
        
        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }

    contentItem: Text {
        text: iconBtn.icon
        font.pixelSize: 18
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    ToolTip.text: iconBtn.tooltip
    ToolTip.visible: hovered && tooltip !== ""
}