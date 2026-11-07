# Factorio Headless Server у контейнері

[English](README.md) | **Українська**

[![Build](https://github.com/craftorio/factorio/actions/workflows/build.yml/badge.svg)](https://github.com/craftorio/factorio/actions/workflows/build.yml) [![Docker Pulls](https://img.shields.io/docker/pulls/craftorio/factorio.svg)](https://hub.docker.com/r/craftorio/factorio/) [![License](https://img.shields.io/github/license/craftorio/factorio.svg)](https://github.com/craftorio/factorio)

Форк [goofball222/factorio](https://github.com/goofball222/factorio). GitHub Actions кожні 2 години перевіряє
[офіційний API](https://factorio.com/api/latest-releases) і збирає нові образи, щойно з'являється новий реліз
headless-сервера Factorio. Образи перезбираються лише для нової версії Factorio або після змін у Dockerfile
та скриптах entrypoint. Теги нижче завжди відповідають актуальним версіям.

Образи збираються для `linux/amd64` та `linux/arm64` і публікуються в:

* GitHub Container Registry: `ghcr.io/craftorio/factorio`
* Docker Hub: `craftorio/factorio`

| Тег Docker | Версія Factorio | Опис | Оновлено |
| --- | :---: | --- | :---: |
| [latest, stable, 2.1.24](https://github.com/craftorio/factorio/blob/main/stable/Dockerfile)<br>[latest-alpine, stable-alpine, 2.1.24-alpine](https://github.com/craftorio/factorio/blob/main/stable/Dockerfile.alpine) | 2.1.24 | Стабільний реліз headless-сервера Factorio | 2026-11-07 | <!-- stable -->
| [experimental](https://github.com/craftorio/factorio/blob/main/experimental/Dockerfile)<br>[experimental-alpine](https://github.com/craftorio/factorio/blob/main/experimental/Dockerfile.alpine) | 2.1.24 | Експериментальний реліз headless-сервера Factorio | 2026-11-07 | <!-- experimental -->

Для стабільного каналу з кожним релізом публікуються теги з номером версії (`2.0.77`, `2.0.77-alpine`), тож можна
зафіксувати конкретну версію Factorio. Якщо експериментальний канал вказує на іншу версію, ніж стабільний, він також
отримує власний тег з версією.

---

* [Останні зміни: CHANGELOG.md на GitHub](https://github.com/craftorio/factorio/blob/main/CHANGELOG.md)
* [Повідомляйте про помилки та пропозиції на GitHub](https://github.com/craftorio/factorio/issues)

---

Для безпеки та зменшення поверхні атаки контейнер запускає headless-сервер Factorio від внутрішнього користувача
та групи `factorio` з наперед заданими UID і GID 999.
Перед скиданням привілеїв і запуском сервера контейнер намагається виправити права на підключених томах і даних.
Якщо контейнер запущено з іншим параметром Docker `--user`, права, можливо, доведеться виправити вручну.

Наприклад: `chown -R 999:999 factorio`

Для внутрішнього користувача та групи factorio можна задати власні UID і GID. Докладніше в розділі «Змінні середовища».

---

**Перед встановленням нових образів завжди зупиняйте наявний контейнер і робіть ПЕРЕВІРЕНУ резервну копію збережень Factorio.**

---

## Швидкий старт

```bash
mkdir -p /opt/factorio && cd /opt/factorio
curl -fsSLO https://raw.githubusercontent.com/craftorio/factorio/main/docker-compose.yml
docker compose up -d
docker logs -f factorio
```

Під час першого запуску поруч із compose-файлом створюється каталог `./data`, у `data/config` копіюються приклади
налаштувань Factorio, генерується випадковий пароль RCON (виводиться в лог і зберігається в `data/config/RCON.pwd`)
і створюється нова карта `save.zip` в іменованому томі Docker `factorio_saves`. Сервер одразу доступний для гри на
порту `34197/udp`.

Конфігурація, моди та сценарії зберігаються в `./data` на хості, а збереження в томі `factorio_saves`. Такий поділ
дає змогу скинути світ командою `docker compose down -v` (видаляє том зі збереженнями, залишає `./data`) і почати
заново через `docker compose up -d`. Резервну копію тому можна зробити командою
`docker compose cp factorio:/factorio/saves ./saves-backup`.

**Очікувано на чистій установці:** лог завершується рядком
`Matching server connection failed: Error when creating server game: Missing token.`
У прикладі `server-settings.json` увімкнено `visibility.public = true`, але немає облікових даних factorio.com, тому
сервер не може зареєструватися в публічному списку серверів. Виправте це, відредагувавши `data/config/server-settings.json`:

* задайте `name`, `description`, `game_password`, `admins`;
* або вкажіть свої `username` і `token` від factorio.com (з [профілю factorio.com](https://factorio.com/profile))
  для публічного сервера, або встановіть `"visibility": {"public": false, "lan": false}` для приватного;

після цього виконайте `docker compose restart factorio`. За бажанням додайте `data/config/server-adminlist.json`.
Щоб грати на власній карті, скопіюйте її в том зі збереженнями та перезапустіть сервер:

```bash
docker compose cp my-save.zip factorio:/factorio/saves/save.zip
docker compose restart factorio
```

Завжди запускайте `docker compose` з каталогу, де лежить `docker-compose.yml`: завдання оновлення ofelia монтує
каталог проєкту за його абсолютним шляхом.

**Міграція наявного сервера** (наприклад, з upstream-образу `goofball222/factorio` з даними в `/opt/factorio`):
зупиніть старий контейнер, перемістіть `config`, `mods` і `scenarios` у `./data`, покладіть поруч новий
`docker-compose.yml`, виконайте `docker compose up -d`, а потім скопіюйте своє збереження в том командою
`docker compose cp saves/save.zip factorio:/factorio/saves/save.zip` і виконайте `docker compose restart factorio`.
Збереження сумісні, якщо версія Factorio така сама або новіша.

**Оновлення** відбуваються автоматично: GitHub Actions публікує нові образи протягом двох годин після релізу
Factorio, а сервіс `ofelia` з compose-файлу кожні 15 хвилин перевіряє, завантажує новий образ і перестворює сервер,
коли образ з'явився. Сервер перезапускається лише тоді, коли образ справді змінився; приберіть сервіс `ofelia`,
якщо хочете оновлювати вручну командою `docker compose pull && docker compose up -d`.

---

## Використання

**Контейнер має єдиний том `/factorio` з такою структурою** (compose-файл монтує його з `./data`, а `saves` виносить в окремий іменований том):

    factorio
    |-- config
    |   |-- map-gen-settings.json
    |   |-- map-gen-settings.example.json
    |   |-- map-settings.json
    |   |-- map-settings.example.json
    |   |-- RCON.pw
    |   |-- server-adminlist.json
    |   |-- server-banlist.json
    |   |-- server-settings.json
    |   `-- server-whitelist.json
    |-- mods
    |   `-- mod.zip
    |-- saves
    |   `-- save.zip
    `-- scenarios
        `-- scenario.zip

**Контейнер відкриває два порти:**
* `27015/tcp`: порт RCON Factorio
* `34197/udp`: стандартний порт сервера Factorio

---

**Найпростіший спосіб запустити контейнер:**

```bash
$ docker run --name factorio -d \
    -p 34197:34197/udp \
    craftorio/factorio
```

---

**Рекомендовано: запуск через [Docker Compose](https://docs.docker.com/compose/):**

Зберігайте config, mods, saves і scenarios на локальній файловій системі або у відомому томі даних (рекомендовано
для збереження даних і діагностики) та відкрийте порт RCON для адміністрування:

```yaml
services:
  factorio:
    image: ghcr.io/craftorio/factorio:latest
    container_name: factorio
    restart: unless-stopped
    ports:
      - "27015:27015"
      - "34197:34197/udp"
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - ./data:/factorio
      - saves:/factorio/saves
    environment:
      - TZ=UTC

volumes:
  saves:
```

[`docker-compose.yml`](https://github.com/craftorio/factorio/blob/main/docker-compose.yml) з конфігурацією та модами в `./data` поруч
із compose-файлом, збереженнями в іменованому томі `factorio_saves` і завданням [ofelia](https://github.com/mcuadros/ofelia), яке кожні 15 хвилин завантажує образ
і перестворює сервер, коли опубліковано новий.

---

**Логи доступні безпосередньо з працюючого контейнера, наприклад: "docker logs factorio"**

---

**Змінні середовища:**

| Змінна | Типово | Опис |
| :--- | :---: | --- |
| `DEBUG` | ***false*** | Встановіть *true* для докладнішого виводу контейнера під час налагодження |
| `FACTORIO_OPTS` | ***не задано*** | Додаткові параметри командного рядка для виконуваного файлу сервера Factorio |
| `FACTORIO_PORT` | ***не задано*** | Перевизначає стандартний порт сервера для підключення клієнтів |
| `FACTORIO_RCON_PASSWORD` | ***не задано*** | Задає пароль RCON сервера |
| `FACTORIO_RCON_PORT` | ***27015*** | Задає порт адміністрування RCON |
| `FACTORIO_SCENARIO` | ***не задано*** | Назва сценарію, який має запустити сервер |
| `PGID` | ***999*** | GID внутрішньої групи factorio (використовується для власника файлів) |
| `PUID` | ***999*** | UID внутрішнього користувача factorio (використовується для процесу та власника файлів) |
| `RUN_CHOWN` | ***true*** | Встановіть *false*, щоб вимкнути автоматичний `chown` під час запуску. Пришвидшує старт на хостах з overlay2. **ВАЖЛИВО:** перед вимкненням переконайтеся, що права на всіх підключених томах правильні, інакше Factorio не запуститься. |
| `RUNAS_UID0` | ***false*** | Встановіть *true*, щоб змусити контейнер запускати сервер Factorio від UID=0 (root). **ВАЖЛИВО:** запуск із цим значенням небезпечний |

---

Під час першого запуску контейнера файли server-settings.json і map-gen-settings.json заповнюються прикладами
Factorio, якщо їх ще немає. Наполегливо рекомендуємо відредагувати їх і перезапустити контейнер або покласти
готові копії в каталог config до першого запуску. Приклади конфігурацій є в архіві headless-сервера в теці "data".
Якщо під час запуску не знайдено збереження, контейнер також створить стандартну карту save.zip у теці saves.

Пароль RCON можна задати змінною середовища FACTORIO_RCON_PASSWORD або він зчитується з `/factorio/config/RCON.pwd`
під час кожного запуску контейнера. Якщо змінна FACTORIO_RCON_PASSWORD не задана і файлу RCON.pwd немає, буде
згенеровано випадковий пароль і збережено в `/factorio/config/RCON.pwd`. Чинний пароль RCON також видно на початку
логу контейнера під час кожного запуску.

---

## Приклади необов'язкових конфігурацій

`config/server-whitelist.json` - **якщо файл є, доступ матимуть лише перелічені користувачі Factorio**

    [
        "user1",
        "user2",
        "user3"
    ]

`config/server-banlist.json` - якщо файл є, переліченим користувачам Factorio буде відмовлено в доступі

    [
        "banneduser1",
        "banneduser2",
        "banneduser3",
        "banneduser4"
    ]

`config/server-adminlist.json` - якщо файл є, перелічені користувачі Factorio отримають права адміністратора

    [
        "adminuser1",
        "adminuser2"
    ]

[//]: # (Licensed under the Apache 2.0 license)
[//]: # (Copyright 2019 The Goofball - goofball222@gmail.com)
[//]: # (Copyright 2026 Craftorio - https://github.com/craftorio/factorio)
