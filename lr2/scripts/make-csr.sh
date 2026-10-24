#!/usr/bin/env bash
# Создаёт закрытый ключ района и запрос на сертификат (CSR) для городского УЦ.
#   ./scripts/make-csr.sh КОД_РАЙОНА [доп. имя ...]
#   пример: ./scripts/make-csr.sh bank api.bank.city.lab
# Ключ остаётся у вас (tls/private/district.key) и НИКУДА не отправляется.
# Паспортному столу отправляется только tls/district.csr, а отпечаток называется голосом.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ $# -ge 1 ]] || { echo "использование: $0 КОД_РАЙОНА [доп. имя ...]" >&2; exit 1; }
CODE="$1"; shift
NAMES="DNS:$CODE.city.lab"
for n in "$@"; do NAMES+=",DNS:$n"; done

mkdir -p tls/private
chmod 700 tls/private
if [[ -f tls/private/district.key ]]; then
  echo "Ключ tls/private/district.key уже есть — используем его (новый ключ: удалите файл вручную)."
else
  (umask 077; openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out tls/private/district.key)
fi
openssl req -new -sha256 -key tls/private/district.key \
  -subj "/O=Digital City/OU=$CODE/CN=$CODE.city.lab" \
  -addext "subjectAltName=$NAMES" -out tls/district.csr

FP=$(openssl req -in tls/district.csr -outform DER | sha256sum | cut -c1-16)
echo
echo "Запрос: tls/district.csr  (имена: $NAMES)"
echo "Отпечаток запроса: $FP"
echo "1) Отправьте tls/district.csr Паспортному столу (в чат или архивом)."
echo "2) Отпечаток назовите тимлиду Паспортного стола ГОЛОСОМ на паре или по видеосвязи — не в том же чате."
echo "3) В ответ получите district.crt и city-root.crt — положите их в папку tls/."
