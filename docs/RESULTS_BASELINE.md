# Результаты базовых экспериментов

Дата прогона: 17.11.2026. Полный набор артефактов и исходные логи: [experiments/results/matrix-20261117-025251-6b4a30af](../test_suite_minimization/experiments/results/matrix-20261117-025251-6b4a30af). Сводная таблица: [summary.csv](../test_suite_minimization/experiments/results/matrix-20261117-025251-6b4a30af/summary.csv).

Пути в сохранённых командах и сообщениях об ошибках отражают фактические запуски до реорганизации каталогов. Актуальные команды приведены в [BUILD_AND_TESTS.md](./BUILD_AND_TESTS.md).

## Условия и воспроизводимость

- SchemaAnalyst, критерий `CondAICC`, схема `CourseworkSchema`, seed `0`, budget `10000`, `readability=false`, `fullreduce=false`.
- Генераторы: `avsDefaults`, `randomDefaults`, `dominoRandom`, `dominoAVS`.
- Штатные методы: `none`, `simpleGreedy`, `additionalGreedy`, `HGS`, `random`, `sticcer`; дополнительно проверен `boundaryAware`.
- Среда: Windows NT 10.0.26200.0; Windows PowerShell 5.1.26100.9818; Eclipse Temurin JDK 8u512-b09; Gradle wrapper 4.10.2; PostgreSQL 18.7 x64 на `127.0.0.1:55432`; MSYS2 g++ 16.2.0; CMake 4.4.3.
- Успешная команда матрицы:

  ```powershell
  $script = 'C:\Users\Dashyla\Desktop\computer_security\8_semester\Courswork\test_suite_minimization\experiments\run_matrix.ps1'
  $commandText = "& '$script' -Generators @('avsDefaults','randomDefaults','dominoRandom','dominoAVS') -Seeds @(0) -Budget 10000"
  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $commandText
  ```

Для каждой пары «генератор, seed» набор создавался один раз в `.ser`. Каждый штатный редуктор отдельно открывал этот файл через `ObjectInputStream`; он не получал результат предыдущего редуктора. В каждом отчёте одной группы `snapshot_sha256` совпадает:

| Генератор | Исходных тестов | state/data INSERT | Требований | Подтверждённых наблюдаемых границ | SHA-256 снимка |
|---|---:|---:|---:|---:|---|
| `avsDefaults` | 24 | 30 / 24 | 24 | 8 | `dfa813b78e7a0ddc98d0e24220f2abbc8aa74f77d443cff69b69a074a7cbacb5` |
| `randomDefaults` | 24 | 30 / 24 | 24 | 5 | `cacb2605e2c8ad50053afb7962dea579de463cfce82972937ae4948c085e5154` |
| `dominoRandom` | 24 | 30 / 24 | 24 | 5 | `738f1477ed25f1fee19247f02c95ee29b64b12236c4bd7a0a449853a93ee31b3` |
| `dominoAVS` | 16 | 16 / 16 | 16 | 3 | `d0d4ff50938264a37e6f1643150a9c17a2597faf97f849887b36fb899e12e5d6` |

Время генерации измерено внутри `TestSuiteGenerator.generate()`. Время штатного сокращения измерено вокруг вызова Java reducer; для `boundaryAware` указано время выбора C++-редуктора. Эти значения не включают PostgreSQL-валидацию и запуск JVM. `none` также имеет небольшое ненулевое время обвязки.

## Подтверждённые результаты

Сокращение размера показано как `финал/исходно`; вставки — отдельно для `state` и `data`. `Требования` — число сохранившихся/исходных SchemaAnalyst requirements. `Границы` — число всех подтверждённых наблюдений после редуктора / число наблюдений исходного набора; STICCER может породить дополнительные наблюдения. Все строки PostgreSQL в таблице совпали с ожидаемым результатом.

### `avsDefaults`

Время генерации: **144.665 ms**; исходно 24 теста, 30 `state` и 24 `data` INSERT.

| Редуктор | TestCase | state INSERT | data INSERT | Сокращение, ms | Требования | Границы | PostgreSQL | Неподтверждённые кандидаты |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `none` | 24/24 | 30/30 | 24/24 | 0.007 | 24/24 | 8/8 | 24/24 | 9 |
| `simpleGreedy` | 17/24 | 22/30 | 17/24 | 77.105 | 24/24 | 5/8 | 17/17 | 9 |
| `additionalGreedy` | 17/24 | 22/30 | 17/24 | 79.232 | 24/24 | 5/8 | 17/17 | 9 |
| `HGS` | 17/24 | 22/30 | 17/24 | 68.338 | 24/24 | 6/8 | 17/17 | 9 |
| `random` | 17/24 | 22/30 | 17/24 | 68.543 | 24/24 | 6/8 | 17/17 | 9 |
| `sticcer` | 10/24 | 13/30 | 17/24 | 87.945 | 7/24 | 5/8 | 10/10 | 6 |
| `boundaryAware` | 18/24 | 23/30 | 18/24 | 0.749 | 24/24 | 8/8 | 18/18 | 9 |

### `randomDefaults`

Время генерации: **837.871 ms**; исходно 24 теста, 30 `state` и 24 `data` INSERT.

| Редуктор | TestCase | state INSERT | data INSERT | Сокращение, ms | Требования | Границы | PostgreSQL | Неподтверждённые кандидаты |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `none` | 24/24 | 30/30 | 24/24 | 0.007 | 24/24 | 5/5 | 24/24 | 6 |
| `simpleGreedy` | 18/24 | 23/30 | 18/24 | 73.590 | 24/24 | 5/5 | 18/18 | 6 |
| `additionalGreedy` | 17/24 | 22/30 | 17/24 | 84.614 | 24/24 | 5/5 | 17/17 | 6 |
| `HGS` | 16/24 | 21/30 | 16/24 | 67.736 | 24/24 | 5/5 | 16/16 | 6 |
| `random` | 18/24 | 23/30 | 18/24 | 67.757 | 24/24 | 5/5 | 18/18 | 6 |
| `sticcer` | 8/24 | 11/30 | 17/24 | 92.518 | 9/24 | 6/5 | 8/8 | 3 |
| `boundaryAware` | 16/24 | 21/30 | 16/24 | 0.519 | 24/24 | 5/5 | 16/16 | 6 |

### `dominoRandom`

Время генерации: **72.647 ms**; исходно 24 теста, 30 `state` и 24 `data` INSERT.

| Редуктор | TestCase | state INSERT | data INSERT | Сокращение, ms | Требования | Границы | PostgreSQL | Неподтверждённые кандидаты |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `none` | 24/24 | 30/30 | 24/24 | 0.007 | 24/24 | 5/5 | 24/24 | 9 |
| `simpleGreedy` | 18/24 | 23/30 | 18/24 | 76.388 | 24/24 | 5/5 | 18/18 | 9 |
| `additionalGreedy` | 18/24 | 23/30 | 18/24 | 79.350 | 24/24 | 5/5 | 18/18 | 9 |
| `HGS` | 17/24 | 22/30 | 17/24 | 65.961 | 24/24 | 5/5 | 17/17 | 9 |
| `random` | 18/24 | 23/30 | 18/24 | 63.933 | 24/24 | 5/5 | 18/18 | 9 |
| `sticcer` | 7/24 | 10/30 | 18/24 | 86.093 | 4/24 | 5/5 | 7/7 | 3 |
| `boundaryAware` | 17/24 | 22/30 | 17/24 | 0.652 | 24/24 | 5/5 | 17/17 | 9 |

### `dominoAVS`

Время генерации: **447.058 ms**; исходно 16 тестов, 16 `state` и 16 `data` INSERT.

| Редуктор | TestCase | state INSERT | data INSERT | Сокращение, ms | Требования | Границы | PostgreSQL | Неподтверждённые кандидаты |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `none` | 16/16 | 16/16 | 16/16 | 0.010 | 16/16 | 3/3 | 16/16 | 6 |
| `simpleGreedy` | 12/16 | 12/16 | 12/16 | 65.745 | 16/16 | 3/3 | 12/12 | 6 |
| `additionalGreedy` | 12/16 | 12/16 | 12/16 | 80.745 | 16/16 | 3/3 | 12/12 | 6 |
| `HGS` | 11/16 | 11/16 | 11/16 | 62.618 | 16/16 | 3/3 | 11/11 | 6 |
| `random` | 11/16 | 11/16 | 11/16 | 62.663 | 16/16 | 3/3 | 11/11 | 6 |
| `sticcer` | 5/16 | 5/16 | 12/16 | 73.079 | 5/16 | 4/3 | 5/5 | 2 |
| `boundaryAware` | 11/16 | 11/16 | 11/16 | 0.350 | 16/16 | 3/3 | 11/11 | 6 |

### Потерянные и добавленные наблюдения

Все обозначения `B|check|distance|truth` получены из исходных тестов и подтверждены фактическим результатом PostgreSQL. Отрицательные тесты учитываются как свидетельство конкретного CHECK только при SQLSTATE `23514` и совпадении имени ограничения; ошибки PK/FK/NOT NULL не засчитываются этому CHECK.

Исходные множества подтверждённых границ:

| Генератор | Наблюдаемые границы в полном наборе |
|---|---|
| `avsDefaults` | `B|amount_ceiling|-1|true`; `B|amount_ceiling|0|true`; `B|amount_ceiling|right-null|unknown`; `B|amount_min|0|true`; `B|ceiling_max|-1|true`; `B|ceiling_max|left-null|unknown`; `B|floor_min|+1|true`; `B|floor_min|left-null|unknown` |
| `randomDefaults` | `B|amount_ceiling|0|true`; `B|amount_ceiling|right-null|unknown`; `B|amount_min|0|true`; `B|ceiling_max|left-null|unknown`; `B|floor_min|left-null|unknown` |
| `dominoRandom` | `B|amount_ceiling|right-null|unknown`; `B|amount_min|0|true`; `B|ceiling_max|left-null|unknown`; `B|floor_min|0|false`; `B|floor_min|left-null|unknown` |
| `dominoAVS` | `B|amount_ceiling|right-null|unknown`; `B|ceiling_max|left-null|unknown`; `B|floor_min|left-null|unknown` |

Исходные requirement-id — `R|R1`…`R|R24` для первых трёх генераторов. Для `dominoAVS` покрыты `R|R1`, `R|R11`, `R|R12`, `R|R13`, `R|R14`, `R|R15`, `R|R16`, `R|R18`, `R|R19`, `R|R2`, `R|R21`, `R|R22`, `R|R23`, `R|R24`, `R|R3`, `R|R7`. У каждой строки таблиц выше отчёт сохраняет точные множества после редукции; потери перечислены далее.

| Генератор | Редуктор | Потерянные границы |
|---|---|---|
| `avsDefaults` | `simpleGreedy`, `additionalGreedy` | `B|amount_ceiling|-1|true`; `B|amount_ceiling|0|true`; `B|floor_min|+1|true` |
| `avsDefaults` | `HGS` | `B|amount_ceiling|-1|true`; `B|ceiling_max|-1|true` |
| `avsDefaults` | `random` | `B|amount_ceiling|0|true`; `B|floor_min|+1|true` |
| `avsDefaults` | `sticcer` | `B|amount_ceiling|-1|true`; `B|amount_ceiling|0|true`; `B|floor_min|+1|true` |
| `dominoRandom` | `sticcer` | `B|floor_min|0|false` |
| Остальные комбинации | — | Потерь исходных границ нет |

STICCER также сформировал дополнительные наблюдения: `B|amount_ceiling|both-null|unknown` для `randomDefaults` и `dominoRandom`, `B|floor_min|+1|true` для `dominoAVS`. Поэтому число границ после STICCER иногда больше исходного, не отменяя перечисленных потерь.

Потерянные требования SchemaAnalyst обнаружены только у STICCER:

- `avsDefaults` (17): `R|R10`, `R|R11`, `R|R12`, `R|R13`, `R|R16`, `R|R17`, `R|R18`, `R|R19`, `R|R2`, `R|R20`, `R|R22`, `R|R23`, `R|R24`, `R|R3`, `R|R5`, `R|R8`, `R|R9`.
- `randomDefaults` (15): `R|R10`, `R|R13`, `R|R15`, `R|R17`, `R|R18`, `R|R2`, `R|R20`, `R|R21`, `R|R22`, `R|R24`, `R|R3`, `R|R5`, `R|R7`, `R|R8`, `R|R9`.
- `dominoRandom` (20): `R|R10`, `R|R11`, `R|R12`, `R|R13`, `R|R15`, `R|R16`, `R|R17`, `R|R18`, `R|R19`, `R|R2`, `R|R20`, `R|R21`, `R|R22`, `R|R23`, `R|R24`, `R|R3`, `R|R5`, `R|R7`, `R|R8`, `R|R9`.
- `dominoAVS` (11): `R|R11`, `R|R12`, `R|R13`, `R|R15`, `R|R18`, `R|R2`, `R|R21`, `R|R22`, `R|R23`, `R|R24`, `R|R3`.

### PostgreSQL и ручной NULL oracle

Все **28** результатов редуктора совпали с ожидаемым поведением PostgreSQL; каждый полный исходный набор также проверен: `avsDefaults` 24/24, `randomDefaults` 24/24, `dominoRandom` 24/24, `dominoAVS` 16/16. В полных наборах первых трёх генераторов фактические результаты: 13 успешных вставок, 3 ошибки `23502`, 3 ошибки `23505`, 1 ошибка `23503`, 4 ошибки `23514`. Для `dominoAVS`: 8 успешных, 2 `23502`, 1 `23505`, 1 `23503`, 4 `23514`. У всех строк `matches_expected=True`.

Отдельно выполнен [manual_null_oracle.sql](../../schemaanalyst_experiments/manual_null_oracle.sql) на PostgreSQL 18.7; фактический вывод psql сохранён в [manual-null-oracle-direct.log](../../schemaanalyst_experiments/results/baseline-20261116/manual-null-oracle-direct.log). Выражение `((x > 0 AND y > 0) IS NOT FALSE)` дало совпадение 7/7:

| x | y | Ожидаемое принятие | Фактическое принятие |
|---|---|---|---|
| NULL | -1 | нет | нет |
| NULL | 1 | да | да |
| -1 | NULL | нет | нет |
| 1 | NULL | да | да |
| NULL | NULL | да | да |
| 1 | 1 | да | да |
| -1 | 1 | нет | нет |

## Подтверждённые факты и ограничения выводов

**Подтверждено запуском:**

- `.\SchemaAnalyst\gradlew.bat -p .\SchemaAnalyst compile --offline --no-daemon` и компиляция экспериментальных Java-классов завершились успешно.
- C++-проект собрался; CTest: 1/1 тест пройден. Регрессионный тест подтверждает, что FK-ошибка не засчитывается как покрытие CHECK.
- Схема, генерация, экспорт, запуск шести штатных методов, C++-проверка и выполнение итоговых SQL-тестов в PostgreSQL завершились для всех четырёх генераторов.
- `boundaryAware` сохранил все обнаруженные в исходном наборе требования и подтверждённые граничные наблюдения во всех четырёх запусках.
- На конкретном снимке `avsDefaults` четыре штатных редуктора потеряли хотя бы одну числовую границу; STICCER потерял требования во всех четырёх запусках и одну границу в `dominoRandom`.
- `unverified_boundary_tests` — число тестов-кандидатов, которые не подтверждают целевой CHECK из-за другой причины отказа. Эти кандидаты не входят в покрытие границ и не означают, что подтверждённые обязательства были потеряны. Статус `PASS_WITH_UNVERIFIED_CANDIDATES` означает, что все подтверждённые исходные обязательства сохранены, PostgreSQL совпал с ожиданиями, но в отчёте остаются такие исключённые кандидаты.

**Не подтверждено и не должно выводиться из этих данных:**

- Это один seed и одна схема. Результаты не являются статистической оценкой эффективности генераторов/редукторов и не доказывают общий уровень качества.
- Отсутствие `-1`, `0` или `+1` для сравнения означает только, что такая подтверждённая граница не встретилась в данном исходном наборе. Оно не доказывает невозможность её получить.
- Эксперимент не включает mutation score, сложные CHECK с `AND`/`OR`, произвольную арифметику, тестирование полного диапазона `INTEGER`/`BIGINT` или независимые схемы.
- `boundaryAware` является проверенным прототипом, но его корректность за пределами поддерживаемых простых CHECK не установлена.
- C++ строит штатное покрытие из `coveredRequirementIds`, которые отдельно вычисляет Java-экспортёр через `PredicateChecker`; C++ не исполняет заново произвольные SchemaAnalyst predicates. Граничные наблюдения он пересчитывает по строкам и PostgreSQL evidence.

## Ошибки и неуспешные попытки

Следующие четыре ошибки возникли при настройке сценария матрицы. Они не входят в итоговую матрицу; после исправлений полный прогон завершился без записей в `failures.csv`.

1. **Неверное представление списка генераторов** (`PowerShell 5.1.26100.9818`, Java Temurin 8u512). Команда передала список как одну строку:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Users\Dashyla\Desktop\computer_security\8_semester\Courswork\test_suite_minimization\experiments\run_matrix.ps1 -Generators avsDefaults,randomDefaults,dominoRandom,dominoAVS -Seeds 0 -Budget 10000
   ```

   Полное сообщение Java:

   ```text
   Exception in thread "main" org.schemaanalyst.data.generation.DataGenerationException: Unknown data generator "avsDefaults,randomDefaults,dominoRandom,dominoAVS"
       at org.schemaanalyst.data.generation.DataGeneratorFactory.instantiate(DataGeneratorFactory.java:62)
       at org.schemaanalyst.minimization.GenerateBaselineSnapshot.main(GenerateBaselineSnapshot.java:51)
   ```

2. **Позиционные аргументы были ошибочно привязаны к `JavaHome`** (`PowerShell 5.1.26100.9818`). Команда:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Users\Dashyla\Desktop\computer_security\8_semester\Courswork\test_suite_minimization\experiments\run_matrix.ps1 -Generators avsDefaults randomDefaults dominoRandom dominoAVS -Seeds 0 -Budget 10000
   ```

   Ошибка:

   ```text
   Resolve-Path : Cannot find path 'C:\Users\Dashyla\Desktop\computer_security\8_semester\Courswork\test_suite_minimization\randomDefaults' because it does not exist.
   At run_matrix.ps1:16 char:18
   + $javaHomePath = (Resolve-Path $JavaHome).Path
   +                  ~~~~~~~~~~~~~~~~~~~~~~
       + CategoryInfo          : ObjectNotFound: (...) [Resolve-Path], ItemNotFoundException
       + FullyQualifiedErrorId : PathNotFound,Microsoft.PowerShell.Commands.ResolvePathCommand
   ```

3. **Сценарий был вызван без обхода Execution Policy** (`PowerShell 5.1.26100.9818`). Команда `& $script -Generators @('avsDefaults','randomDefaults','dominoRandom','dominoAVS') -Seeds @(0) -Budget 10000` завершилась ошибкой. Полное сообщение:

   ```text
   Невозможно загрузить файл C:\Users\Dashyla\Desktop\computer_security\8_semester\Courswork\test_suite_minimization\experiments\run_matrix.ps1, так как выполнение сценариев отключено в этой системе. Для получения дополнительных сведений см. about_Execution_Policies по адресу https:/go.microsoft.com/fwlink/?LinkID=135170.
   строка:2 знак:152
   + ... script=Join-Path $repo 'experiments\run_matrix.ps1';& $script -Genera ...
   +                                                           ~~~~~~~
   + CategoryInfo          : SecurityError: (:) [], PSSecurityException
   + FullyQualifiedErrorId : UnauthorizedAccess
   ```

4. **Ошибка привязки `Add-Member` при записи PostgreSQL evidence** (`PowerShell 5.1.26100.9818`). Команда:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Users\Dashyla\Desktop\computer_security\8_semester\Courswork\test_suite_minimization\experiments\run_matrix.ps1 -Generators avsDefaults -Seeds 0 -Budget 10000
   ```

   Сообщение:

   ```text
   Add-Member : Parameter set cannot be resolved using the specified named parameters.
   At run_matrix.ps1:212 char:17
   +                 $test | Add-Member -NotePropertyName postgresValidation -Force -Value (...)
   +                 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
   CategoryInfo          : InvalidArgument: (:) [Add-Member], ParentContainsErrorRecordException
   FullyQualifiedErrorId : AmbiguousParameterSet
   ```

   В исходном вызове сочетались `-Force` и `-Value`; параметр исправлен на `-NotePropertyValue`, после чего smoke и полный прогон прошли.

В сохранённом Gradle XML-отчёте также зафиксированы **15 ошибок из 1715 тестов**: 10 PostgreSQL-ошибок с сообщением `The authentication type 10 is not supported`; два `NullPointerException` в `TestDataTypes`; два `NullPointerException` в `TestSchema.testParsedCaseStudies`; и `AssertionError` в `TestPKCColumnE.testDoublePKTwoExchange` (`expected:<8> but was:<7>`). Подробности находятся в [TEST-org.schemaanalyst.unittest.dbms.TestPostgres.xml](../SchemaAnalyst/build/test-results/test/TEST-org.schemaanalyst.unittest.dbms.TestPostgres.xml), [TEST-org.schemaanalyst.unittest.sqlrepresentation.datatype.TestDataTypes.xml](../SchemaAnalyst/build/test-results/test/TEST-org.schemaanalyst.unittest.sqlrepresentation.datatype.TestDataTypes.xml), [TEST-org.schemaanalyst.unittest.sqlrepresentation.TestSchema.xml](../SchemaAnalyst/build/test-results/test/TEST-org.schemaanalyst.unittest.sqlrepresentation.TestSchema.xml) и [TEST-org.schemaanalyst.unittest.mutation.operator.TestPKCColumnE.xml](../SchemaAnalyst/build/test-results/test/TEST-org.schemaanalyst.unittest.mutation.operator.TestPKCColumnE.xml). Исходная командная строка полного Gradle test-прогона не сохранилась; эти тесты не являются частью успешной PostgreSQL-валидации матрицы.

## Решение о дальнейшей реализации

**Рекомендуется продолжить разработку boundary-aware reducer**, поскольку прототип в этом запуске сохранил все подтверждённые границы и требования, а на снимке `avsDefaults` несколько штатных методов потеряли числовые границы. Это подтверждает практическую ценность отдельного критерия, но не доказывает статистическое преимущество на всех схемах и seeds. Следующий этап — заранее зафиксировать набор seed, расширить схемы и поддерживаемые случаи, затем повторить независимую матрицу; сохранять SQLSTATE и причины исключения boundary-кандидатов в каждом прогоне.
