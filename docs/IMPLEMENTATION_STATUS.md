# Проверенное состояние практической части

Последняя проверка: 18.11.2026. Схема `CourseworkSchema` теперь описывает предметную БД лабораторий, сотрудников, пользователей, оборудования, торговых автоматов и товаров. Java-описание и [`experiments/schema.sql`](../test_suite_minimization/experiments/schema.sql) согласованы по девяти таблицам, ключам, типам и ограничениям.

## Реализованные компоненты

- Java-обвязки `GenerateBaselineSnapshot`, `ExportBaselineJson` и `RunSnapshotReducer` сохраняют один исходный `.ser`, экспортируют JSON и независимо перечитывают исходный снимок для каждого редуктора.
- Схема содержит таблицы-связки `employee_laboratories`, `vending_machines_goods` и `users_equipment`; числовые CHECK на остаток и вместимость образуют сравнения `x op c` и `x op y`.
- C++ `boundaryAware` строит покрытие исходных требований и подтверждённых границ, выбирает набор и проверяет его на том же входном наборе.
- `validate_postgres.ps1` выполняет `state` и `data` в отдельном состоянии схемы для каждого теста, сохраняет SQLSTATE и имя CHECK.
- `run_matrix.ps1` запускает независимую матрицу и сохраняет сводку, JSON, CSV и журналы.

Подтверждённое ограничение: граничный анализ поддерживает простые сравнения целочисленного столбца с константой и двух целочисленных столбцов с операторами `<`, `<=`, `>` и `>=`. Сложные выражения, общая логика составных CHECK, типы `NUMERIC` и даты в boundary-анализ не входят.

## Подтверждённые запуски

- SchemaAnalyst собран `.\SchemaAnalyst\gradlew.bat -p .\SchemaAnalyst compile --offline --no-daemon` под Eclipse Temurin 8u512-b09, Gradle wrapper 4.10.2.
- Экспериментальные Java-классы с новой `CourseworkSchema` скомпилированы; CMake-сборка и CTest прошли в рамках `run_matrix.ps1`.
- Ручной SQL NULL oracle на PostgreSQL 18.7 выполнил 10 сочетаний количества/вместимости; все `actual_accept` совпали с `expected_accept`.
- Матрица `CondAICC`, seed 0, budget 10000 выполнена для четырёх генераторов, шести штатных методов и `boundaryAware`: 28 строк результата. Во всех строках PostgreSQL совпал с ожидаемым результатом.
- `boundaryAware` сохранил доступные подтверждённые требования и границы для всех четырёх исходных наборов. STICCER потерял требования во всех четырёх запусках; `HGS` потерял одну границу в запуске `randomDefaults`. Подробности и метрики — в [`RESULTS_BASELINE.md`](./RESULTS_BASELINE.md).
- Реальный пример `avsDefaults`, seed 0: 54 исходных теста; после `boundaryAware` — 48 тестов, 54/54 требования, 5/5 границ и 48/48 совпадений PostgreSQL. Его `.ser`, JSON, отчёты и CSV находятся в [`example-data/avsDefaults-seed0`](../test_suite_minimization/experiments/example-data/avsDefaults-seed0).

Для нового примера хеш `.ser` — `1a9f8393d85e3b941d66cc26309ad34b014dd644a1d57abfbfb1bd25e9e02f36`. Проверенная среда: Windows PowerShell 5.1.26100.9818, PostgreSQL 18.7, MSYS2 g++ 16.2.0, CMake 4.4.3.

Первый запуск матрицы во время обновления схемы и DDL отброшен; его результаты не включены в baseline. Авторитетные результаты получены повторным прогоном после фиксации файлов. Полный Gradle `test` при этой проверке не запускался.
