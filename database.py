from peewee import *
import datetime

db = SqliteDatabase('console_history.db')

class BaseModel(Model):
    class Meta:
        database = db

class Session(BaseModel):
    name = CharField(verbose_name="Название сеанса")
    user = CharField(verbose_name="Имя пользователя", default="User")
    created_at = DateTimeField(default=datetime.datetime.now)

    class Meta:
        order_by = ('-created_at',)

class Message(BaseModel):
    session = ForeignKeyField(Session, backref='messages', on_delete='CASCADE')
    text = TextField(verbose_name="Текст сообщения")
    message_type = CharField(verbose_name="Тип (Команда/Ответ)") 
    timestamp = DateTimeField(default=datetime.datetime.now)

    class Meta:
        order_by = ('timestamp',)

def init_db():
    db.connect()
    db.create_tables([Session, Message], safe=True)
    
    if Session.select().count() == 0:
        print("База пуста. Создаем тестовые данные...")
        s1 = Session.create(name="Первый запуск", user="Admin")
        Message.create(session=s1, text="echo Hello World", message_type="command")
        Message.create(session=s1, text="Hello World", message_type="response")
        Message.create(session=s1, text="dir", message_type="command")
    
    db.close()
    
if __name__ == "__main__":
    init_db()
    print("База данных инициализирована.")