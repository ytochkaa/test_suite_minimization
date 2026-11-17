# SchemaAnalyst: генерация и сокращение тестов

Этот репозиторий содержит исходный Java-проект SchemaAnalyst и практическую
часть курсовой работы `test_suite_minimization`: воспроизводимый эксперимент,
проверку тестовых данных в PostgreSQL и C++-прототип редуктора с сохранением
граничных обязательств.

## Как устроен рабочий каталог

В рабочем каталоге `Courswork` проекты хранятся отдельно:

```text
Courswork/
├── schemaanalyst/schemaanalyst/  # отдельная копия исходного проекта SchemaAnalyst
└── test_suite_minimization/      # этот репозиторий и материалы курсовой
```

Этот README относится к `test_suite_minimization`. Внутри репозитория файлы
сгруппированы по назначению в разделы **SchemaAnalyst** и
**test_suite_minimization**. Чтобы не ломать существующую сборку Java, исходники
SchemaAnalyst оставлены в их обычных каталогах (`src`, `casestudies`,
`config`); они не перемещались. Полный прежний README сохранён в
[старое описание.md](./старое%20описание.md).

## SchemaAnalyst — базовый Java-проект

SchemaAnalyst генерирует наборы тестовых данных для проверки ограничений
реляционной схемы. Java-часть и её исходная структура находятся в этом
репозитории, а отдельная исходная копия — в `..\schemaanalyst\schemaanalyst`.

### Основные каталоги

| Путь | Назначение |
|---|---|
| `src/main/java` | Основной Java-код: модель схемы, генераторы данных, критерии покрытия, редукторы и анализ мутантов. |
| `src/test/java` | Java unit- и integration-тесты. Основной агрегатор тестов: `org.schemaanalyst.unittest.AllTests`. |
| `casestudies` | SQL-схемы и наборы case study, используемые генерацией и экспериментами. |
| `config` | Конфигурация СУБД, путей, логирования и экспериментов. |
| `lib` | Подключённые Java/Ant/Jacoco библиотеки. |
| `scripts` | Скрипты запуска анализа, экспериментов, проверки SQL и обновления настроек. |
| `gradle/wrapper` | Компоненты Gradle Wrapper, позволяющие собирать проект без отдельной установки Gradle. |
| `.github/workflows` | Настройки автоматической сборки в GitHub Actions. |

### Файлы SchemaAnalyst в корне

| Файл | Назначение |
|---|---|
| `.gitignore` | Исключает локальные сборки, временные файлы и локальную конфигурацию из Git. |
| `.mdlrc` | Настройки проверки Markdown. |
| `.github/workflows/build.yml` | CI-сценарий сборки проекта в GitHub Actions. |
| `build.gradle` | Основная Gradle-сборка Java-проекта и его задач. |
| `build.xml` | Сборка Ant, используемая некоторыми экспериментальными сценариями. |
| `settings.gradle` | Настройки Gradle-проекта. |
| `gradlew`, `gradlew.bat` | Unix- и Windows-обёртки Gradle. |
| `gradle/wrapper/gradle-wrapper.jar` | Исполняемая часть Gradle Wrapper. |
| `gradle/wrapper/gradle-wrapper.properties` | Версия Gradle и параметры загрузки Wrapper. |
| `LICENSE.txt` | Лицензия исходного проекта. |
| `schemaanalyst-logo-gh.png` | Изображение SchemaAnalyst. |
| `ukwac_char_lm` | Файл языковой модели, используемый компонентом `LangModel` генерации данных. |
| `run-analysepipeline.sh` | Запуск анализа схем через pipeline. |
| `run-mutant-timing.sh` | Замер времени анализа мутантов. |
| `run-options-random.sh` | Эксперименты с параметрами генерации и случайным выбором. |
| `run-options-random-fullreduce.sh` | Вариант эксперимента с дополнительным полным сокращением. |
| `run-virtual.sh` | Запуск виртуального анализа мутантов. |
| `run-virtual-timing.sh` | Вариант виртуального анализа с замером времени. |
| `SampleReductionExperimentRunner.sh` | Обёртка для запуска серии экспериментов по сокращению. |

### Конфигурационные файлы

| Файл | Назначение |
|---|---|
| `config/capture.properties` | Настройки захвата/сохранения экспериментальных данных. |
| `config/database.properties` | Параметры подключения к СУБД. |
| `config/experiment.properties` | Настройки экспериментальных запусков. |
| `config/locations.properties` | Пути к рабочим каталогам и данным. |
| `config/logging.properties` | Уровни и настройки журналирования. |

В `lib` находятся `JavaRunner.jar`, `ant-launcher.jar`, `ant-sources.jar`,
`ant.jar` и `jacocoant.jar`. В `scripts` лежат:

| Файл | Назначение |
|---|---|
| `scripts/analysecoverage.sh` | Запуск анализа покрытия. |
| `scripts/analysepipeline.sh` | Запуск анализа через pipeline. |
| `scripts/build_coursework_docx.ps1` | Сборка Word-материала курсовой. |
| `scripts/checks/checks.sql` | SQL-определения проверок для экспериментов. |
| `scripts/checks/functions.sql` | SQL-функции для проверок. |
| `scripts/checks/inserts.sql` | Тестовые SQL-вставки для проверок. |
| `scripts/coverageexperiment.sh` | Серия экспериментов по покрытию. |
| `scripts/experiment.sh` | Общая оболочка экспериментального запуска. |
| `scripts/find_alive.R` | R-скрипт обработки результатов и поиска выживших мутантов. |
| `scripts/generatorexperiment.sh` | Эксперименты с генераторами тестовых данных. |
| `scripts/interactorexperiment.sh` | Эксперименты компонента interaction. |
| `scripts/issta-scripts.zip` | Архив скриптов для соответствующих экспериментальных запусков. |
| `scripts/livemutantexperiment.sh` | Эксперименты с live-мутантами. |
| `scripts/operatorexperiment.sh` | Эксперименты с операторами мутаций. |
| `scripts/pipelineexperiment.sh` | Эксперименты с вариантами pipeline. |
| `scripts/runExperiments.py` | Python-драйвер пакетного запуска экспериментов. |
| `scripts/runMutation.py` | Python-драйвер запуска mutation analysis. |
| `scripts/techniqueexperiment.sh` | Сравнение техник генерации/анализа. |
| `scripts/threadexperiment.sh` | Эксперименты с потоками. |
| `scripts/updateproperties.sh` | Обновление свойств конфигурации перед запуском. |

## test_suite_minimization — практическая часть

Практическая часть проверяет, какие требования и граничные случаи остаются
после сокращения набора. Каждый штатный редуктор получает независимую копию
одного и того же исходного снимка. Отдельно проверяются сравнения `x op c` и
`x op y`, а фактическое поведение SQL сверяется с PostgreSQL.

### Java-обвязка экспериментов

| Файл | Назначение |
|---|---|
| `src/main/java/org/schemaanalyst/minimization/BaselineSnapshot.java` | Сериализуемый снимок схемы, набора тестов, требований и параметров генерации. |
| `src/main/java/org/schemaanalyst/minimization/CourseworkSchema.java` | Небольшая схема с CHECK, ключами и ограничениями для воспроизводимого эксперимента. |
| `src/main/java/org/schemaanalyst/minimization/GenerateBaselineSnapshot.java` | Однократная генерация и сохранение исходного набора в `.ser`. |
| `src/main/java/org/schemaanalyst/minimization/ExportBaselineJson.java` | Экспорт сохранённого снимка в JSON для C++ и PostgreSQL-валидатора. |
| `src/main/java/org/schemaanalyst/minimization/SnapshotJsonExporter.java` | Формирование JSON со схемой, требованиями, тестами, INSERT и данными генерации. |
| `src/main/java/org/schemaanalyst/minimization/RunSnapshotReducer.java` | Повторное чтение одного снимка и независимый запуск выбранного штатного редуктора. |
| `src/main/java/org/schemaanalyst/minimization/JsonUtil.java` | Запись JSON без дополнительной Java-зависимости. |
| `src/main/java/org/schemaanalyst/testgeneration/coveragecriterion/integrityconstraint/CondAICC.java` | Реализация критерия покрытия, используемого в экспериментах. |

### C++ редуктор (`cpp`)

| Файл | Назначение |
|---|---|
| `cpp/CMakeLists.txt` | Настройка CMake-сборки и регистрации тестов CTest. |
| `cpp/README.md` | Краткое описание алгоритма, формата входа и команд сборки C++-части. |
| `cpp/include/minimizer/boundary.hpp` | Типы и интерфейс построения покрытия требований и границ. |
| `cpp/include/minimizer/json.hpp` | Интерфейс чтения и записи JSON. |
| `cpp/include/minimizer/minimizer.hpp` | Интерфейс минимизации тестового набора. |
| `cpp/include/minimizer/model.hpp` | Типы входных данных: схема, CHECK, требования и тесты. |
| `cpp/src/boundary.cpp` | Расчёт покрытия требований и проверяемых границ. |
| `cpp/src/json.cpp` | Парсинг и сериализация JSON. |
| `cpp/src/main.cpp` | Командная точка входа C++-программы. |
| `cpp/src/minimizer.cpp` | Детерминированный выбор поднабора тестов. |
| `cpp/src/model.cpp` | Разбор модели входных данных и PostgreSQL evidence. |
| `cpp/tests/test_minimizer.cpp` | C++ unit/regression-тесты редуктора. |

### Эксперименты и PostgreSQL (`experiments`)

| Файл | Назначение |
|---|---|
| `experiments/README.md` | Протокол генерации исходного снимка и независимого запуска редукторов. |
| `experiments/FORMAT.md` | Формат JSON-обмена между Java и C++, включая PostgreSQL evidence. |
| `experiments/LAUNCH_STATUS.md` | Журнал первоначальной диагностики запуска Java-эксперимента. |
| `experiments/schema.sql` | SQL-схема, используемая проверочными сценариями. |
| `experiments/manual_null_oracle.sql` | Ручная проверка поведения CHECK при NULL. |
| `experiments/run_cpp_checks.ps1` | Сборка и тестирование C++-редуктора из PowerShell. |
| `experiments/run_matrix.ps1` | Запуск матрицы генераторов и редукторов на независимых снимках. |
| `experiments/validate_postgres.ps1` | Выполнение тестов в PostgreSQL и сохранение фактических результатов/SQLSTATE. |
| `experiments/fixtures/basic.json` | Минимальная JSON-фикстура для проверки формата и C++-обработки. |
| `experiments/fixtures/postgres-boundaries.json` | Фикстура с проверками граничных сравнений и PostgreSQL evidence. |

### Документы и результаты

| Файл | Назначение |
|---|---|
| `docs/BUILD_AND_TESTS.md` | Подробная инструкция по сборке, тестам, CTest, PostgreSQL и матрице экспериментов. |
| `docs/IMPLEMENTATION_STATUS.md` | Реализованные компоненты, проверенные запуски и ограничения текущей версии. |
| `docs/PRACTICAL_CHAPTER.md` | Текст практической главы курсовой работы. |
| `docs/Coursework_PostgreSQL_Practical.docx` | Word-материал практической части по PostgreSQL. |
| `RESULTS_BASELINE.md` | Числа тестов и INSERT, время, покрытие, потерянные границы и фактические ответы PostgreSQL. |
| `старое описание.md` | Точная копия README, который находился здесь до замены на это русскоязычное описание. |

Сырые файлы запусков (`.ser`, CSV, JSON-отчёты и логи) создаются в
`experiments/results/`. Этот каталог игнорируется Git; основные подтверждённые
результаты сохранены в `RESULTS_BASELINE.md`.

## Сборка и тестирование

Подробные команды и требования к среде приведены в
[руководстве по сборке и тестам](./docs/BUILD_AND_TESTS.md). Кратко:

```powershell
.\gradlew.bat compile --offline --no-daemon
.\gradlew.bat test --offline --no-daemon
```

Для C++ потребуются CMake, Ninja и компилятор C++17; команды находятся в
руководстве выше. Для полной экспериментальной матрицы также нужен локальный
PostgreSQL. Результаты всех выполненных базовых прогонов и известные ошибки
полного Java test suite перечислены в [RESULTS_BASELINE.md](./RESULTS_BASELINE.md).

## Лицензия

См. [LICENSE.txt](./LICENSE.txt).
