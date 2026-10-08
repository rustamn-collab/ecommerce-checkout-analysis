# ecommerce-checkout-analysis
Пет-проект системного аналитика: анализ и проектирование процесса оформления заказа в e-commerce
# E-commerce Checkout Analysis

Пет-проект системного аналитика: анализ и проектирование процесса оформления заказа с курьерской доставкой и онлайн-оплатой.

## 📋 Содержание

| № | Раздел | Описание |
|---|--------|----------|
| 1 | [Введение и бизнес-контекст](docs/01-introduction.md) | О компании, цели, проблемы AS-IS, целевое видение TO-BE |
| 2 | [Область проекта](docs/02-scope.md) | In Scope, Out of Scope, зависимости, риски |
| 3 | [Функциональные требования](docs/03-functional-requirements.md) | FR-01..FR-34, трассировка |
| 4 | [Нефункциональные требования](docs/04-nonfunctional-requirements.md) | Производительность, SLA, безопасность, наблюдаемость |
| 5 | [Use Cases](docs/05-use-cases.md) | UC-01 и альтернативные сценарии |
| 6 | [Бизнес-процессы (BPMN)](docs/06-bpmn-processes.md) | AS-IS и TO-BE |
| 7 | [Архитектура](docs/07-architecture.md) | C4: Context, Container, Component |
| 8 | [State Machine заказа](docs/08-state-machine.md) | Жизненный цикл заказа |
| 9 | [Kafka-события](docs/09-kafka-events.md) | Топики, схемы, DLQ |
| 10 | [API-контракты](docs/10-api-contracts.md) | REST API для корзины и чекаута |
| 11 | [Модель данных](docs/11-data-model.md) | ER-диаграмма, таблицы, индексы |
| 12 | [Тестирование](docs/12-testing.md) | Стратегия, тест-кейсы, UAT |
| 13 | [Мониторинг](docs/13-monitoring.md) | Метрики, алерты, трейсинг |
| 14 | [Безопасность](docs/14-security.md) | PCI DSS, JWT, rate limiting |
| 15 | [Риски и митигации](docs/15-risks.md) | Таблица рисков |

## 📐 Диаграммы

- [Sequence-диаграмма оформления заказа](diagrams/sequence-diagram.puml)
- [BPMN AS-IS](diagrams/bpmn-as-is.puml)
- [BPMN TO-BE](diagrams/bpmn-to-be.puml)
- [State Machine заказа](diagrams/state-machine.puml)
- [Архитектура C4](diagrams/architecture-c4.puml)

## 🗄️ База данных

- [SQL-схема](db/schema.sql)

## 🛠️ Стек

BPMN, PlantUML, REST API, Swagger/OpenAPI, Apache Kafka, PostgreSQL, микросервисная архитектура, Jira, Confluence.
