# 13. Мониторинг и Observability

## 13.1. Назначение документа

Раздел описывает систему мониторинга и observability для чекаута. Документ содержит:

- Цели мониторинга.
- SLO / SLI / SLA.
- Ключевые метрики (Golden Signals).
- Стратегию логирования.
- Распределённый трейсинг.
- Алерты и их пороги.
- Дашборды Grafana.
- Инструменты мониторинга.
- Runbook для дежурного инженера.

**Цель:** обеспечить видимость работы системы, быстро обнаруживать и устранять инциденты, поддерживать SLA 99,95%.

---

## 13.2. Цели мониторинга

| № | Цель | Метрика |
|---|------|---------|
| 1 | Обнаруживать инциденты до жалоб клиентов | MTTR ≤ 15 мин |
| 2 | Понимать состояние системы в реальном времени | Дашборды с latency 30 сек |
| 3 | Отслеживать SLA/SLO | 99,95% доступности |
| 4 | Разбирать инциденты постфактум | Retention логов 30 дней |
| 5 | Прогнозировать проблемы | Алерты до отказа |
| 6 | Обеспечить трассировку запросов | Correlation ID во всех сервисах |

---

## 13.3. SLO / SLI / SLA

### 13.3.1. Определения

- **SLI (Service Level Indicator)** — измеряемая метрика (например, latency).
- **SLO (Service Level Objective)** — целевое значение SLI (например, p95 ≤ 1,5 сек).
- **SLA (Service Level Agreement)** — обязательство перед клиентом (например, 99,95% доступности).

### 13.3.2. SLI / SLO по сервисам

| Сервис | SLI | SLO | SLA |
|--------|-----|-----|-----|
| **Cart Service** | Latency p95 | ≤ 1,5 сек | 99,95% |
| **Cart Service** | Availability | 99,95% | 99,95% |
| **Checkout Service** | Latency p95 | ≤ 2 сек | 99,95% |
| **Checkout Service** | Error rate | ≤ 0,5% | — |
| **Checkout Service** | Availability | 99,95% | 99,95% |
| **Logistics Service** | Latency p95 | ≤ 1 сек | 99,9% |
| **Payment Gateway** | Success rate | ≥ 98% | 99,9% |
| **Kafka** | Consumer Lag | ≤ 1000 | — |
| **PostgreSQL** | Query latency p95 | ≤ 100 мс | — |
| **API Gateway** | Latency p95 | ≤ 200 мс | 99,99% |

### 13.3.3. Error Budget

**Error Budget** = 100% − SLO = 0,05% от общего времени.

- В месяц: 0,05% × 30 дней × 24 часа = **21,6 минуты** недоступности.
- Если бюджет исчерпан — стоп на новые фичи, фокус на надёжность.

### 13.3.4. Burn Rate

| Burn Rate | Порог | Действие |
|-----------|-------|----------|
| 1x | Норма | Мониторинг |
| 2x | Warning | Уведомление команды |
| 5x | Critical | PagerDuty, стоп релизов |
| 14x | Emergency | Все на разбор инцидента |

---

## 13.4. Golden Signals (ключевые метрики)

### 13.4.1. Четыре золотых сигнала

| Сигнал | Описание | Метрики |
|--------|----------|---------|
| **Latency** | Время ответа | p50, p95, p99 |
| **Traffic** | Нагрузка | RPS, количество запросов |
| **Errors** | Ошибки | 4xx, 5xx, error rate |
| **Saturation** | Насыщение | CPU, RAM, connections, disk |

### 13.4.2. Метрики по сервисам

| Метрика | Источник | Retention |
|---------|----------|-----------|
| `http_requests_total` | Spring Actuator | 1 год |
| `http_request_duration_seconds` | Spring Actuator | 1 год |
| `http_requests_errors_total` | Spring Actuator | 1 год |
| `jvm_memory_used_bytes` | Micrometer | 1 год |
| `jvm_gc_pause_seconds` | Micrometer | 1 год |
| `kafka_consumer_lag` | Kafka Exporter | 1 год |
| `kafka_producer_errors_total` | Kafka Exporter | 1 год |
| `db_connections_active` | PostgreSQL Exporter | 1 год |
| `db_query_duration_seconds` | PostgreSQL Exporter | 1 год |
| `redis_hits_total` | Redis Exporter | 1 год |
| `business_orders_created_total` | Custom | 5 лет |
| `business_orders_completed_total` | Custom | 5 лет |
| `business_payment_success_total` | Custom | 5 лет |
| `business_payment_failed_total` | Custom | 5 лет |
| `business_cart_conversion_rate` | Custom | 5 лет |

### 13.4.3. Бизнес-метрики

| Метрика | Описание | Целевое значение |
|---------|----------|------------------|
| Конверсия корзины | % оформленных корзин | ≥ 60% |
| Успешные оплаты | % успешных платежей | ≥ 95% |
| Доля отмен | % отменённых заказов | ≤ 15% |
| Средний чек | Сумма заказа | ≥ 5 000 ₽ |
| Время оформления | От корзины до оплаты | ≤ 3 мин |
| Доля EXPIRED | Заказы с истёкшим резервом | ≤ 5% |

---

## 13.5. Логирование

### 13.5.1. Принципы

- **Structured JSON** — все логи в формате JSON.
- **Correlation ID** — единый ID для запроса через все сервисы.
- **Уровни:** DEBUG, INFO, WARN, ERROR.
- **Никаких ПДн** — не логируем номера карт, пароли, токены.
- **Централизация** — ELK Stack (Elasticsearch + Logstash + Kibana).

### 13.5.2. Формат лога

```json
{
  "timestamp": "2026-10-16T12:00:00.123Z",
  "level": "INFO",
  "service": "checkout-service",
  "version": "1.5.2",
  "correlation_id": "c1c2c3c4-d5d6-7e8f-9a0b-1c2d3e4f5a6b",
  "trace_id": "t1t2t3t4-u5u6-7v8w-9x0y-1z2a3b4c5d6e",
  "span_id": "s1s2s3s4",
  "user_id": "u1u2u3u4-v5v6-7w8x-9y0z-1a2b3c4d5e6f",
  "order_id": "o1o2o3o4-p5q6-7r8s-9t0u-1v2w3x4y5z6a",
  "message": "Order created successfully",
  "duration_ms": 245,
  "http": {
    "method": "POST",
    "path": "/api/v1/checkout/confirm",
    "status": 201
  }
}
```

### 13.5.3. Уровни логирования

| Уровень | Когда использовать |
|---------|-------------------|
| DEBUG | Детали для разработки (не в проде) |
| INFO | Нормальные операции |
| WARN | Подозрительные ситуации |
| ERROR | Ошибки, требующие внимания |
| FATAL | Критические ошибки |

### 13.5.4. Что логируем

| Событие | Уровень | Пример |
|---------|---------|--------|
| Заказ создан | INFO | `Order created` |
| Оплата прошла | INFO | `Payment success` |
| Оплата не прошла | WARN | `Payment failed` |
| ERP недоступна | ERROR | `ERP timeout` |
| DLQ событие | ERROR | `Message moved to DLQ` |
| Webhook получен | INFO | `Webhook received` |
| Ошибка подписи | WARN | `Invalid signature` |

### 13.5.5. Что НЕ логируем

- Номера банковских карт.
- Пароли и токены.
- Полные ПДн (только ID).
- CVV-коды.

### 13.5.6. Retention

| Тип логов | Retention |
|-----------|-----------|
| INFO | 30 дней |
| WARN | 90 дней |
| ERROR | 1 год |
| Audit | 5 лет |

---

## 13.6. Распределённый трейсинг

### 13.6.1. Зачем нужен

Трейсинг показывает **полный путь запроса** через все сервисы:
- Где задерживается?
- Какой сервис виноват в ошибке?
- Сколько времени занял каждый вызов?

### 13.6.2. Стек

- **OpenTelemetry** — стандарт сбора телеметрии.
- **Jaeger** — хранилище и UI для трейсов.
- **Correlation ID** — пробрасывается через все сервисы.
