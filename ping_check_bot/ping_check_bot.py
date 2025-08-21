import subprocess
import asyncio

from aiogram import Bot, Dispatcher, types
from aiogram.filters import Command
from aiogram.types import InlineKeyboardMarkup, InlineKeyboardButton

import config

bot = Bot(token=config.TOKEN)
dp = Dispatcher()

auto_ping_enabled = False
auto_ping_task = None

def ping_host(ip):
    try:
        output = subprocess.check_output(['ping', '-c', '1', '-W', '2', ip], stderr=subprocess.STDOUT, universal_newlines=True)
        return f"✅ {ip} доступен\n{output.splitlines()[-2]}"
    except subprocess.CalledProcessError:
        return f"❌ {ip} недоступен!"

async def auto_ping_loop(chat_id):
    global auto_ping_enabled
    while auto_ping_enabled:
        for ip in config.PING_IPS:
            result = ping_host(ip)
            await bot.send_message(chat_id, f"[Автопинг]\n{result}")
        await asyncio.sleep(config.PING_INTERVAL)

@dp.message(Command("start"))
async def start_cmd(message: types.Message):
    keyboard = InlineKeyboardMarkup(inline_keyboard=[
        [
            InlineKeyboardButton(text="Включить автопинг", callback_data="enable_ping"),
            InlineKeyboardButton(text="Отключить автопинг", callback_data="disable_ping")
        ],
        [
            InlineKeyboardButton(text="Проверить сейчас", callback_data="check_now")
        ]
    ])
    await message.answer("Выберите действие:", reply_markup=keyboard)

@dp.callback_query()
async def process_callback(callback: types.CallbackQuery):
    global auto_ping_enabled, auto_ping_task
    if callback.data == "enable_ping":
        if not auto_ping_enabled:
            auto_ping_enabled = True
            auto_ping_task = asyncio.create_task(auto_ping_loop(config.ADMIN_ID))
            await callback.message.answer("Автопинг запущен.")
        else:
            await callback.message.answer("Автопинг уже работает.")
        await callback.answer()
    elif callback.data == "disable_ping":
        auto_ping_enabled = False
        if auto_ping_task:
            auto_ping_task.cancel()
            auto_ping_task = None
        await callback.message.answer("Автопинг остановлен.")
        await callback.answer()
    elif callback.data == "check_now":
        results = []
        for ip in config.PING_IPS:
            results.append(ping_host(ip))
        await callback.message.answer("\n\n".join(results))
        await callback.answer()

async def main():
    await dp.start_polling(bot)

if __name__ == "__main__":
    asyncio.run(main())