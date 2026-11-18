# Глава 2. Практическая часть

## 2.1. Задача и результат в двух словах

В практической части проверяется, можно ли уменьшить набор тестов SchemaAnalyst, сохранив полезное покрытие. Редуктор должен оставить:

1. все требования SchemaAnalyst, которые покрывал исходный набор;
2. все доступные в исходном наборе граничные наблюдения для поддерживаемых целочисленных сравнений.

В работе сравниваются штатные алгоритмы сокращения тестового набора SchemaAnalyst и отдельный C++-прототип `boundaryAware`. PostgreSQL используется, чтобы проверить не только ожидаемый результат теста, но и фактическую причину отказа SQL.

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

Код SchemaAnalyst и его алгоритмы генерации и сокращения не изменялись. Добавлены только Java-обвязка для сохранения и экспорта снимка, C++-алгоритм сокращения тестового набора и сценарии эксперимента.

### Этапы практической реализации

1. **Подготовлена предметная схема.** В Java и PostgreSQL согласованы девять таблиц, их первичные и внешние ключи, а также целочисленные ограничения `CHECK`, на которых можно наблюдать значения до границы, на границе и после неё.
2. **Собрана среда запуска.** SchemaAnalyst компилируется с JDK 8; C++-часть собирается CMake и проверяется через CTest; PostgreSQL используется как независимая база для исполнения SQL.
3. **Сгенерированы исходные наборы тестов.** Для каждой пары «генератор, seed» SchemaAnalyst один раз создаёт `TestSuite`. В эксперименте используются `CondAICC` и четыре генератора: `avsDefaults`, `randomDefaults`, `dominoRandom`, `dominoAVS`.
4. **Зафиксирован общий вход для сравнения.** Исходный `TestSuite` сохраняется в `.ser`, затем Java-обвязка экспортирует его в JSON. Снимок не меняется между сравниваемыми запусками; его SHA-256 позволяет проверить, что вход одинаков.
5. **Проверены исходные тесты в PostgreSQL.** Выполняются подготовительные вставки `state` и проверяемые вставки `data`. Для каждого теста фиксируются ожидаемый исход, фактический результат, SQLSTATE и сообщение PostgreSQL. Граница учитывается только тогда, когда наблюдение подтверждено выполнением именно целевого ограничения.
6. **Запущены способы сокращения независимо.** Контрольный режим `none` (без сокращения), каждый штатный алгоритм (`simpleGreedy`, `additionalGreedy`, `HGS`, `random`, `STICCER`) и `boundaryAware` получают отдельную загрузку одного и того же исходного снимка. Результат одного способа не используется как вход для другого.
7. **Проверено сохранение покрытия и границ.** Для каждого результата сравниваются требования SchemaAnalyst и подтверждённые граничные наблюдения с исходным набором. Для `boundaryAware` дополнительно проверяется, что выбранные тесты вместе покрывают все исходные требования и границы.
8. **Повторно исполнены выбранные тесты и собраны метрики.** PostgreSQL перепроверяет каждый выбранный `TestCase`; результаты сверяются с ожидаемыми. Для каждого запуска сохраняются размер набора, число `state`/`data` INSERT, время генерации и сокращения, покрытие, границы и фактические ответы PostgreSQL.
9. **Сформулированы выводы с ограничениями.** Подтверждённые факты отделяются от предположений; потери требований и границ указываются для каждого метода. Отсутствие результата не трактуется как нулевой показатель или как доказательство потери покрытия.

## 2.2. Термины на примере проекта

- **Схема базы данных** описывает таблицы, столбцы и ограничения. Например, `CHECK (quantity_of_goods >= 0)` запрещает отрицательный остаток товара.
- **Требование покрытия** — проверка, которую создаёт критерий SchemaAnalyst. Например, критерий может потребовать проверить успешный и неуспешный исход для условия.
- **`TestCase`** — один тестовый случай: какое состояние подготовить, какие данные вставить и какой результат ожидается.
- **`state`** — подготовительные строки. Например, строка родительской таблицы, на которую ссылается внешний ключ.
- **`data`** — проверяемые строки. Их вставка должна либо пройти, либо завершиться ожидаемым отказом.
- **`TestSuite`** — полный список `TestCase`, созданный одним запуском генератора.
- **Алгоритм сокращения тестового набора** выбирает тесты, которые нужно оставить. В этой работе выбираются целые `TestCase`, а не отдельные строки изнутри теста.
- **PostgreSQL oracle** — сама СУБД, используемая для проверки фактического результата SQL. Это важно, потому что вставка может быть отклонена не тем ограничением, которое проверяет тест.

Исходный набор создаётся один раз для каждой пары «генератор, seed». Все сравниваемые методы получают один и тот же снимок. В частности, результат `simpleGreedy` не подаётся на вход `additionalGreedy` или следующему методу.

## 2.3. Схема и тестовые данные

Для эксперимента используется предметная схема лаборатории, оборудования и торговых автоматов. Java-описание находится в [`CourseworkSchema.java`](../test_suite_minimization/src/main/java/org/schemaanalyst/minimization/CourseworkSchema.java), а соответствующий DDL для PostgreSQL — в [`schema.sql`](../test_suite_minimization/experiments/schema.sql). Java- и SQL-описания задают одни и те же таблицы и ограничения.

В модели девять таблиц:

| Таблица | Назначение, ключи и основные поля |
|---|---|
| `employees` | Сотрудники: `employee_id` — PK; должность, ФИО, паспортные сведения, СНИЛС, ИНН и даты. Паспортные номера, СНИЛС и ИНН хранятся как текст, чтобы не потерять формат и ведущие нули. |
| `laboratories` | Лаборатории: `laboratory_id` — PK; спецификация. |
| `employee_laboratories` | Связь сотрудника с лабораторией: составной PK `(employee_id, laboratory_id)`; оба поля — FK. Это таблица-связка `e_l` с диаграммы и позволяет сотруднику работать в нескольких лабораториях. |
| `equipment` | Оборудование: `equipment_id` — PK; название, описание, сертификат; `laboratory_id` — FK на лабораторию. |
| `users` | Пользователи: `user_id` — PK; СНИЛС и ФИО. В перечне полей указан СНИЛС; поле ИНН с картинки в эту таблицу не добавлено. |
| `automatons_food` | Торговые автоматы: `vending_machine_id` — PK; модель и тип; `laboratory_id` — FK на лабораторию. |
| `goods` | Товары: `product_id` — PK; название. |
| `vending_machines_goods` | Ассортимент и остаток в автомате: составной PK `(vending_machine_id, goods_id)`; оба поля — FK; количество, вместимость и цена. |
| `users_equipment` | Выдача оборудования пользователям: `user_id` и `equipment_id` — FK; время выдачи и возврата. Составной PK `(user_id, equipment_id, start_time)` позволяет хранить разные периоды выдачи одной пары. |

Связи на диаграмме отражены так: лаборатория связана с оборудованием и автоматами отношением «один ко многим»; сотрудники и лаборатории связаны «многие ко многим» через `employee_laboratories`; автоматы и товары — «многие ко многим» через `vending_machines_goods`; пользователи и оборудование — через `users_equipment`. Названия столбцов приведены к единому `snake_case`; `laboratory_number` с текстового списка нормализован до `laboratory_id`, как на диаграмме и в первичном ключе лаборатории.

В `vending_machines_goods` добавлено согласованное для тестов поле `stock_capacity`: максимальное количество данного товара в конкретном автомате. Оно нужно для проверки осмысленного сравнения количества с другим целочисленным полем. Правила таблицы:

| CHECK | Форма | Смысл |
|---|---|---|
| `quantity_nonnegative`: `quantity_of_goods >= 0` | `x op c` | Остаток не может быть отрицательным. |
| `stock_capacity_positive`: `stock_capacity > 0` | `x op c` | Вместимость должна быть положительной. |
| `quantity_within_capacity`: `quantity_of_goods <= stock_capacity` | `x op y` | Остаток не должен превышать вместимость. |

Ограниченные значения `quantity_of_goods` и `stock_capacity` объявлены `NOT NULL`: в PostgreSQL CHECK с результатом `UNKNOWN` (например, из-за NULL) не отклоняет строку. Цена хранится как `NUMERIC(10,2)`, но не участвует в boundary-анализе: текущий прототип обрабатывает только целочисленные сравнения. Поля `passport_date` и `hire_date` имеют тип DATE, а периоды выдачи — TIMESTAMP.

В приложенной папке нет бинарной копии работающей PostgreSQL-базы. `schema.sql` — это DDL для её создания; строки состояния и тестовые SQL-вставки находятся в JSON. Валидатор очищает схему `public` и создаёт её заново перед каждым TestCase, поэтому данные разных тестов не смешиваются. Использовать для валидации следует только отдельную тестовую базу.

### Пример одного теста

Исходный Java-объект сохраняется в бинарный `.ser`-снимок. Java-экспортёр создаёт JSON, который можно читать как текст. Ниже приведён реальный TestCase `T45` из полного запуска `avsDefaults`, seed `0`. JSON также содержит параметры генерации, описание схемы, список требований и SHA-256 исходного снимка.

```json
{
  "id": "T45",
  "sourceRequirementId": "R45",
  "coveredRequirementIds": ["R45", "R47", "R49", "R51", "R53"],
  "expectedResult": true,
  "state": [
    {"table": "automatons_food", "values": {"vending_machine_id": "0", "vending_machine_model": "''", "type_of_vending_machine": "''", "laboratory_id": "0"}},
    {"table": "goods", "values": {"product_id": "0", "product_name": "''"}},
    {"table": "laboratories", "values": {"laboratory_id": "0", "laboratory_specification": "''"}}
  ],
  "data": [
    {
      "table": "vending_machines_goods",
      "values": {
        "vending_machine_id": "0",
        "goods_id": "0",
        "quantity_of_goods": "0",
        "stock_capacity": "1",
        "price": "0"
      }
    }
  ],
  "stateSql": [
    "INSERT INTO \"laboratories\"(\"laboratory_id\", \"laboratory_specification\") VALUES (0, '');",
    "INSERT INTO \"automatons_food\"(\"vending_machine_id\", \"vending_machine_model\", \"type_of_vending_machine\", \"laboratory_id\") VALUES (0, '', '', 0);",
    "INSERT INTO \"goods\"(\"product_id\", \"product_name\") VALUES (0, '');"
  ],
  "dataSql": [
    "INSERT INTO \"vending_machines_goods\"(\"vending_machine_id\", \"goods_id\", \"quantity_of_goods\", \"stock_capacity\", \"price\") VALUES (0, 0, 0, 1, 0);"
  ],
  "stateInsertCount": 3,
  "dataInsertCount": 1
}
```

Сначала в `state` создаются лаборатория, автомат и товар, на которые ссылается строка в `data`. Для `T45` остаток равен нулю, вместимость равна единице, и вставка проходит все три CHECK. Это фрагмент реального экспорта; полный TestCase и его проверка сохранены в приложенной папке примера.

## 2.4. Какие границы сохраняет прототип

Прототип анализирует простые целочисленные сравнения с операторами `<`, `<=`, `>` и `>=` в формах `x op c` и `x op y`. Для них он вычисляет разность левого и правого операндов:

- для `x op c`: `d = x - c`;
- для `x op y`: `d = x - y`.

Наблюдаемыми числовыми категориями считаются `d = -1`, `d = 0` и `d = +1`: значение непосредственно до границы, на границе и после неё. Ключ в C++-отчёте включает ограничение, разность и результат сравнения, например `B|quantity_nonnegative|0|true`. Значение истины зависит от оператора: для `x >= c` категории `-1`, `0`, `+1` дают `FALSE`, `TRUE`, `TRUE`; для `x < c` — `TRUE`, `FALSE`, `FALSE`.

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
| 8. Схема БД и NULL oracle | [`postgres/schema.sql`](../test_suite_minimization/experiments/example-data/avsDefaults-seed0/postgres/schema.sql), [`postgres/manual_null_oracle.sql`](../test_suite_minimization/experiments/example-data/avsDefaults-seed0/postgres/manual_null_oracle.sql) | DDL девяти таблиц и отдельный SELECT для десяти случаев с NULL и граничными числами. |
| 9. Среда и полная сводка | [`environment/`](../test_suite_minimization/experiments/example-data/avsDefaults-seed0/environment/), [`summary/summary.csv`](../test_suite_minimization/experiments/example-data/avsDefaults-seed0/summary/summary.csv) | Версии ПО, параметры генерации и строки исходной матрицы по всем генераторам и алгоритмам сокращения. Абсолютные пути внутри CSV относятся к машине исходного запуска. |

SHA-256 файла `.ser` равен `1a9f8393d85e3b941d66cc26309ad34b014dd644a1d57abfbfb1bd25e9e02f36`. Такое же значение записано в JSON-снимках: оно позволяет убедиться, что все сравниваемые способы сокращения получили один исходный набор.

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

Алгоритм детерминирован для одного входного JSON, но это жадная минимизация, а не доказательство глобально минимального по размеру набора. В отличие от него, штатный STICCER может объединять тесты и создавать новые сочетания данных; каждый штатный алгоритм сокращения запускается с повторной загрузкой одного и того же `.ser`.

Проверка требований имеет важное ограничение: C++ проверяет сохранение переданных Java-идентификаторов, а не самих SQL-предикатов. Для штатных Java-алгоритмов сокращения экспортёр заново считает покрытие тестов через `PredicateChecker`. Для `boundaryAware` сценарий повторно запускает C++ на выбранном JSON и сравнивает наборы требований и подтверждённых границ с исходными.

## 2.7. Результат реального примера

Запуск выполнен 18.11.2026 на Windows, с `CondAICC`, `avsDefaults`, seed `0` и бюджетом `10000`. Полная таблица измерений находится в [`RESULTS_BASELINE.md`](./RESULTS_BASELINE.md); ниже приведены данные для приложенного реального примера.

| Метрика | Исходный набор | После `boundaryAware` |
|---|---:|---:|
| `TestCase` | 54 | 48 |
| `state` INSERT | 122 | 105 |
| `data` INSERT | 66 | 60 |
| Требования SchemaAnalyst | 54 | 54 |
| Подтверждённые граничные наблюдения | 5 | 5 |
| PostgreSQL: тестов с ожидаемым фактом | 54/54 | 48/48 |

Генерация заняла `147.6211 ms`, отбор — `2.7042 ms`. Время не включает запуск JVM и PostgreSQL-валидацию. Итоговый статус — `PASS_WITH_UNVERIFIED_CANDIDATES`: все требования, 5 исходных границ и 48 PostgreSQL-результатов подтверждены, но у 9 тестов полного набора были кандидаты границ, не подтверждённые целевым CHECK. Эти кандидаты не засчитывались как границы.

Это результат одного seed и одной схемы, а не статистическое доказательство превосходства какого-либо способа сокращения. В полном прогоне использованы четыре генератора и шесть штатных методов; подробные потери требований и границ по каждой комбинации приведены в baseline-отчёте.

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

Если нужных Gradle-зависимостей нет в локальном кеше, повторите без `--offline`. Полный `test` SchemaAnalyst — отдельный шаг и в этой проверке не запускался; предыдущий полный прогон содержал известные проблемы в старых unit-тестах. Успешный `compile` и PostgreSQL-матрица не означают, что весь unit-набор прошёл.

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

В отчёте должны быть 54 исходных теста, 54 требования и 5 подтверждённых границ; `selectedTestCount` должен быть равен 48. C++-программа пишет выбранные ID в отчёт, но не формирует JSON сокращённого набора: приложенный `output/avsDefaults-0-boundaryAware.json` создан оркестратором `run_matrix.ps1` по этим ID.

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

Ожидается десять строк, в которых `actual_accept` совпадает с `expected_accept`. Запрос отдельно показывает, как SQL CHECK оценивает комбинации чисел и NULL; `NOT NULL` проверяется вставками в саму таблицу.

### 2.8.4. Сгенерировать новую матрицу целиком

Для нового запуска сценарий сам собирает C++, компилирует Java-обвязку, генерирует один `.ser` на комбинацию «генератор, seed», выполняет PostgreSQL-проверки, запускает все алгоритмы сокращения независимо и сохраняет результаты. Передайте путь к JDK 8 и параметры своей тестовой базы:

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
