## 9. Контейнеризация

### 9.1. Установка Docker Engine

Docker Engine установлен на виртуальной машине Ubuntu из официального
репозитория Docker. Пакет `docker.io` из стандартного репозитория Ubuntu
не использовался.

Установлены следующие компоненты:

- Docker Engine (`docker-ce`);
- Docker CLI (`docker-ce-cli`);
- containerd;
- Docker Buildx;
- Docker Compose Plugin.

Проверка установленных версий:

```bash
docker version
docker compose version
```

Версия Docker Engine: указывается по выводу команды `docker version`.

Версия Docker Compose: указывается по выводу команды
`docker compose version`.

Служба Docker включена в автозагрузку и должна находиться в состоянии
`active`:

```bash
sudo systemctl enable docker
systemctl is-active docker
```

### 9.2. Доступ к Docker

В группу `docker` добавлена учётная запись:

```text
devops
```

Проверка участников группы:

```bash
getent group docker
```

Пользователь `devops` может выполнять команды Docker без `sudo`:

```bash
docker ps
docker compose version
```

Членство в группе `docker` фактически предоставляет возможность получить
права root, поэтому добавлять в неё посторонних пользователей запрещено.

### 9.3. Расположение проекта

Проект контейнеризованного приложения расположен на виртуальной машине
в каталоге:

```text
/home/devops/app
```

Основные файлы проекта:

```text
/home/devops/app/Dockerfile
/home/devops/app/docker-compose.yml
/home/devops/app/app.py
/home/devops/app/requirements.txt
/home/devops/app/.env.example
/home/devops/app/.env
```

Исходный код хранится в репозитории на хостовой системе macOS и
доставляется на виртуальную машину командой:

```bash
rsync -avz --delete --exclude=.env app/ devops:app/
```

Параметр `--exclude=.env` обязателен: он предотвращает удаление или
перезапись файла с секретными данными на виртуальной машине.

### 9.4. Переменные окружения

Файл с рабочими переменными окружения расположен только на виртуальной
машине:

```text
/home/devops/app/.env
```

Права файла должны быть равны `600`, владелец — пользователь `devops`:

```bash
stat -c '%a %U:%G %n' /home/devops/app/.env
```

Ожидаемый результат:

```text
600 devops:devops /home/devops/app/.env
```

Файл содержит следующие переменные:

```text
POSTGRES_DB
POSTGRES_USER
POSTGRES_PASSWORD
DB_HOST
```

Пароль PostgreSQL в документацию и репозиторий не записывается. Для
создания нового случайного пароля используется команда:

```bash
openssl rand -hex 16
```

Файл `.env` исключён из Git. В репозитории хранится только шаблон
`.env.example` без настоящего пароля.

Проверка отсутствия `.env` в репозитории:

```bash
git ls-files | grep -x 'app/.env'
```

Команда должна завершиться без вывода.

### 9.5. Сервисы Docker Compose

Конфигурация `docker-compose.yml` запускает два сервиса:

- `app` — приложение Flask, запускаемое через Gunicorn;
- `db` — PostgreSQL 16 на основе образа `postgres:16-alpine`.

Приложение внутри контейнера запускается от имени непривилегированного
пользователя `app`, а не root.

Проверка:

```bash
cd /home/devops/app
docker compose exec app id
```

Запуск проекта:

```bash
cd /home/devops/app
docker compose up -d --build
```

Проверка состояния:

```bash
docker compose ps
```

У контейнера PostgreSQL должно отображаться состояние `healthy`.

Остановка проекта без удаления данных:

```bash
docker compose down
```

### 9.6. Сеть и опубликованные порты

Docker Compose создаёт изолированную сеть:

```text
app_backend
```

В этой сети приложение находит PostgreSQL по DNS-имени сервиса:

```text
db
```

Проверка разрешения имени:

```bash
cd /home/devops/app
docker compose exec app getent hosts db
```

Порт приложения опубликован только на loopback-адресе виртуальной машины:

```text
127.0.0.1:5000 -> контейнер app:5000
```

В `docker-compose.yml` используется запись:

```yaml
ports:
  - "127.0.0.1:5000:5000"
```

Поэтому порт приложения недоступен напрямую с хостовой системы и из
локальной сети.

Порт PostgreSQL `5432` не публикуется. Приложение обращается к базе данных
только через внутреннюю сеть Docker.

Проверка портов:

```bash
sudo ss -tlnp | grep -E ':(5000|5432)\b'
```

Ожидается только сокет:

```text
127.0.0.1:5000
```

Порт `5432` на виртуальной машине прослушиваться не должен.

Порт `5001`, использовавшийся для демонстрации обхода UFW, не должен
оставаться опубликованным после завершения проверки.

### 9.7. Именованный том

Данные PostgreSQL хранятся в именованном томе:

```text
app_db_data
```

Том подключён к каталогу контейнера:

```text
/var/lib/postgresql/data
```

Проверка тома:

```bash
docker volume ls
docker volume inspect app_db_data
```

Команда:

```bash
docker compose down
```

удаляет контейнеры и сеть, но сохраняет именованный том и данные
PostgreSQL.

Команда:

```bash
docker compose down -v
```

удаляет контейнеры вместе с томом и базой данных. На рабочей системе эту
команду выполнять нельзя без необходимости и резервной копии.

### 9.8. Обратный прокси-сервер Nginx

Приложение публикуется через Nginx по адресу:

```text
https://devops.local/app/
```

Проверка состояния приложения доступна по адресу:

```text
https://devops.local/app/health
```

Конфигурация виртуального хоста находится в файле:

```text
/etc/nginx/sites-available/devops-site
```

В HTTPS-блоке `server` используется следующая конфигурация:

```nginx
location /app/ {
    proxy_pass http://127.0.0.1:5000/;
    proxy_set_header Host              $host;
    proxy_set_header X-Real-IP         $remote_addr;
    proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

Завершающий символ `/` в `proxy_pass` удаляет префикс `/app/`.
Например, запрос `/app/health` передаётся контейнеру как `/health`.

После изменения конфигурации выполняется проверка и перезагрузка Nginx:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

Проверка приложения с хоста macOS:

```bash
curl --cacert ~/devops.crt https://devops.local/app/
curl --cacert ~/devops.crt https://devops.local/app/health
curl --cacert ~/devops.crt -I https://devops.local/
```

Статический ресурс по адресу `https://devops.local/` должен продолжать
работать.

### 9.9. Диагностика

Проверка состояния контейнеров:

```bash
cd /home/devops/app
docker compose ps
```

Просмотр журналов приложения:

```bash
docker compose logs --tail=50 app
```

Просмотр журналов PostgreSQL:

```bash
docker compose logs --tail=50 db
```

Просмотр журнала ошибок Nginx:

```bash
sudo tail -n 20 /var/log/nginx/devops-site.error.log
```

Проверка локального доступа к приложению:

```bash
curl -i http://127.0.0.1:5000/health
curl -i http://127.0.0.1:5000/
```

Если Nginx возвращает `502 Bad Gateway`, необходимо проверить:

1. запущен ли контейнер `app`;
2. прослушивается ли адрес `127.0.0.1:5000`;
3. нет ли ошибок в журнале приложения;
4. правильно ли указан адрес `proxy_pass`;
5. нет ли записи `Connection refused` в журнале Nginx.

Для восстановления проекта после перезагрузки виртуальной машины:

```bash
cd /home/devops/app
docker compose up -d
docker compose ps
```
