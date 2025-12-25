import sys
import os
import subprocess
import locale
import glob
from datetime import datetime
from PySide6.QtCore import QObject, Slot, Signal, Property
from database import Session, Message, db

class ConsoleBackend(QObject):
    STANDARD_COMMANDS = [
        "dir", "ls", "cd", "cls", "clear", "ping", "ipconfig", "ifconfig",
        "echo", "mkdir", "md", "rmdir", "rd", "copy", "del", "help", "exit", "whoami"
    ]
     
    def __init__(self):
        super().__init__()
        self._current_session_id = None
        self._current_directory = os.getcwd()

        self._command_buffer = [] # cписок текстов команд
        self._buffer_index = 0    # текущая позиция в истории

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

        self._command_buffer.append(command_text)
        self._buffer_index = len(self._command_buffer)

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
        msgs = Message.select().where(
            (Message.session == session_id) & (Message.message_type == 'command')
        ).order_by(Message.timestamp)
        
        self._command_buffer = [m.text for m in msgs]
        self._buffer_index = len(self._command_buffer)

    @Slot(result=str)
    def get_prev_command(self):
        """Возвращает предыдущую команду (стрелка ВВЕРХ)"""
        if self._buffer_index > 0:
            self._buffer_index -= 1
            return self._command_buffer[self._buffer_index]
        elif self._buffer_index == 0 and self._command_buffer:
            # Если мы в самом начале, возвращаем первую команду
            return self._command_buffer[0]
        return ""

    @Slot(result=str)
    def get_next_command(self):
        """Возвращает следующую команду (стрелка ВНИЗ)"""
        # если мы не в конце списка
        if self._buffer_index < len(self._command_buffer) - 1:
            self._buffer_index += 1
            return self._command_buffer[self._buffer_index]
        else:
            # если мы дошли до низа, возвращаем пустую строку (новая команда)
            self._buffer_index = len(self._command_buffer)
            return ""
        
    @Slot(str, result='QVariantList')
    def get_suggestions(self, input_text):
        """возвращает список файлов/папок для автоподстановки"""
        
        # если строка пустая, ничего не подсказываем
        if not input_text:
            return []

        # берем последнее слово из введенной строки
        # например, если ввели "cd Des", нам нужно искать совпадения для "Des"    
        text = input_text.strip()
        parts = input_text.split(' ')
        prefix = parts[-1]
        
        results = []

        if len(parts) == 1:
            for cmd in self.STANDARD_COMMANDS:
                if cmd.startswith(prefix):
                    results.append(cmd)


        # если префикс пустой, показываем все файлы
        if not prefix:
            search_pattern = os.path.join(self._current_directory, "*")
        else:
            search_pattern = os.path.join(self._current_directory, prefix + "*")

        try:
            # ищем файлы и папки
            matches = glob.glob(search_pattern)                    
            results = [os.path.basename(m) for m in matches]
            results.sort()            
            return results
        except Exception as e:
            print(f"Error in autocomplete: {e}")
            return []
        
        results = list(set(results))
        results.sort()
        
        return results
