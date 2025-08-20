#!/bin/bash
set -e

# === 1. Качаем основной скрипт gost ===
echo -e "\033[33mСкачиваю основной скрипт gost...\033[0m"
wget -O /root/gost-setup-xsform.sh https://raw.githubusercontent.com/XSFORM/gost-setup-xsform/main/gost-setup-xsform.sh
chmod +x /root/gost-setup-xsform.sh

# === 2. Качаем бот для мониторинга (ping_check_bot) ===
echo -e "\033[33mСкачиваю файлы бота ping_check_bot...\033[0m"
mkdir -p /root/ping_check_bot
wget -qO- https://github.com/XSFORM/gost-setup-xsform/archive/main.tar.gz | tar -xz --strip=2 -C /root/ping_check_bot gost-setup-xsform/main/ping_check_bot

# === 3. Запрашиваем Telegram BOT TOKEN и CHAT ID ===
echo -e "\033[32mВведите Telegram BOT TOKEN (например, 123456:ABC...):\033[0m"
read -r BOT_TOKEN
echo -e "\033[32mВведите ваш Telegram Chat ID (например, 123456789):\033[0m"
read -r ADMIN_ID

# === 4. Создаём config для бота ===
cat > /root/ping_check_bot/config.py <<EOF
TOKEN = "$BOT_TOKEN"
ADMIN_ID = $ADMIN_ID
EOF

# === 5. Устанавливаем зависимости для Python-бота ===
apt update
apt install -y python3 python3-pip
pip3 install -r /root/ping_check_bot/requirements.txt

# === 6. Копируем systemd unit для автозапуска ===
cp /root/ping_check_bot/ping_check_bot.service /etc/systemd/system/ping_check_bot.service

systemctl daemon-reload
systemctl enable --now ping_check_bot.service

echo -e "\033[32mУстановка завершена! Gost-скрипт лежит в /root/gost-setup-xsform.sh, бот активен.\033[0m"
echo -e "\033[33mДля управления gost используйте /root/gost-setup-xsform.sh. Для мониторинга — бот работает, настройки в /root/ping_check_bot/config.py.\033[0m"