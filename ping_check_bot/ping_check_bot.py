import subprocess
import threading
import time

from aiogram import Bot, Dispatcher, types, executor
from aiogram.types import InlineKeyboardMarkup, InlineKeyboardButton

import config

bot = Bot(token=config.TOKEN)
dp = Dispatcher(bot)

auto_ping_enabled = False
auto_ping_thread = None

def ping_host(ip):
    try:
        output = subprocess.check_output(['ping', '-c', '1', '-W', '2', ip], stderr=subprocess.STDOUT, universal_newlines=True)
        return f"✅ {ip} доступен\n{output.splitlines()[-2]}"
    except subprocess.CalledProcessError:
        return f"❌ {ip} недоступен!"

def auto_ping_loop(chat_id):
    global auto_ping_enabled
    while auto_ping_enabled:
        for ip in config.PING_IPS:
            result = ping_host(ip)
            bot.send_message(chat_id, f"[Автопинг]\n{result}")
        time.sleep(config.PING_INTERVAL)

@dp.message_handler(commands=["start"])
async def start_cmd(message: types.Message):
    keyboard = InlineKeyboardMarkup(row_width=2)
    keyboard.add(
        InlineKeyboardButton("Включить автопинг", callback_data="enable_ping"),
        InlineKeyboardButton("Отключить автопинг", callback_data="disable_ping"),
        InlineKeyboardButton("Проверить сейчас", callback_data="check_now"),
    )
    await message.answer("Выберите действие:", reply_markup=keyboard)

@dp.callback_query_handler(lambda c: True)
async def process_callback(callback_query: types.CallbackQuery):
    global auto_ping_enabled, auto_ping_thread
    if callback_query.data == "enable_ping":
        if not auto_ping_enabled:
            auto_ping_enabled = True
            auto_ping_thread = threading.Thread(target=auto_ping_loop, args=(config.ADMIN_ID,), daemon=True)
            auto_ping_thread.start()
            await callback_query.message.answer("Автопинг запущен.")
        else:
            await callback_query.message.answer("Автопинг уже работает.")
        await callback_query.answer()
    elif callback_query.data == "disable_ping":
        auto_ping_enabled = False
        await callback_query.message.answer("Автопинг остановлен.")
        await callback_query.answer()
    elif callback_query.data == "check_now":
        results = []
        for ip in config.PING_IPS:
            results.append(ping_host(ip))
        await callback_query.message.answer("\n\n".join(results))
        await callback_query.answer()

if __name__ == "__main__":
    executor.start_polling(dp)