#!/usr/bin/env bash
set -euo pipefail

REMOTE="devops"
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"

REPO_ROOT="$(git rev-parse --show-toplevel)"
LOCAL_DIR="${REPO_ROOT}/site/"

case "${1:-}" in
  "")
    DRY_RUN=false
    ;;
  --dry-run)
    DRY_RUN=true
    ;;
  *)
    echo "Использование: scripts/deploy.sh [--dry-run]" >&2
    exit 1
    ;;
esac

if [[ ! -f "${LOCAL_DIR}index.html" ]]; then
  echo "Ошибка: отсутствует site/index.html" >&2
  exit 1
fi

if [[ -n "$(git -C "${REPO_ROOT}" status --porcelain)" ]]; then
  echo "Ошибка: в репозитории есть незафиксированные изменения" >&2
  exit 1
fi

RSYNC_ARGS=(
  -avz
  --delete
  --chmod=D755,F644
  -e "ssh -o BatchMode=yes -o ConnectTimeout=5"
)

if [[ "${DRY_RUN}" == true ]]; then
  RSYNC_ARGS+=(--dry-run)
fi

rsync "${RSYNC_ARGS[@]}" \
  "${LOCAL_DIR}" "${REMOTE}:${REMOTE_DIR}/"

if [[ "${DRY_RUN}" == true ]]; then
  exit 0
fi

if ! curl -fsS --cacert "${CA_CERT}" "${SITE_URL}" > /dev/null; then
  echo "Ошибка: ресурс недоступен после деплоя" >&2
  exit 1
fi

echo "Доставлен коммит: $(git -C "${REPO_ROOT}" rev-parse --short HEAD)"
