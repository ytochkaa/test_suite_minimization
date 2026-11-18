# Статус запуска Java-эксперимента

Дата последнего запуска: 18.11.2026.

Новая предметная `CourseworkSchema` успешно скомпилирована вместе с Java-обвязками. Полная матрица `run_matrix.ps1` завершилась с кодом `0` и обработала четыре генератора, seed `0`, шесть штатных методов и `boundaryAware`.

Проверенный снимок `avsDefaults-0.ser` создан из схемы с девятью таблицами:

```text
sha256=1a9f8393d85e3b941d66cc26309ad34b014dd644a1d57abfbfb1bd25e9e02f36
generator=avsDefaults
criterion=CondAICC
seed=0
budget=10000
tests=54
requirements_covered=54
```

Фактические JSON, CSV и журналы полной матрицы сохранены на машине запуска в `results/matrix-20261118-031008-81981e91`. Отобранный реальный пример включён в `example-data/avsDefaults-seed0`.

Среда: Eclipse Temurin JDK 8u512-b09, Gradle wrapper 4.10.2, PostgreSQL 18.7, PowerShell 5.1.26100.9818. В успешной матрице все результаты выполнения SQL в PostgreSQL совпали с ожиданиями; потери покрытий некоторых штатных алгоритмов сокращения перечислены в `../../docs/RESULTS_BASELINE.md`.
