#!/usr/bin/env bash
# Аудит конфигурации сервера devops-vm

set -uo pipefail

REMOTE="devops"
CERT_CHECK_SECONDS="${CERT_CHECK_SECONDS:-2592000}"

if [[ ! "${CERT_CHECK_SECONDS}" =~ ^[0-9]+$ ]]; then
    echo "Ошибка: CERT_CHECK_SECONDS должен быть целым числом" >&2
    exit 1
fi

ssh \
    -o BatchMode=yes \
    -o ConnectTimeout=5 \
    "${REMOTE}" \
    "CERT_CHECK_SECONDS=${CERT_CHECK_SECONDS} bash -s" <<'REMOTE_SCRIPT'

set -uo pipefail

FAILED=0

check() {
    local description="$1"
    shift

    local output
    local status

    if output="$("$@" 2>&1)"; then
        printf '[OK] %s\n' "${description}"

        if [[ -n "${output}" ]]; then
            printf '%s\n' "${output}"
        fi
    else
        status=$?
        printf '[FAIL] %s, код возврата %s\n' \
            "${description}" "${status}"

        if [[ -n "${output}" ]]; then
            printf '%s\n' "${output}"
        fi

        FAILED=$((FAILED + 1))
    fi
}

echo "[4] Веб-сервер"

check \
    "Служба nginx активна" \
    systemctl is-active nginx

check \
    "Конфигурация nginx синтаксически корректна" \
    sudo -n /usr/sbin/nginx -t

check \
    "Сертификат действует ещё не менее 30 дней" \
    openssl x509 \
        -checkend "${CERT_CHECK_SECONDS}" \
        -noout \
        -in /etc/ssl/certs/devops.crt

check \
    "Нет файлов с записью для всех, ключ имеет права 600" \
    bash -c '
        bad_files="$(find /var/www/devops-site -perm -o+w -print)"
        key_mode="$(sudo -n /usr/bin/stat -c "%a" /etc/ssl/private/devops.key)"

        printf "Файлы с правом записи для всех: %s\n" \
            "${bad_files:-нет}"
        printf "Права закрытого ключа: %s\n" \
            "${key_mode:-не определены}"

        test -z "${bad_files}" &&
        test "${key_mode}" = "600"
    '

if [[ "${FAILED}" -eq 0 ]]; then
    echo "Аудит успешно завершён"
    exit 0
else
    echo "Аудит завершён с ошибками: ${FAILED}"
    exit 1
fi

REMOTE_SCRIPT

SSH_STATUS=$?

if [[ "${SSH_STATUS}" -ne 0 ]]; then
    exit 1
fi

exit 0

