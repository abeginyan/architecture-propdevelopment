#!/usr/bin/env bash
# Задание 5, п. 1-2. Четыре сервиса на Nginx в одном пространстве имён, у каждого метка role.
set -euo pipefail
NS=traffic-demo

kubectl cluster-info >/dev/null 2>&1 || { echo "Кластер недоступен. Запустите Minikube." >&2; exit 1; }
kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create namespace "$NS"

for role in front-end back-end-api admin-front-end admin-back-end-api; do
  name="${role}-app"
  if kubectl -n "$NS" get pod "$name" >/dev/null 2>&1; then
    echo "$name уже есть, пропускаем"
    continue
  fi
  # role — метка роли из задания (по ней работают сетевые политики).
  # app — служебная метка: служба выбирает поды только по ней, чтобы тестовые поды с такой же ролью
  # не попадали в список адресатов службы.
  kubectl run "$name" -n "$NS" --image=nginx --labels "role=${role},app=${name}" --expose --port 80
  kubectl -n "$NS" patch svc "$name" --type=json \
    -p "[{\"op\":\"replace\",\"path\":\"/spec/selector\",\"value\":{\"app\":\"${name}\"}}]"
done

kubectl -n "$NS" wait --for=condition=Ready pod -l 'role in (front-end,back-end-api,admin-front-end,admin-back-end-api)' --timeout=180s
kubectl -n "$NS" get pods --show-labels
kubectl -n "$NS" get svc
