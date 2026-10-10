#!/usr/bin/env bash
# Задание 4, п. 4. Создание пространств имён и ролей (ClusterRole).
#
# Пространство имён (namespace) — «отдельная комната» в кластере. Каждому домену компании
# отведена своя комната, так права можно ограничить рамками домена.
# Роль (ClusterRole) — только набор разрешений. Кому они выданы и где — решает 03-bind-roles.sh.
#
# Принципы: наименьшие привилегии; чтение секретов — только у отдельных ролей; изменение прав доступа
# (RBAC) у DevOps отключено, чтобы права менялись только через согласование с ИБ.
set -euo pipefail

command -v kubectl >/dev/null || { echo "Не найден kubectl" >&2; exit 1; }

# Остановиться сразу, если кластер недоступен
kubectl cluster-info >/dev/null 2>&1 || { echo "Кластер недоступен. Запустите Docker Desktop и 'minikube start --driver=docker', затем проверьте 'kubectl get nodes'." >&2; exit 1; }

# ---------- Пространства имён по доменам ----------
for entry in sales:sales housing:housing finance:finance data:data smart-home:housing; do
  ns="${entry%%:*}"; domain="${entry#*:}"
  kubectl apply -f - <<YAML
apiVersion: v1
kind: Namespace
metadata:
  name: ${ns}
  labels:
    propdevelopment.io/domain: ${domain}
YAML
done

# ---------- 1. pd-viewer: только просмотр (без секретов) ----------
kubectl apply -f - <<'YAML'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pd-viewer
  labels: {propdevelopment.io/managed: "true"}
rules:
  - apiGroups: [""]
    resources: [pods, pods/log, services, endpoints, configmaps, persistentvolumeclaims, serviceaccounts, resourcequotas, events]
    verbs: [get, list, watch]
  - apiGroups: [apps]
    resources: [deployments, statefulsets, daemonsets, replicasets]
    verbs: [get, list, watch]
  - apiGroups: [batch]
    resources: [jobs, cronjobs]
    verbs: [get, list, watch]
  - apiGroups: [networking.k8s.io]
    resources: [ingresses, networkpolicies]
    verbs: [get, list, watch]
  - apiGroups: [autoscaling]
    resources: [horizontalpodautoscalers]
    verbs: [get, list, watch]
YAML

# ---------- 2. pd-developer: управление приложениями в своём домене (без секретов) ----------
kubectl apply -f - <<'YAML'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pd-developer
  labels: {propdevelopment.io/managed: "true"}
rules:
  # всё, что видит наблюдатель
  - apiGroups: [""]
    resources: [pods, pods/log, services, endpoints, configmaps, persistentvolumeclaims, serviceaccounts, resourcequotas, events]
    verbs: [get, list, watch]
  - apiGroups: [apps]
    resources: [deployments, statefulsets, daemonsets, replicasets]
    verbs: [get, list, watch]
  - apiGroups: [batch]
    resources: [jobs, cronjobs]
    verbs: [get, list, watch]
  - apiGroups: [networking.k8s.io]
    resources: [ingresses, networkpolicies]
    verbs: [get, list, watch]
  - apiGroups: [autoscaling]
    resources: [horizontalpodautoscalers]
    verbs: [get, list, watch]
  # плюс изменение приложений (но не сетевых политик, не прав и не секретов)
  - apiGroups: [""]
    resources: [services, configmaps, persistentvolumeclaims]
    verbs: [create, update, patch, delete]
  - apiGroups: [""]
    resources: [pods]
    verbs: [delete]                      # перезапуск пода
  - apiGroups: [apps]
    resources: [deployments, statefulsets]
    verbs: [create, update, patch, delete]
  - apiGroups: [batch]
    resources: [jobs, cronjobs]
    verbs: [create, update, patch, delete]
  - apiGroups: [networking.k8s.io]
    resources: [ingresses]
    verbs: [create, update, patch, delete]
  - apiGroups: [autoscaling]
    resources: [horizontalpodautoscalers]
    verbs: [create, update, patch, delete]
YAML

# ---------- 3. pd-ops-engineer: эксплуатация в своём домене, ПРИВИЛЕГИРОВАННО: секреты и вход в под ----------
kubectl apply -f - <<'YAML'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pd-ops-engineer
  labels: {propdevelopment.io/managed: "true"}
rules:
  - apiGroups: [""]
    resources: [pods, pods/log, services, endpoints, configmaps, persistentvolumeclaims, serviceaccounts, resourcequotas, events]
    verbs: [get, list, watch]
  - apiGroups: [apps]
    resources: [deployments, statefulsets, daemonsets, replicasets]
    verbs: [get, list, watch]
  - apiGroups: [batch]
    resources: [jobs, cronjobs]
    verbs: [get, list, watch]
  - apiGroups: [networking.k8s.io]
    resources: [ingresses, networkpolicies]
    verbs: [get, list, watch]
  - apiGroups: [autoscaling]
    resources: [horizontalpodautoscalers]
    verbs: [get, list, watch]
  # перезапуск и масштабирование
  - apiGroups: [""]
    resources: [pods]
    verbs: [delete]
  - apiGroups: [apps]
    resources: [deployments, statefulsets]
    verbs: [patch, update]
  - apiGroups: [apps]
    resources: [deployments/scale, statefulsets/scale]
    verbs: [get, update, patch]
  # привилегированные действия
  - apiGroups: [""]
    resources: [secrets]
    verbs: [get, list, watch]
  - apiGroups: [""]
    resources: [pods/exec, pods/portforward]
    verbs: [create]
YAML

# ---------- 4. pd-cluster-configurator: настройка кластера (DevOps) ----------
kubectl apply -f - <<'YAML'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pd-cluster-configurator
  labels: {propdevelopment.io/managed: "true"}
rules:
  # устройство кластера
  - apiGroups: [""]
    resources: [namespaces, resourcequotas, limitranges, persistentvolumes, serviceaccounts]
    verbs: [get, list, watch, create, update, patch, delete]
  - apiGroups: [""]
    resources: [nodes]
    verbs: [get, list, watch, patch]     # patch нужен для cordon/drain
  - apiGroups: [""]
    resources: [pods, pods/log, services, endpoints, configmaps, persistentvolumeclaims, events]
    verbs: [get, list, watch, create, update, patch, delete]
  - apiGroups: [apps, batch, autoscaling]
    resources: ["*"]
    verbs: [get, list, watch, create, update, patch, delete]
  - apiGroups: [networking.k8s.io]
    resources: [ingresses, ingressclasses, networkpolicies]
    verbs: [get, list, watch, create, update, patch, delete]
  - apiGroups: [storage.k8s.io]
    resources: [storageclasses]
    verbs: [get, list, watch, create, update, patch, delete]
  - apiGroups: [policy]
    resources: [poddisruptionbudgets]
    verbs: [get, list, watch, create, update, patch, delete]
  - apiGroups: [apiextensions.k8s.io]
    resources: [customresourcedefinitions]
    verbs: [get, list, watch, create, update, patch, delete]
  # секреты: можно записать и заменить, ПРОЧИТАТЬ нельзя (нет get/list/watch)
  - apiGroups: [""]
    resources: [secrets]
    verbs: [create, update, patch, delete]
  # права доступа: только смотреть. Менять их — через согласование с ИБ
  - apiGroups: [rbac.authorization.k8s.io]
    resources: [roles, rolebindings, clusterroles, clusterrolebindings]
    verbs: [get, list, watch]
YAML

# ---------- 5. pd-security-auditor: специалист по ИБ, ПРИВИЛЕГИРОВАННО: чтение всего, включая секреты ----------
kubectl apply -f - <<'YAML'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pd-security-auditor
  labels: {propdevelopment.io/managed: "true"}
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: [get, list, watch]            # только чтение, ничего изменить нельзя
  - nonResourceURLs: ["*"]
    verbs: [get]
YAML

echo "Роли созданы:"
kubectl get clusterrole -l propdevelopment.io/managed=true
