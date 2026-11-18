# Сборка и запуск тестов

Инструкция для Windows и раздельной структуры SchemaAnalyst + `test_suite_minimization`. Все команды запускаются из корня репозитория.

## Где находятся исходники и тесты

| Что искать | Путь |
|---|---|
| Java production-код SchemaAnalyst | `SchemaAnalyst\src\main\java` |
| Java unit-тесты SchemaAnalyst | `SchemaAnalyst\src\test\java\org\schemaanalyst\unittest` |
| Основной список Java-тестов | `SchemaAnalyst\src\test\java\org\schemaanalyst\unittest\AllTests.java` |
| Java-обвязки эксперимента | `test_suite_minimization\src\main\java\org\schemaanalyst\minimization` |
| C++ unit/regression test | `test_suite_minimization\cpp\tests\test_minimizer.cpp` |
| Регистрация C++ теста в CTest | `test_suite_minimization\cpp\CMakeLists.txt` |
| JSON fixture для проверки PostgreSQL | `test_suite_minimization\experiments\fixtures\postgres-boundaries.json` |
| Ручной SQL NULL oracle | `test_suite_minimization\experiments\example-data\avsDefaults-seed0\postgres\manual_null_oracle.sql` |

В VS Code откройте корень репозитория. Java-тесты можно просматривать в Explorer по пути выше; если установлен **Test Runner for Java**, они также появятся в панели **Testing**. Для C++ после конфигурации откройте панель CMake/CTest или используйте `ctest -N`, чтобы вывести зарегистрированные тесты. CLI-команды ниже работают независимо от наличия расширений VS Code.

## Требования

- JDK 8 или совместимый JDK, доступный через `JAVA_HOME`/`PATH`.
- Gradle wrapper из репозитория (отдельно устанавливать Gradle не нужно).
- Для C++: CMake, Ninja и C++17-компилятор. Проверенная конфигурация использовала MSYS2 MinGW-w64.
- Для полной экспериментальной матрицы: локальный PostgreSQL и утилиты `psql.exe` и `createdb.exe`.

Сценарий `test_suite_minimization\experiments\run_matrix.ps1` по умолчанию ожидает JDK в соседнем каталоге `..\schemaanalyst_experiments\runtime\jdk8u512-b09` и использует SchemaAnalyst из `SchemaAnalyst`. Для другой установки укажите `-JavaHome`/`-DependencyBuild` и при необходимости измените пути к CMake, компилятору, CTest и PostgreSQL в начале сценария.

### Подготовить PostgreSQL для экспериментов

Установите и запустите службу PostgreSQL. В базовом прогоне использовались PostgreSQL 18.7, адрес `127.0.0.1`, порт `55432`, пользователь `baseline` и отдельная база `coursework_validation`. Если PostgreSQL слушает другой порт, передайте его через `-PostgresPort` либо `-Port`.

Создайте роль с правом создавать тестовую базу, подключившись администратором PostgreSQL:

```powershell
$psql = 'C:\Program Files\PostgreSQL\18\bin\psql.exe'
& $psql -h 127.0.0.1 -p 55432 -U postgres -d postgres `
  -c 'CREATE ROLE baseline LOGIN CREATEDB;'
```

Если роль уже существует, используйте `ALTER ROLE baseline LOGIN CREATEDB`. При парольной аутентификации сохраните пароль в стандартном `pgpass.conf`, так как сценарии запускают `psql.exe` и `createdb.exe` без интерактивного запроса.

> **Важно:** `validate_postgres.ps1` перед каждым тестом выполняет `DROP SCHEMA public CASCADE`, затем создаёт схему заново. Используйте отдельную пустую базу, например `coursework_validation`; не направляйте сценарий на рабочую базу с ценными таблицами. Если базы ещё нет, валидатор создаст её от имени пользователя, которому выдано право `CREATEDB`.

## Собрать SchemaAnalyst

В PowerShell из корня проекта:

```powershell
.\SchemaAnalyst\gradlew.bat -p .\SchemaAnalyst compile --offline --no-daemon
```

`--offline` использует уже загруженные зависимости. При первой сборке без локального кэша удалите этот параметр, чтобы Gradle мог скачать зависимости:

```powershell
.\SchemaAnalyst\gradlew.bat -p .\SchemaAnalyst compile --no-daemon
```

Сборка Gradle дополнительно подключает Java-обвязки из `test_suite_minimization\src\main\java`. Основные результаты находятся в `SchemaAnalyst\build\classes\java\main` и `SchemaAnalyst\build\lib`.

## Запустить Java-тесты

Полный набор:

```powershell
.\SchemaAnalyst\gradlew.bat -p .\SchemaAnalyst test --offline --no-daemon
```

Один класс:

```powershell
.\SchemaAnalyst\gradlew.bat -p .\SchemaAnalyst test --tests 'org.schemaanalyst.unittest.dbms.TestPostgres' --offline --no-daemon
```

Результаты:

- HTML-отчёт: `SchemaAnalyst\build\reports\tests\test\index.html`;
- XML-результаты по классам: `SchemaAnalyst\build\test-results\test\TEST-*.xml`.

Если нужно показать тесты в отчёте или на защите, откройте HTML-отчёт в браузере. В нём видны количество тестов, ошибки и stack trace. Полный Gradle-набор не запускался в текущей проверке новой предметной схемы; предыдущий запуск содержал известные проблемы legacy JDBC с PostgreSQL SCRAM, NPE в части старых case-study tests и несовпадение ожидаемого количества мутантов. Не считайте один только успешный `compile` прохождением полного unit-набора.

## Собрать и проверить C++ reducer

```powershell
& 'C:\msys64\mingw64\bin\cmake.exe' -S .\test_suite_minimization\cpp -B .\test_suite_minimization\build\cpp -G Ninja "-DCMAKE_CXX_COMPILER=C:\msys64\mingw64\bin\g++.exe"
& 'C:\msys64\mingw64\bin\cmake.exe' --build .\test_suite_minimization\build\cpp
& 'C:\msys64\mingw64\bin\ctest.exe' --test-dir .\test_suite_minimization\build\cpp -N
& 'C:\msys64\mingw64\bin\ctest.exe' --test-dir .\test_suite_minimization\build\cpp --output-on-failure
```

`ctest -N` только показывает зарегистрированные тесты; последняя команда выполняет их. В текущем проекте зарегистрирован `minimizer_tests`, исходник — `test_suite_minimization\cpp\tests\test_minimizer.cpp`.

Чтобы запустить C++-программу вручную на JSON:

```powershell
.\test_suite_minimization\build\cpp\test_suite_minimization.exe `
  .\test_suite_minimization\experiments\fixtures\postgres-boundaries.json `
  .\test_suite_minimization\build\cpp\fixture-report.json
```

Программа печатает число входных тестов, требований и границ, а полный отчёт записывает в указанный выходной JSON.

## Проверить приложенный реальный пример

В [`test_suite_minimization\experiments\example-data\avsDefaults-seed0`](../test_suite_minimization/experiments/example-data/avsDefaults-seed0) лежат файлы реального запуска: исходный Java `.ser`, Java JSON-экспорт, JSON с результатом PostgreSQL, отчёт C++-редуктора, выбранный JSON и CSV ответов PostgreSQL. Описание каждого файла и контрольная сумма снимка находятся в README этой папки.

После сборки C++ и настройки отдельной тестовой базы выполните команды из корня репозитория:

```powershell
$example = '.\test_suite_minimization\experiments\example-data\avsDefaults-seed0'
$exe = '.\test_suite_minimization\build\cpp\test_suite_minimization.exe'
& $exe `
  (Join-Path $example 'input\avsDefaults-0-full-validated.json') `
  '.\test_suite_minimization\build\cpp\example-full-report.json'

& '.\test_suite_minimization\experiments\validate_postgres.ps1' `
  -InputJson (Join-Path $example 'output\avsDefaults-0-boundaryAware.json') `
  -HostName '127.0.0.1' -Port 55432 `
  -User 'baseline' -Database 'coursework_validation' `
  -ResultPath '.\test_suite_minimization\build\example-boundaryAware-postgres.csv'
```

Первая команда должна показать 54 исходных теста, 54 требования и 5 подтверждённых границ; в отчёте ожидается 48 выбранных тестов. Вторая команда повторно выполняет выбранные тесты на вашей базе и создаёт CSV в `build`. Если PostgreSQL или его утилиты установлены не по пути из сценария, укажите `-Psql` и `-Createdb`.

## Выполнить ручной SQL oracle

При запущенном локальном PostgreSQL:

```powershell
& 'C:\Program Files\PostgreSQL\18\bin\psql.exe' `
  -X -h 127.0.0.1 -p 55432 -U baseline -d coursework_validation `
  -f .\test_suite_minimization\experiments\example-data\avsDefaults-seed0\postgres\manual_null_oracle.sql
```

Скрипт выводит десять комбинаций остатка и вместимости, ожидаемого и фактического результата CHECK. Он выполняет только `SELECT` и не изменяет схему.

## Запустить экспериментальную матрицу

Перед запуском проверьте, что PostgreSQL доступен на `127.0.0.1:55432`, а база и пользователь из параметров сценария доступны. Матрица по умолчанию запускает четыре генератора, seed `0`, budget `10000`, шесть штатных редукторов и `boundaryAware`.

Чтобы разрешить выполнение скрипта только для этого процесса PowerShell и передать массив генераторов без ошибок привязки аргументов:

```powershell
$script = (Resolve-Path '.\test_suite_minimization\experiments\run_matrix.ps1').Path
$commandText = "& '$script' -Generators @('avsDefaults','randomDefaults','dominoRandom','dominoAVS') -Seeds @(0) -Budget 10000"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $commandText
```

Для быстрого прогона одного генератора замените список на `@('avsDefaults')`. Не запускайте редукторы вручную на результатах друг друга: сценарий сам перечитывает общий исходный `.ser` для каждого метода.

Для каждого запуска создаётся новая папка `test_suite_minimization\experiments\results\matrix-<run-id>`. В ней:

- `summary.csv` — число исходных/итоговых тестов и INSERT, время, покрытие, потерянные обязанности и статус PostgreSQL;
- `*-full-postgres.csv` — фактические результаты PostgreSQL для исходного набора;
- `*-<reducer>-postgres.csv` — фактические результаты для набора после конкретного редуктора;
- `*.ser` — исходные сериализованные снимки; одинаковый `snapshot_sha256` в строках сводки подтверждает общий вход для редукторов этой группы;
- `*.json` — экспорт, результаты редукции и отчёты покрытия;
- `*.log` и `environment.log` — команды/вывод этапов и версии среды; при ошибках также создаётся `failures.csv`.

Показать сводку последнего запуска можно так:

```powershell
$run = Get-ChildItem .\test_suite_minimization\experiments\results -Directory -Filter 'matrix-*' |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1
Import-Csv (Join-Path $run.FullName 'summary.csv') |
  Format-Table generator, reducer, status, final_tests, lost_requirements, lost_boundaries, postgres_status -AutoSize
```

Сначала проверяйте `postgres_status` и `status`. `PASS_WITH_UNVERIFIED_CANDIDATES` означает, что подтверждённые обязательства сохранены и SQL совпал с ожиданиями, но некоторые boundary-кандидаты не засчитаны из-за отказа по другому ограничению. Такие тесты перечислены в JSON-отчёте и не являются доказательством покрытия целевого CHECK.
