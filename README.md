# SchemaAnalyst и test_suite_minimization

Репозиторий разделён на два проекта и отдельный каталог документов:

```text
.
├── SchemaAnalyst/                 # исходный Java-проект и его сборка
├── test_suite_minimization/       # код и сценарии практической части
├── docs/                          # руководство, отчёты и материалы курсовой
├── .github/workflows/build.yml    # проверка README в GitHub Actions
├── .gitignore                     # правила исключения локальных файлов
├── .mdlrc                         # настройки Markdown lint
├── LICENSE.txt                    # лицензия
└── README.md                      # это описание структуры
```

SchemaAnalyst содержит генерацию тестовых данных и штатные алгоритмы сокращения тестового набора.
`test_suite_minimization` добавляет Java-обвязку экспериментов, C++-алгоритм сокращения тестового набора и
проверку PostgreSQL. Документы и отчёты находятся отдельно в `docs/`.

## `SchemaAnalyst/`

### Каталоги

| Путь | Назначение |
|---|---|
| `SchemaAnalyst/src/main/java` | Основной Java-код SchemaAnalyst: модель схемы, генераторы, критерии покрытия и штатные алгоритмы сокращения тестового набора. |
| `SchemaAnalyst/src/test/java` | Java unit- и integration-тесты; агрегатор — `org.schemaanalyst.unittest.AllTests`. |
| `SchemaAnalyst/src/paper` | Материалы, связанные с публикациями и исследовательской частью исходного проекта. |
| `SchemaAnalyst/casestudies` | SQL-схемы и исходные данные примеров для генерации и экспериментов. |
| `SchemaAnalyst/config` | Конфигурация СУБД, путей, логирования и экспериментов. |
| `SchemaAnalyst/gradle/wrapper` | Компоненты Gradle Wrapper. |
| `SchemaAnalyst/lib` | Подключённые Java, Ant и Jacoco библиотеки. |
| `SchemaAnalyst/scripts` | Сценарии анализа, экспериментов и обновления конфигурации. |

### Файлы сборки и запуска

| Файл | Назначение |
|---|---|
| `SchemaAnalyst/build.gradle` | Gradle-сборка SchemaAnalyst; подключает Java-обвязки из `test_suite_minimization/src/main/java`. |
| `SchemaAnalyst/build.xml` | Сборка Ant, используемая некоторыми исходными сценариями. |
| `SchemaAnalyst/settings.gradle` | Имя и настройки Gradle-проекта. |
| `SchemaAnalyst/gradlew`, `SchemaAnalyst/gradlew.bat` | Unix- и Windows-обёртки Gradle. |
| `SchemaAnalyst/gradle/wrapper/gradle-wrapper.jar` | Исполняемая часть Gradle Wrapper. |
| `SchemaAnalyst/gradle/wrapper/gradle-wrapper.properties` | Версия Gradle и параметры загрузки Wrapper. |
| `SchemaAnalyst/SampleReductionExperimentRunner.sh` | Запускает серию экспериментов по сокращению. |
| `SchemaAnalyst/run-analysepipeline.sh` | Запуск анализа схем через pipeline. |
| `SchemaAnalyst/run-mutant-timing.sh` | Замер времени анализа мутантов. |
| `SchemaAnalyst/run-options-random.sh` | Эксперименты с параметрами и случайным выбором. |
| `SchemaAnalyst/run-options-random-fullreduce.sh` | Вариант эксперимента с полным сокращением. |
| `SchemaAnalyst/run-virtual.sh` | Запуск виртуального анализа мутантов. |
| `SchemaAnalyst/run-virtual-timing.sh` | Вариант виртуального анализа с замером времени. |
| `SchemaAnalyst/schemaanalyst-logo-gh.png` | Изображение SchemaAnalyst. |
| `SchemaAnalyst/ukwac_char_lm` | Языковая модель, используемая компонентом `LangModel` генерации данных. |

### Конфигурация и библиотеки

| Файл | Назначение |
|---|---|
| `SchemaAnalyst/config/capture.properties` | Настройки захвата экспериментальных данных. |
| `SchemaAnalyst/config/database.properties` | Параметры подключения к СУБД. |
| `SchemaAnalyst/config/experiment.properties` | Настройки экспериментальных запусков. |
| `SchemaAnalyst/config/locations.properties` | Пути к рабочим каталогам и данным. |
| `SchemaAnalyst/config/logging.properties` | Настройки журналирования. |

В `SchemaAnalyst/lib` находятся `JavaRunner.jar`, `ant-launcher.jar`,
`ant-sources.jar`, `ant.jar` и `jacocoant.jar`.

### Сценарии в `SchemaAnalyst/scripts`

| Файл | Назначение |
|---|---|
| `analysecoverage.sh` | Запуск анализа покрытия. |
| `analysepipeline.sh` | Запуск анализа через pipeline. |
| `checks/checks.sql` | SQL-определения проверок для экспериментов. |
| `checks/functions.sql` | SQL-функции для проверок. |
| `checks/inserts.sql` | Тестовые SQL-вставки для проверок. |
| `coverageexperiment.sh` | Серия экспериментов по покрытию. |
| `experiment.sh` | Общая оболочка экспериментального запуска. |
| `find_alive.R` | Обработка результатов и поиск выживших мутантов. |
| `generatorexperiment.sh` | Эксперименты с генераторами тестовых данных. |
| `interactorexperiment.sh` | Эксперименты компонента interaction. |
| `issta-scripts.zip` | Архив экспериментальных скриптов. |
| `livemutantexperiment.sh` | Эксперименты с live-мутантами. |
| `operatorexperiment.sh` | Эксперименты с операторами мутаций. |
| `pipelineexperiment.sh` | Эксперименты с вариантами pipeline. |
| `runExperiments.py` | Python-драйвер пакетного запуска экспериментов. |
| `runMutation.py` | Python-драйвер mutation analysis. |
| `techniqueexperiment.sh` | Сравнение техник генерации и анализа. |
| `threadexperiment.sh` | Эксперименты с потоками. |
| `updateproperties.sh` | Обновление конфигурационных свойств. |

## `test_suite_minimization/`

Практическая часть сравнивает штатные алгоритмы сокращения тестового набора и проверяет отдельное
сохранение требований SchemaAnalyst и наблюдаемых границ для сравнений `x op c`
и `x op y`. Каждый алгоритм запускается на независимой копии исходного набора.

### Java-обвязка (`test_suite_minimization/src`)

| Файл | Назначение |
|---|---|
| `BaselineSnapshot.java` | Сериализуемый снимок схемы, набора тестов, требований и параметров генерации. |
| `CourseworkSchema.java` | Предметная схема лабораторий, сотрудников, оборудования, пользователей и торговых автоматов; включает PK/FK и тестируемые CHECK для количества товара и вместимости. |
| `GenerateBaselineSnapshot.java` | Однократная генерация и сохранение исходного набора в `.ser`. |
| `ExportBaselineJson.java` | Экспорт сохранённого снимка в JSON. |
| `SnapshotJsonExporter.java` | Формирование JSON со схемой, требованиями, тестами и SQL. |
| `RunSnapshotReducer.java` | Независимый запуск выбранного штатного алгоритма сокращения на снимке. |
| `JsonUtil.java` | Запись JSON без дополнительной Java-зависимости. |

Сборка Gradle проекта SchemaAnalyst подключает эти исходники; отдельная копия
Java-зависимостей не создаётся.

### C++-алгоритм сокращения тестового набора (`test_suite_minimization/cpp`)

| Файл | Назначение |
|---|---|
| `CMakeLists.txt` | Настройка CMake и регистрация тестов CTest. |
| `README.md` | Описание алгоритма, формата входа и команд сборки C++-части. |
| `include/minimizer/boundary.hpp` | Интерфейс расчёта покрытия требований и границ. |
| `include/minimizer/json.hpp` | Интерфейс чтения и записи JSON. |
| `include/minimizer/minimizer.hpp` | Интерфейс минимизации тестового набора. |
| `include/minimizer/model.hpp` | Модель схемы, CHECK, требований и тестов. |
| `src/boundary.cpp` | Расчёт покрытия требований и подтверждённых границ. |
| `src/json.cpp` | Парсинг и сериализация JSON. |
| `src/main.cpp` | Точка входа C++-программы. |
| `src/minimizer.cpp` | Детерминированный выбор поднабора тестов. |
| `src/model.cpp` | Разбор входной модели и PostgreSQL evidence. |
| `tests/test_minimizer.cpp` | Unit- и regression-тесты C++-алгоритма сокращения тестового набора. |

### Эксперименты (`test_suite_minimization/experiments`)

| Файл | Назначение |
|---|---|
| `README.md` | Протокол генерации снимка и независимого запуска алгоритмов сокращения тестового набора. |
| `FORMAT.md` | Формат JSON-обмена между Java, C++ и PostgreSQL-валидатором. |
| `LAUNCH_STATUS.md` | Журнал первоначальной диагностики запуска Java-эксперимента. |
| `schema.sql` | SQL-схема для проверочных сценариев. |
| `manual_null_oracle.sql` | Проверка семантики CHECK при NULL. |
| `example-data/avsDefaults-seed0/` | Реальные `.ser`, JSON, C++-отчёт, SQL-схема и результаты PostgreSQL для воспроизводимого примера. |
| `run_cpp_checks.ps1` | Сборка и тестирование C++-алгоритма сокращения тестового набора из PowerShell. |
| `run_matrix.ps1` | Запуск матрицы генераторов и алгоритмов сокращения на независимых снимках. |
| `validate_postgres.ps1` | Выполнение тестов в PostgreSQL и сохранение результата, SQLSTATE и ограничения. |
| `fixtures/basic.json` | Минимальная фикстура JSON для C++-проверки. |
| `fixtures/postgres-boundaries.json` | Фикстура с граничными сравнениями и PostgreSQL evidence. |

`test_suite_minimization/scripts/build_coursework_docx.ps1` собирает Word-материал
курсовой работы.

## `docs/`

| Файл | Назначение |
|---|---|
| `BUILD_AND_TESTS.md` | Команды сборки, расположение тестов, PostgreSQL и запуск матрицы. |
| `IMPLEMENTATION_STATUS.md` | Реализованные компоненты, результаты запусков и ограничения. |
| `PRACTICAL_CHAPTER.md` | Текст практической главы курсовой. |
| `Coursework_PostgreSQL_Practical.docx` | Word-материал практической части. |
| `RESULTS_BASELINE.md` | Метрики, покрытие, потерянные границы и фактические ответы PostgreSQL. |
| `старое описание.md` | Точная копия README, сохранённая перед обновлением описания проекта. |

Сырые `.ser`, CSV, JSON-отчёты и логи новых запусков создаются под
`test_suite_minimization/experiments/results/` и не добавляются в Git. Единственное
исключение — один небольшой исходный `.ser` в
[`example-data/avsDefaults-seed0`](./test_suite_minimization/experiments/example-data/avsDefaults-seed0),
включённый для воспроизводимого примера.

## Сборка и тесты

Все команды выполняются из корня репозитория. Java-обвязки компилируются вместе
с SchemaAnalyst:

```powershell
.\SchemaAnalyst\gradlew.bat -p .\SchemaAnalyst compile --offline --no-daemon
.\SchemaAnalyst\gradlew.bat -p .\SchemaAnalyst test --offline --no-daemon
```

C++-алгоритм сокращения тестового набора и зарегистрированный CTest можно собрать и проверить скриптом:

```powershell
.\test_suite_minimization\experiments\run_cpp_checks.ps1
```

Для полной матрицы нужен локальный PostgreSQL и установленный JDK. Подробные
инструкции и известные ограничения приведены в
[руководстве по сборке и тестам](./docs/BUILD_AND_TESTS.md). Результаты базовых
прогонов находятся в [RESULTS_BASELINE.md](./docs/RESULTS_BASELINE.md).

## Лицензия

См. [LICENSE.txt](./LICENSE.txt).
