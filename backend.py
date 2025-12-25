import sys
import os
import subprocess
import locale
from datetime import datetime
from PySide6.QtCore import QObject, Slot, Signal, Property
from database import Session, Message, db

class ConsoleBackend(QObject):
    def __init__(self):
        super().__init__()
        self._current_session_id = None
        self._current_directory = os.getcwd()
        if Session.select().count() == 0:
            self.create_session("Default Session")
        else:
            last_session = Session.select().order_by(Session.created_at.desc()).get()
            self.load_session(last_session.id)

    historyChanged = Signal()
    sessionsChanged = Signal()

    @Property('QVariantList', notify=historyChanged)
    def history(self):
        if not self._current_session_id:
            return []
        
        messages = []
        query = Message.select().where(Message.session == self._current_session_id).order_by(Message.timestamp)
        
        for msg in query:
            messages.append({
                "type": msg.message_type,
                "text": msg.text
            })
        return messages

    @Property('QVariantList', notify=sessionsChanged)
    def sessions(self):
        sessions_data = []
        for s in Session.select().order_by(Session.created_at.desc()):
            sessions_data.append({
                "id": s.id,
                "name": s.name,
                "user": s.user,
                "date": s.created_at.strftime("%Y-%m-%d %H:%M")
            })
        return sessions_data

    @Slot(str)
    def execute_command(self, command_text):
        """Выполняет команду, сохраняет её и результат в БД"""
        if not command_text.strip() or not self._current_session_id:
            return

        current_session = Session.get_by_id(self._current_session_id)
        Message.create(
            session=current_session,
            text=command_text,
            message_type="command"
        )
        self.historyChanged.emit()
        if command_text.strip().lower().startswith("cd "):
            target_dir = command_text.strip()[3:].strip()
            try:
                os.chdir(target_dir)
                self._current_directory = os.getcwd()
                output = f"Directory changed to: {self._current_directory}"
            except FileNotFoundError:
                output = "The system cannot find the path specified."
            except Exception as e:
                output = str(e)
        else:
            try:
                result = subprocess.run(
                    command_text, 
                    shell=True, 
                    cwd=self._current_directory, 
                    capture_output=True
                )
                
                encoding = "cp866" if os.name == 'nt' else "utf-8"        
                if result.stdout:
                    output = result.stdout.decode(encoding, errors='replace')
                elif result.stderr:
                    output = result.stderr.decode(encoding, errors='replace')
                else:
                    output = ""
                    
            except Exception as e:
                output = f"Error executing command: {str(e)}"
        #сохранение ответа в бд
        if output.strip():
            Message.create(
                session=current_session,
                text=output.strip(),
                message_type="response"
            )
            self.historyChanged.emit()

    @Slot(str)
    def create_session(self, name):
        """Создает новый сеанс"""
        import getpass
        username = getpass.getuser()
        
        new_session = Session.create(name=name, user=username)
        self.load_session(new_session.id)
        self.sessionsChanged.emit()

    @Slot(int)
    def delete_session(self, session_id):
        """Удаляет сеанс"""
        q = Session.delete().where(Session.id == session_id)
        q.execute()
    
        if self._current_session_id == session_id:
            first = Session.select().first()
            if first:
                self.load_session(first.id)
            else:
                self._current_session_id = None
                self.historyChanged.emit()
                
        self.sessionsChanged.emit()

    @Slot(int)
    def load_session(self, session_id):
        """Переключает текущий сеанс"""
        self._current_session_id = session_id
        print(f"Loaded session ID: {session_id}")
        self.historyChanged.emit()