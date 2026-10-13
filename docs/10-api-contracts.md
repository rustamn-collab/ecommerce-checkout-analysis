# 10. API-контракты

## 10.1. Назначение документа

Раздел описывает REST API для взаимодействия Frontend с микросервисами системы оформления заказа. Документ содержит:

- Общие принципы API (версионирование, аутентификация, формат).
- Полный список эндпоинтов с описанием.
- Схемы запросов и ответов (JSON).
- Единый формат ошибок.
- Коды ответов.
- Rate limiting и идемпотентность.
- Примеры curl-запросов.
- Ссылки на Swagger/OpenAPI.

**Формат:** REST, JSON.
**Базовый URL:** `https://api.example.com/api/v1`
**Аутентификация:** Bearer-токен (JWT).
**Инструмент документации:** Swagger / OpenAPI 3.0.

---

## 10.2. Общие принципы

### 10.2.1. Версионирование

Версия API указывается в URL:
```
https://api.example.com/api/v1/...
```

**Правила:**
- При breaking changes — увеличивается мажорная версия (`/v2/`).
- Старая версия поддерживается минимум 6 месяцев.
- Минорные изменения (добавление поля) — без смены версии.

### 10.2.2. Аутентификация

Все защищённые эндпоинты требуют заголовок:
```
Authorization: Bearer <JWT-token>
```

**JWT содержит:**
- `user_id` — идентификатор пользователя.
- `exp` — время истечения (TTL 1 час).
- `roles` — роли пользователя.

**Обновление токена:** через `POST /auth/refresh` (вне рамок этого документа).

### 10.2.3. Формат данных

- **Запросы и ответы:** JSON (UTF-8).
- **Даты:** ISO 8601 (`2026-10-13T12:00:00Z`).
- **Валюта:** ISO 4217 (`RUB`).
- **UUID:** формат `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`.

### 10.2.4. Идемпотентность

Для операций, которые могут быть повторены (создание заказа, оплата), используется заголовок:
```
Idempotency-Key: <UUID>
```

**Правила:**
- Клиент генерирует UUID и передаёт в заголовке.
- Сервер сохраняет результат в Redis на 24 часа.
- Повторный запрос с тем же ключом возвращает сохранённый результат.

### 10.2.5. Единый формат ошибок

Все ошибки возвращаются в едином формате:

```json
{
  "error": "ERROR_CODE",
  "message": "Человекочитаемое описание",
  "details": {
    "field": "delivery.address.postal_code",
    "reason": "Неверный формат индекса"
  },
  "correlation_id": "c1c2c3c4-d5d6-7e8f-9a0b-1c2d3e4f5a6b",
  "timestamp": "2026-10-13T12:00:00Z"
}
```

### 10.2.6. Коды ответов

| Код | Значение | Когда используется |
|-----|----------|-------------------|
| 200 | OK | Успешный GET, PUT, PATCH |
| 201 | Created | Успешный POST (создание) |
| 204 | No Content | Успешный DELETE |
| 400 | Bad Request | Ошибка валидации |
| 401 | Unauthorized | Отсутствует или неверный токен |
| 403 | Forbidden | Недостаточно прав |
| 404 | Not Found | Ресурс не найден |
| 409 | Conflict | Конфликт (out of stock, слот занят) |
| 422 | Unprocessable Entity | Бизнес-ошибка |
| 429 | Too Many Requests | Превышен rate limit |
| 500 | Internal Server Error | Ошибка сервиса |
| 503 | Service Unavailable | Внешняя система недоступна |

### 10.2.7. Rate limiting

| Тип запроса | Лимит |
|-------------|-------|
| GET | 100 RPS на пользователя |
| POST | 20 RPS на пользователя |
| POST `/checkout/confirm` | 5 RPS на пользователя |

При превышении — ответ `429 Too Many Requests` с заголовком:
```
Retry-After: 60
```

### 10.2.8. Пагинация

Для списков используется cursor-based пагинация:

```json
{
  "items": [...],
  "pagination": {
    "next_cursor": "eyJpZCI6MTIzfQ==",
    "has_more": true,
    "total_count": 150
  }
}
```

**Query-параметры:**
- `limit` — размер страницы (default 20, max 100).
- `cursor` — курсор для следующей страницы.

---

## 10.3. Список эндпоинтов

| Метод | Путь | Назначение |
|-------|------|-----------|
| GET | `/cart` | Получить корзину |
| POST | `/cart/items` | Добавить товар |
| PATCH | `/cart/items/{id}` | Изменить количество |
| DELETE | `/cart/items/{id}` | Удалить товар |
| POST | `/cart/calculate` | Рассчитать корзину с доставкой |
| POST | `/checkout/confirm` | Подтвердить заказ |
| POST | `/checkout/cancel` | Отменить заказ |
| POST | `/payments/webhook` | Webhook от платёжного шлюза |
| POST | `/logistics/calculate` | Рассчитать доставку |
| GET | `/orders` | Получить список заказов |
| GET | `/orders/{id}` | Получить детали заказа |
| GET | `/orders/{id}/status` | Получить статус заказа |

---

## 10.4. Cart API

### 10.4.1. GET /cart

**Назначение:** получить текущую корзину пользователя.

**Аутентификация:** требуется.

**Request:**
```http
GET /api/v1/cart
Authorization: Bearer <token>
```

**Response 200:**
```json
{
  "cart_id": "c1d2e3f4-a5b6-7c8d-9e0f-1a2b3c4d5e6f",
  "user_id": "u1u2u3u4-v5v6-7w8x-9y0z-1a2b3c4d5e6f",
  "items": [
    {
      "item_id": "i1i2i3i4-j5j6-7k8l-9m0n-1o2p3q4r5s6t",
      "product_id": "p1p2p3p4-q5q6-7r8s-9t0u-1v2w3x4y5z6a",
      "name": "Стол письменный",
      "quantity": 2,
      "price": 5990.00,
      "total": 11980.00,
      "available": true,
      "warehouse_id": "w1w2w3w4-x5x6-7y8z-9a0b-1c2d3e4f5a6b"
    }
  ],
  "subtotal": 11980.00,
  "currency": "RUB",
  "updated_at": "2026-10-13T12:00:00Z"
}
```

**Response 401 (не авторизован):**
```json
{
  "error": "UNAUTHORIZED",
  "message": "Требуется авторизация",
  "correlation_id": "c1c2c3c4-d5d6-7e8f-9a0b-1c2d3e4f5a6b",
  "timestamp": "2026-10-13T12:00:00Z"
}
```

---

### 10.4.2. POST /cart/items

**Назначение:** добавить товар в корзину.

**Аутентификация:** требуется.

**Request:**
```http
POST /api/v1/cart/items
Authorization: Bearer <token>
Content-Type: application/json
```

```json
{
  "product_id": "p1p2p3p4-q5q6-7r8s-9t0u-1v2w3x4y5z6a",
  "quantity": 2
}
```

**Response 201:**
```json
{
  "item_id": "i1i2i3i4-j5j6-7k8l-9m0n-1o2p3q4r5s6t",
  "product_id": "p1p2p3p4-q5q6-7r8s-9t0u-1v2w3x4y5z6a",
  "quantity": 2,
  "price": 5990.00,
  "total": 11980.00
}
```

**Response 400 (ошибка валидации):**
```json
{
  "error": "VALIDATION_ERROR",
  "message": "Некорректное количество",
  "details": {
    "field": "quantity",
    "reason": "Значение должно быть больше 0 и меньше 100"
  },
  "correlation_id": "c1c2c3c4-d5d6-7e8f-9a0b-1c2d3e4f5a6b",
  "timestamp": "2026-10-13T12:00:00Z"
}
```

**Response 409 (товара нет в наличии):**
```json
{
  "error": "OUT_OF_STOCK",
  "message": "Товар отсутствует на складе",
  "details": {
    "product_id": "p1p2p3p4-q5q6-7r8s-9t0u-1v2w3x4y5z6a",
    "available": 0
  },
  "correlation_id": "c1c2c3c4-d5d6-7e8f-9a0b-1c2d3e4f5a6b",
  "timestamp": "2026-10-13T12:00:00Z"
}
```

---

### 10.4.3. PATCH /cart/items/{id}

**Назначение:** изменить количество товара в корзине.

**Request:**
```http
PATCH /api/v1/cart/items/i1i2i3i4-j5j6-7k8l-9m0n-1o2p3q4r5s6t
Authorization: Bearer <token>
```

```json
{
  "quantity": 3
}
```

**Response 200:**
```json
{
  "item_id": "i1i2i3i4-j5j6-7k8l-9m0n-1o2p3q4r5s6t",
  "quantity": 3,
  "total": 17970.00
}
```

---

### 10.4.4. DELETE /cart/items/{id}

**Назначение:** удалить товар из корзины.

**Request:**
```http
DELETE /api/v1/cart/items/i1i2i3i4-j5j6-7k8l-9m0n-1o2p3q4r5s6t
Authorization: Bearer <token>
```

**Response 204:** (без тела)

---

### 10.4.5. POST /cart/calculate

**Назначение:** рассчитать итоговую стоимость корзины с учётом доставки. Проверяет остатки в ERP и запрашивает доставку у Logistics Service.

**Request:**
```http
POST /api/v1/cart/calculate
Authorization: Bearer <token>
Content-Type: application/json
```

```json
{
  "user_id": "u1u2u3u4-v5v6-7w8x-9y0z-1a2b3c4d5e6f",
  "items": [
    {
      "product_id": "p1p2p3p4-q5q6-7r8s-9t0u-1v2w3x4y5z6a",
      "quantity": 2
    },
    {
      "product_id": "p2p3p4p5-q6q7-8r9s-0t1u-2v3w4x5y6z7a",
      "quantity": 1
    }
  ],
  "delivery": {
    "address": {
      "city": "Набережные Челны",
      "street": "Проспект Мира",
      "house": "10",
      "postal_code": "423800"
    }
  }
}
```

**Response 200:**
```json
{
  "cart_id": "c1d2e3f4-a5b6-7c8d-9e0f-1a2b3c4d5e6f",
  "items": [
    {
      "product_id": "p1p2p3p4-q5q6-7r8s-9t0u-1v2w3x4y5z6a",
      "name": "Стол письменный",
      "quantity": 2,
      "price": 5990.00,
      "total": 11980.00,
      "available": true,
      "warehouse_id": "w1w2w3w4-x5x6-7y8z-9a0b-1c2d3e4f5a6b"
    }
  ],
  "subtotal": 11980.00,
  "delivery": {
    "amount": 490.00,
    "currency": "RUB",
    "slots": [
      {
        "id": "s1s2s3s4-t5u6-7v8w-9x0y-1z2a3b4c5d6e",
        "start": "2026-10-15T10:00:00Z",
        "end": "2026-10-15T14:00:00Z",
        "price": 490.00
      },
      {
        "id": "s2s3s4s5-u6v7-8w9x-0y1z-2a3b4c5d6e7f",
        "start": "2026-10-15T14:00:00Z",
        "end": "2026-10-15T18:00:00Z",
        "price": 590.00
      }
    ]
  },
  "total": 12470.00,
  "currency": "RUB",
  "reservation_available": true
}
```

**Response 409 (товара нет в наличии):**
```json
{
  "error": "OUT_OF_STOCK",
  "message": "Товар 'Стол письменный' отсутствует на складе",
  "details": {
    "product_id": "p1p2p3p4-q5q6-7r8s-9t0u-1v2w3x4y5z6a",
    "requested": 2,
    "available": 0,
    "alternative_warehouses": [
      {
        "warehouse_id": "w9w8w7w6-x5y4-3z2a-1b0c-9d8e7f6a5b4c",
        "available": 3,
        "delivery_days": 5
      }
    ]
  },
  "correlation_id": "c1c2c3c4-d5d6-7e8f-9a0b-1c2d3e4f5a6b",
  "timestamp": "2026-10-13T12:00:00Z"
}
```

---

## 10.5. Checkout API

### 10.5.1. POST /checkout/confirm

**Назначение:** создать заказ, зарезервировать товар на 15 минут и инициировать оплату.

**Аутентификация:** требуется.
**Идемпотентность:** обязателен заголовок `Idempotency-Key`.

**Request:**
```http
POST /api/v1/checkout/confirm
Authorization: Bearer <token>
Idempotency-Key: 123e4567-e89b-12d3-a456-426614174000
Content-Type: application/json
```

```json
{
  "user_id": "u1u2u3u4-v5v6-7w8x-9y0z-1a2b3c4d5e6f",
  "cart_id": "c1d2e3f4-a5b6-7c8d-9e0f-1a2b3c4d5e6f",
  "delivery": {
    "address": {
      "city": "Набережные Челны",
      "street": "Проспект Мира",
      "house": "10",
      "postal_code": "423800"
    },
    "slot_id": "s1s2s3s4-t5u6-7v8w-9x0y-1z2a3b4c5d6e"
  },
  "payment": {
    "method": "CARD"
  }
}
```

**Response 201:**
```json
{
  "order_id": "o1o2o3o4-p5q6-7r8s-9t0u-1v2w3x4y5z6a",
  "status": "PENDING_PAYMENT",
  "total": 12470.00,
  "currency": "RUB",
  "payment_url": "https://payment.gateway/checkout/abc123xyz",
  "reservation_expires_at": "2026-10-13T12:15:00Z",
  "created_at": "2026-10-13T12:00:00Z"
}
```

**Response 409 (слот недоступен):**
```json
{
  "error": "SLOT_UNAVAILABLE",
  "message": "Выбранный интервал доставки больше недоступен",
  "available_slots": [
    {
      "id": "s2s3s4s5-u6v7-8w9x-0y1z-2a3b4c5d6e7f",
      "start": "2026-10-16T10:00:00Z",
      "end": "2026-10-16T14:00:00Z",
      "price": 490.00
    }
  ],
  "correlation_id": "c1c2c3c4-d5d6-7e8f-9a0b-1c2d3e4f5a6b",
  "timestamp": "2026-10-13T12:00:00Z"
}
```

**Response 409 (товара не хватило при резервировании):**
```json
{
  "error": "RESERVATION_FAILED",
  "message": "Не удалось зарезервировать товар. Возможно, он закончился.",
  "details": {
    "product_id": "p1p2p3p4-q5q6-7r8s-9t0u-1v2w3x4y5z6a"
  },
  "correlation_id": "c1c2c3c4-d5d6-7e8f-9a0b-1c2d3e4f5a6b",
  "timestamp": "2026-10-13T12:00:00Z"
}
```

---

### 10.5.2. POST /checkout/cancel

**Назначение:** отменить заказ. Если оплата прошла — инициировать возврат.

**Request:**
```http
POST /api/v1/checkout/cancel
Authorization: Bearer <token>
Content-Type: application/json
```

```json
{
  "order_id": "o1o2o3o4-p5q6-7r8s-9t0u-1v2w3x4y5z6a",
  "reason": "CUSTOMER_REQUEST"
}
```

**Response 200 (отмена после неуспешной оплаты):**
```json
{
  "order_id": "o1o2o3o4-p5q6-7r8s-9t0u-1v2w3x4y5z6a",
  "status": "CANCELLED",
  "refund_required": false,
  "cancelled_at": "2026-10-13T12:30:00Z"
}
```

**Response 200 (отмена после успешной оплаты):**
```json
{
  "order_id": "o1o2o3o4-p5q6-7r8s-9t0u-1v2w3x4y5z6a",
  "status": "REFUND_PENDING",
  "refund_required": true,
  "refund_amount": 12470.00,
  "refund_status": "PENDING",
  "estimated_refund_days": 5,
  "cancelled_at": "2026-10-13T12:30:00Z"
}
```

**Response 409 (отмена невозможна):**
```json
{
  "error": "CANCELLATION_NOT_ALLOWED",
  "message": "Заказ уже передан курьеру и не может быть отменён",
  "order_id": "o1o2o3o4-p5q6-7r8s-9t0u-1v2w3x4y5z6a",
  "status": "IN_TRANSIT",
  "correlation_id": "c1c2c3c4-d5d6-7e8f-9a0b-1c2d3e4f5a6b",
  "timestamp": "2026-10-13T12:30:00Z"
}
```

---

## 10.6. Payment Webhook

### 10.6.1. POST /payments/webhook

**Назначение:** получить уведомление от платёжного шлюза. Вызывается самим шлюзом, не клиентом.

**Аутентификация:** подпись в заголовке `X-Signature`.

**Request (успешная оплата):**
```http
POST /api/v1/payments/webhook
X-Signature: sha256=8f14e45fceea167a5a36dedd4bea2543...
Content-Type: application/json
```

```json
{
  "event": "payment.success",
  "payment_id": "p1p2p3p4-q5q6-7r8s-9t0u-1v2w3x4y5z6a",
  "order_id": "o1o2o3o4-p5q6-7r8s-9t0u-1v2w3x4y5z6a",
  "amount": 12470.00,
  "currency": "RUB",
  "external_id": "pay_abc123xyz",
  "timestamp": "2026-10-13T12:05:00Z",
  "signature": "sha256=8f14e45fceea167a5a36dedd4bea2543..."
}
```

**Request (неуспешная оплата):**
```json
{
  "event": "payment.failed",
  "payment_id": "p1p2p3p4-q5q6-7r8s-9t0u-1v2w3x4y5z6a",
  "order_id": "o1o2o3o4-p5q6-7r8s-9t0u-1v2w3x4y5z6a",
  "amount": 12470.00,
  "currency": "RUB",
  "reason": "INSUFFICIENT_FUNDS",
  "timestamp": "2026-10-13T12:05:00Z",
  "signature": "sha256=..."
}
```

**Response 200:**
```json
{
  "status": "ok",
  "processed_at": "2026-10-13T12:05:01Z"
}
```

**Response 400 (некорректная подпись):**
```json
{
  "error": "INVALID_SIGNATURE",
  "message": "Подпись webhook не прошла проверку",
  "correlation_id": "c1c2c3c4-d5d6-7e8f-9a0b-1c2d3e4f5a6b",
  "timestamp": "2026-10-13T12:05:00Z"
}
```

### 10.6.2. Логика обработки

1. Проверить подпись `X-Signature`.
2. Проверить идемпотентность по `payment_id`.
3. Найти заказ по `order_id`.
4. Обновить статус заказа.
5. Опубликовать событие в Kafka.
6. Вернуть `200 OK` (чтобы шлюз не повторял запрос).

---

## 10.7. Logistics API

### 10.7.1. POST /logistics/calculate

**Назначение:** рассчитать стоимость и сроки доставки.

**Request:**
```json
{
  "items": [
    {
      "product_id": "p1p2p3p4-q5q6-7r8s-9t0u-1v2w3x4y5z6a",
      "quantity": 2
    }
  ],
  "address": {
    "city": "Набережные Челны",
    "street": "Проспект Мира",
    "house": "10",
    "postal_code": "423800"
  }
}
```

**Response 200:**
```json
{
  "delivery_options": [
    {
      "type": "COURIER",
      "amount": 490.00,
      "currency": "RUB",
      "slots": [
        {
          "id": "s1s2s3s4-t5u6-7v8w-9x0y-1z2a3b4c5d6e",
          "start": "2026-10-15T10:00:00Z",
          "end": "2026-10-15T14:00:00Z"
        }
      ]
    }
  ],
  "is_split": true,
  "split_reason": "Товары на разных складах"
}
```

---

## 10.8. Orders API

### 10.8.1. GET /orders

**Назначение:** получить список заказов пользователя.

**Request:**
```http
GET /api/v1/orders?limit=20&cursor=eyJpZCI6MTIzfQ==
Authorization: Bearer <token>
```

**Response 200:**
```json
{
  "items": [
    {
      "order_id": "o1o2o3o4-p5q6-7r8s-9t0u-1v2w3x4y5z6a",
      "status": "DELIVERED",
      "total": 12470.00,
      "currency": "RUB",
      "created_at": "2026-10-13T12:00:00Z",
      "delivered_at": "2026-10-15T13:45:00Z"
    }
  ],
  "pagination": {
    "next_cursor": null,
    "has_more": false,
    "total_count": 1
  }
}
```

### 10.8.2. GET /orders/{id}

**Назначение:** получить детали заказа.

**Response 200:**
```json
{
  "order_id": "o1o2o3o4-p5q6-7r8s-9t0u-1v2w3x4y5z6a",
  "status": "DELIVERED",
  "user_id": "u1u2u3u4-v5v6-7w8x-9y0z-1a2b3c4d5e6f",
  "items": [
    {
      "product_id": "p1p2p3p4-q5q6-7r8s-9t0u-1v2w3x4y5z6a",
      "name": "Стол письменный",
      "quantity": 2,
      "price": 5990.00,
      "total": 11980.00
    }
  ],
  "subtotal": 11980.00,
  "delivery_amount": 490.00,
  "total": 12470.00,
  "currency": "RUB",
  "delivery": {
    "address": {
      "city": "Набережные Челны",
      "street": "Проспект Мира",
      "house": "10",
      "postal_code": "423800"
    },
    "courier_service": "CDEK",
    "tracking_number": "CDEK1234567890",
    "slot_start": "2026-10-15T10:00:00Z",
    "slot_end": "2026-10-15T14:00:00Z"
  },
  "payment": {
    "method": "CARD",
    "status": "SUCCESS",
    "paid_at": "2026-10-13T12:04:30Z"
  },
  "created_at": "2026-10-13T12:00:00Z",
  "updated_at": "2026-10-15T13:45:00Z"
}
```

### 10.8.3. GET /orders/{id}/status

**Назначение:** получить текущий статус заказа (для polling).

**Response 200:**
```json
{
  "order_id": "o1o2o3o4-p5q6-7r8s-9t0u-1v2w3x4y5z6a",
  "status": "IN_TRANSIT",
  "status_history": [
    {
      "from": "CONFIRMED",
      "to": "ASSEMBLING",
      "at": "2026-10-14T08:00:00Z"
    },
    {
      "from": "ASSEMBLING",
      "to": "READY_FOR_SHIPMENT",
      "at": "2026-10-14T16:00:00Z"
    },
    {
      "from": "READY_FOR_SHIPMENT",
      "to": "IN_TRANSIT",
      "at": "2026-10-15T10:00:00Z"
    }
  ],
  "updated_at": "2026-10-15T10:00:00Z"
}
```

---

## 10.9. Примеры curl

### 10.9.1. Расчёт корзины

```bash
curl -X POST https://api.example.com/api/v1/cart/calculate \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "items": [
      {"product_id": "p1p2p3p4-q5q6-7r8s-9t0u-1v2w3x4y5z6a", "quantity": 2}
    ],
    "delivery": {
      "address": {
        "city": "Набережные Челны",
        "street": "Проспект Мира",
        "house": "10",
        "postal_code": "423800"
      }
    }
  }'
```

### 10.9.2. Подтверждение заказа

```bash
curl -X POST https://api.example.com/api/v1/checkout/confirm \
  -H "Authorization: Bearer <token>" \
  -H "Idempotency-Key: 123e4567-e89b-12d3-a456-426614174000" \
  -H "Content-Type: application/json" \
  -d '{
    "cart_id": "c1d2e3f4-a5b6-7c8d-9e0f-1a2b3c4d5e6f",
    "delivery": {
      "address": {...},
      "slot_id": "s1s2s3s4-t5u6-7v8w-9x0y-1z2a3b4c5d6e"
    },
    "payment": {"method": "CARD"}
  }'
```

---

## 10.10. Swagger / OpenAPI

Полная спецификация API доступна в файле `openapi.yaml` (см. репозиторий).

**Что содержит OpenAPI:**
- Все эндпоинты.
- Схемы запросов и ответов.
- Схемы ошибок.
- Примеры.
- Описания параметров.

**Как использовать:**
- Импортировать в Postman.
- Открыть в Swagger UI.
- Сгенерировать клиентский SDK.

---

## 10.11. Версионирование и deprecation

| Версия | Статус | Дата |
|--------|--------|------|
| v1 | Active | 2026-01 |
| v2 | Planned | 2027-01 |

**Правила deprecation:**
- О вводе новой версии сообщается за 3 месяца.
- Старая версия поддерживается 6 месяцев.
- В ответах старой версии добавляется заголовок `Deprecation: true`.

---
