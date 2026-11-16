# Статус исходного Java-эксперимента

Дата: 17.11.2026.

Новые классы `CourseworkSchema`, `BaselineSnapshot` и `GenerateBaselineSnapshot` успешно скомпилированы `javac 1.8.0_512` с classpath ранее собранного SchemaAnalyst.

Первый запуск через Java debugger остановился до main:

```text
Gradle build failed with exit code 1.
```

Диагностика Java Language Server:

```text
Missing mandatory Classpath entries. Resolve Project Problems.
GenerateBaselineSnapshot.java is a non-project file, only syntax errors are reported.
```

После явной компиляции был выполнен запуск с `skipBuild=true` и полным classpath. Инструмент вернул:

```text
Debug session not yet detected for
org.schemaanalyst.minimization.GenerateBaselineSnapshot after 120 seconds.
Startup is unconfirmed, not necessarily failed.
```

Активная debug-сессия не обнаружена, файл снимка не создан. В списке процессов найден Gradle 4.10.2 daemon, запущенный на Oracle JDK 27:

```text
oracleJdk-27\bin\java.exe ...
org.gradle.launcher.daemon.bootstrap.GradleDaemon 4.10.2
```

Таким образом, воспроизводимый Java-запуск пока блокируется конфигурацией Java/Gradle в VS Code. Отсутствие снимка не считается нулевым результатом генерации.
