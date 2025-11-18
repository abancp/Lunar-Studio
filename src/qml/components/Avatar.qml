import QtQuick

Rectangle {
    id: avatar
    width: 36
    height: 36
    radius: 18
    
    property string role: "user"
    
    gradient: Gradient {
        GradientStop { 
            position: 0.0
            color: avatar.role === "user" ? "#F472B6" : "#8B5CF6"
        }
        GradientStop { 
            position: 1.0
            color: avatar.role === "user" ? "#EC4899" : "#7C3AED"
        }
    }

    Text {
        anchors.centerIn: parent
        text: avatar.role === "user" ? "U" : "AI"
        color: "white"
        font.pixelSize: 14
        font.bold: true
    }
}