import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15

ApplicationWindow {
    id: window
    visible: true
    width: 1024
    height: 768
    title: qsTr("Эмулятор консоли (Вариант 6)")    
    color: "#2b2b2b"
    SplitView {
        anchors.fill: parent
        orientation: Qt.Horizontal
        SessionView {
            SplitView.preferredWidth: 250
            SplitView.minimumWidth: 150
            SplitView.maximumWidth: 400
        }
        
        ConsoleView {
            SplitView.fillWidth: true
        }
    }
}