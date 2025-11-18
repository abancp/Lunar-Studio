import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import LocalLLM 1.0
import "../components"
import "../utils"

Page {
    id: chat
    background: Rectangle {
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0F0F1E" }
            GradientStop { position: 1.0; color: "#1A0E1F" }
        }
    }

    Engine {
        id: engine
        onTokenGenerated: {
            if (chatMessages.count > 0) {
                var lastMsg = chatMessages.get(chatMessages.count - 1)
                if (lastMsg.role === "assistant") {
                    var newText = lastMsg.text + token
                    chatMessages.setProperty(chatMessages.count - 1, "text", newText)
                    
                    if (newText.includes("search(")) {
                        chatMessages.setProperty(chatMessages.count - 1, "isSearching", true)
                    }
                    
                    if (lastMsg.isSearching && newText.includes("search(") && newText.includes(")")) {
                        var searchStart = newText.lastIndexOf("search(")
                        var searchEnd = newText.indexOf(")", searchStart)
                        if (searchEnd !== -1) {
                            var afterSearch = newText.substring(searchEnd + 1).trim()
                            if (afterSearch.length > 0 && !afterSearch.startsWith("search(")) {
                                chatMessages.setProperty(chatMessages.count - 1, "isSearching", false)
                                chatMessages.setProperty(chatMessages.count - 1, "searchCompleted", true)
                            }
                        }
                    }
                }
            }
            scrollToBottom()
        }
        onGenerationFinished: {
            if (chatMessages.count > 0) {
                var lastMsg = chatMessages.get(chatMessages.count - 1)
                if (lastMsg.role === "assistant" && lastMsg.isSearching) {
                    chatMessages.setProperty(chatMessages.count - 1, "isSearching", false)
                    if (lastMsg.text.includes("search(")) {
                        chatMessages.setProperty(chatMessages.count - 1, "searchCompleted", true)
                    }
                }
            }
            scrollToBottom()
            messageInput.canSend = true
        }
    }

    ListModel {
        id: chatMessages
    }

    property string currentModel: "Gemma 3 270M"
    property bool modelMenuOpen: false

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Header {
            Layout.fillWidth: true
            currentModel: chat.currentModel
            onModelSelectorClicked: modelPopup.open()
            onLoadModelClicked: console.log("Load model clicked")
            onPluginsClicked: console.log("Plugins clicked")
        }

        // Chat area
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            clip: true
            
            background: Rectangle {
                color: "transparent"
            }

            ListView {
                id: chatListView
                model: chatMessages
                spacing: 16
                anchors.fill: parent
                anchors.margins: 20

                delegate: MessageBubble {
                    width: chatListView.width
                    role: model.role
                    text: model.text
                    timestamp: model.timestamp
                    isSearching: model.isSearching
                    searchCompleted: model.searchCompleted
                }

                // Empty state
                ColumnLayout {
                    anchors.centerIn: parent
                    visible: chatMessages.count === 0
                    spacing: 12

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "✨"
                        font.pixelSize: 48
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Start a conversation"
                        font.pixelSize: 18
                        font.bold: true
                        color: "#A78BFA"
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Select a model and begin chatting"
                        font.pixelSize: 14
                        color: "#6B7280"
                    }
                }
            }
        }

        MessageInput {
            id: messageInput
            Layout.fillWidth: true
            canSend: !engine.isGenerating
            onSendMessage: chat.sendMessage(text)
        }
    }

    ModelPopup {
        id: modelPopup
        anchors.centerIn: parent
        onSelected: {
            chat.currentModel = modelName
        }
    }

    function sendMessage(text) {
        var timestamp = Qt.formatTime(new Date(), "hh:mm AP")
        
        chatMessages.append({
            role: "user",
            text: text,
            timestamp: timestamp,
            isSearching: false,
            searchCompleted: false
        })
        
        chatMessages.append({
            role: "assistant",
            text: "",
            timestamp: timestamp,
            isSearching: false,
            searchCompleted: false
        })
        
        engine.ask(text)
        messageInput.clear()
        messageInput.canSend = false
        scrollToBottom()
    }

    function scrollToBottom() {
        chatListView.positionViewAtEnd()
    }
}