import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: header
    height: 60
    color: "#8B5CF6"
    
    signal modelSelectorClicked()
    signal loadModelClicked()
    signal pluginsClicked()
    
    property string currentModel: "Gemma 3 270M"
    
    // Subtle gradient overlay
    Rectangle {
        anchors.fill: parent
        color: "#0F0F1E"
        opacity: 0.8
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        spacing: 16

        // App Icon & Title
        RowLayout {
            spacing: 8
            
            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 6
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#EC4899" }
                    GradientStop { position: 1.0; color: "#8B5CF6" }
                }

                Text {
                    anchors.centerIn: parent
                    text: "⚡"
                    font.pixelSize: 16
                }
            }

            Text {
                text: "Lunar Studio"
                font.pixelSize: 15
                font.bold: true
                color: "white"
            }
        }

        // Spacer to push buttons to center/right
        Item {
            Layout.fillWidth: true
        }

        // Model Selector
        ModelSelectorButton {
            currentModel: header.currentModel
            onClicked: header.modelSelectorClicked()
        }

        // Load Model Button
        LoadModelButton {
            onClicked: header.loadModelClicked()
        }

        // Settings/Plugin Icon
        IconButton {
            icon: "🔌"
            tooltip: "Plugins"
            onClicked: header.pluginsClicked()
        }
    }

    // Bottom border with gradient
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 2
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#A78BFA" }
            GradientStop { position: 0.5; color: "#F472B6" }
            GradientStop { position: 1.0; color: "#A78BFA" }
        }
    }
}