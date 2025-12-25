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
            id: inputContainer
            Layout.fillWidth: true
            height: 50
            color: "#252526"            
            Rectangle {
                width: parent.width; height: 1; color: "#444"; anchors.top: parent.top
            }

            Popup {
                id: suggestionPopup
                y: -height - 5
                x: 40
                width: 200
                height: Math.min(contentHeight, 150)
                padding: 0
                
                background: Rectangle {
                    color: "#2b2b2b"
                    border.color: "#555"
                    border.width: 1
                }

                property var suggestions: [] // cюда загрузим данные из Python

                contentItem: ListView {
                    id: suggestionList
                    clip: true
                    model: suggestionPopup.suggestions
                    implicitHeight: contentItem.childrenRect.height 

                    highlight: Rectangle {
                        color: "#007acc" 
                        radius: 2
                    }
                    highlightMoveDuration: 0

                    delegate: ItemDelegate {
                        width: suggestionPopup.width
                        height: 30
                        property bool isCurrent: ListView.isCurrentItem
                        contentItem: Text {
                            text: modelData
                            color: "white"
                            font.family: "Consolas"
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                        
                        background: Rectangle {
                            color: "transparent" // фон рисует highlight
                        }

                        onClicked: {
                            suggestionList.currentIndex = index
                            applySuggestion(modelData)
                        }
                    }
                }
            }

            function applySuggestion(suggestion) {
                var currentText = commandInput.text
                var lastSpaceIndex = currentText.lastIndexOf(" ")
                
                if (lastSpaceIndex !== -1) {
                    // если есть пробел, заменяем последнее слово
                    commandInput.text = currentText.substring(0, lastSpaceIndex + 1) + suggestion
                } else {
                    // если пробелов нет, заменяем всё слово
                    commandInput.text = suggestion
                }
                suggestionPopup.close()
                commandInput.forceActiveFocus()
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

                    onTextEdited: {
                        if (suggestionPopup.opened) {
                            suggestionPopup.close()
                        }
                    }                   

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if(suggestionPopup.opened) {                                
                                // если попап открыт, enter применяет выделенное слово
                                inputContainer.applySuggestion(suggestionPopup.suggestions[suggestionList.currentIndex])
                                event.accepted = true
                            } else {
                                // если закрыт - выполняем команду
                                if (text.trim() !== "") {
                                    backend.execute_command(text)
                                    text = "" 
                                }
                            }
                        }
                        // стрелка вверх
                        if (event.key === Qt.Key_Up) {
                            if (suggestionPopup.opened) {
                                // Двигаемся по списку подсказок
                                suggestionList.decrementCurrentIndex()
                                event.accepted = true
                            } else {
                                // Двигаемся по истории команд
                                var prevCmd = backend.get_prev_command()
                                text = prevCmd
                                event.accepted = true
                            }
                        }

                        // стрелка вниз
                        if (event.key === Qt.Key_Down) {
                            if (suggestionPopup.opened) {
                                // Двигаемся по списку подсказок
                                suggestionList.incrementCurrentIndex()
                                event.accepted = true
                            } else {
                                // Двигаемся по истории команд
                                var nextCmd = backend.get_next_command()
                                text = nextCmd
                                event.accepted = true
                            }
                        }

                        if (event.key === Qt.Key_Tab) {
                            event.accepted = true 
                            
                            if (suggestionPopup.opened) {
                                // ВТОРОЕ НАЖАТИЕ: Применяем выбранное
                                var selectedItem = suggestionPopup.suggestions[suggestionList.currentIndex]
                                inputContainer.applySuggestion(selectedItem)
                            } else {
                                // ПЕРВОЕ НАЖАТИЕ: Открываем список
                                var results = backend.get_suggestions(text)
                                
                                if (results.length > 0) {                                    
                                    suggestionPopup.suggestions = results
                                    suggestionPopup.open()
                                    suggestionList.currentIndex = 0
                                }
                            }
                        }
                        // 5. Обработка ESCAPE (закрыть попап)
                        if (event.key === Qt.Key_Escape) {
                            if (suggestionPopup.opened) {
                                suggestionPopup.close()
                                event.accepted = true
                            }
                        }
                    }
                }
            }
        }
    }
}