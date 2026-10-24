# События района 8 — Городской SOC

Формат конверта — CloudEvents 1.0 (соглашение Р5 «Архитектуры города»).
Тип события: `city.soc.объект.действие.vN`. Время — UTC.
В `data` и `subject` — только идентификаторы, не ФИО и не секреты.

## Публикуем

| Тип (`type`) | Когда | Кто получатель | Поля `data` (пример) |
|---|---|---|---|
| `city.soc.incident.opened.v1` | SOC открыл инцидент (правило корреляции, тревога другого района или слепая зона) | район, которого касается инцидент (поле `district`) | `incident_id`, `district`, `severity`, `category`, `rule_id`, `first_seen`, `request_ids` |
| `city.soc.incident.closed.v1` *(предложение совету)* | инцидент закрыт | тот же район | `incident_id`, `district`, `resolution` (`resolved` / `false_positive`) |
| `city.soc.source.silent.v1` *(предложение совету)* | от района нет журналов дольше 5 минут | район-источник, Транспорт | `district`, `last_seen` |

Пример:

```json
{
  "specversion": "1.0",
  "id": "8f1c2a4e-5b7d-4e2a-9c31-0d6e7f8a9b10",
  "source": "/d8-soc/api",
  "type": "city.soc.incident.opened.v1",
  "time": "2026-10-13T05:07:31.415Z",
  "subject": "INC-2026-0042",
  "datacontenttype": "application/json",
  "data": {
    "incident_id": "INC-2026-0042",
    "district": "bank",
    "severity": "high",
    "category": "auth.bruteforce",
    "rule_id": "SOC-R-003",
    "first_seen": "2026-10-13T05:05:12.004Z",
    "request_ids": ["a1b2c3d4e5f60718"]
  }
}
```

## Потребляем

| Тип (`type`) | От кого | Что делаем при получении | Что делаем с неверным / повторным событием |
|---|---|---|---|
| `city.grid.alarm.raised.v1` | Энергосеть (`/d6-grid/…`) | создаём инцидент с severity из события, публикуем `incident.opened` для Энергосети | неверный `source` или формат — не создаём инцидент, пишем `event.rejected` в журнал; повтор по `id` — игнорируем, пишем `event.duplicate` |
| `city.gateway.block.added.v1` | Шлюз (`/d1-gateway/…`) | добавляем IP в список заблокированных, связываем с открытыми инцидентами | то же: `event.rejected` / `event.duplicate` |
| `city.transport.delivery.failed.v1` | Транспорт (`/d7-transport/…`) | фиксируем потерю события; если потеряно событие для SOC — алерт дежурному | то же |
| `city.passport.user.disabled.v1` | Паспортный стол (`/d2-passport/…`) | помечаем учётку в журналах как отключённую; вход после отключения — алерт | то же |

## Открытые вопросы к архитектурному совету
- Добавить в каталог `city.soc.incident.closed.v1` и `city.soc.source.silent.v1`.
- Транспорт: гарантирует ли брокер, что `source` нельзя подделать (до подписи на неделе 5)?
- Нужен ли район-источник в `data` инцидента в виде кода Р1 (`bank`) или номера (`4`) — предлагаем код.
- Как районы отправляют журналы в SOC: HTTP-POST JSON Lines или forward-протокол Fluent Bit — нужно общее решение до недели 3.
