# gost-setup-xsform

## Описание

Скрипт для автоматической установки, настройки и управления прокси сервисом [gost](https://github.com/go-gost/gost) + дополнительных инструментов и мониторинга.

**Возможности:**
- Установка и настройка gost на Ubuntu/Debian
- Быстрое управление сервисом (старт, стоп, рестарт, статус, просмотр логов)
- Проверка доступности серверов (ping), быстрая смена TM IP
- Создание и восстановление бэкапов конфигурации
- Перестановка и удаление gost
- Интеграция с Telegram-ботом для мониторинга доступности TM IP (ping_check_bot)

---

## Установка основного скрипта

Скачайте и дайте права на выполнение:

```bash
wget https://raw.githubusercontent.com/XSFORM/gost-setup-xsform/main/gost-setup-xsform.sh
chmod +x gost-setup-xsform.sh
```

## Запуск

```bash
sudo ./gost-setup-xsform.sh
```

_Скрипт тестировался на Ubuntu/Debian. Для работы нужен root-доступ (sudo) для установки пакетов и управления сервисами._

---

## Мониторинг TM IP и Telegram-бот

### Установка Telegram-бота (Ping Monitor)

1. Скачайте и запустите установочный скрипт:

```bash
wget https://raw.githubusercontent.com/XSFORM/gost-setup-xsform/main/install_gost_pingbot.sh
chmod +x install_gost_pingbot.sh
sudo ./install_gost_pingbot.sh
```

2. Следуйте инструкциям: введите Telegram Bot Token и свой Chat ID.

3. Бот будет автоматически установлен и запущен как сервис.  
   Для управления — используйте gost-setup-xsform.sh, для уведомлений — Telegram-бот.

**Структура для бота:**
- `ping_check_bot.py` — основной скрипт бота
- `requirements.txt` — зависимости
- `ping_check_bot.service` — systemd unit для автозапуска

---

## Скриншоты

_(Добавьте свои скриншоты, если хотите)_

---

## Обратная связь

**Автор:** [XSFORM](https://github.com/XSFORM)  
**Telegram-канал:** [https://t.me/XSFORM](https://t.me/XSFORM)
