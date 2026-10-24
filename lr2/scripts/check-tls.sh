#!/usr/bin/env bash
# Проверяет HTTPS района: цепочка до корня города, имя, версии TLS, перенаправление с HTTP.
#   ./scripts/check-tls.sh КОД_РАЙОНА [порт HTTPS, по умолчанию 8443] [порт HTTP, по умолчанию 8081]
# Имя района подставляется через --resolve, поэтому файл hosts и DNS не нужны.
set -uo pipefail
cd "$(dirname "$0")/.."
CODE="$1"; PORT="${2:-8443}"; HPORT="${3:-8081}"
HOST="$CODE.city.lab"
ROOT=tls/city-root.crt
ok=0; bad=0
pass() { echo "  [ OK ] $*"; ok=$((ok+1)); }
fail() { echo "  [FAIL] $*"; bad=$((bad+1)); }

echo "1. HTTPS с проверкой по корню города"
if curl -sS --fail --cacert "$ROOT" --resolve "$HOST:$PORT:127.0.0.1" "https://$HOST:$PORT/health" -o /dev/null; then
  pass "https://$HOST:$PORT/health отвечает, сертификат проверен"
else
  fail "HTTPS не работает или сертификат не проходит проверку"
fi

echo "2. Без корня города клиент обязан отказаться (сертификат не из публичного УЦ)"
if curl -sS --resolve "$HOST:$PORT:127.0.0.1" "https://$HOST:$PORT/health" -o /dev/null 2>/dev/null; then
  fail "соединение прошло без city-root.crt — проверьте, что Caddy использует ваш сертификат"
else
  pass "без city-root.crt — отказ (так и должно быть)"
fi

echo "3. Чужое имя не подходит к сертификату"
if curl -sS --cacert "$ROOT" --resolve "evil.city.lab:$PORT:127.0.0.1" "https://evil.city.lab:$PORT/health" -o /dev/null 2>/dev/null; then
  fail "сертификат подошёл к evil.city.lab"
else
  pass "evil.city.lab — отказ"
fi

echo "4. Старые версии TLS выключены"
if openssl s_client -connect "127.0.0.1:$PORT" -servername "$HOST" -tls1_1 -cipher "DEFAULT@SECLEVEL=0" </dev/null >/dev/null 2>&1; then
  fail "TLS 1.1 принимается"
else
  pass "TLS 1.1 отклонён"
fi
PROTO=$(openssl s_client -connect "127.0.0.1:$PORT" -servername "$HOST" -CAfile "$ROOT" </dev/null 2>/dev/null | grep -E "^ *Protocol *:|New, TLS" | head -1)
echo "       согласовано: ${PROTO:-не удалось узнать}"

echo "5. Цепочка: сервер отдаёт сертификат района и выпускающего УЦ"
DEPTH=$(openssl s_client -connect "127.0.0.1:$PORT" -servername "$HOST" -showcerts </dev/null 2>/dev/null | grep -c "BEGIN CERTIFICATE")
if [[ "$DEPTH" -ge 2 ]]; then pass "в цепочке $DEPTH сертификата"; else fail "сервер отдаёт $DEPTH сертификат — нужен district.crt с цепочкой"; fi

echo "6. Заголовок HSTS"
if curl -sS -D - -o /dev/null --cacert "$ROOT" --resolve "$HOST:$PORT:127.0.0.1" "https://$HOST:$PORT/health" | grep -qi "strict-transport-security"; then
  pass "Strict-Transport-Security есть"
else
  fail "нет Strict-Transport-Security"
fi

echo "7. HTTP перенаправляет на HTTPS"
LOC=$(curl -sS -o /dev/null -w "%{http_code} %{redirect_url}" --resolve "$HOST:$HPORT:127.0.0.1" "http://$HOST:$HPORT/health" 2>/dev/null)
if [[ "$LOC" == 30[18]\ https://* ]]; then pass "HTTP → $LOC"; else fail "HTTP не перенаправляет на HTTPS ($LOC)"; fi

echo
echo "Итог: пройдено $ok, ошибок $bad"
[[ $bad -eq 0 ]]
