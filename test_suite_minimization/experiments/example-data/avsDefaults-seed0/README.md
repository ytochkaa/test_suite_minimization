# Реальный пример прогона: avsDefaults, seed 0

Эта папка содержит файлы прогона от 18.11.2026 из `matrix-20261118-031008-81981e91`. Исходный `.ser`, Java JSON, отчёты C++ и результаты PostgreSQL скопированы из одной и той же матрицы.

## Результаты этого примера

- Схема `CourseworkSchema`, критерий `CondAICC`, генератор `avsDefaults`, seed `0`, budget `10000`.
- SchemaAnalyst создал 54 `TestCase`: 122 строки `state` и 66 строк `data`; генерация заняла `147.6211 ms`.
- Исходный набор покрыл 54 требования и 5 подтверждённых граничных наблюдений.
- `boundaryAware` оставил 48 тестов: 105 `state` и 60 `data` INSERT; время отбора — `2.7042 ms`.
- В выбранном наборе сохранены все 54 требования и все 5 границ; PostgreSQL подтвердил ожидаемый результат для 48/48 тестов.
- Статус `PASS_WITH_UNVERIFIED_CANDIDATES`: в девяти тестах исходного набора обнаружены кандидаты границ, которые не подтвердили целевой CHECK и поэтому не вошли в число пяти обязательств.

## Цепочка файлов

| Этап | Файл | Что это |
|---|---|---|
| Генерация SchemaAnalyst | [`source/avsDefaults-0.ser`](source/avsDefaults-0.ser) | Сериализованный Java `TestSuite` со схемой, требованиями и тестами. |
| Экспорт Java | [`input/avsDefaults-0-full.json`](input/avsDefaults-0-full.json) | Исходный набор, описание схемы и требований, строки `state`/`data` и SQL. |
| PostgreSQL evidence | [`input/avsDefaults-0-full-validated.json`](input/avsDefaults-0-full-validated.json) | Java JSON с фактическим результатом выполнения каждого полного теста. Это вход C++-редуктора. |
| Анализ исходного набора | [`output/avsDefaults-0-full-boundary-report.json`](output/avsDefaults-0-full-boundary-report.json) | Отчёт C++ с множествами покрытий, выбранными ID и объяснениями выбора. |
| Набор после отбора | [`output/avsDefaults-0-boundaryAware.json`](output/avsDefaults-0-boundaryAware.json) | JSON выбранных тестов; формируется оркестратором `run_matrix.ps1` по ID из отчёта C++. |
| Проверенный результат | [`output/avsDefaults-0-boundaryAware-validated.json`](output/avsDefaults-0-boundaryAware-validated.json), [`output/avsDefaults-0-boundaryAware-verify.json`](output/avsDefaults-0-boundaryAware-verify.json) | PostgreSQL evidence для выбранных тестов и повторная проверка покрытия. |
| PostgreSQL | [`postgres/schema.sql`](postgres/schema.sql), [`postgres/manual_null_oracle.sql`](postgres/manual_null_oracle.sql) | DDL девяти таблиц и ручной SQL `SELECT` для десяти комбинаций количества/вместимости и NULL. |
| Фактические ответы БД | [`postgres/avsDefaults-0-full-postgres.csv`](postgres/avsDefaults-0-full-postgres.csv), [`postgres/avsDefaults-0-boundaryAware-postgres.csv`](postgres/avsDefaults-0-boundaryAware-postgres.csv) | По одной строке на тест с ожидаемым и фактическим результатом, фазой, SQLSTATE и причиной отказа. |
| Параметры запуска | [`environment/environment.log`](environment/environment.log), [`environment/avsDefaults-0-generation.log`](environment/avsDefaults-0-generation.log) | Версии ПО и параметры генерации. |
| Сравнение методов | [`summary/summary.csv`](summary/summary.csv) | Все 28 сочетаний четырёх генераторов и семи методов отбора; пути внутри CSV относятся к исходному компьютеру. |

SHA-256 файла `source/avsDefaults-0.ser`:

```text
1a9f8393d85e3b941d66cc26309ad34b014dd644a1d57abfbfb1bd25e9e02f36
```

Это же значение записано в JSON-снимках. `schema.sql` — DDL для создания тестовых таблиц, а не физический дамп PostgreSQL. Проверяемые строки уже содержатся в JSON. Валидатор перед каждым тестом пересоздаёт схему `public`; используйте только отдельную тестовую базу без ценных данных.

## Проверка на своём компьютере

Команды выполнять из корня репозитория в PowerShell. Нужны собранный C++-исполняемый файл и локальный PostgreSQL.

Запустить C++-анализ сохранённого полного набора:

```powershell
$example = '.\test_suite_minimization\experiments\example-data\avsDefaults-seed0'
$exe = '.\test_suite_minimization\build\cpp\test_suite_minimization.exe'
& $exe `
  (Join-Path $example 'input\avsDefaults-0-full-validated.json') `
  '.\test_suite_minimization\build\cpp\example-full-report.json'
```

В отчёте должны быть 54 исходных теста, 54 требования, 5 подтверждённых границ и 48 выбранных тестов.

Проверить выбранный JSON в своей отдельной тестовой базе (подставьте свои адрес, порт, роль и пути к PostgreSQL, если они отличаются):

```powershell
& '.\test_suite_minimization\experiments\validate_postgres.ps1' `
  -InputJson (Join-Path $example 'output\avsDefaults-0-boundaryAware.json') `
  -HostName '127.0.0.1' -Port 55432 `
  -User 'baseline' -Database 'coursework_validation' `
  -ResultPath '.\test_suite_minimization\build\example-boundaryAware-postgres.csv'
```

Результат должен содержать 48 строк, все с `matches_expected=True`. Полная настройка PostgreSQL и запуск матрицы описаны в [`docs/BUILD_AND_TESTS.md`](../../../../docs/BUILD_AND_TESTS.md).
