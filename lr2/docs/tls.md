# ЛР2 — HTTPS района 8 (Городской SOC)

**Команда:** 8 · **Район:** 8 — Городской SOC (`soc.city.lab`) · **Дата:** 24.10.2026

## 1. Вывод check-tls.sh

```text
$ ./scripts/check-tls.sh soc
1. HTTPS с проверкой по корню города
  [ OK ] https://soc.city.lab:8443/health отвечает, сертификат проверен
2. Без корня города клиент обязан отказаться (сертификат не из публичного УЦ)
  [ OK ] без city-root.crt — отказ (так и должно быть)
3. Чужое имя не подходит к сертификату
  [ OK ] evil.city.lab — отказ
4. Старые версии TLS выключены
  [ OK ] TLS 1.1 отклонён
       согласовано: New, TLSv1.3, Cipher is TLS_AES_128_GCM_SHA256
5. Цепочка: сервер отдаёт сертификат района и выпускающего УЦ
  [ OK ] в цепочке 2 сертификата
6. Заголовок HSTS
  [ OK ] Strict-Transport-Security есть
7. HTTP перенаправляет на HTTPS
  [ OK ] HTTP → 301 https://soc.city.lab:8443/health

Итог: пройдено 7, ошибок 0
```

## 2. Сертификат района

```text
$ openssl x509 -in tls/district.crt -noout -subject -issuer -dates -ext subjectAltName,keyUsage,extendedKeyUsage
subject=O = Digital City, OU = soc, CN = soc.city.lab
issuer=O = Digital City, CN = Digital City Issuing CA 1
notBefore=Oct 24 10:51:32 2026 GMT
notAfter=Jan 22 10:51:32 2027 GMT
X509v3 Key Usage: critical
    Digital Signature
X509v3 Extended Key Usage:
    TLS Web Server Authentication, TLS Web Client Authentication
X509v3 Subject Alternative Name:
    DNS:soc.city.lab, DNS:api.soc.city.lab
```

- Срок — 90 дней (24.10.2026 — 22.01.2027), назначение — только TLS-сервер/клиент, не УЦ.
- `district.crt` содержит 2 сертификата: сертификат района и Digital City Issuing CA 1; цепочка до корня проверена (`openssl verify` — OK).
- Сертификат выпущен на наш ключ: SHA-256 открытого ключа из `district.crt` и из `tls/private/district.key` совпадают (`2e2e91c1111e49ef…`).
- Второе имя `api.soc.city.lab` включено в SAN (бонус).

## 3. Сверка корня и запроса

- Отпечаток SHA-256 корня `city-root.crt`: `19:2D:38:FB:26:B6:07:ED:7D:45:6B:ED:D8:F7:4F:9D:E0:7F:67:FC:6E:31:79:A1:53:04:00:41:11:7B:F5:12`.
  Сверили первые 16 символов (`192D38FB26B607ED`) с тимлидом Паспортного стола Руденко Никитой Витальевичем голосом по телефону, 24.10.2026 в 20:30. Совпал.
- Отпечаток нашего запроса — `95bc3d2a41b833c5`. По ошибке он был отправлен в тот же чат, что и `district.csr`; после этого продиктован тимлиду Паспортного стола голосом по телефону 24.10.2026 в 20:30 (тот же звонок) и совпал с отпечатком, который показал скрипт УЦ. Вывод для команды: отпечаток в том же чате ничего не доказывает — посредник, подменивший файл, подменил бы и отпечаток; значение имеет только второй канал.
- Корень ограничен именами `city.lab` / `*.city.lab` (Name Constraints) и `pathlen:1`; выпускающий УЦ — `pathlen:0`.

### Изменение в compose.tls.yaml
Контейнер `tls` не запускался: `exec /usr/bin/caddy: operation not permitted`. Причина — бинарнику `caddy` в образе `caddy:2.8-alpine` выдана файловая capability `cap_net_bind_service`, а `cap_drop: [ALL]` убирает её из ограничивающего набора, и ядро запрещает запуск. Исправление — `cap_add: [NET_BIND_SERVICE]`; остальные capabilities по-прежнему сброшены, `no-new-privileges` и `read_only` сохранены.

## 4. Задание района 8
- Сбор журналов v0: [soc/merge_logs.py](../soc/merge_logs.py), отчёт — [soc-logs-v0.md](soc-logs-v0.md)
- Разбор журнала выпусков УЦ: [soc/registry_report.py](../soc/registry_report.py), отчёт — там же

## 5. Ответы на вопросы
<раздел от Ярослава: tls-answers.md>
