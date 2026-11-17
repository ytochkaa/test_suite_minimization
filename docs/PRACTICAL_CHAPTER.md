# Глава 2. Практическая часть

## 2.1. Задача и результат в двух словах

В практической части проверяется, можно ли уменьшить набор тестов SchemaAnalyst, сохранив полезное покрытие. Редуктор должен оставить:

1. все требования SchemaAnalyst, которые покрывал исходный набор;
2. все доступные в исходном наборе граничные наблюдения для поддерживаемых целочисленных сравнений.

В работе сравниваются штатные редукторы SchemaAnalyst и отдельный C++-прототип `boundaryAware`. PostgreSQL используется, чтобы проверить не только ожидаемый результат теста, но и фактическую причину отказа SQL.

Основная цепочка выглядит так:

```text
схема + критерий + генератор
          │
          ▼
SchemaAnalyst создаёт TestSuite ──► Java-снимок .ser
                                         │
                                         ▼
                              Java экспортирует JSON
                                         │
                      PostgreSQL проверяет каждый TestCase
                                         │
                                         ▼
                         C++ выбирает TestCase для сохранения
                                         │
                                         ▼
                   PostgreSQL и C++ повторно проверяют результат
```

Код SchemaAnalyst и его алгоритмы генерации и сокращения не изменялись. Добавлены только Java-обвязка для сохранения и экспорта снимка, C++-редуктор и сценарии эксперимента.

## 2.2. Термины на примере проекта

- **Схема базы данных** описывает таблицы, столбцы и ограничения. Например, `CHECK (amount >= 10)` задаёт правило для значений столбца `amount`.
- **Требование покрытия** — проверка, которую создаёт критерий SchemaAnalyst. Например, критерий может потребовать проверить успешный и неуспешный исход для условия.
- **`TestCase`** — один тестовый случай: какое состояние подготовить, какие данные вставить и какой результат ожидается.
- **`state`** — подготовительные строки. Например, строка родительской таблицы, на которую ссылается внешний ключ.
- **`data`** — проверяемые строки. Их вставка должна либо пройти, либо завершиться ожидаемым отказом.
- **`TestSuite`** — полный список `TestCase`, созданный одним запуском генератора.
- **Редуктор** выбирает тесты, которые нужно оставить. В этой работе выбираются целые `TestCase`, а не отдельные строки изнутри теста.
- **PostgreSQL oracle** — сама СУБД, используемая для проверки фактического результата SQL. Это важно, потому что вставка может быть отклонена не тем ограничением, которое проверяет тест.

Исходный набор создаётся один раз для каждой пары «генератор, seed». Все сравниваемые методы получают один и тот же снимок. В частности, результат `simpleGreedy` не подаётся на вход `additionalGreedy` или следующему методу.

## 2.3. Схема и тестовые данные

Для эксперимента создана Java-схема [`CourseworkSchema.java`](../test_suite_minimization/src/main/java/org/schemaanalyst/minimization/CourseworkSchema.java). Её SQL-эквивалент для PostgreSQL находится в [`schema.sql`](../test_suite_minimization/experiments/schema.sql).

В приложенной папке нет бинарной копии работающей PostgreSQL-базы. `schema.sql` — это DDL для создания таблиц и ограничений; сами тестовые строки и их SQL-вставки находятся в JSON-файлах. Валидатор создаёт отдельное чистое состояние базы для каждого TestCase.

В схеме две таблицы:

| Таблица | Столбцы и ограничения |
|---|---|
| `parent` | `id INTEGER PRIMARY KEY` |
| `sample` | `id` — первичный ключ; `parent_id` — внешний ключ на `parent.id`; `code` — UNIQUE; `amount` — NOT NULL; `ceiling` и `floor` допускают NULL |

Таблица `sample` содержит четыре CHECK:

| CHECK | Пример формы | Значение для опыта |
|---|---|---|
| `amount_min`: `amount >= 10` | `x op c` | сравнение столбца с константой |
| `amount_ceiling`: `amount <= ceiling` | `x op y` | сравнение двух столбцов |
| `ceiling_max`: `ceiling < 100` | `x op c` | сравнение столбца с константой |
| `floor_min`: `floor > 0` | `x op c` | сравнение столбца с константой |

Подготовительная строка `parent` в `state` нужна, чтобы вставка `sample` с `parent_id = 1` не завершилась ошибкой внешнего ключа. Строка `sample` в `data` — собственно проверяемый тест. Перед каждым TestCase валидатор очищает схему `public` и загружает DDL заново, поэтому данные одного теста не влияют на следующий.

### Пример одного теста

Исходный Java-объект сохраняется в бинарный `.ser`-снимок. Java-экспортёр создаёт JSON, который можно читать как текст. Ниже — сокращённый иллюстративный пример одной записи из его массива `tests`; полный JSON также содержит параметры генерации, описание схемы, список требований и SHA-256 исходного снимка.

```json
{
  "id": "T2",
  "sourceRequirementId": "R1",
  "coveredRequirementIds": ["R1"],
  "expectedResult": true,
  "state": [
    {"table": "parent", "values": {"id": "1"}}
  ],
  "data": [
    {
      "table": "sample",
      "values": {
        "id": "2",
        "parent_id": "1",
        "code": "2",
        "amount": "10",
        "ceiling": "50",
        "floor": "1"
      }
    }
  ],
  "stateSql": ["INSERT INTO parent (id) VALUES (1);"],
  "dataSql": [
    "INSERT INTO sample (id, parent_id, code, amount, ceiling, floor) VALUES (2, 1, 2, 10, 50, 1);"
  ],
  "stateInsertCount": 1,
  "dataInsertCount": 1
}
```

Сначала вставляется `parent(id=1)`, затем строка `sample`. Значения удовлетворяют внешнему ключу, уникальности, `NOT NULL` и всем четырём CHECK, поэтому в примере ожидается успешная вставка. Это пример структуры записи, а не утверждение, что именно этот TestCase входил в базовый запуск.

## 2.4. Какие границы сохраняет прототип

Прототип анализирует простые целочисленные сравнения с операторами `<`, `<=`, `>` и `>=` в формах `x op c` и `x op y`. Для них он вычисляет разность левого и правого операндов:

- для `x op c`: `d = x - c`;
- для `x op y`: `d = x - y`.

Наблюдаемыми числовыми категориями считаются `d = -1`, `d = 0` и `d = +1`: значение непосредственно до границы, на границе и после неё. Ключ в C++-отчёте включает ограничение, разность и результат сравнения, например `B|amount_min|0|true`. Значение истины зависит от оператора: для `x >= c` категории `-1`, `0`, `+1` дают `FALSE`, `TRUE`, `TRUE`; для `x < c` — `TRUE`, `FALSE`, `FALSE`.

Если операнд равен NULL, числовая разность не вычисляется. Прототип записывает отдельные категории `left-null`, `right-null` и `both-null` с результатом `unknown`. Это отдельные наблюдения SQL NULL, а не позиции −1, 0 или +1.

В PostgreSQL ограничение `CHECK` отклоняет строку, когда выражение равно `FALSE`; `TRUE` и `UNKNOWN` (результат сравнения с NULL) проходят. Поэтому вставка с NULL может быть успешной, но учитывается отдельно от числовой границы.

Число само по себе не доказывает покрытие целевого CHECK:

- C++ ищет значения в строках `data` нужной таблицы;
- если PostgreSQL принял тест, он должен совпадать с ожидаемым успешным результатом;
- если тест ожидал отказ, засчитывается только SQLSTATE `23514` и имя именно целевого CHECK;
- ошибка первичного/внешнего ключа, UNIQUE, NOT NULL или другого CHECK не подтверждает исследуемую границу.

Разность вычисляется в C++ типом `__int128`, чтобы вычитание значений `BIGINT` не переполнялось. Поддерживаются типы столбцов `INTEGER` и `BIGINT` и целые числовые константы. Не поддерживаются десятичные константы, `NUMERIC`, вещественные типы, арифметические выражения, функции SQL и составные условия CHECK с общим анализом `AND`/`OR`.

## 2.5. Какие файлы проходят через систему

В репозитории приложена папка с **реальными артефактами** запуска `avsDefaults`, seed `0`:

[`test_suite_minimization/experiments/example-data/avsDefaults-seed0/`](../test_suite_minimization/experiments/example-data/avsDefaults-seed0/)

| Шаг | Файл из папки | Кто создал и для чего он нужен |
|---|---|---|
| 1. Исходный набор | [`source/avsDefaults-0.ser`](../test_suite_minimization/experiments/example-data/avsDefaults-seed0/source/avsDefaults-0.ser) | Обвязка `GenerateBaselineSnapshot` запускает генерацию SchemaAnalyst и сериализует объекты схемы, требований и `TestSuite`. Это бинарный файл, не SQL и не JSON. |
| 2. Экспорт Java | [`input/avsDefaults-0-full.json`](../test_suite_minimization/experiments/example-data/avsDefaults-seed0/input/avsDefaults-0-full.json) | Java-обвязка переносит схему, требования, тесты, строки `state`/`data` и SQL в JSON. |
| 3. Вход C++ | [`input/avsDefaults-0-full-validated.json`](../test_suite_minimization/experiments/example-data/avsDefaults-seed0/input/avsDefaults-0-full-validated.json) | Тот же набор после PostgreSQL-проверки; содержит фактический результат и SQLSTATE. Именно этот файл передаётся C++ для исходного анализа. |
| 4. Отчёт C++ | [`output/avsDefaults-0-full-boundary-report.json`](../test_suite_minimization/experiments/example-data/avsDefaults-seed0/output/avsDefaults-0-full-boundary-report.json) | Содержит `selectedTestIds`, счётчики требований и границ, объяснения выбора и время отбора. C++ CLI выдаёт этот отчёт, а не переписанный TestSuite. |
| 5. Выбранный набор | [`output/avsDefaults-0-boundaryAware.json`](../test_suite_minimization/experiments/example-data/avsDefaults-seed0/output/avsDefaults-0-boundaryAware.json) | Сценарий `run_matrix.ps1` берёт ID из отчёта C++ и формирует JSON только с выбранными тестами. Этот файл затем проверяется PostgreSQL. |
| 6. Проверка выхода | [`output/avsDefaults-0-boundaryAware-validated.json`](../test_suite_minimization/experiments/example-data/avsDefaults-seed0/output/avsDefaults-0-boundaryAware-validated.json), [`output/avsDefaults-0-boundaryAware-verify.json`](../test_suite_minimization/experiments/example-data/avsDefaults-seed0/output/avsDefaults-0-boundaryAware-verify.json) | Первый содержит PostgreSQL evidence для выбранных тестов; второй — повторный отчёт покрытия после сокращения. |
| 7. Фактический результат БД | [`postgres/avsDefaults-0-full-postgres.csv`](../test_suite_minimization/experiments/example-data/avsDefaults-seed0/postgres/avsDefaults-0-full-postgres.csv), [`postgres/avsDefaults-0-boundaryAware-postgres.csv`](../test_suite_minimization/experiments/example-data/avsDefaults-seed0/postgres/avsDefaults-0-boundaryAware-postgres.csv) | По одной строке на TestCase: ожидаемый/фактический исход, фаза, SQLSTATE и сообщение об ошибке. |
| 8. Схема БД и NULL oracle | [`postgres/schema.sql`](../test_suite_minimization/experiments/example-data/avsDefaults-seed0/postgres/schema.sql), [`postgres/manual_null_oracle.sql`](../test_suite_minimization/experiments/example-data/avsDefaults-seed0/postgres/manual_null_oracle.sql) | DDL таблиц эксперимента и отдельный SELECT для семи случаев с NULL. |
| 9. Среда и полная сводка | [`environment/`](../test_suite_minimization/experiments/example-data/avsDefaults-seed0/environment/), [`summary/summary.csv`](../test_suite_minimization/experiments/example-data/avsDefaults-seed0/summary/summary.csv) | Версии ПО, параметры генерации и строки исходной матрицы по всем генераторам/редукторам. Абсолютные пути внутри CSV относятся к машине исходного запуска. |

SHA-256 файла `.ser` равен `dfa813b78e7a0ddc98d0e24220f2abbc8aa74f77d443cff69b69a074a7cbacb5`. Такое же значение записано в JSON-снимках: оно позволяет убедиться, что сравниваемые редукторы получили один исходный набор.

## 2.6. Как работает сокращение

Из полного набора формируются два множества:

- `R` — требования SchemaAnalyst, для которых Java-экспортёр нашёл покрывающий тест;
- `B` — граничные наблюдения, найденные в исходных данных и подтверждённые PostgreSQL.

Цель — выбрать тесты, покрытие которых вместе содержит `U = R ∪ B`. Отбор `boundaryAware` выполняется так:

1. Из JSON строится покрытие каждого TestCase. Требования берутся из `coveredRequirementIds`, рассчитанных Java-экспортёром через `PredicateChecker`; C++ не исполняет заново произвольные Java-предикаты.
2. Граничные наблюдения вычисляются по значениям теста. Неподтверждённые PostgreSQL кандидаты в `B` не входят и отдельно попадают в отчёт.
3. Сначала сохраняются тесты, которые являются единственными свидетелями хотя бы одного требования или границы.
4. Затем добавляются тесты с наибольшим количеством ещё не покрытых требований и границ.
5. При равном выигрыше выбирается тест с меньшим числом `state` + `data` INSERT, а затем с меньшим ID.
6. После жадного выбора алгоритм в обратном порядке удаляет тест, если покрытие `U` от этого не меняется.

Алгоритм детерминирован для одного входного JSON, но это жадная минимизация, а не доказательство глобально минимального по размеру набора. В отличие от него, штатный STICCER может объединять тесты и создавать новые сочетания данных; для остальных штатных редукторов каждый запуск заново загружает один и тот же `.ser`.

Проверка требований имеет важное ограничение: C++ проверяет сохранение переданных Java-идентификаторов, а не самих SQL-предикатов. Для штатных Java-редукторов экспортёр заново считает покрытие тестов через `PredicateChecker`. Для boundary-aware результата сценарий повторно запускает C++ на выбранном JSON и сравнивает наборы требований и подтверждённых границ с исходными.

## 2.7. Результат реального примера

Запуск выполнен 17.11.2026 на Windows, с `CondAICC`, `avsDefaults`, seed `0` и бюджетом `10000`. Полная таблица измерений находится в [`RESULTS_BASELINE.md`](./RESULTS_BASELINE.md); ниже приведена одна строка для приложенного примера.

| Метрика | Исходный набор | После `boundaryAware` |
|---|---:|---:|
| `TestCase` | 24 | 18 |
| `state` INSERT | 30 | 23 |
| `data` INSERT | 24 | 18 |
| Требования SchemaAnalyst | 24 | 24 |
| Подтверждённые граничные наблюдения | 8 | 8 |
| PostgreSQL: тестов с ожидаемым фактом | 24/24 | 18/18 |

Генерация заняла `144.6654 ms`, отбор — `0.7494 ms`. Время не включает запуск JVM и PostgreSQL-валидацию. Итоговый статус — `PASS_WITH_UNVERIFIED_CANDIDATES`: все требования, 8 исходных границ и 18 PostgreSQL-результатов подтверждены, но у 9 тестов полного набора были кандидаты границ, не подтверждённые целевым CHECK. Эти кандидаты не засчитывались как границы.

Это результат одного seed и одной схемы, а не статистическое доказательство превосходства редуктора. В полном прогоне использованы четыре генератора и шесть штатных методов; подробные потери требований и границ по каждой комбинации приведены в baseline-отчёте.

## 2.8. Как запустить тесты локально

Все команды ниже запускаются в PowerShell из корня репозитория.

### 2.8.1. Подготовить программы

Нужны:

- JDK 8 (проверенный запуск использовал Temurin 8u512); Gradle поставлять отдельно не нужно, используется wrapper;
- CMake, Ninja и C++17-компилятор (проверялись MSYS2 MinGW-w64);
- PostgreSQL и утилиты `psql.exe`, `createdb.exe`;
- PowerShell 5.1 или новее.

Собрать SchemaAnalyst и Java-обвязку:

```powershell
.\SchemaAnalyst\gradlew.bat -p .\SchemaAnalyst compile --offline --no-daemon
```

Если нужных Gradle-зависимостей нет в локальном кеше, повторите без `--offline`. Полный `test` SchemaAnalyst — отдельный шаг: на проверенной среде он завершился с 15 известными ошибками из 1715 тестов; причины перечислены в `RESULTS_BASELINE.md`. Эти старые тесты не являются PostgreSQL-проверкой приложенного примера.

Собрать C++ и выполнить его CTest:

```powershell
.\test_suite_minimization\experiments\run_cpp_checks.ps1
```

Этот скрипт также запускает C++ на небольшой фикстуре. В нём заданы пути к CMake, MinGW и CTest для проверенной конфигурации `C:\msys64`; для другой установки измените переменные в начале `run_cpp_checks.ps1`.

### 2.8.2. Подготовить отдельную PostgreSQL-базу

В базовом прогоне использовались адрес `127.0.0.1`, порт `55432`, пользователь `baseline` и база `coursework_validation`. Порт и пути к PostgreSQL можно изменить параметрами сценария. Роль `baseline` должен создать администратор PostgreSQL, например:

```powershell
$psql = 'C:\Program Files\PostgreSQL\18\bin\psql.exe'
& $psql -h 127.0.0.1 -p 55432 -U postgres -d postgres `
  -c 'CREATE ROLE baseline LOGIN CREATEDB;'
```

Если роль уже существует, вместо `CREATE ROLE` задайте ей `LOGIN` и `CREATEDB` через `ALTER ROLE`. При парольной аутентификации сохраните пароль в стандартном `pgpass.conf`, потому что сценарии запускают `psql`/`createdb` без интерактивного запроса.

**Используйте только отдельную тестовую базу без ценных данных.** `validate_postgres.ps1` перед каждым тестом выполняет `DROP SCHEMA public CASCADE`, затем создаёт `public` заново и подключает `experiments/schema.sql`. Нельзя указывать рабочую базу с пользовательскими таблицами. Если базы `coursework_validation` ещё нет, валидатор создаст её; для этого у роли должно быть право `CREATEDB`.

### 2.8.3. Проверить приложенные реальные файлы

Сначала повторно запустите C++ на исходном JSON с PostgreSQL evidence. Команда пишет новый отчёт в игнорируемую папку сборки и не меняет приложенные исходные файлы:

```powershell
$example = '.\test_suite_minimization\experiments\example-data\avsDefaults-seed0'
$exe = '.\test_suite_minimization\build\cpp\test_suite_minimization.exe'
& $exe `
  (Join-Path $example 'input\avsDefaults-0-full-validated.json') `
  '.\test_suite_minimization\build\cpp\example-full-report.json'
```

В отчёте должны быть 24 исходных теста, 24 требования и 8 подтверждённых границ; `selectedTestCount` должен быть равен 18. C++-программа пишет выбранные ID в отчёт, но не формирует JSON сокращённого набора: приложенный `output/avsDefaults-0-boundaryAware.json` создан оркестратором `run_matrix.ps1` по этим ID.

Проверить выбранный набор в своей тестовой базе:

```powershell
& '.\test_suite_minimization\experiments\validate_postgres.ps1' `
  -InputJson (Join-Path $example 'output\avsDefaults-0-boundaryAware.json') `
  -HostName '127.0.0.1' -Port 55432 `
  -User 'baseline' -Database 'coursework_validation' `
  -ResultPath '.\test_suite_minimization\build\example-boundaryAware-postgres.csv'
```

При другой установке PostgreSQL передайте также `-Psql` и `-Createdb`. Полученный CSV будет содержать одну строку на выбранный тест. Скрипт ожидает фактический результат каждой вставки и завершится ошибкой, если найдёт несовпадение.

Дополнительный ручной NULL oracle — это только `SELECT`, он не изменяет таблицы:

```powershell
& $psql -X -h 127.0.0.1 -p 55432 -U baseline -d coursework_validation `
  -f '.\test_suite_minimization\experiments\example-data\avsDefaults-seed0\postgres\manual_null_oracle.sql'
```

Ожидается семь строк, в которых `actual_accept` совпадает с `expected_accept`.

### 2.8.4. Сгенерировать новую матрицу целиком

Для нового запуска сценарий сам собирает C++, компилирует Java-обвязку, генерирует один `.ser` на комбинацию «генератор, seed», выполняет PostgreSQL-проверки, запускает все редукторы независимо и сохраняет результаты. Передайте путь к JDK 8 и параметры своей тестовой базы:

```powershell
$javaHome = 'C:\Program Files\Eclipse Adoptium\jdk-8'
$script = (Resolve-Path '.\test_suite_minimization\experiments\run_matrix.ps1').Path
$commandText = "& '$script' -JavaHome '$javaHome' -PostgresPort 55432 -PostgresUser baseline -PostgresDatabase coursework_validation -Generators @('avsDefaults') -Seeds @(0) -Budget 10000"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $commandText
```

Для полной исходной матрицы замените `@('avsDefaults')` на `@('avsDefaults','randomDefaults','dominoRandom','dominoAVS')`. Скрипт создаёт новую папку `test_suite_minimization/experiments/results/matrix-*`; этот каталог исключён из Git. В начале `run_matrix.ps1` при необходимости исправьте пути к `cmake.exe`, `g++.exe`, `ctest.exe`, `psql.exe` и `createdb.exe`.

В `summary.csv` проверьте `status`, `postgres_status`, число тестов, требования до/после и потерянные границы. Не трактуйте отсутствие файла или строки как нулевой результат. `PASS_WITH_UNVERIFIED_CANDIDATES` означает, что подтверждённые обязательства сохранены и SQL совпал с ожиданиями, но в исходном наборе остались кандидаты, которые не подтвердили целевой CHECK.

## 2.9. Ограничения и вывод

- Подробно измерен один seed для одной схемы; выводы относятся к этим входным данным.
- Если значение −1, 0 или +1 не встретилось в исходном наборе, эксперимент не доказывает, что его невозможно сгенерировать.
- Покрытие обычных требований в C++ основано на `coveredRequirementIds` Java-экспортёра; C++ не является независимым исполнителем произвольных предикатов SchemaAnalyst.
- Граничный анализ ограничен простыми целочисленными CHECK. Составные логические выражения, арифметика и другие SQL-типы требуют отдельной реализации и проверки.
- Результат `boundaryAware` показывает, что на данном примере можно сохранить все найденные требования и подтверждённые границы при меньшем числе тестов. Один прогон не доказывает универсальную эффективность и не гарантирует оптимальное решение.

Практическая цепочка от генерации до PostgreSQL-проверки воспроизводима и приложена в виде файлов реального запуска. Следующий корректный шаг для обобщающего вывода — заранее задать несколько seeds и схем, повторить матрицу без изменения условий и отдельно учитывать только PostgreSQL-подтверждённые границы.
