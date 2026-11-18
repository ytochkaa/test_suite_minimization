# Базовые результаты на предметной схеме

Дата прогона: 18.11.2026. Схема: `CourseworkSchema` — сотрудники, лаборатории, пользователи, оборудование, торговые автоматы, товары и таблицы-связки. Полный каталог результатов этого прогона на исходном компьютере:
`test_suite_minimization/experiments/results/matrix-20261118-031008-81981e91`.
Сводная таблица всех 28 запусков приложена в [`summary.csv`](../test_suite_minimization/experiments/example-data/avsDefaults-seed0/summary/summary.csv); пример полного прогона `avsDefaults` также находится в [`example-data/avsDefaults-seed0`](../test_suite_minimization/experiments/example-data/avsDefaults-seed0).

## Условия эксперимента

- SchemaAnalyst, критерий `CondAICC`, seed `0`, budget `10000`, `readability=false`, `fullreduce=false`.
- Генераторы: `avsDefaults`, `randomDefaults`, `dominoRandom`, `dominoAVS`.
- Редукторы: `none`, `simpleGreedy`, `additionalGreedy`, `HGS`, `random`, `sticcer`; дополнительно — `boundaryAware`.
- Каждый алгоритм сокращения получил один и тот же неизменный `.ser` для своей пары «генератор, seed». Хеш снимка совпадает в семи строках соответствующей группы.
- PostgreSQL запускался на `127.0.0.1:55432`, база `coursework_validation`; в каждой строке сводки есть число тестов с фактическим результатом, совпавшим с ожидаемым.
- Java — Eclipse Temurin 8u512-b09, Gradle wrapper 4.10.2, PostgreSQL 18.7, PowerShell 5.1.26100.9818, MSYS2 g++ 16.2.0, CMake 4.4.3.
- Результаты ниже взяты из завершённого прогона после фиксации Java- и SQL-схемы. Более ранний запуск `matrix-20261118-024456-98c07d6e` пересекался с обновлением этих файлов и был отброшен: его ошибки не являются результатами эксперимента.

Генерация измерена внутри `TestSuiteGenerator.generate()`. Время редукции измерено вокруг соответствующего вызова; для `boundaryAware` — время выбора C++. Значения не включают запуск JVM и PostgreSQL-валидацию.

Обозначения в таблицах: `тесты`, `state`, `data`, требования, границы и PostgreSQL записаны как `после / исходно`. `PASS_WITH_UNVERIFIED_CANDIDATES` означает, что покрытие подтверждено и SQL совпал с ожиданием, но в исходном наборе есть кандидаты границ, отклонённые не целевым CHECK. `REQUIREMENT_OR_BOUNDARY_LOSS` отмечает потерю покрытия, даже если PostgreSQL результаты для оставшихся тестов верны.

## `avsDefaults`

Исходно: 54 теста, 122 `state` INSERT, 66 `data` INSERT, 54 требования, 5 границ. Генерация: `147.621 ms`.

| Редуктор | Тесты | state | data | Редукция, ms | Требования | Границы | PostgreSQL | Статус |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `none` | 54/54 | 122/122 | 66/66 | 0.007 | 54/54 | 5/5 | 54/54 | `PASS_WITH_UNVERIFIED_CANDIDATES` |
| `simpleGreedy` | 48/54 | 105/122 | 60/66 | 174.989 | 54/54 | 5/5 | 48/48 | `PASS_WITH_UNVERIFIED_CANDIDATES` |
| `additionalGreedy` | 48/54 | 105/122 | 60/66 | 185.741 | 54/54 | 5/5 | 48/48 | `PASS_WITH_UNVERIFIED_CANDIDATES` |
| `HGS` | 48/54 | 105/122 | 60/66 | 170.108 | 54/54 | 5/5 | 48/48 | `PASS_WITH_UNVERIFIED_CANDIDATES` |
| `random` | 48/54 | 105/122 | 60/66 | 163.083 | 54/54 | 5/5 | 48/48 | `PASS_WITH_UNVERIFIED_CANDIDATES` |
| `sticcer` | 35/54 | 75/122 | 60/66 | 188.522 | 29/54 | 5/5 | 35/35 | `REQUIREMENT_OR_BOUNDARY_LOSS` |
| `boundaryAware` | 48/54 | 105/122 | 60/66 | 2.704 | 54/54 | 5/5 | 48/48 | `PASS_WITH_UNVERIFIED_CANDIDATES` |

## `randomDefaults`

Исходно: 52 теста, 114 `state` INSERT, 60 `data` INSERT, 52 требования, 2 границы. Генерация: `2320.119 ms`.

| Редуктор | Тесты | state | data | Редукция, ms | Требования | Границы | PostgreSQL | Статус |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `none` | 52/52 | 114/114 | 60/60 | 0.007 | 52/52 | 2/2 | 52/52 | `PASS_WITH_UNVERIFIED_CANDIDATES` |
| `simpleGreedy` | 46/52 | 97/114 | 54/60 | 185.872 | 52/52 | 2/2 | 46/46 | `PASS_WITH_UNVERIFIED_CANDIDATES` |
| `additionalGreedy` | 46/52 | 97/114 | 54/60 | 164.643 | 52/52 | 2/2 | 46/46 | `PASS_WITH_UNVERIFIED_CANDIDATES` |
| `HGS` | 46/52 | 97/114 | 54/60 | 150.180 | 52/52 | 1/2 | 46/46 | `REQUIREMENT_OR_BOUNDARY_LOSS` |
| `random` | 46/52 | 97/114 | 54/60 | 169.301 | 52/52 | 2/2 | 46/46 | `PASS_WITH_UNVERIFIED_CANDIDATES` |
| `sticcer` | 32/52 | 69/114 | 54/60 | 176.419 | 25/52 | 2/2 | 32/32 | `REQUIREMENT_OR_BOUNDARY_LOSS` |
| `boundaryAware` | 46/52 | 97/114 | 54/60 | 2.335 | 52/52 | 2/2 | 46/46 | `PASS_WITH_UNVERIFIED_CANDIDATES` |

## `dominoRandom`

Исходно: 54 теста, 122 `state` INSERT, 66 `data` INSERT, 54 требования, 2 границы. Генерация: `94.848 ms`.

| Редуктор | Тесты | state | data | Редукция, ms | Требования | Границы | PostgreSQL | Статус |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `none` | 54/54 | 122/122 | 66/66 | 0.007 | 54/54 | 2/2 | 54/54 | `PASS_WITH_UNVERIFIED_CANDIDATES` |
| `simpleGreedy` | 48/54 | 105/122 | 60/66 | 173.544 | 54/54 | 2/2 | 48/48 | `PASS_WITH_UNVERIFIED_CANDIDATES` |
| `additionalGreedy` | 48/54 | 105/122 | 60/66 | 181.926 | 54/54 | 2/2 | 48/48 | `PASS_WITH_UNVERIFIED_CANDIDATES` |
| `HGS` | 48/54 | 105/122 | 60/66 | 160.102 | 54/54 | 2/2 | 48/48 | `PASS_WITH_UNVERIFIED_CANDIDATES` |
| `random` | 48/54 | 105/122 | 60/66 | 174.288 | 54/54 | 2/2 | 48/48 | `PASS_WITH_UNVERIFIED_CANDIDATES` |
| `sticcer` | 33/54 | 73/122 | 60/66 | 195.207 | 25/54 | 2/2 | 33/33 | `REQUIREMENT_OR_BOUNDARY_LOSS` |
| `boundaryAware` | 48/54 | 105/122 | 60/66 | 2.532 | 54/54 | 2/2 | 48/48 | `PASS_WITH_UNVERIFIED_CANDIDATES` |

## `dominoAVS`

Исходно: 53 теста, 119 `state` INSERT, 65 `data` INSERT, 53 требования, 4 границы. Генерация: `276.058 ms`.

| Редуктор | Тесты | state | data | Редукция, ms | Требования | Границы | PostgreSQL | Статус |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `none` | 53/53 | 119/119 | 65/65 | 0.012 | 53/53 | 4/4 | 53/53 | `PASS_WITH_UNVERIFIED_CANDIDATES` |
| `simpleGreedy` | 47/53 | 102/119 | 59/65 | 176.472 | 53/53 | 4/4 | 47/47 | `PASS_WITH_UNVERIFIED_CANDIDATES` |
| `additionalGreedy` | 47/53 | 102/119 | 59/65 | 186.227 | 53/53 | 4/4 | 47/47 | `PASS_WITH_UNVERIFIED_CANDIDATES` |
| `HGS` | 47/53 | 102/119 | 59/65 | 164.213 | 53/53 | 4/4 | 47/47 | `PASS_WITH_UNVERIFIED_CANDIDATES` |
| `random` | 47/53 | 102/119 | 59/65 | 167.494 | 53/53 | 4/4 | 47/47 | `PASS_WITH_UNVERIFIED_CANDIDATES` |
| `sticcer` | 33/53 | 74/119 | 59/65 | 187.110 | 26/53 | 4/4 | 33/33 | `REQUIREMENT_OR_BOUNDARY_LOSS` |
| `boundaryAware` | 47/53 | 102/119 | 59/65 | 2.556 | 53/53 | 4/4 | 47/47 | `PASS_WITH_UNVERIFIED_CANDIDATES` |

## Подтверждённые граничные наблюдения

Наблюдения относятся только к значениям, доступным в исходном наборе и подтверждённым PostgreSQL. `-1`, `0`, `+1` — разность операндов; `true`/`false` — результат CHECK. Сравнение с NULL обозначается `unknown` и не является числовой границей.

| Генератор | Подтверждённые границы исходного набора |
|---|---|
| `avsDefaults` | `B|quantity_nonnegative|-1|false`; `B|quantity_nonnegative|0|true`; `B|quantity_within_capacity|-1|true`; `B|stock_capacity_positive|+1|true`; `B|stock_capacity_positive|0|false` |
| `randomDefaults` | `B|quantity_nonnegative|0|true`; `B|stock_capacity_positive|0|false` |
| `dominoRandom` | `B|quantity_nonnegative|0|true`; `B|stock_capacity_positive|0|false` |
| `dominoAVS` | `B|quantity_nonnegative|0|true`; `B|quantity_within_capacity|-1|true`; `B|stock_capacity_positive|+1|true`; `B|stock_capacity_positive|0|false` |

`boundaryAware` сохранил весь соответствующий набор требований и все исходные подтверждённые границы для каждого генератора. Штатные алгоритмы сокращения не гарантируют сохранение boundary-наблюдений: `HGS` для `randomDefaults` потерял `B|quantity_nonnegative|0|true`. `STICCER` потерял требования во всех четырёх запусках:

- `avsDefaults`: `R|R11`, `R|R13`, `R|R15`, `R|R16`, `R|R18`, `R|R19`, `R|R2`, `R|R24`, `R|R25`, `R|R27`, `R|R28`, `R|R3`, `R|R30`, `R|R31`, `R|R33`, `R|R34`, `R|R36`, `R|R38`, `R|R40`, `R|R41`, `R|R46`, `R|R48`, `R|R50`, `R|R8`, `R|R9`.
- `randomDefaults`: `R|R11`, `R|R13`, `R|R15`, `R|R16`, `R|R18`, `R|R19`, `R|R2`, `R|R20`, `R|R21`, `R|R24`, `R|R25`, `R|R27`, `R|R28`, `R|R3`, `R|R30`, `R|R31`, `R|R36`, `R|R38`, `R|R4`, `R|R40`, `R|R41`, `R|R42`, `R|R46`, `R|R48`, `R|R5`, `R|R8`, `R|R9`.
- `dominoRandom`: `R|R11`, `R|R13`, `R|R15`, `R|R16`, `R|R18`, `R|R19`, `R|R2`, `R|R20`, `R|R21`, `R|R24`, `R|R25`, `R|R27`, `R|R28`, `R|R3`, `R|R30`, `R|R31`, `R|R33`, `R|R34`, `R|R36`, `R|R38`, `R|R4`, `R|R40`, `R|R41`, `R|R46`, `R|R48`, `R|R5`, `R|R50`, `R|R8`, `R|R9`.
- `dominoAVS`: `R|R11`, `R|R13`, `R|R15`, `R|R16`, `R|R18`, `R|R19`, `R|R2`, `R|R20`, `R|R21`, `R|R24`, `R|R25`, `R|R27`, `R|R28`, `R|R3`, `R|R30`, `R|R31`, `R|R36`, `R|R38`, `R|R4`, `R|R40`, `R|R41`, `R|R44`, `R|R46`, `R|R48`, `R|R5`, `R|R8`, `R|R9`.

## Вывод и ограничения

- В `boundaryAware` PostgreSQL совпал с ожиданием во всех 28 строках матрицы; это подтверждает корректность выполнения сохранённых наборов на данном seed, а не универсальную корректность всех возможных схем.
- Boundary-aware выбор сохранил все обнаруженные подтверждённые границы и исходные требования. Для `avsDefaults` он сократил 54 теста до 48.
- Обычные алгоритмы `simpleGreedy`, `additionalGreedy`, `HGS` и `random` не потеряли требования в этих запусках, но `HGS` потерял одну границу в `randomDefaults`. STICCER значительно сокращает набор, однако теряет требования во всех четырёх случаях.
- Число неподтверждённых кандидатов в исходных наборах: 9 для `avsDefaults`, 4 для `randomDefaults`, 8 для `dominoRandom`, 9 для `dominoAVS`. Это число тестов с кандидатами, а не число уникальных обязательств.
- Эксперимент использует одну схему и один seed; выводы нельзя автоматически переносить на другие схемы и входные данные. Анализатор границ работает только с простыми целочисленными сравнениями; цена `NUMERIC` и даты в boundary-набор не входят.
