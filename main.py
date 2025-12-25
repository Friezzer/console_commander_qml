import sys
import os
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from database import init_db
from backend import ConsoleBackend

if __name__ == "__main__":
    init_db()

    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    backend = ConsoleBackend()
    engine.rootContext().setContextProperty("backend", backend)
    
    qml_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), "qml/main.qml")
    engine.load(qml_file)

    if not engine.rootObjects():
        sys.exit(-1)

    sys.exit(app.exec())