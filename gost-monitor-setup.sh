#!/bin/bash

set -e

MONITOR_CONF="$HOME/.gost_monitor.conf"
MONITOR_SCRIPT="$HOME/.gost_ping_monitor.sh"

GREEN='\033[32m'
RED='\033[31m'
YELLOW='\033[33m'
NC='\033[0m'

check_deps() {
  for pkg in curl ping; do
    if ! command -v "$pkg" &>/dev/null; then
      echo -e "${YELLOW}Устанавливаю $pkg...${NC}"
      sudo apt update && sudo apt install -y "$pkg"
    fi
  done
}

setup_monitor_params() {
  echo -e "${YELLOW}Настройка параметров мониторинга TM IP и Telegram${NC}"

  read -rp "Введите первый TM IP (AGTS) [185.69.186.72]: " tmip1
  [[ -z "$tmip1" ]] && tmip1="185.69.186.72"

  read -rp "Введите второй TM IP (Telekom) [95.85.101.124]: " tmip2
  [[ -z "$tmip2" ]] && tmip2="95.85.101.124"

  read -rp "Введите Telegram Bot Token: " ttoken
  while [[ -z "$ttoken" ]]; do
    echo -e "${RED}Токен не может быть пустым!${NC}"
    read -rp "Введите Telegram Bot Token: " ttoken
  done

  read -rp "Введите Telegram Chat ID: " tchatid
  while [[ -z "$tchatid" ]]; do
    echo -e "${RED}Chat ID не может быть пустым!${NC}"
    read -rp "Введите Telegram Chat ID: " tchatid
  done

  echo "TM_IP1=$tmip1" > "$MONITOR_CONF"
  echo "TM_IP2=$tmip2" >> "$MONITOR_CONF"
  echo "TELEGRAM_TOKEN=$ttoken" >> "$MONITOR_CONF"
  echo "TELEGRAM_CHATID=$tchatid" >> "$MONITOR_CONF"
  echo "INTERVAL=10" >> "$MONITOR_CONF"

  echo -e "${GREEN}Параметры сохранены: $MONITOR_CONF${NC}"
}

gen_monitor_script() {
  cat > "$MONITOR_SCRIPT" <<EOF
#!/bin/bash
source "$MONITOR_CONF"
fail=0
for ip in "\$TM_IP1" "\$TM_IP2"; do
  if ! ping -c 2 -W 2 "\$ip" &>/dev/null; then
    fail=1
  fi
done
if [[ \$fail -eq 1 ]]; then
  msg="ВНИМАНИЕ: Один или оба TM IP (\$TM_IP1, \$TM_IP2) недоступны! Возможна блокировка."
  curl -s -X POST "https://api.telegram.org/bot\$TELEGRAM_TOKEN/sendMessage" -d "chat_id=\$TELEGRAM_CHATID" -d "text=\$msg" >/dev/null
fi
EOF
  chmod +x "$MONITOR_SCRIPT"
  echo -e "${GREEN}Мониторинговый скрипт создан: $MONITOR_SCRIPT${NC}"
}

enable_auto_ping() {
  source "$MONITOR_CONF"
  echo -e "${YELLOW}Выберите интервал автопроверки:${NC}"
  echo "1. 10 минут"
  echo "2. 1 час"
  echo "3. 3 часа"
  echo "4. 6 часов"
  echo "5. 12 часов"
  echo "6. 24 часа"
  read -rp "Ваш выбор: " interval_choice
  case "$interval_choice" in
    1) interval="10" ;;
    2) interval="60" ;;
    3) interval="180" ;;
    4) interval="360" ;;
    5) interval="720" ;;
    6) interval="1440" ;;
    *) echo "Некорректный выбор, по умолчанию 10 минут"; interval="10" ;;
  esac

  # Обновляем интервал в конфиге
  sed -i "/^INTERVAL=/d" "$MONITOR_CONF"
  echo "INTERVAL=$interval" >> "$MONITOR_CONF"

  # Удаляем старый cron и добавляем новый
  crontab -l 2>/dev/null | grep -v "$MONITOR_SCRIPT" > /tmp/cron_gostmon
  echo "*/$interval * * * * $MONITOR_SCRIPT" >> /tmp/cron_gostmon
  crontab /tmp/cron_gostmon
  rm -f /tmp/cron_gostmon

  echo -e "${GREEN}Автоматическая проверка включена!${NC} (интервал: $interval мин)"
}

disable_auto_ping() {
  crontab -l 2>/dev/null | grep -v "$MONITOR_SCRIPT" | crontab -
  echo -e "${YELLOW}Автопроверка отключена.${NC}"
}

manual_ping_check() {
  source "$MONITOR_CONF"
  local fail=0
  echo -e "${GREEN}Проверяю доступность TM IP...${NC}"
  for ip in "$TM_IP1" "$TM_IP2"; do
    if ping -c 2 -W 2 "$ip" &>/dev/null; then
      echo -e "$ip: ${GREEN}✅ доступен${NC}"
    else
      echo -e "$ip: ${RED}❌ недоступен!${NC}"
      fail=1
    fi
  done
  if [[ $fail -eq 1 ]]; then
    echo -e "${YELLOW}Один или оба TM IP недоступны — возможно блокировка!${NC}"
  else
    echo -e "${GREEN}Оба TM IP доступны.${NC}"
  fi
}

main() {
  check_deps
  if [[ ! -f "$MONITOR_CONF" ]]; then
    setup_monitor_params
  fi
  gen_monitor_script

  echo -e "${GREEN}Мониторинг TM IP & Telegram готов к работе!${NC}"
  echo -e "${YELLOW}Выберите действие:${NC}"
  echo "1. Включить автоматическую проверку"
  echo "2. Отключить автопроверку"
  echo "3. Проверить доступность TM IP сейчас"
  echo "4. Сменить настройки мониторинга"
  echo "0. Выйти"
  while true; do
    read -rp "Ваш выбор: " choice
    case "$choice" in
      1) enable_auto_ping ;;
      2) disable_auto_ping ;;
      3) manual_ping_check ;;
      4) setup_monitor_params; gen_monitor_script ;;
      0) echo -e "${GREEN}Готово. Скрипт завершён.${NC}"; exit 0 ;;
      *) echo -e "${YELLOW}Некорректный выбор${NC}" ;;
    esac
  done
}

main