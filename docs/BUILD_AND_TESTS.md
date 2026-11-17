# Сборка и запуск тестов

Инструкция для Windows и текущей структуры SchemaAnalyst + C++ reducer. Все команды запускаются из корня репозитория `test_suite_minimization`.

## Где находятся исходники и тесты

| Что искать | Путь |
|---|---|
| Java production-код SchemaAnalyst | `src\main\java` |
| Java unit-тесты | `src\test\java\org\schemaanalyst\unittest` |
| Основной список Java-тестов | `src\test\java\org\schemaanalyst\unittest\AllTests.java` |
| C++ unit/regression test | `cpp\tests\test_minimizer.cpp` |
| Регистрация C++ теста в CTest | `cpp\CMakeLists.txt` |
| JSON fixture для проверки PostgreSQL | `experiments\fixtures\postgres-boundaries.json` |
| Ручной SQL NULL oracle | `..\schemaanalyst_experiments\manual_null_oracle.sql` |

В VS Code откройте корень репозитория. Java-тесты можно просматривать в Explorer по пути выше; если установлен **Test Runner for Java**, они также появятся в панели **Testing**. Для C++ после конфигурации откройте панель CMake/CTest или используйте `ctest -N`, чтобы вывести зарегистрированные тесты. CLI-команды ниже работают независимо от наличия расширений VS Code.

## Требования

- JDK 8 или совместимый JDK, доступный через `JAVA_HOME`/`PATH`.
- Gradle wrapper из репозитория (отдельно устанавливать Gradle не нужно).
- Для C++: CMake, Ninja и C++17-компилятор. Проверенная конфигурация использовала MSYS2 MinGW-w64.
- Для полной экспериментальной матрицы: локальный PostgreSQL и утилиты `psql.exe` и `createdb.exe`.

Сценарий `experiments\run_matrix.ps1` по умолчанию ожидает JDK в соседнем каталоге `..\..\schemaanalyst_experiments\runtime\jdk8u512-b09` и использует пути `C:\msys64\mingw64\bin` и `C:\Program Files\PostgreSQL\18\bin`. Для другой установки укажите `-JavaHome`/`-DependencyBuild` и при необходимости измените пути к CMake, компилятору, CTest и PostgreSQL в начале сценария.

## Собрать SchemaAnalyst

В PowerShell из корня проекта:

```powershell
.\gradlew.bat compile --offline --no-daemon
```

`--offline` использует уже загруженные зависимости. При первой сборке без локального кэша удалите этот параметр, чтобы Gradle мог скачать зависимости:

```powershell
.\gradlew.bat compile --no-daemon
```

Основные результаты сборки находятся в `build\classes\java\main` и `build\lib`.

## Запустить Java-тесты

Полный набор:

```powershell
.\gradlew.bat test --offline --no-daemon
```

Один класс:

```powershell
.\gradlew.bat test --tests 'org.schemaanalyst.unittest.dbms.TestPostgres' --offline --no-daemon
```

Результаты:

- HTML-отчёт: `build\reports\tests\test\index.html`;
- XML-результаты по классам: `build\test-results\test\TEST-*.xml`.

Если нужно показать тесты в отчёте или на защите, откройте HTML-отчёт в браузере. В нём видны количество тестов, ошибки и stack trace. На проверенной конфигурации полный набор имел 1715 тестов и 15 известных ошибок: проблемы legacy JDBC с PostgreSQL SCRAM, NPE в части старых case-study tests и несовпадение ожидаемого количества мутантов. Поэтому не трактуйте `test` как полностью зелёный запуск; детали зафиксированы в [RESULTS_BASELINE.md](../RESULTS_BASELINE.md).

## Собрать и проверить C++ reducer

```powershell
& 'C:\msys64\mingw64\bin\cmake.exe' -S .\cpp -B .\build\cpp -G Ninja "-DCMAKE_CXX_COMPILER=C:\msys64\mingw64\bin\g++.exe"
& 'C:\msys64\mingw64\bin\cmake.exe' --build .\build\cpp
& 'C:\msys64\mingw64\bin\ctest.exe' --test-dir .\build\cpp -N
& 'C:\msys64\mingw64\bin\ctest.exe' --test-dir .\build\cpp --output-on-failure
```

`ctest -N` только показывает зарегистрированные тесты; последняя команда выполняет их. В текущем проекте зарегистрирован `minimizer_tests`, исходник — `cpp\tests\test_minimizer.cpp`.

Чтобы запустить C++-программу вручную на JSON:

```powershell
.\build\cpp\test_suite_minimization.exe `
  .\experiments\fixtures\postgres-boundaries.json `
  .\build\cpp\fixture-report.json
```

Программа печатает число входных тестов, требований и границ, а полный отчёт записывает в указанный выходной JSON.

## Выполнить ручной SQL oracle

При запущенном локальном PostgreSQL:

```powershell
& 'C:\Program Files\PostgreSQL\18\bin\psql.exe' `
  -X -h 127.0.0.1 -p 55432 -U baseline -d coursework_validation `
  -f ..\schemaanalyst_experiments\manual_null_oracle.sql
```

Скрипт выводит семь комбинаций `x`, `y`, ожидаемого и фактического результата CHECK. Он выполняет только `SELECT` и не изменяет схему.

## Запустить экспериментальную матрицу

Перед запуском проверьте, что PostgreSQL доступен на `127.0.0.1:55432`, а база и пользователь из параметров сценария доступны. Матрица по умолчанию запускает четыре генератора, seed `0`, budget `10000`, шесть штатных редукторов и `boundaryAware`.

Чтобы разрешить выполнение скрипта только для этого процесса PowerShell и передать массив генераторов без ошибок привязки аргументов:

```powershell
$script = (Resolve-Path '.\experiments\run_matrix.ps1').Path
$commandText = "& '$script' -Generators @('avsDefaults','randomDefaults','dominoRandom','dominoAVS') -Seeds @(0) -Budget 10000"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $commandText
```

Для быстрого прогона одного генератора замените список на `@('avsDefaults')`. Не запускайте редукторы вручную на результатах друг друга: сценарий сам перечитывает общий исходный `.ser` для каждого метода.

Для каждого запуска создаётся новая папка `experiments\results\matrix-<run-id>`. В ней:

- `summary.csv` — число исходных/итоговых тестов и INSERT, время, покрытие, потерянные обязанности и статус PostgreSQL;
- `*-full-postgres.csv` — фактические результаты PostgreSQL для исходного набора;
- `*-<reducer>-postgres.csv` — фактические результаты для набора после конкретного редуктора;
- `*.ser` — исходные сериализованные снимки; одинаковый `snapshot_sha256` в строках сводки подтверждает общий вход для редукторов этой группы;
- `*.json` — экспорт, результаты редукции и отчёты покрытия;
- `*.log` и `environment.log` — команды/вывод этапов и версии среды; при ошибках также создаётся `failures.csv`.

Показать сводку последнего запуска можно так:

```powershell
$run = Get-ChildItem .\experiments\results -Directory -Filter 'matrix-*' |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1
Import-Csv (Join-Path $run.FullName 'summary.csv') |
  Format-Table generator, reducer, status, final_tests, lost_requirements, lost_boundaries, postgres_status -AutoSize
```

Сначала проверяйте `postgres_status` и `status`. `PASS_WITH_UNVERIFIED_CANDIDATES` означает, что подтверждённые обязательства сохранены и SQL совпал с ожиданиями, но некоторые boundary-кандидаты не засчитаны из-за отказа по другому ограничению. Такие тесты перечислены в JSON-отчёте и не являются доказательством покрытия целевого CHECK.
