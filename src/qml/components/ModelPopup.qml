import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: modelPopup
    width: 400
    height: 320
    modal: true
    focus: true
    padding: 0
    
    background: Rectangle {
        radius: 6
        color: "#1F2937"
        border.color: "#8B5CF6"
        border.width: 1
        
        layer.enabled: true
        layer.effect: ShaderEffect {
            property color shadowColor: "#40000000"
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            
            Text {
                Layout.fillWidth: true
                text: "Select Model"
                font.pixelSize: 16
                font.bold: true
                color: "#E9D5FF"
            }
            
            IconButton {
                icon: "✕"
                onClicked: modelPopup.close()
            }
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: ListModel {
                ListElement { name: "Gemma 3"; size: "270M"; loaded: false }
                ListElement { name: "Qwen 2.5"; size: "0.5B"; loaded: false }
                ListElement { name: "Qwen 3"; size: "0.6B"; loaded: true }
            }
            spacing: 4
            clip: true

            delegate: Rectangle {
                width: ListView.view.width
                height: 48
                radius: 6
                color: modelMouseArea.containsMouse ? "#374151" : "transparent"
                
                Behavior on color {
                    ColorAnimation { duration: 150 }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 8
                        Layout.preferredHeight: 8
                        radius: 4
                        color: model.loaded ? "#10B981" : "#6B7280"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: model.name
                            font.pixelSize: 13
                            color: "white"
                            font.weight: Font.Medium
                        }

                        Text {
                            text: model.size + " parameters"
                            font.pixelSize: 11
                            color: "#9CA3AF"
                        }
                    }

                    Text {
                        text: model.loaded ? "✓" : ""
                        font.pixelSize: 16
                        color: "#10B981"
                    }
                }

                MouseArea {
                    id: modelMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    
                    onClicked: {
                        modelPopup.selected(model.name)
                        modelPopup.close()
                    }
                }
            }
        }
    }
    
    signal selected(string modelName)
}