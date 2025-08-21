#!/bin/bash
set -e

echo -e "\033[36m--- Установка Python и pip ---\033[0m"
apt update
apt install -y python3 python3-pip git

echo -e "\033[36m--- Скачивание бота из GitHub ---\033[0m"
git clone https://github.com/XSFORM/gost-setup-xsform.git /opt/gost-setup-xsform

echo -e "\033[36m--- Установка зависимостей ---\033[0m"
pip3 install -r /opt/gost-setup-xsform/ping_check_bot/requirements.txt

echo -e "\033[32mВведите Telegram BOT TOKEN:\033[0m"
read -r BOT_TOKEN
echo -e "\033[32mВведите Telegram CHAT ID:\033[0m"
read -r CHAT_ID

cat > /opt/gost-setup-xsform/ping_check_bot/config.py <<EOF
TOKEN = "$BOT_TOKEN"
ADMIN_ID = $CHAT_ID
PING_IPS = ["185.69.186.61"]
PING_INTERVAL = 60
EOF

echo -e "\033[36m--- Настройка автозапуска ---\033[0m"
cp /opt/gost-setup-xsform/ping_check_bot/ping_check_bot.service /etc/systemd/system/ping_check_bot.service
systemctl daemon-reload
systemctl enable --now ping_check_bot.service

echo -e "\033[32mБот установлен и запущен! Управление через Telegram.\033[0m"