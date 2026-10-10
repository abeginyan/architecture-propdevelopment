#!/usr/bin/env bash
# Дополнительно: проверка, что права работают так, как задумано (запускать от администратора).
# Использует «выдачу себя за пользователя» (--as/--as-group), поэтому сертификаты не нужны.
set -uo pipefail
fail=0
# Предварительная проверка: кластер доступен и администратор может «выдавать себя» за пользователя
if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "kubectl не видит кластер. Запустите minikube и проверьте: kubectl config current-context" >&2; exit 2
fi
pre="$(kubectl auth can-i get pods -n default --as=probe --as-group=probe 2>&1 | tr -d '\r')"
case "$pre" in yes|no) ;; *) echo "Не удалось проверить права. Ответ kubectl:" >&2; echo "$pre" >&2
  echo "Запускайте скрипт от администратора кластера (контекст minikube)." >&2; exit 2;; esac

check() {  # check <ожидание yes|no> <пользователь> <группа> <аргументы can-i...>
  local want="$1" user="$2" group="$3"; shift 3
  local out got
  out="$(kubectl auth can-i "$@" --as="$user" --as-group="$group" 2>&1 | tr -d '\r')"
  got="$(printf '%s\n' "$out" | tail -n1)"
  if [ "$got" = "$want" ]; then printf 'OK    %-22s %s -> %s\n' "$user" "$*" "$got"
  else printf 'ОШИБКА %-21s %s -> %s (ожидали %s)\n' "$user" "$*" "${out:-пусто}" "$want"; fail=1; fi
}
# разработчик «Продаж»
check yes anna-sales-dev sales-developers create deployments -n sales
check no  anna-sales-dev sales-developers get secrets -n sales
check no  anna-sales-dev sales-developers get pods -n finance
check no  anna-sales-dev sales-developers create rolebindings -n sales
# аналитик «Продаж» (просмотр)
check yes oleg-sales-analyst sales-viewers list pods -n sales
check no  oleg-sales-analyst sales-viewers delete pods -n sales
# менеджер «ЖКУ» видит и «Умный дом»
check yes boris-housing-viewer housing-viewers list pods -n smart-home
check no  boris-housing-viewer housing-viewers create deployments -n housing
# инженер по эксплуатации «Финансов»
check yes dmitry-finance-ops finance-ops get secrets -n finance
check yes dmitry-finance-ops finance-ops create pods --subresource=exec -n finance
check no  dmitry-finance-ops finance-ops get secrets -n sales
check no  dmitry-finance-ops finance-ops create deployments -n finance
# DevOps
check yes ivan-devops platform-devops create namespaces
check yes ivan-devops platform-devops create secrets -n sales
check no  ivan-devops platform-devops get secrets -n sales
check no  ivan-devops platform-devops create clusterrolebindings
# ИБ
check yes elena-security security-auditors get secrets -n sales
check yes elena-security security-auditors list clusterrolebindings
check no  elena-security security-auditors create deployments -n sales
check no  elena-security security-auditors delete secrets -n sales
[ "$fail" -eq 0 ] && echo "Все проверки пройдены" || { echo "Есть расхождения"; exit 1; }
