# Задание 4. Защита доступа к кластеру Kubernetes

Файлы:

| Файл | Назначение |
|---|---|
| `roles-table.md` | Таблица ролей, полномочий и групп |
| `01-create-users.sh` | Создание пользователей (клиентские сертификаты) |
| `02-create-roles.sh` | Создание пространств имён и ролей |
| `03-bind-roles.sh` | Привязка групп к ролям |
| `04-verify-access.sh` | Дополнительно: проверка выданных прав |

## Запуск

```bash
minikube start --driver=docker          # пустой кластер
./02-create-roles.sh                    # роли и пространства имён
./03-bind-roles.sh                      # привязки групп к ролям
./01-create-users.sh                    # пользователи (файлы доступа в ~/.propdevelopment-k8s-users)
./04-verify-access.sh                   # проверка
```

Те же команды в Windows PowerShell (скрипты `.sh` запускать в Git Bash или WSL):

```powershell
kubectl --kubeconfig "$HOME\.propdevelopment-k8s-users\anna-sales-dev.kubeconfig" get secrets -n sales
kubectl --kubeconfig "$HOME\.propdevelopment-k8s-users\anna-sales-dev.kubeconfig" get pods -n finance
```

Порядок скриптов задания (пользователи → роли → привязки) тоже работает: права появляются после привязки.
Скрипты можно запускать повторно, они ничего не дублируют.
Каталог с ключами пользователей в Git не добавлять.
