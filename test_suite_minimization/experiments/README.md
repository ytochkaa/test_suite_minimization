# Воспроизводимый исходный эксперимент

Класс `GenerateBaselineSnapshot` генерирует набор один раз и сохраняет весь связанный граф объектов в `.ser`. Каждый редуктор должен открывать этот файл заново, поэтому результаты предыдущего метода не становятся входом следующего.

Минимальная конфигурация:

- схема: `CourseworkSchema`;
- СУБД-модель: Postgres;
- критерий: CondAICC;
- генераторы: `avsDefaults`, `randomDefaults`, `dominoRandom`, `dominoAVS`;
- seed: 0;
- бюджет: 10000;
- readability: false;
- fullreduce: false.

Пример аргументов Java main:

```text
org.schemaanalyst.minimization.GenerateBaselineSnapshot avsDefaults 0 10000 results/avsDefaults-0.ser
```

Файлы `*.ser`, собранные классы и результаты запусков не добавляются в Git.
