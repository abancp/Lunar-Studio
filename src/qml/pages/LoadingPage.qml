// LoadingPage.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    anchors.fill: parent

    // Timing (in milliseconds)
    property int autoNavigateDelay: 1800

    // Signal to notify main window
    signal goChat()

    // White theme palette
    readonly property color bgColor: "#FFFFFF"
    readonly property color titleColor: "#222222"
    readonly property color subtitleColor: "#555555"
    readonly property color spinnerColor: "#3F51B5"   // Indigo
    readonly property color footerColor: "#777777"

    Rectangle {
        anchors.fill: parent
        color: bgColor

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 22
            width: Math.min(parent.width * 0.85, 600)

            // Spinner (Canvas)
            Canvas {
                id: spinner
                width: 70
                height: 70
                anchors.horizontalCenter: parent.horizontalCenter

                property real angle: 0

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)

                    ctx.strokeStyle = spinnerColor
                    ctx.lineWidth = 6

                    ctx.beginPath()
                    ctx.arc(width/2, height/2, width/2 - 6,
                            angle, angle + Math.PI * 1.5)
                    ctx.stroke()
                }

                Timer {
                    interval: 16
                    repeat: true
                    running: true
                    onTriggered: {
                        spinner.angle += 0.08
                        spinner.requestPaint()
                    }
                }
            }

            // App title
            Text {
                id: title
                text: "Lunar Studio"
                font.pixelSize: 26
                font.bold: true
                color: titleColor
                horizontalAlignment: Text.AlignHCenter
                Layout.alignment: Qt.AlignHCenter
            }

            // Subtitle
            Text {
                text: "Preparing your local AI workspace..."
                font.pixelSize: 15
                color: subtitleColor
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }

            // Footer
            Text {
                text: "Local LLM — fast, private, offline"
                font.pixelSize: 12
                color: footerColor
                horizontalAlignment: Text.AlignHCenter
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    // Auto-navigate to chat page
    Timer {
        id: navTimer
        interval: autoNavigateDelay
        running: true
        repeat: false
        onTriggered: {
            // Use signal if called inside StackView
            root.goChat()

            // OR directly call window.goToChat() if global:
            if (typeof window !== "undefined" && window.goToChat)
                window.goToChat()
        }
    }
}
