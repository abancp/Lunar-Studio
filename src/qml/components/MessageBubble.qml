import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: messageBubble
    width: parent.width
    height: Math.max(messageColumn.height + 32, 60)
    
    property string role: "user"
    property string text: ""
    property string timestamp: ""
    property bool isSearching: false
    property bool searchCompleted: false
    
    signal thinkingToggled(bool expanded)
    
    Row {
        anchors.fill: parent
        spacing: 12
        layoutDirection: messageBubble.role === "user" ? Qt.RightToLeft : Qt.LeftToRight

        Avatar {
            role: messageBubble.role
        }

        ColumnLayout {
            id: messageColumn
            width: parent.width - 48
            spacing: 8

            SearchingIndicator {
                visible: messageBubble.isSearching
            }

            SearchedLabel {
                visible: messageBubble.searchCompleted && !messageBubble.isSearching
            }

            // Main message bubble
            Rectangle {
                id: bubble
                Layout.fillWidth: true
                Layout.preferredHeight: messageContent.height + 24
                radius: 12
                color: messageBubble.role === "user" ? "#1E1530" : "#1A1A2E"
                border.color: messageBubble.role === "user" ? "#C084FC" : "#A78BFA"
                border.width: 1.5

                layer.enabled: true
                layer.effect: ShaderEffect {
                    property color shadowColor: messageBubble.role === "user" ? "#20C084FC" : "#20A78BFA"
                }

                Column {
                    id: messageContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 8

                    ThinkingSection {
                        text: messageBubble.text
                        onToggled: messageBubble.thinkingToggled(expanded)
                    }

                    // Main message text
                    Text {
                        id: mainText
                        width: parent.width
                        text: MessageUtils.getMainContent(messageBubble.text)
                        wrapMode: Text.Wrap
                        color: "#E9D5FF"
                        font.pixelSize: 15
                        lineHeight: 1.5
                        visible: text !== ""
                    }
                }
            }

            // Timestamp
            Text {
                Layout.alignment: messageBubble.role === "user" ? Qt.AlignRight : Qt.AlignLeft
                text: messageBubble.timestamp
                font.pixelSize: 11
                color: "#6B7280"
                opacity: 0.7
            }
        }
    }
}