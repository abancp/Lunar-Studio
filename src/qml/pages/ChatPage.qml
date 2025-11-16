import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import LocalLLM 1.0

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
                    
                    // Check if search pattern appears
                    if (newText.includes("search(")) {
                        chatMessages.setProperty(chatMessages.count - 1, "isSearching", true)
                    }
                    
                    // Check if searching has ended (closing parenthesis after search)
                    if (lastMsg.isSearching && newText.includes("search(") && newText.includes(")")) {
                        var searchStart = newText.lastIndexOf("search(")
                        var searchEnd = newText.indexOf(")", searchStart)
                        if (searchEnd !== -1) {
                            // Check if there's content after the search call
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
            // Make sure searching indicator is hidden when generation completes
            if (chatMessages.count > 0) {
                var lastMsg = chatMessages.get(chatMessages.count - 1)
                if (lastMsg.role === "assistant" && lastMsg.isSearching) {
                    chatMessages.setProperty(chatMessages.count - 1, "isSearching", false)
                    // Mark as searched if search was used
                    if (lastMsg.text.includes("search(")) {
                        chatMessages.setProperty(chatMessages.count - 1, "searchCompleted", true)
                    }
                }
            }
            scrollToBottom()
            userInput.enabled = true
        }
    }

    ListModel {
        id: chatMessages
    }

    // Available models list
    ListModel {
        id: modelsModel
        ListElement { name: "GPT-4 Turbo"; size: "175B"; loaded: false }
        ListElement { name: "Claude 3 Opus"; size: "137B"; loaded: false }
        ListElement { name: "Llama 3 70B"; size: "70B"; loaded: true }
        ListElement { name: "Mistral 7B"; size: "7B"; loaded: false }
        ListElement { name: "Phi-3 Medium"; size: "14B"; loaded: false }
    }

    property string currentModel: "Llama 3 70B"
    property bool modelMenuOpen: false
    property bool commandPaletteOpen: false

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Modern Header with Model Controls
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 65
            color: "#8B5CF6"
            
            // Subtle gradient overlay
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#8B5CF6" }
                    GradientStop { position: 1.0; color: "#A78BFA" }
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                spacing: 20

                // App Icon & Title
                RowLayout {
                    spacing: 12
                    
                    Rectangle {
                        Layout.preferredWidth: 38
                        Layout.preferredHeight: 38
                        radius: 8
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#EC4899" }
                            GradientStop { position: 1.0; color: "#8B5CF6" }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "⚡"
                            font.pixelSize: 20
                        }
                    }

                    Text {
                        text: "AI Studio"
                        font.pixelSize: 16
                        font.bold: true
                        color: "white"
                    }
                }

                Item { Layout.fillWidth: true }

                // Model Selector
                Button {
                    Layout.preferredHeight: 40
                    Layout.preferredWidth: 200
                    
                    background: Rectangle {
                        radius: 8
                        color: parent.hovered ? "#7C3AED" : "#6D28D9"
                        border.color: "#A78BFA"
                        border.width: 1
                        
                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                    }

                    contentItem: RowLayout {
                        spacing: 8
                        
                        Text {
                            text: "📦"
                            font.pixelSize: 16
                        }
                        
                        Text {
                            Layout.fillWidth: true
                            text: chat.currentModel
                            font.pixelSize: 13
                            color: "white"
                            elide: Text.ElideRight
                        }
                        
                        Text {
                            text: modelMenuOpen ? "▲" : "▼"
                            font.pixelSize: 10
                            color: "#E9D5FF"
                        }
                    }

                    onClicked: {
                        modelMenuOpen = !modelMenuOpen
                        commandPaletteOpen = false
                    }
                }

                // Load Model Button
                Button {
                    Layout.preferredHeight: 40
                    Layout.preferredWidth: 120
                    
                    background: Rectangle {
                        radius: 8
                        color: parent.hovered ? "#BE185D" : "#DB2777"
                        
                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                    }

                    contentItem: RowLayout {
                        spacing: 6
                        
                        Text {
                            text: "↓"
                            font.pixelSize: 18
                            color: "white"
                            font.bold: true
                        }
                        
                        Text {
                            text: "Load Model"
                            font.pixelSize: 13
                            color: "white"
                            font.weight: Font.Medium
                        }
                    }

                    onClicked: {
                        console.log("Load model clicked")
                    }
                }

                // Command Palette
                Button {
                    Layout.preferredHeight: 40
                    Layout.preferredWidth: 40
                    
                    background: Rectangle {
                        radius: 8
                        color: parent.hovered ? "#7C3AED" : "#6D28D9"
                        border.color: "#A78BFA"
                        border.width: 1
                        
                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                    }

                    contentItem: Text {
                        text: "⌘"
                        font.pixelSize: 20
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        commandPaletteOpen = !commandPaletteOpen
                        modelMenuOpen = false
                    }
                }

                // Settings/Plugin Icon
                Button {
                    Layout.preferredHeight: 40
                    Layout.preferredWidth: 40
                    
                    background: Rectangle {
                        radius: 8
                        color: parent.hovered ? "#7C3AED" : "transparent"
                        
                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                    }

                    contentItem: Text {
                        text: "🔌"
                        font.pixelSize: 18
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        console.log("Plugins clicked")
                    }
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

                delegate: Item {
                    width: chatListView.width
                    height: Math.max(messageColumn.height + 32, 60)

                    Row {
                        anchors.fill: parent
                        spacing: 12
                        layoutDirection: model.role === "user" ? Qt.RightToLeft : Qt.LeftToRight

                        Rectangle {
                            width: 36
                            height: 36
                            radius: 18
                            
                            gradient: Gradient {
                                GradientStop { 
                                    position: 0.0
                                    color: model.role === "user" ? "#F472B6" : "#8B5CF6"
                                }
                                GradientStop { 
                                    position: 1.0
                                    color: model.role === "user" ? "#EC4899" : "#7C3AED"
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: model.role === "user" ? "U" : "AI"
                                color: "white"
                                font.pixelSize: 14
                                font.bold: true
                            }
                        }

                        ColumnLayout {
                            id: messageColumn
                            width: parent.width - 48 // 36 (avatar) + 12 (spacing)
                            spacing: 8

                            // Searching indicator
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 40
                                radius: 20
                                visible: model.isSearching === true
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
                                            running: model.isSearching === true
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
                                            running: model.isSearching === true
                                            loops: Animation.Infinite
                                            NumberAnimation { from: 1.0; to: 0.5; duration: 1000 }
                                            NumberAnimation { from: 0.5; to: 1.0; duration: 1000 }
                                        }
                                    }
                                }
                            }

                            // Searched label (after search completes)
                            Rectangle {
                                Layout.preferredWidth: searchedLabel.width + 16
                                Layout.preferredHeight: 24
                                radius: 12
                                visible: model.searchCompleted === true && model.isSearching === false
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

                            // Main message bubble
                            Rectangle {
                                id: messageBubble
                                Layout.fillWidth: true
                                Layout.preferredHeight: messageContent.height + 24
                                radius: 12
                                color: model.role === "user" ? "#1E1530" : "#1A1A2E"
                                border.color: model.role === "user" ? "#C084FC" : "#A78BFA"
                                border.width: 1.5

                                layer.enabled: true
                                layer.effect: ShaderEffect {
                                    property color shadowColor: model.role === "user" ? "#20C084FC" : "#20A78BFA"
                                }

                                Column {
                                    id: messageContent
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 12
                                    spacing: 8

                                    // Thinking section (collapsible) - Shows immediately when <think> appears
                                    Column {
                                        id: thinkingSection
                                        width: parent.width
                                        visible: hasThinkingTag(model.text)
                                        spacing: 4
                                        
                                        property bool thinkingExpanded: true

                                        MouseArea {
                                            width: parent.width
                                            height: thinkingHeader.height
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                thinkingSection.thinkingExpanded = !thinkingSection.thinkingExpanded
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
                                            text: extractThinkingContent(model.text)
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
                                            visible: thinkingSection.thinkingExpanded && getMainContent(model.text) !== ""
                                        }
                                    }

                                    // Main message text
                                    Text {
                                        id: mainText
                                        width: parent.width
                                        text: getMainContent(model.text)
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
                                Layout.alignment: model.role === "user" ? Qt.AlignRight : Qt.AlignLeft
                                text: model.timestamp || ""
                                font.pixelSize: 11
                                color: "#6B7280"
                                opacity: 0.7
                            }
                        }
                    }
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

        // Input area
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 90
            color: "#1A1A2E"
            
            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#A78BFA" }
                    GradientStop { position: 0.5; color: "#F472B6" }
                    GradientStop { position: 1.0; color: "#A78BFA" }
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    radius: 25
                    color: "#0F0F1E"
                    border.color: userInput.activeFocus ? "#C084FC" : "#8B5CF6"
                    border.width: userInput.activeFocus ? 2 : 1.5
                    
                    Behavior on border.color {
                        ColorAnimation { duration: 200 }
                    }

                    TextField {
                        id: userInput
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.rightMargin: 20
                        placeholderText: "Type your message..."
                        font.pixelSize: 15
                        background: Item {}
                        color: "#E9D5FF"
                        
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
                        
                        gradient: Gradient {
                            GradientStop { 
                                position: 0.0
                                color: parent.hovered ? "#BE185D" : "#EC4899"
                                
                                Behavior on color {
                                    ColorAnimation { duration: 200 }
                                }
                            }
                            GradientStop { 
                                position: 1.0
                                color: parent.hovered ? "#7C3AED" : "#8B5CF6"
                                
                                Behavior on color {
                                    ColorAnimation { duration: 200 }
                                }
                            }
                        }
                    }

                    contentItem: Text {
                        text: "→"
                        font.pixelSize: 24
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.bold: true
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

    // Model Selector Popup (Outside ColumnLayout)
    Rectangle {
        id: modelPopup
        visible: modelMenuOpen
        anchors.horizontalCenter: parent.horizontalCenter
        y: 70
        width: 400
        height: 320
        radius: 6
        color: "#1F2937"
        border.color: "#8B5CF6"
        border.width: 1
        z: 1000
        
        layer.enabled: true
        layer.effect: ShaderEffect {
            property color shadowColor: "#40000000"
        }

        opacity: modelMenuOpen ? 1 : 0
        scale: modelMenuOpen ? 1 : 0.95
        
        Behavior on opacity {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: 200; easing.type: Easing.OutBack }
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
                
                Button {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    
                    background: Rectangle {
                        radius: 6
                        color: parent.hovered ? "#374151" : "transparent"
                    }
                    
                    contentItem: Text {
                        text: "✕"
                        color: "#9CA3AF"
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: modelMenuOpen = false
                }
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: modelsModel
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
                            chat.currentModel = model.name
                            modelMenuOpen = false
                        }
                    }
                }
            }
        }
    }

    // Command Palette Popup (Outside ColumnLayout)
    Rectangle {
        id: commandPopup
        visible: commandPaletteOpen
        anchors.horizontalCenter: parent.horizontalCenter
        y: 70
        width: 500
        height: 280
        radius: 6
        color: "#1F2937"
        border.color: "#8B5CF6"
        border.width: 1
        z: 1000
        
        layer.enabled: true
        layer.effect: ShaderEffect {
            property color shadowColor: "#40000000"
        }

        opacity: commandPaletteOpen ? 1 : 0
        scale: commandPaletteOpen ? 1 : 0.95
        
        Behavior on opacity {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: 200; easing.type: Easing.OutBack }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                
                Text {
                    Layout.fillWidth: true
                    text: "Command Palette"
                    font.pixelSize: 16
                    font.bold: true
                    color: "#E9D5FF"
                }
                
                Button {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    
                    background: Rectangle {
                        radius: 6
                        color: parent.hovered ? "#374151" : "transparent"
                    }
                    
                    contentItem: Text {
                        text: "✕"
                        color: "#9CA3AF"
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: commandPaletteOpen = false
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: 8
                color: "#374151"

                TextField {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    placeholderText: "Type a command..."
                    font.pixelSize: 14
                    color: "white"
                    background: Item {}
                    
                    placeholderTextColor: "#6B7280"
                }
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: ListModel {
                    ListElement { icon: "⚙️"; cmd: "Settings"; desc: "Open settings" }
                    ListElement { icon: "📝"; cmd: "New Chat"; desc: "Start new conversation" }
                    ListElement { icon: "🗑️"; cmd: "Clear History"; desc: "Clear chat history" }
                    ListElement { icon: "🎨"; cmd: "Change Theme"; desc: "Customize appearance" }
                }
                spacing: 2
                clip: true

                delegate: Rectangle {
                    width: ListView.view.width
                    height: 48
                    radius: 6
                    color: cmdMouseArea.containsMouse ? "#374151" : "transparent"
                    
                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        Text {
                            text: model.icon
                            font.pixelSize: 18
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: model.cmd
                                font.pixelSize: 13
                                color: "white"
                            }

                            Text {
                                text: model.desc
                                font.pixelSize: 11
                                color: "#9CA3AF"
                            }
                        }
                    }

                    MouseArea {
                        id: cmdMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        
                        onClicked: {
                            console.log("Command:", model.cmd)
                            commandPaletteOpen = false
                        }
                    }
                }
            }
        }
    }

    function sendMessage() {
        var userMessage = userInput.text.trim()
        var timestamp = Qt.formatTime(new Date(), "hh:mm AP")
        
        chatMessages.append({
            role: "user",
            text: userMessage,
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
        
        engine.ask(userMessage)
        userInput.text = ""
        userInput.enabled = false
        scrollToBottom()
    }

    function scrollToBottom() {
        chatListView.positionViewAtEnd()
    }

    function hasThinkingTag(text) {
        // Check if <think> tag exists (even if not closed yet)
        return text.indexOf("<think>") !== -1
    }

    function extractThinkingContent(text) {
        var thinkStart = text.indexOf("<think>")
        if (thinkStart === -1) return ""
        
        var thinkEnd = text.indexOf("</think>")
        
        // If closing tag exists, extract between tags
        if (thinkEnd !== -1) {
            return text.substring(thinkStart + 7, thinkEnd).trim()
        } else {
            // If closing tag doesn't exist yet, show everything after <think>
            return text.substring(thinkStart + 7).trim()
        }
    }

    function getMainContent(text) {
        // Remove search() calls
        var result = removeSearch(text)
        
        // Check if we have thinking tags
        var thinkStart = result.indexOf("<think>")
        if (thinkStart === -1) {
            // No thinking tags, return all content
            return result.trim()
        }
        
        var thinkEnd = result.indexOf("</think>")
        if (thinkEnd === -1) {
            // Thinking not closed yet, return content before <think>
            return result.substring(0, thinkStart).trim()
        }
        
        // Return content before <think> and after </think>
        var before = result.substring(0, thinkStart)
        var after = result.substring(thinkEnd + 8)
        return (before + " " + after).trim()
    }

    function extractThinking(text) {
        var thinkStart = text.indexOf("<think>")
        var thinkEnd = text.indexOf("</think>")
        
        if (thinkStart !== -1 && thinkEnd !== -1) {
            return text.substring(thinkStart + 7, thinkEnd).trim()
        }
        return ""
    }

    function removeThinking(text) {
        // Remove thinking tags and content
        var result = text
        var thinkStart = text.indexOf("<think>")
        var thinkEnd = text.indexOf("</think>")
        
        while (thinkStart !== -1 && thinkEnd !== -1) {
            result = result.substring(0, thinkStart) + result.substring(thinkEnd + 8)
            thinkStart = result.indexOf("<think>")
            thinkEnd = result.indexOf("</think>")
        }
        
        return result.trim()
    }

    function removeSearch(text) {
        // Remove search() function calls from displayed text
        var result = text
        var searchStart = text.indexOf("search(")
        
        while (searchStart !== -1) {
            var searchEnd = text.indexOf(")", searchStart)
            if (searchEnd !== -1) {
                result = result.substring(0, searchStart) + result.substring(searchEnd + 1)
                searchStart = result.indexOf("search(")
            } else {
                break
            }
        }
        
        return result.trim()
    }

    // Close dropdowns when clicking outside
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: {
            modelMenuOpen = false
            commandPaletteOpen = false
        }
    }
}