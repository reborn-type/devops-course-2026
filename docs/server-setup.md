# Конфигурация сервера devops-vm

## 8. Веб-сервер

На сервере установлен веб-сервер Nginx:

```bash
sudo apt update
sudo apt install -y nginx

Основной файл конфигурации ресурса: 

/etc/nginx/sites-available/devops-site


Ресурс активирован символической ссылкой:

/etc/nginx/sites-enabled/devops-site



Стандартный ресурс Nginx отключён удалением ссылки:

sudo rm /etc/nginx/sites-enabled/default



Конфигурация проверяется и применяется командами:

sudo nginx -t
sudo systemctl reload nginx


Запросы по HTTP на порту 80 перенаправляются на HTTPS с кодом 301. Ресурс по HTTPS обслуживается на порту 443.


Каталог опубликованного ресурса:

/var/www/devops-site


Владелец каталога и файлов:

devops:devops


Права доступа: 
- Каталоги - `755`;
- Файлы - `644`;
- Пользователь Nginx `www-data` может читать ресурс, но не может его изменять. 


Самоподписный сертификат расположен по пути: 

/etc/ssl/certs/devops.crt

Сертификат имеет права `644` и является открытой частью ключевой пары.


Закрытый ключ расположен по пути:

/etc/ssl/private/devops.key

Закрытый ключ принадлежит пользователю `root`, имеет права `600` и не копируется за пределы `/etc/ssl/private`.


Сертификат и ключ сформированы командой:

```Bash
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/devops.key \
  -out /etc/ssl/certs/devops.crt \
  -subj "/CN=devops.local" \
  -addext "subjectAltName=DNS:devops.local"


Срок действия сертификата — 365 дней. Имя ресурса указано в расширении Subject Alternative Name:

DNS:devops.local


Проверка сертификата:

```Bash
openssl x509 -in /etc/ssl/certs/devops.crt \
  -noout -subject -issuer -dates -ext subjectAltName


Проверка прав ключа и сертификата:

```Bash
sudo ls -l /etc/ssl/private/devops.key \
  /etc/ssl/certs/devops.crt



