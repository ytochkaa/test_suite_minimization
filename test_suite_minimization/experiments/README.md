# Воспроизводимый исходный эксперимент

Класс `GenerateBaselineSnapshot` генерирует набор один раз и сохраняет весь связанный граф объектов в `.ser`. Каждый редуктор должен открывать этот файл заново, поэтому результаты предыдущего метода не становятся входом следующего.

Минимальная конфигурация:

- схема: `CourseworkSchema` — сотрудники, лаборатории, пользователи, оборудование, автоматы, товары и три таблицы-связки;
- СУБД-модель: Postgres;
- критерий: CondAICC;
- генераторы: `avsDefaults`, `randomDefaults`, `dominoRandom`, `dominoAVS`;
- seed: 0;
- бюджет: 10000;
- readability: false;
- fullreduce: false.

В `vending_machines_goods` остаток хранится в `quantity_of_goods`, а ограничение по вместимости — в `stock_capacity`. CHECK-ограничения проверяют неотрицательный остаток, положительную вместимость и условие `quantity_of_goods <= stock_capacity`. Они дают целочисленные примеры сравнений `x op c` и `x op y` для boundary-aware эксперимента.

Реальный набор артефактов для `avsDefaults`, seed `0` приложен в
[`example-data/avsDefaults-seed0`](example-data/avsDefaults-seed0). В папке есть
исходный `.ser`, Java JSON до и после PostgreSQL-проверки, C++-отчёт, выбранный
набор, CSV результатов БД, SQL-схема и сведения о версии среды. Контрольная
сумма `.ser` совпадает с `snapshotSha256` в JSON. Инструкция по локальному
повторному запуску находится в README этой папки и в
[`docs/BUILD_AND_TESTS.md`](../../docs/BUILD_AND_TESTS.md).

Пример аргументов Java main:

```text
org.schemaanalyst.minimization.GenerateBaselineSnapshot avsDefaults 0 10000 results/avsDefaults-0.ser
```

Снимки и сырые результаты новых запусков, а также собранные классы не добавляются
в Git. Исключение — сохранённый `.ser` в
[`example-data/avsDefaults-seed0`](example-data/avsDefaults-seed0), который нужен
для демонстрации реального сквозного прогона.
