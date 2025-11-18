import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import LunarStudioUI 1.0  // Import your module

Column {
    id: thinkingSection
    width: parent.width
    visible: MessageUtils.hasThinkingTag(text)
    spacing: 4
    
    property string text: ""
    property bool thinkingExpanded: true
    
    signal toggled(bool expanded)
    
    MouseArea {
        width: parent.width
        height: thinkingHeader.height
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            thinkingSection.thinkingExpanded = !thinkingSection.thinkingExpanded
            thinkingSection.toggled(thinkingSection.thinkingExpanded)
        }

        RowLayout {
            id: thinkingHeader
            width: parent.width
            spacing: 8

            Text {
                text: thinkingSection.thinkingExpanded ? "▼" : "▶"
                font.pixelSize: 10
                color: "#9CA3AF"
            }

            Text {
                text: "Thinking"
                font.pixelSize: 12
                color: "#9CA3AF"
                font.italic: true
            }

            Item { Layout.fillWidth: true }
        }
    }

    Text {
        id: thinkingText
        width: parent.width
        text: MessageUtils.extractThinkingContent(thinkingSection.text)
        wrapMode: Text.Wrap
        color: "#9CA3AF"
        font.pixelSize: 13
        lineHeight: 1.4
        opacity: 0.4
        visible: thinkingSection.thinkingExpanded
        font.italic: true
    }

    Rectangle {
        width: parent.width
        height: 1
        color: "#374151"
        visible: thinkingSection.thinkingExpanded && MessageUtils.getMainContent(thinkingSection.text) !== ""
    }
}