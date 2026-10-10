# Задание 5. Управление трафиком внутри кластера Kubernetes

## Что сделано

В пространстве имён `traffic-demo` развёрнуты четыре сервиса на Nginx. Роль каждого записана в метке `role`:

| Под / служба | Метка `role` |
|---|---|
| `front-end-app` | `front-end` |
| `back-end-api-app` | `back-end-api` |
| `admin-front-end-app` | `admin-front-end` |
| `admin-back-end-api-app` | `admin-back-end-api` |

Сетевые политики:

| Файл | Что делает |
|---|---|
| `00-default-deny.yaml` | Запрещает в пространстве имён весь входящий и исходящий трафик подов. Отдельно разрешает подам обращаться к DNS кластера, иначе нельзя обратиться к службе по имени |
| `non-admin-api-allow.yaml` | Разрешает трафик в обе стороны (порт 80) между `front-end` и `back-end-api` |
| `admin-api-allow.yaml` | Разрешает трафик в обе стороны (порт 80) между `admin-front-end` и `admin-back-end-api` |

Итог: каждая пара общается только внутри себя. `front-end` не достучится до `admin-back-end-api` и наоборот, а посторонний под (без метки) не достучится ни до одного из четырёх сервисов.

Как это работает: политика «запретить всё» закрывает всё, а остальные политики открывают конкретные проходы. Для связи нужно разрешение на стороне отправителя (egress) и на стороне получателя (ingress), поэтому в каждой политике есть оба раздела.

## Важно: нужен кластер с поддержкой сетевых политик

Стандартный Minikube может принимать политики, но **не применять** их, тогда проверка покажет «доступ» везде. Для задания использован отдельный кластер с сетевым модулем Cilium:

```bash
minikube start -p netpol --driver=docker --cni=cilium
kubectl config use-context netpol
kubectl get pods -n kube-system        # поды cilium-* и coredns должны быть в состоянии Running
```

Calico (`--cni=calico`) на Docker Desktop для Windows не запустился: `calico-node` падает с ошибкой «failed to mkdir /sys/kernel/security: read-only file system». Поэтому выбран Cilium.

Обратно к кластеру из Задания 4: `kubectl config use-context minikube`.

## Запуск

```bash
./01-deploy-services.sh                 # четыре сервиса
kubectl apply -f 00-default-deny.yaml
kubectl apply -f non-admin-api-allow.yaml
kubectl apply -f admin-api-allow.yaml
./02-test-traffic.sh                    # проверка всех пар
```

Ручная проверка, как в задании. Имя пода задаём вручную (в PowerShell переменной `$RANDOM` нет; в bash можно `test-$RANDOM`, в PowerShell `"test-$(Get-Random)"`):

```bash
# от имени front-end (разрешено только back-end-api)
kubectl run test-front -n traffic-demo --rm -i -t --image=alpine --labels role=front-end -- sh
/ # wget -qO- --timeout=2 http://back-end-api-app           # ответ nginx
/ # wget -qO- --timeout=2 http://admin-back-end-api-app     # таймаут
/ # exit

# посторонний под без метки: везде таймаут
kubectl run test-other -n traffic-demo --rm -i -t --image=alpine -- sh
/ # wget -qO- --timeout=2 http://front-end-app
/ # exit
```

Метку `--labels role=...` в тестовом поде задавать нужно: политики смотрят на метки, и без неё под считается посторонним.

Очистка: `kubectl delete namespace traffic-demo`.
