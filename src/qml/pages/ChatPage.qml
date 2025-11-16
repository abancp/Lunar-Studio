import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import LocalLLM 1.0

Page {
    id: chat
    background: Rectangle {
        color: "#F8F9FA"
    }

    Engine {
        id: engine
        onTokenGenerated: {
            if (chatMessages.count > 0) {
                var lastMsg = chatMessages.get(chatMessages.count - 1)
                if (lastMsg.role === "assistant") {
                    chatMessages.setProperty(chatMessages.count - 1, "text", lastMsg.text + token)
                }
            }
            scrollToBottom()
        }
        onGenerationFinished: {
            scrollToBottom()
            userInput.enabled = true
        }
    }

    ListModel {
        id: chatMessages
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Header
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 70
            color: "white"
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 15

                Rectangle {
                    Layout.preferredWidth: 45
                    Layout.preferredHeight: 45
                    radius: 22.5
                    color: "#4F46E5"

                    Text {
                        anchors.centerIn: parent
                        text: "AI"
                        color: "white"
                        font.pixelSize: 16
                        font.bold: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "AI Assistant"
                        font.pixelSize: 18
                        font.bold: true
                        color: "#1F2937"
                    }

                    Text {
                        text: "Always here to help"
                        font.pixelSize: 13
                        color: "#6B7280"
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: "#E5E7EB"
            }
        }

        // Chat area
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            clip: true

            ListView {
                id: chatListView
                model: chatMessages
                spacing: 16
                anchors.fill: parent
                anchors.margins: 20

                delegate: Item {
                    width: chatListView.width
                    height: messageContent.height + 24

                    RowLayout {
                        anchors.fill: parent
                        spacing: 12
                        layoutDirection: model.role === "user" ? Qt.RightToLeft : Qt.LeftToRight

                        Rectangle {
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            Layout.alignment: Qt.AlignTop
                            radius: 18
                            color: model.role === "user" ? "#10B981" : "#4F46E5"

                            Text {
                                anchors.centerIn: parent
                                text: model.role === "user" ? "U" : "AI"
                                color: "white"
                                font.pixelSize: 14
                                font.bold: true
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.maximumWidth: chatListView.width * 0.75
                            Layout.preferredHeight: messageText.height + 24
                            radius: 12
                            color: model.role === "user" ? "#EFF6FF" : "white"
                            border.color: model.role === "user" ? "#DBEAFE" : "#E5E7EB"
                            border.width: 1

                            Column {
                                id: messageContent
                                anchors.fill: parent
                                anchors.margins: 12

                                Text {
                                    id: messageText
                                    width: parent.width
                                    text: model.text
                                    wrapMode: Text.Wrap
                                    color: "#1F2937"
                                    font.pixelSize: 15
                                    lineHeight: 1.5
                                }
                            }
                        }
                    }
                }

                // Empty state
                Text {
                    anchors.centerIn: parent
                    visible: chatMessages.count === 0
                    text: "Start a conversation..."
                    font.pixelSize: 18
                    color: "#9CA3AF"
                }
            }
        }

        // Input area
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 90
            color: "white"
            
            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: 1
                color: "#E5E7EB"
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    radius: 25
                    color: "#F3F4F6"
                    border.color: userInput.activeFocus ? "#4F46E5" : "#E5E7EB"
                    border.width: userInput.activeFocus ? 2 : 1

                    TextField {
                        id: userInput
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.rightMargin: 20
                        placeholderText: "Type your message..."
                        font.pixelSize: 15
                        background: Item {}
                        color: "#1F2937"
                        
                        Keys.onReturnPressed: {
                            if (text.trim() !== "" && !engine.isGenerating) {
                                sendMessage()
                            }
                        }
                    }
                }

                Button {
                    Layout.preferredWidth: 50
                    Layout.preferredHeight: 50
                    
                    background: Rectangle {
                        radius: 25
                        color: parent.hovered ? "#4338CA" : "#4F46E5"
                        
                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                    }

                    contentItem: Text {
                        text: "→"
                        font.pixelSize: 24
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        if (userInput.text.trim() !== "" && !engine.isGenerating) {
                            sendMessage()
                        }
                    }
                }
            }
        }
    }

    function sendMessage() {
        var userMessage = userInput.text.trim()
        
        // Add user message
        chatMessages.append({
            role: "user",
            text: userMessage
        })
        
        // Add assistant placeholder
        chatMessages.append({
            role: "assistant",
            text: ""
        })
        
        // Send to engine
        engine.ask(userMessage)
        userInput.text = ""
        scrollToBottom()
    }

    function scrollToBottom() {
        chatListView.positionViewAtEnd()
    }
}