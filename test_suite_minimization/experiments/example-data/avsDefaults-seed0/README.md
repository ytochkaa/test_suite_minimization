# Реальный пример прогона: avsDefaults, seed 0

Эта папка содержит отобранные файлы одного завершённого прогона от 17.11.2026. Это не синтетическая фикстура: сериализованный снимок, JSON, отчёты и CSV скопированы из `matrix-20261117-025251-6b4a30af`.

## Цепочка файлов

| Этап | Файл | Что это |
|---|---|---|
| Генерация SchemaAnalyst | [`source/avsDefaults-0.ser`](source/avsDefaults-0.ser) | Сериализованный Java `TestSuite` со схемой, требованиями и тестами. Это бинарный файл, его не нужно открывать как текст. |
| Экспорт Java | [`input/avsDefaults-0-full.json`](input/avsDefaults-0-full.json) | Исходный набор, описание схемы и требований, строки `state`/`data` и SQL. |
| PostgreSQL evidence | [`input/avsDefaults-0-full-validated.json`](input/avsDefaults-0-full-validated.json) | Вход boundary-aware C++-редуктора: экспорт плюс результат выполнения каждого теста в PostgreSQL. |
| Анализ исходного набора | [`output/avsDefaults-0-full-boundary-report.json`](output/avsDefaults-0-full-boundary-report.json) | Отчёт C++ с множествами покрытий, выбранными ID тестов и объяснениями выбора. |
| Набор после отбора | [`output/avsDefaults-0-boundaryAware.json`](output/avsDefaults-0-boundaryAware.json) | JSON с выбранными тестами; его валидируют в PostgreSQL. Сам JSON формирует `run_matrix.ps1` по ID из отчёта C++. |
| Проверенный результат | [`output/avsDefaults-0-boundaryAware-validated.json`](output/avsDefaults-0-boundaryAware-validated.json), [`output/avsDefaults-0-boundaryAware-verify.json`](output/avsDefaults-0-boundaryAware-verify.json) | Набор с результатами PostgreSQL и итоговая повторная проверка покрытия. |
| PostgreSQL | [`postgres/schema.sql`](postgres/schema.sql), [`postgres/manual_null_oracle.sql`](postgres/manual_null_oracle.sql) | DDL таблиц эксперимента и отдельный `SELECT` для семи случаев с NULL. |
| Фактические ответы БД | [`postgres/avsDefaults-0-full-postgres.csv`](postgres/avsDefaults-0-full-postgres.csv), [`postgres/avsDefaults-0-boundaryAware-postgres.csv`](postgres/avsDefaults-0-boundaryAware-postgres.csv) | По одной строке на тест с ожидаемым/фактическим результатом, фазой, SQLSTATE и причиной отказа. |
| Параметры запуска | [`environment/environment.log`](environment/environment.log), [`environment/avsDefaults-0-generation.log`](environment/avsDefaults-0-generation.log) | Версии среды и параметры генерации. |
| Сравнение методов | [`summary/summary.csv`](summary/summary.csv) | Полная сводка исходной матрицы по четырём генераторам и семи вариантам отбора. Пути в ней указывают на компьютер, где был сделан этот запуск. |

SHA-256 файла `source/avsDefaults-0.ser`:

```text
dfa813b78e7a0ddc98d0e24220f2abbc8aa74f77d443cff69b69a074a7cbacb5
```

Это же значение записано в JSON-снимках. Таким образом можно проверить, что JSON и выходы редукторов относятся к одному исходному набору.

Файл `postgres/schema.sql` содержит структуру таблиц и ограничения, а не физический дамп PostgreSQL. Проверяемые строки уже содержатся в JSON; валидатор каждый раз пересоздаёт схему и выполняет их заново.

## Что показал этот пример

- SchemaAnalyst с `CondAICC`, генератором `avsDefaults`, seed `0` и бюджетом `10000` создал 24 `TestCase`.
- В исходном наборе было 30 строк `state` и 24 строки `data`; генерация заняла `144.6654 ms`.
- C++-редуктор выбрал 18 исходных тестов: 23 `state` и 18 `data` INSERT. Время `selectionNanoseconds` — `0.7494 ms`.
- Покрыты все 24 исходных требования и сохранены все 8 граничных наблюдений, доступных и подтверждённых в полном наборе.
- PostgreSQL подтвердил ожидаемый результат для всех 18 выбранных тестов.
- Статус `PASS_WITH_UNVERIFIED_CANDIDATES` не означает расхождение SQL: в 9 тестах полного набора были граничные кандидаты, которые не подтвердили целевой CHECK. Эти кандидаты не засчитывались; в отчёте остаются 8 подтверждённых обязательств.

## Проверка файлов на своём компьютере

Команды выполнять из корня репозитория в PowerShell. Нужны собранный C++-исполняемый файл и локальный PostgreSQL. Валидатор удаляет и создаёт заново схему `public` перед каждым тестом; используйте только отдельную тестовую базу без ценных данных. Подробные требования, настройка PostgreSQL и запуск полной матрицы описаны в [`docs/BUILD_AND_TESTS.md`](../../../../docs/BUILD_AND_TESTS.md).

Запустить C++-анализ сохранённого полного набора:

```powershell
$example = '.\test_suite_minimization\experiments\example-data\avsDefaults-seed0'
$exe = '.\test_suite_minimization\build\cpp\test_suite_minimization.exe'
& $exe `
  (Join-Path $example 'input\avsDefaults-0-full-validated.json') `
  '.\test_suite_minimization\build\cpp\example-full-report.json'
```

Проверить выбранный JSON в своей тестовой базе (подставьте свои адрес, порт, роль и пути к `psql.exe`/`createdb.exe`, если они отличаются):

```powershell
& '.\test_suite_minimization\experiments\validate_postgres.ps1' `
  -InputJson (Join-Path $example 'output\avsDefaults-0-boundaryAware.json') `
  -HostName '127.0.0.1' -Port 55432 `
  -User 'baseline' -Database 'coursework_validation' `
  -ResultPath '.\test_suite_minimization\build\example-boundaryAware-postgres.csv'
```

Команда проверки только читает и выполняет переданные тесты; DDL таблиц сценарий загружает из [`../../schema.sql`](../../schema.sql) относительно этой папки. Для нового полного прогона используйте `experiments/run_matrix.ps1`: он заново генерирует снимок и создаёт новую папку `experiments/results/matrix-*`.
