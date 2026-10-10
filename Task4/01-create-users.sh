#!/usr/bin/env bash
# Задание 4, п. 3. Создание пользователей Kubernetes (Minikube).
#
# Как это работает (простыми словами): в Kubernetes нет «базы пользователей».
# Пользователь — это клиентский сертификат, подписанный центром сертификации кластера.
# Имя пользователя берётся из поля CN сертификата, группы — из полей O.
# Права выдаются не пользователю, а группе (см. 03-bind-roles.sh).
#
# Запуск: ./01-create-users.sh   (нужны kubectl, openssl, доступ администратора к кластеру)
# Результат: для каждого пользователя файл $OUT_DIR/<имя>.kubeconfig (ключ и сертификат внутри).
# ВАЖНО: каталог с ключами не коммитить в Git.
set -euo pipefail

# Windows: запускать в Git Bash или WSL, при запущенном Docker Desktop и Minikube

OUT_DIR="${OUT_DIR:-$HOME/.propdevelopment-k8s-users}"
CERT_TTL_SECONDS="${CERT_TTL_SECONDS:-2592000}"   # срок жизни сертификата: 30 суток, потом выпустить заново

# Формат: "имя-пользователя:группа1,группа2"
USERS=(
  "anna-sales-dev:sales-developers"          # разработчик домена «Продажи»
  "oleg-sales-analyst:sales-viewers"         # бизнес-аналитик домена «Продажи»
  "boris-housing-viewer:housing-viewers"     # менеджер операционной команды домена «ЖКУ»
  "dmitry-finance-ops:finance-ops"           # инженер по эксплуатации домена «Финансы»
  "ivan-devops:platform-devops"              # DevOps-инженер (настройка кластера)
  "elena-security:security-auditors"         # специалист по ИБ
)

for cmd in kubectl openssl base64; do
  command -v "$cmd" >/dev/null || { echo "Не найден инструмент: $cmd" >&2; exit 1; }
done

# Остановиться сразу, если кластер недоступен
kubectl cluster-info >/dev/null 2>&1 || { echo "Кластер недоступен. Запустите Docker Desktop и 'minikube start --driver=docker', затем проверьте 'kubectl get nodes'." >&2; exit 1; }

umask 077
mkdir -p "$OUT_DIR"
chmod 700 "$OUT_DIR"

# Адрес API-сервера и сертификат центра сертификации берём из текущего kubeconfig администратора
SERVER="$(kubectl config view --minify --flatten -o jsonpath='{.clusters[0].cluster.server}')"
CA_FILE="$(mktemp)"
trap 'rm -f "$CA_FILE"' EXIT
kubectl config view --minify --flatten -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' \
  | base64 -d > "$CA_FILE"

for entry in "${USERS[@]}"; do
  user="${entry%%:*}"
  groups="${entry#*:}"
  csr_name="pd-user-${user}"
  echo "==> Пользователь ${user} (группы: ${groups})"

  # 1. Закрытый ключ и запрос на сертификат. Группы кладём в поля O
  subj="/CN=${user}"
  IFS=',' read -ra group_list <<< "$groups"
  for g in "${group_list[@]}"; do subj+="/O=${g}"; done
  openssl genrsa -out "${OUT_DIR}/${user}.key" 2048 2>/dev/null
  # MSYS2_ARG_CONV_EXCL: в Git Bash на Windows не даёт превратить "/CN=..." в путь к файлу
  # (остальные пути при этом преобразуются как обычно)
  MSYS2_ARG_CONV_EXCL="/CN=" openssl req -new -key "${OUT_DIR}/${user}.key" -subj "$subj" -out "${OUT_DIR}/${user}.csr"

  # 2. Отправляем запрос в кластер и подтверждаем его (запрос неизменяем, поэтому старый удаляем)
  kubectl delete csr "$csr_name" --ignore-not-found >/dev/null
  kubectl apply -f - <<YAML
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: ${csr_name}
spec:
  request: $(base64 -w0 < "${OUT_DIR}/${user}.csr")
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: ${CERT_TTL_SECONDS}
  usages:
    - client auth
YAML
  kubectl certificate approve "$csr_name" >/dev/null

  # 3. Ждём выдачи сертификата (до 30 секунд)
  cert_b64=""
  for _ in $(seq 1 30); do
    cert_b64="$(kubectl get csr "$csr_name" -o jsonpath='{.status.certificate}')"
    [ -n "$cert_b64" ] && break
    sleep 1
  done
  [ -n "$cert_b64" ] || { echo "Сертификат для ${user} не выдан" >&2; exit 1; }
  echo "$cert_b64" | base64 -d > "${OUT_DIR}/${user}.crt"

  # 4. Собираем отдельный kubeconfig, чтобы не трогать конфигурацию администратора
  cfg="${OUT_DIR}/${user}.kubeconfig"
  rm -f "$cfg"
  kubectl config --kubeconfig="$cfg" set-cluster propdevelopment \
    --server="$SERVER" --certificate-authority="$CA_FILE" --embed-certs=true >/dev/null
  kubectl config --kubeconfig="$cfg" set-credentials "$user" \
    --client-certificate="${OUT_DIR}/${user}.crt" --client-key="${OUT_DIR}/${user}.key" \
    --embed-certs=true >/dev/null
  kubectl config --kubeconfig="$cfg" set-context "${user}@propdevelopment" \
    --cluster=propdevelopment --user="$user" >/dev/null
  kubectl config --kubeconfig="$cfg" use-context "${user}@propdevelopment" >/dev/null

  kubectl delete csr "$csr_name" >/dev/null   # запрос больше не нужен
  rm -f "${OUT_DIR}/${user}.csr"
done

echo
echo "Готово. Файлы доступа: ${OUT_DIR}/*.kubeconfig"
echo "Проверка: KUBECONFIG=${OUT_DIR}/ivan-devops.kubeconfig kubectl auth whoami"
