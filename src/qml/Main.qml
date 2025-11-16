import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

ApplicationWindow {
    id: win
    visible: true
    width: 1000
    height: 680
    color: "#f6f7f9"
    title: "LunarStudio – Visible Responsive UI"

    // ================================
    // HEADER
    // ================================
    Rectangle {
        id: header
        width: parent.width
        height: 70
        anchors.top: parent.top
        color: "white"
        border.color: "#e0e0e0"

        RowLayout {
            anchors.fill: parent
            anchors.margins: 20

            Text {
                text: "LunarStudio"
                font.pixelSize: 24
                color: "#111"
            }

            Item { Layout.fillWidth: true }

            Repeater {
                model: ["Home", "Models", "Docs", "About"]

                delegate: Button {
                    text: modelData
                    flat: true
                    font.pixelSize: 15
                }
            }
        }
    }

    // ================================
    // MAIN CONTENT (NO SCROLLVIEW)
    // ================================
    Column {
        id: content
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 20
        spacing: 30

        // ---------- HERO ----------
        Column {
            width: parent.width
            spacing: 10

            Text {
                text: "Your Local AI Engine"
                font.pixelSize: 28
                color: "#111"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                width: parent.width
            }

            Text {
                text: "Fast. Private. Runs fully on-device."
                font.pixelSize: 16
                color: "#555"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                width: parent.width
            }

            Button {
                text: "Show Popup"
                anchors.horizontalCenter: parent.horizontalCenter
                width: 160
                height: 42
                onClicked: popup.open()
            }
        }

        // ---------- CARDS (VISIBLE ALWAYS) ----------
        Flow {
            width: parent.width
            spacing: 20

            Repeater {
                model: [
                    { title: "Fast", desc: "Optimized inference engine for speed." },
                    { title: "Private", desc: "No cloud needed. Fully local." },
                    { title: "Developer Friendly", desc: "Simple API & customizable." }
                ]

                delegate: Rectangle {
                    width: Math.min(260, win.width * 0.45)
                    height: 150
                    radius: 12
                    color: "white"
                    border.color: "#dcdcdc"

                    Column {
                        anchors.fill: parent
                        anchors.margins: 16

                        Text {
                            text: model.title
                            font.pixelSize: 18
                            font.bold: true
                            color: "#111"
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            text: model.desc
                            font.pixelSize: 14
                            color: "#555"
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: popup
        modal: true
        dim: true
        width: 360
        height: 220
        x: (win.width - width) / 2
        y: (win.height - height) / 2

        background: Rectangle {
            color: "white"
            radius: 12
            border.color: "#dcdcdc"
        }

        Column {
            anchors.fill: parent
            anchors.margins: 20

            Text {
                text: "Welcome!"
                font.pixelSize: 20
                font.bold: true
            }

            Text {
                text: "This popup is visible and works."
                wrapMode: Text.WordWrap
            }

            Item { Layout.fillHeight: true }

            Button {
                text: "Close"
                onClicked: popup.close()
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
