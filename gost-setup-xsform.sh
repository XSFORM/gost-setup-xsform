#!/bin/bash

set -e

# Цвета (с использованием \033 для совместимости и echo -e для отображения)
GREEN='\033[32m'
RED='\033[31m'
YELLOW='\033[33m'
NC='\033[0m' # No Color

GOST_BIN="/usr/local/bin/gost"
GOST_SERVICE="/usr/lib/systemd/system/gost.service"
BACKUP_DIR="/var/backups/gost-xsform"
TMP_DIR="/tmp/gost-xsform"
REPO="ginuerzh/gost"

logo_xsform() {
cat <<'EOF'

 ░▒▓██████▓▒░ ░▒▓██████▓▒░ ░▒▓███████▓▒░▒▓████████▓▒░
░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░         ░▒▓█▓▒░
░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░         ░▒▓█▓▒░
░▒▓█▓▒▒▓███▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓██████▓▒░   ░▒▓█▓▒░
░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░      ░▒▓█▓▒░  ░▒▓█▓▒░
░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░      ░▒▓█▓▒░  ░▒▓█▓▒░
 ░▒▓██████▓▒░ ░▒▓██████▓▒░░▒▓███████▓▒░   ░▒▓█▓▒░
        mod от XSFORM  |  Telegram: @XSFORM
====================================================
EOF
}

show_menu() {
  echo
  echo "Выберите действие:"
  echo -e " ${GREEN}1${NC}. Установить Gost (или обновить до последней версии)"
  echo -e " ${GREEN}2${NC}. Редактировать конфигурацию"
  echo -e " ${GREEN}3${NC}. Добавить конфигурацию (добавить дополнительный сервер)"
  echo -e " ${GREEN}4${NC}. Показать текущую конфигурацию"
  echo -e " ${GREEN}5${NC}. Пинг серверов"
  echo -e " ${GREEN}6${NC}. Проверить статус Gost"
  echo -e " ${GREEN}7${NC}. Остановить Gost"
  echo -e " ${GREEN}8${NC}. Запустить Gost"
  echo -e " ${GREEN}9${NC}. Перезапустить Gost"
  echo -e "${GREEN}10${NC}. Показать лог Gost (последние 20 строк)"
  echo -e "${GREEN}11${NC}. Бэкапировать конфигурацию"
  echo -e "${GREEN}12${NC}. Восстановить конфигурацию из бэкапа"
  echo -e "${GREEN}13${NC}. Удалить бэкап"
  echo -e "${GREEN}14${NC}. Переустановить Gost (самая свежая версия)"
  echo -e "${GREEN}15${NC}. Удалить Gost (бинари и systemd unit)"
  echo -e "${GREEN}16${NC}. Ускорить TCP/UDP (sysctl)"
  echo -e " ${GREEN}0${NC}. Выйти"
}

pause() { read -rp "$(echo -e "${YELLOW}Нажмите Enter для продолжения...${NC}")"; }

check_requirements() {
  for pkg in wget curl jq tar gzip nano iproute2; do
    if ! command -v "$pkg" &>/dev/null; then
      echo -e "${YELLOW}Устанавливаю $pkg...${NC}"
      sudo apt update && sudo apt install -y "$pkg"
    fi
  done
}

get_latest_gost_version() {
  curl -s "https://api.github.com/repos/$REPO/releases/latest" | jq -r '.tag_name' | sed 's/^v//'
}

install_gost() {
  local version url
  version=$(get_latest_gost_version)
  echo -e "${GREEN}Будет установлена самая свежая версия gost: $version${NC}"
  mkdir -p "$TMP_DIR"
  cd "$TMP_DIR"

  url="https://github.com/$REPO/releases/download/v$version/gost_${version}_linux_amd64.tar.gz"
  echo "Скачиваю gost v$version..."
  wget -q --show-progress "$url" -O gost.tar.gz || { echo -e "${RED}Ошибка: не удалось скачать $url${NC}"; pause; return 1; }
  tar -xzf gost.tar.gz || { echo -e "${RED}Ошибка: не удалось распаковать gost.tar.gz${NC}"; pause; return 1; }

  if [[ ! -f "gost" ]]; then
    echo -e "${RED}Ошибка: файл gost не найден после распаковки!${NC}"
    pause
    return 1
  fi
  chmod +x gost
  sudo mv gost "$GOST_BIN"
  sudo chmod +x "$GOST_BIN"
  cd - >/dev/null
}

configure_gost_service() {
  echo
  echo "=== Конфигурирование перенаправления ==="
  local gost_ls=""
  while true; do
    echo "Пример протоколов: tcp, udp, http, https, socks5, socks4, tls, ws, wss, h2, relay"
    read -rp "Введите протокол: " proto
    while [[ -z "$proto" ]]; do
      echo -e "${YELLOW}Поле не может быть пустым!${NC}"
      read -rp "Введите протокол: " proto
    done

    read -rp "Введите локальный порт: " local_port
    while ! [[ "$local_port" =~ ^[0-9]+$ ]]; do
      echo -e "${YELLOW}Порт должен быть числом!${NC}"
      read -rp "Введите локальный порт: " local_port
    done

    read -rp "Введите IP-адрес назначения: " remote_ip
    while ! [[ "$remote_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; do
      echo -e "${YELLOW}Введите корректный IPv4 адрес!${NC}"
      read -rp "Введите IP-адрес назначения: " remote_ip
    done

    read -rp "Введите порт назначения: " remote_port
    while ! [[ "$remote_port" =~ ^[0-9]+$ ]]; do
      echo -e "${YELLOW}Порт должен быть числом!${NC}"
      read -rp "Введите порт назначения: " remote_port
    done

    gost_ls="$gost_ls -L=${proto}://:${local_port}/${remote_ip}:${remote_port}"

    read -rp "Добавить еще одну настройку перенаправления? (y/n): " more
    [[ "$more" =~ ^[Yy]$ ]] || break
  done

  sudo tee "$GOST_SERVICE" >/dev/null <<EOF
[Unit]
Description=GO Simple Tunnel (mod от XSFORM)
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=$GOST_BIN$gost_ls
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable gost
  sudo systemctl restart gost

  echo -e "${GREEN}Установка и конфигурация завершены! Gost запущен.${NC}"
  pause
}

add_gost_server() {
  if [[ ! -f "$GOST_SERVICE" ]]; then
    echo -e "${RED}Gost не установлен. Сначала выполните установку (пункт 1 меню).${NC}"
    pause
    return
  fi

  echo
  echo "=== Добавление дополнительного перенаправления ==="
  echo "Пример протоколов: tcp, udp, http, https, socks5, socks4, tls, ws, wss, h2, relay"
  read -rp "Введите протокол: " proto
  while [[ -z "$proto" ]]; do
    echo -e "${YELLOW}Поле не может быть пустым!${NC}"
    read -rp "Введите протокол: " proto
  done

  read -rp "Введите локальный порт: " local_port
  while ! [[ "$local_port" =~ ^[0-9]+$ ]]; do
    echo -e "${YELLOW}Порт должен быть числом!${NC}"
    read -rp "Введите локальный порт: " local_port
  done

  read -rp "Введите IP-адрес назначения: " remote_ip
  while ! [[ "$remote_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; do
    echo -e "${YELLOW}Введите корректный IPv4 адрес!${NC}"
    read -rp "Введите IP-адрес назначения: " remote_ip
  done

  read -rp "Введите порт назначения: " remote_port
  while ! [[ "$remote_port" =~ ^[0-9]+$ ]]; do
    echo -e "${YELLOW}Порт должен быть числом!${NC}"
    read -rp "Введите порт назначения: " remote_port
  done

  new_ls=" -L=${proto}://:${local_port}/${remote_ip}:${remote_port}"

  sudo sed -i "/^ExecStart=/ s|\$|${new_ls}|" "$GOST_SERVICE"

  sudo systemctl daemon-reload
  sudo systemctl restart gost

  echo -e "${GREEN}Дополнительный сервер добавлен и сервис перезапущен.${NC}"
  pause
}

ping_gost_servers() {
  if [[ ! -f "$GOST_SERVICE" ]]; then
    echo -e "${RED}Gost не установлен. Сначала выполните установку (пункт 1 меню).${NC}"
    pause
    return
  fi

  echo "=== Проверка доступности серверов (ping) ==="
  mapfile -t ips < <(grep -oP '([0-9]{1,3}\.){3}[0-9]{1,3}' "$GOST_SERVICE" | sort -u)

  if [[ ${#ips[@]} -eq 0 ]]; then
    echo -e "${YELLOW}В конфигурации не найдено IP-адресов.${NC}"
    pause
    return
  fi

  local statuses=()
  local i=1
  for ip in "${ips[@]}"; do
    if ping -c 1 -W 1 "$ip" &>/dev/null; then
      statuses+=("${GREEN}✅${NC}")
    else
      statuses+=("${RED}❌${NC}")
    fi
    echo -e "$i. $ip  ${statuses[$((i-1))]}"
    ((i++))
  done

  echo
  read -rp "Введите номер IP для подробной проверки (или Enter для выхода): " sel
  if [[ -z "$sel" || ! "$sel" =~ ^[0-9]+$ || "$sel" -lt 1 || "$sel" -gt "${#ips[@]}" ]]; then
    echo "Выход из режима проверки серверов."
    pause
    return
  fi

  ip="${ips[$((sel-1))]}"
  echo "Проверяю IP $ip..."
  if ping -c 2 -W 2 "$ip" &>/dev/null; then
    echo -e "${GREEN}✅ Сервер $ip доступен (ping успешен).${NC}"
  else
    echo -e "${RED}❌ Сервер $ip недоступен!${NC}"
    echo -e "${YELLOW}ip не отвечает на ping. Возможные причины: сервер отключён, ICMP-запросы заблокированы, либо IP-адрес заблокирован провайдером в одной из стран, через которые происходит подключение.${NC}"
    read -rp "Хотите заменить этот IP прямо сейчас? (y/n): " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
      while true; do
        read -rp "Введите новый IP-адрес для замены $ip: " newip
        [[ "$newip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && break
        echo -e "${RED}Неверный IP-адрес! Попробуйте снова.${NC}"
      done
      sudo sed -i "s/$ip/$newip/g" "$GOST_SERVICE"
      sudo systemctl daemon-reload
      sudo systemctl restart gost
      echo -e "${GREEN}IP $ip заменён на $newip. Конфиг обновлён и сервис перезапущен.${NC}"
    fi
  fi
  pause
}

edit_servers() {
  echo -e "${YELLOW}Открывается редактор nano для ручного редактирования $GOST_SERVICE${NC}"
  sudo nano "$GOST_SERVICE"
  sudo systemctl daemon-reload
  sudo systemctl restart gost
  echo -e "${GREEN}Сервис перезапущен после ручного редактирования.${NC}"
  pause
}

show_config() {
  if [[ ! -f "$GOST_SERVICE" ]]; then
    echo -e "${RED}Gost не установлен. Сначала выполните установку (пункт 1 меню).${NC}"
    pause
    return
  fi
  echo "=== Текущая конфигурация Gost ==="
  cat "$GOST_SERVICE"
  pause
}

gost_status() {
  if [[ ! -f "$GOST_BIN" ]]; then
    echo -e "${RED}Gost не установлен. Сначала выполните установку (пункт 1 меню).${NC}"
    pause
    return
  fi
  sudo systemctl status gost --no-pager
  pause
}

gost_stop() {
  if [[ ! -f "$GOST_BIN" ]]; then
    echo -e "${RED}Gost не установлен. Сначала выполните установку (пункт 1 меню).${NC}"
    pause
    return
  fi
  sudo systemctl stop gost
  echo -e "${YELLOW}Gost остановлен.${NC}"
  pause
}

gost_start() {
  if [[ ! -f "$GOST_BIN" ]]; then
    echo -e "${RED}Gost не установлен. Сначала выполните установку (пункт 1 меню).${NC}"
    pause
    return
  fi
  sudo systemctl start gost
  echo -e "${GREEN}Gost запущен.${NC}"
  pause
}

gost_restart() {
  if [[ ! -f "$GOST_BIN" ]]; then
    echo -e "${RED}Gost не установлен. Сначала выполните установку (пункт 1 меню).${NC}"
    pause
    return
  fi
  sudo systemctl restart gost
  echo -e "${GREEN}Gost перезапущен.${NC}"
  pause
}

gost_log() {
  if [[ ! -f "$GOST_BIN" ]]; then
    echo -e "${RED}Gost не установлен. Сначала выполните установку (пункт 1 меню).${NC}"
    pause
    return
  fi
  echo "=== Последние 20 строк журнала gost ==="
  sudo journalctl -u gost --no-pager -n 20
  pause
}

backup_gost() {
  if [[ ! -f "$GOST_BIN" ]]; then
    echo -e "${RED}Gost не установлен. Сначала выполните установку (пункт 1 меню).${NC}"
    pause
    return
  fi
  mkdir -p "$BACKUP_DIR"
  read -rp "Введите имя для бэкапа (Enter — использовать имя по умолчанию): " custom_name
  if [[ -z "$custom_name" ]]; then
    backup_file="$BACKUP_DIR/gost-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
  else
    custom_name=$(echo "$custom_name" | sed 's/[^a-zA-Z0-9._-]//g')
    backup_file="$BACKUP_DIR/${custom_name}.tar.gz"
  fi
  echo "Создаю бэкап в $backup_file"
  sudo tar -czf "$backup_file" "$GOST_BIN" "$GOST_SERVICE"
  echo -e "${GREEN}Бэкап готов: $backup_file${NC}"
  pause
}

restore_gost() {
  if [[ ! -d "$BACKUP_DIR" ]]; then
    echo -e "${RED}Бэкапы не найдены. Сначала создайте бэкап (пункт 11 меню).${NC}"
    pause
    return
  fi
  echo "=== Доступные бэкапы ==="
  local files
  files=($(ls -1t "$BACKUP_DIR"/*.tar.gz 2>/dev/null))
  if [[ ${#files[@]} -eq 0 ]]; then
    echo -e "${RED}Бэкапы не найдены.${NC}"
    pause
    return
  fi
  local i=1
  for f in "${files[@]}"; do
    echo "$i. $f"
    ((i++))
  done
  read -rp "Введите номер файла для восстановления: " num
  local idx=$((num-1))
  if [[ -n "${files[$idx]}" && -f "${files[$idx]}" ]]; then
    sudo tar -xzf "${files[$idx]}" -C /
    sudo systemctl daemon-reload
    sudo systemctl restart gost
    echo -e "${GREEN}Восстановление завершено и gost перезапущен.${NC}"
  else
    echo -e "${RED}Файл не найден!${NC}"
  fi
  pause
}

delete_backup() {
  if [[ ! -d "$BACKUP_DIR" ]]; then
    echo -e "${RED}Бэкапы не найдены.${NC}"
    pause
    return
  fi
  echo "=== Доступные бэкапы для удаления ==="
  local files
  files=($(ls -1t "$BACKUP_DIR"/*.tar.gz 2>/dev/null))
  if [[ ${#files[@]} -eq 0 ]]; then
    echo -e "${RED}Бэкапы не найдены.${NC}"
    pause
    return
  fi
  local i=1
  for f in "${files[@]}"; do
    echo "$i. $f"
    ((i++))
  done
  read -rp "Введите номер файла для удаления: " num
  local idx=$((num-1))
  if [[ -n "${files[$idx]}" && -f "${files[$idx]}" ]]; then
    sudo rm -f "${files[$idx]}"
    echo -e "${YELLOW}Бэкап удалён: ${files[$idx]}${NC}"
  else
    echo -e "${RED}Файл не найден!${NC}"
  fi
  pause
}

reinstall_gost() {
  if [[ ! -f "$GOST_BIN" ]]; then
    echo -e "${RED}Gost не установлен. Сначала выполните установку (пункт 1 меню).${NC}"
    pause
    return
  fi
  echo -e "${YELLOW}Переустановка удалит бинарник gost и установит последнюю версию.${NC}"
  read -rp "Продолжить? [y/N]: " ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    sudo systemctl stop gost || true
    sudo rm -f "$GOST_BIN"
    install_gost
    sudo systemctl daemon-reload
    sudo systemctl restart gost
    echo -e "${GREEN}Gost переустановлен и запущен.${NC}"
  else
    echo -e "${YELLOW}Переустановка отменена.${NC}"
  fi
  pause
}

delete_gost() {
  if [[ ! -f "$GOST_BIN" && ! -f "$GOST_SERVICE" ]]; then
    echo -e "${RED}Gost не установлен.${NC}"
    pause
    return
  fi
  echo -e "${RED}Удаление отключит сервис, удалит бинарник и systemd unit.${NC}"
  read -rp "Вы уверены? [y/N]: " ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    sudo systemctl stop gost || true
    sudo systemctl disable gost || true
    sudo rm -f "$GOST_BIN" "$GOST_SERVICE"
    sudo systemctl daemon-reload
    echo -e "${GREEN}Gost удалён.${NC}"
  else
    echo -e "${YELLOW}Удаление отменено.${NC}"
  fi
  pause
}

# =========================
#  Ускоритель TCP/UDP (IPv4)
# =========================
optimize_tcp_udp() {
  echo -e "${YELLOW}Устанавливаю системные твики для TCP/UDP (IPv4 only)…${NC}"

  local CONF="/etc/sysctl.d/98-vpn-proxy.conf"
  local BAKDIR="/etc/sysctl.d/.backups"
  local stamp; stamp() { date +%F-%H%M%S; }

  # Требуем root
  if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Запусти от root: sudo $0${NC}"
    pause
    return 1
  fi

  # Бэкап предыдущего файла (если был)
  sudo mkdir -p "$BAKDIR"
  if [[ -f "$CONF" ]]; then
    sudo cp -a "$CONF" "$BAKDIR/$(basename "$CONF").$(stamp).bak"
    echo -e "${GREEN}Бэкап создан: $BAKDIR/$(basename "$CONF").$(stamp).bak${NC}"
  fi

  # IPv4 only, включаем UDP+TCP твики сразу (поставил и забыл)
  sudo tee "$CONF" >/dev/null <<'EOF'
# --- VPN Proxy Optimizer (GOST) — IPv4 only, UDP+TCP ---
# Включаем форвардинг (на случай DNAT/маршрутизации через хост)
net.ipv4.ip_forward = 1

# Лёгкий планировщик очередей — меньше джиттер/задержка
net.core.default_qdisc = fq

# Общие лимиты буферов (полезно и TCP, и UDP)
net.core.rmem_max = 2500000
net.core.wmem_max = 2500000
net.core.optmem_max = 25165824
net.core.netdev_max_backlog = 5000

# UDP: держим подключения дольше, меньше ложных обрывов через NAT
net.netfilter.nf_conntrack_udp_timeout = 60
net.netfilter.nf_conntrack_udp_timeout_stream = 180

# TCP: быстрее качает на «шумных» каналах
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_low_latency = 1
EOF

  # Применяем параметры ядра
  sudo modprobe nf_conntrack 2>/dev/null || true
  sudo sysctl --system >/dev/null || true

  # Ставим fq на активные интерфейсы сразу (без ребута)
  mapfile -t ifs < <(ip -o link show | awk -F': ' '/UP/ {print $2}' | grep -v '^lo$' || true)
  for i in "${ifs[@]}"; do
    sudo tc qdisc replace dev "$i" root fq 2>/dev/null || true
  done

  echo
  echo -e "${GREEN}[OK] Ускорение TCP/UDP применено: $CONF${NC}"
  sudo sysctl net.ipv4.ip_forward \
              net.core.default_qdisc \
              net.core.rmem_max net.core.wmem_max \
              net.netfilter.nf_conntrack_udp_timeout \
              net.ipv4.tcp_congestion_control net.ipv4.tcp_fastopen \
              net.ipv4.tcp_low_latency 2>/dev/null || true
  echo
  pause
}

main_menu() {
  while true; do
    clear
    logo_xsform
    show_menu
    read -rp "Ваш выбор: " choice
    case "$choice" in
      1)
        check_requirements
        install_gost && configure_gost_service
        ;;
      2) edit_servers ;;
      3) add_gost_server ;;
      4) show_config ;;
      5) ping_gost_servers ;;
      6) gost_status ;;
      7) gost_stop ;;
      8) gost_start ;;
      9) gost_restart ;;
     10) gost_log ;;
     11) backup_gost ;;
     12) restore_gost ;;
     13) delete_backup ;;
     14) reinstall_gost ;;
     15) delete_gost ;;
	 16) optimize_tcp_udp ;;
      0) echo -e "${GREEN}Выход. Спасибо, что используете XSFORM mod!${NC}"; exit 0 ;;
      *) echo -e "${YELLOW}Некорректный выбор${NC}"; pause ;;
    esac
  done
}

main_menu
