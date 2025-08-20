import telebot
from config import TOKEN, ADMIN_ID

bot = telebot.TeleBot(TOKEN)

@bot.message_handler(commands=['start'])
def send_welcome(message):
    bot.send_message(message.chat.id, "Добро пожаловать, Ping Monitor бот!")

@bot.message_handler(func=lambda m: True)
def echo_all(message):
    bot.send_message(message.chat.id, "Добро пожаловать, Ping Monitor бот!")

if __name__ == '__main__':
    bot.polling(none_stop=True)