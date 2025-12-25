import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    color: "#1e1e1e" 

    property color consoleTextColor: "#00ff00" 

    ColumnLayout {
        anchors.fill: parent
        spacing: 5
        Rectangle {
            Layout.fillWidth: true
            height: 40
            color: "#333"
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 5
                spacing: 10

                Label { text: "Цвет текста:"; color: "white" }

                ComboBox {
                    model: ["Green", "White", "Cyan", "Orange"]
                    onCurrentTextChanged: {
                        switch(currentText) {
                            case "Green": consoleTextColor = "#00ff00"; break;
                            case "White": consoleTextColor = "#ffffff"; break;
                            case "Cyan": consoleTextColor = "#00ffff"; break;
                            case "Orange": consoleTextColor = "#ffa500"; break;
                        }
                    }
                }
                
                Item { Layout.fillWidth: true }
            }
        }

        // история команд
        ListView {
            id: consoleHistory
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 5
            Layout.margins: 10
            onCountChanged: Qt.callLater(positionViewAtEnd)
            model: backend.history

            delegate: Column {
                width: ListView.view.width
                
                // команда
                Text {
                    visible: modelData.type === "command"
                    text: "> " + modelData.text
                    color: "white"
                    font.family: "Consolas"
                    font.pixelSize: 14
                    font.bold: true
                    wrapMode: Text.Wrap
                    width: parent.width
                }

                // ответ
                Text {
                    visible: modelData.type === "response"
                    text: modelData.text
                    color: consoleTextColor
                    font.family: "Consolas"
                    font.pixelSize: 14
                    wrapMode: Text.Wrap
                    width: parent.width
                }
            }
        }

        // поле ввода
        Rectangle {
            Layout.fillWidth: true
            height: 50
            color: "#252526"            
            Rectangle {
                width: parent.width; height: 1; color: "#444"; anchors.top: parent.top
            }
            RowLayout {
                anchors.fill: parent
                anchors.margins: 10

                Label {
                    text: ">"
                    color: "white"
                    font.family: "Consolas"
                    font.pixelSize: 16
                }

                TextField {
                    id: commandInput
                    Layout.fillWidth: true
                    color: "white"
                    font.family: "Consolas"
                    font.pixelSize: 16
                    placeholderText: "Введите команду..."
                    background: null
                    selectByMouse: true
                    focus: true // чтобы сразу можно было печатать                    
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (text.trim() !== "") {
                                backend.execute_command(text)
                                text = "" 
                            }
                        }
                        // стрелка вверх
                        if (event.key === Qt.Key_Up) {
                            var prevCmd = backend.get_prev_command()
                            text = prevCmd
                            event.accepted = true // Чтобы курсор не улетал в начало строки
                        }

                        // стрелка вниз
                        if (event.key === Qt.Key_Down) {
                            var nextCmd = backend.get_next_command()
                            text = nextCmd
                            event.accepted = true
                        }
                    }
                }
            }
        }
    }
}