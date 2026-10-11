# 7. Архитектура системы (C4)

## 7.1. Назначение документа

Раздел описывает архитектуру системы оформления заказа с использованием модели **C4** (Context, Container, Component, Code). C4 позволяет показать систему на разных уровнях детализации:

- **Level 1 — Context:** система и её взаимодействие с внешним миром.
- **Level 2 — Container:** крупные технические блоки (микросервисы, БД, брокеры).
- **Level 3 — Component:** внутреннее устройство ключевого сервиса.
- **Level 4 — Code:** не рассматривается в этом документе.

Также раздел содержит:
- Описание каждого сервиса (роль, API, БД, зависимости).
- Технологические решения и обоснования.
- ADR (Architecture Decision Records) — почему выбрали именно эти технологии.

**Инструмент моделирования:** PlantUML (C4-PlantUML).
**Стандарт:** C4 model by Simon Brown.

---

## 7.2. Level 1 — System Context

### 7.2.1. Описание

Система «Checkout Platform» — это ядро оформления заказов в e-commerce. Она взаимодействует с внешними акторами (клиент, оператор) и внешними системами (Payment Gateway, ERP, WMS, курьерские службы).

### 7.2.2. Диаграмма C4 Context

![C4 Context](../diagrams/architecture-context.png)

Исходник: [architecture-context.puml](../diagrams/architecture-context.puml)

### 7.2.3. Акторы и системы

| Элемент | Тип | Описание |
|---------|-----|----------|
| Клиент | Person | Пользователь мобильного приложения или сайта |
| Оператор | Person | Сотрудник клиентского сервиса |
| Checkout Platform | System | Проектируемая система |
| Payment Gateway | External System | Внешний платёжный шлюз |
| ERP System | External System | Учёт остатков и заказов |
| WMS | External System | Управление складом |
| Courier Services | External System | Курьерские службы |
| Push/SMS Provider | External System | FCM, APNS, SMS-шлюз |

---
## 7.3. Level 2 — Container

### 7.3.1. Описание

Система «Checkout Platform» состоит из микросервисов, базы данных, брокера сообщений и API Gateway. Каждый контейнер — отдельно деплоимая единица.

### 7.3.2. Диаграмма C4 Container
![C4 Container](../diagrams/architecture-container.png)

Исходник: [architecture-container.puml](../diagrams/architecture-container.puml)
