#!/usr/bin/env bash
# Задание 5, проверка. Для каждой пары «откуда -> куда» делаем запрос и сравниваем с ожиданием.
# «Откуда» — временные поды-пробы с нужной меткой role (они подчиняются тем же политикам, что и сервисы),
# плюс проба без метки («посторонний» под).
set -uo pipefail
NS=traffic-demo
ROLES=(front-end back-end-api admin-front-end admin-back-end-api)

# пары, между которыми трафик разрешён (в обе стороны)
allowed() {
  case "$1>$2" in
    front-end\>back-end-api|back-end-api\>front-end|\
    admin-front-end\>admin-back-end-api|admin-back-end-api\>admin-front-end) return 0;;
    *) return 1;;
  esac
}

cleanup() { kubectl -n "$NS" delete pod -l probe=true --now --ignore-not-found >/dev/null 2>&1; }
trap cleanup EXIT

echo "Создаём поды-пробы..."
for r in "${ROLES[@]}"; do
  kubectl -n "$NS" run "probe-$r" --image=alpine --labels "role=$r,probe=true" --restart=Never -- sleep 3600 >/dev/null
done
kubectl -n "$NS" run probe-none --image=alpine --labels "probe=true" --restart=Never -- sleep 3600 >/dev/null
kubectl -n "$NS" wait --for=condition=Ready pod -l probe=true --timeout=180s >/dev/null || { echo "Пробы не запустились" >&2; exit 2; }

fail=0
try() {  # try <имя_пробы> <метка_источника> <роль_цели>
  local probe="$1" src="$2" dst="$3" want got
  if [ "$src" != "none" ] && allowed "$src" "$dst"; then want="доступ"; else want="блок"; fi
  if kubectl -n "$NS" exec "$probe" -- wget -q -O /dev/null -T 3 "http://${dst}-app" >/dev/null 2>&1; then got="доступ"; else got="блок"; fi
  if [ "$got" = "$want" ]; then printf 'OK     %-20s -> %-20s %s\n' "$src" "$dst" "$got"
  else printf 'ОШИБКА %-20s -> %-20s получили: %s, ожидали: %s\n' "$src" "$dst" "$got" "$want"; fail=1; fi
}

for s in "${ROLES[@]}"; do for d in "${ROLES[@]}"; do
  [ "$s" = "$d" ] && continue
  try "probe-$s" "$s" "$d"
done; done
for d in "${ROLES[@]}"; do try probe-none none "$d"; done

[ "$fail" -eq 0 ] && echo "Все проверки пройдены" || { echo "Есть расхождения. Проверьте, что в кластере включён CNI с поддержкой NetworkPolicy (см. README)"; exit 1; }
