import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    color: "#3c3f41" 

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Label {
            text: "История сеансов"
            color: "white"
            font.bold: true
            font.pixelSize: 16
            padding: 10
            Layout.fillWidth: true
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#555"
        }

        ListView {
            id: sessionList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            
            // берем список сеансов из бэкенда
            model: backend.sessions

            delegate: ItemDelegate {
                width: sessionList.width
                
                contentItem: Column {
                    spacing: 2
                    // modelData - это способ доступа к словарю из Python
                    Text { 
                        text: modelData.name 
                        color: "white"
                        font.bold: true
                    }
                    Text { 
                        text: modelData.user + " | " + modelData.date 
                        color: "#aaa"
                        font.pixelSize: 12
                    }
                }

                background: Rectangle {
                    color: parent.highlighted || parent.hovered ? "#4c5052" : "transparent"
                }

                Button {
                    text: "X"
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 10
                    flat: true
                    width: 30
                    height: 30
                    contentItem: Text {
                        text: parent.text
                        color: parent.hovered ? "red" : "#777"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        backend.delete_session(modelData.id)
                    }
                }
                
                onClicked: {
                    backend.load_session(modelData.id)
                }
            }
        }

        Button {
            text: "+ Новый сеанс"
            Layout.fillWidth: true
            Layout.margins: 10
            onClicked: {
                var now = new Date()
                var timeString = now.toLocaleTimeString(Qt.locale(), "hh:mm:ss")
                backend.create_session("Сеанс " + timeString)
            }
        }
    }
}