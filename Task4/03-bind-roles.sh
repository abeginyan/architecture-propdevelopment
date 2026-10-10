#!/usr/bin/env bash
# Задание 4, п. 5. Связывание групп пользователей с ролями.
#
# RoleBinding      — выдаёт роль группе в ОДНОМ пространстве имён (домене).
# ClusterRoleBinding — выдаёт роль группе во ВСЁМ кластере (только DevOps и ИБ).
#
# Группы в домене: <домен>-viewers   -> pd-viewer
#                  <домен>-developers -> pd-developer
#                  <домен>-ops        -> pd-ops-engineer
set -euo pipefail

command -v kubectl >/dev/null || { echo "Не найден kubectl" >&2; exit 1; }

# Остановиться сразу, если кластер недоступен
kubectl cluster-info >/dev/null 2>&1 || { echo "Кластер недоступен. Запустите Docker Desktop и 'minikube start --driver=docker', затем проверьте 'kubectl get nodes'." >&2; exit 1; }

# Формат "пространство_имён:префикс_групп". Сервисы «Умный дом» принадлежат домену ЖКУ.
DOMAINS=(sales:sales housing:housing finance:finance data:data smart-home:housing)

bind() {  # bind <namespace> <имя> <роль> <группа>
  kubectl apply -f - <<YAML
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: $2
  namespace: $1
  labels: {propdevelopment.io/managed: "true"}
subjects:
  - kind: Group
    name: $4
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: $3
  apiGroup: rbac.authorization.k8s.io
YAML
}

for entry in "${DOMAINS[@]}"; do
  ns="${entry%%:*}"; prefix="${entry#*:}"
  bind "$ns" "${prefix}-viewers"    pd-viewer        "${prefix}-viewers"
  bind "$ns" "${prefix}-developers" pd-developer     "${prefix}-developers"
  bind "$ns" "${prefix}-ops"        pd-ops-engineer  "${prefix}-ops"
done

# Права на весь кластер
kubectl apply -f - <<'YAML'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: platform-devops-configurator
  labels: {propdevelopment.io/managed: "true"}
subjects:
  - kind: Group
    name: platform-devops
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: pd-cluster-configurator
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: security-auditors-auditor
  labels: {propdevelopment.io/managed: "true"}
subjects:
  - kind: Group
    name: security-auditors
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: pd-security-auditor
  apiGroup: rbac.authorization.k8s.io
YAML

echo "Привязки созданы:"
kubectl get rolebinding -A -l propdevelopment.io/managed=true
kubectl get clusterrolebinding -l propdevelopment.io/managed=true
