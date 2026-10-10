# architecture-propdevelopment

Проектная работа 5 спринта курса «Архитектор ПО» (Яндекс Практикум). Кейс: компания PropDevelopment, один из крупнейших застройщиков, готовится к комплексному аудиту безопасности. Нужно описать данные и риски, подготовить проверочные листы, спроектировать новые интеграции и настроить защиту в Kubernetes.

Каждое задание лежит в своей папке. В каждой папке есть свои пояснения.

## Содержание

| Папка | Задание | Что внутри |
|---|---|---|
| [Task1](Task1) | Проверочный лист по безопасности данных | Классификация данных по ISO 27001/27002 (публичные, внутренние, конфиденциальные, секретные), по 5 рисков на категорию с оценкой и обоснованием. Схема-mindmap |
| [Task2](Task2) | Проверочный лист для бизнес-систем | Проверочный лист безопасности в Markdown по шаблону ИБ: выбранные разделы, обоснование выбора, заполненные поля |
| [Task3](Task3) | Внешние интеграции: интеллектуальный домофон и шлагбаум | Диаграмма контекста и обновлённая диаграмма контейнеров (C4), список требований: безопасность, аутентификация и авторизация, взаимодействие с платформой партнёра |
| [Task4](Task4) | Защита доступа к кластеру Kubernetes | Таблица ролей, скрипты создания пользователей, ролей и привязок (RBAC), скрипт проверки прав |
| [Task5](Task5) | Управление трафиком внутри кластера Kubernetes | Четыре сервиса на Nginx, сетевые политики (NetworkPolicy), скрипты развёртывания и проверки |

## Файлы по заданиям

### Task1. Безопасность данных
- [README.md](Task1/README.md): классификация, риски, оценки, обоснования
- [data-security-mindmap.drawio](Task1/data-security-mindmap.drawio), [data-security-mindmap.png](Task1/data-security-mindmap.png): mindmap «Безопасность данных»

### Task2. Проверочный лист
- [checklist.md](Task2/checklist.md): проверочный лист (разделы: управление доступом, безопасность данных, защита инфраструктуры, управление инцидентами, общие вопросы, оборудование и физическая безопасность), с обоснованием выбора разделов

### Task3. Внешние интеграции
- [context-diagram.drawio](Task3/context-diagram.drawio), [PNG](Task3/context-diagram.png): диаграмма контекста
- [container-diagram-updated.drawio](Task3/container-diagram-updated.drawio), [PNG](Task3/container-diagram-updated.png): диаграмма контейнеров, новые и изменённые элементы с зелёной обводкой
- [requirements.md](Task3/requirements.md): требования и ключевые решения

### Task4. RBAC в Kubernetes
- [roles-table.md](Task4/roles-table.md): роли, права, группы пользователей
- [01-create-users.sh](Task4/01-create-users.sh), [02-create-roles.sh](Task4/02-create-roles.sh), [03-bind-roles.sh](Task4/03-bind-roles.sh): пользователи, роли, привязки
- [04-verify-access.sh](Task4/04-verify-access.sh): проверка выданных прав
- [README.md](Task4/README.md): порядок запуска

### Task5. Сетевые политики
- [00-default-deny.yaml](Task5/00-default-deny.yaml): запрет всего трафика и разрешение DNS
- [non-admin-api-allow.yaml](Task5/non-admin-api-allow.yaml), [admin-api-allow.yaml](Task5/admin-api-allow.yaml): разрешённые пары сервисов
- [01-deploy-services.sh](Task5/01-deploy-services.sh), [02-test-traffic.sh](Task5/02-test-traffic.sh): развёртывание и проверка
- [README.md](Task5/README.md): порядок запуска

## Как запускать задания 4 и 5

Нужны Docker, Minikube, kubectl и Bash (на Windows: Git Bash или WSL, скрипты `.sh` в PowerShell не запускаются).

```bash
# Задание 4: обычный Minikube
minikube start --driver=docker
cd Task4
./02-create-roles.sh && ./03-bind-roles.sh && ./01-create-users.sh && ./04-verify-access.sh

# Задание 5: отдельный кластер с поддержкой сетевых политик (Cilium)
minikube start -p netpol --driver=docker --cni=cilium
kubectl config use-context netpol
cd ../Task5
./01-deploy-services.sh
kubectl apply -f 00-default-deny.yaml -f non-admin-api-allow.yaml -f admin-api-allow.yaml
./02-test-traffic.sh
```

Подробности и ручная проверка: в README каждой папки.

## Замечания

- Ссылки на законы (152-ФЗ и другие) и числовые значения (сроки токенов, хранения, доступности) в Task1–Task3 даны как рекомендуемые, их нужно согласовать с юристами и бизнесом.
- PNG диаграмм в Task1 и Task3 сделаны приближённой отрисовкой; точный экспорт получается из файлов `.drawio` в [draw.io](https://app.diagrams.net) (File, Export as, PNG).
- Закрытые ключи пользователей Kubernetes (создаются в `~/.propdevelopment-k8s-users`) в репозиторий не добавлять.
