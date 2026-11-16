param(
    [string]$JavaHome = (Join-Path $PSScriptRoot '../../schemaanalyst_experiments/runtime/jdk8u512-b09'),
    [string]$DependencyBuild = (Join-Path $PSScriptRoot '../../schemaanalyst/schemaanalyst'),
    [int[]]$Seeds = @(0),
    [int]$Budget = 10000
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$javaHomePath = (Resolve-Path $JavaHome).Path
$dependencyPath = (Resolve-Path $DependencyBuild).Path
$java = Join-Path $javaHomePath 'bin/java.exe'
$javac = Join-Path $javaHomePath 'bin/javac.exe'
$classes = Join-Path $root 'build/classes/java/main'
$classpath = "$classes;$dependencyPath/build/classes/java/main;$dependencyPath/build/lib/*;$dependencyPath/lib/*"
$resultRoot = Join-Path $PSScriptRoot ('results/matrix-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$cpp = Join-Path $root 'build/cpp/test_suite_minimization.exe'

New-Item -ItemType Directory -Force -Path $classes, $resultRoot | Out-Null

$javaSources = Get-ChildItem (Join-Path $root 'src/main/java/org/schemaanalyst/minimization') -Filter '*.java' |
    Select-Object -ExpandProperty FullName
& $javac -encoding UTF-8 -cp $classpath -d $classes $javaSources
if ($LASTEXITCODE -ne 0) { throw 'Compilation of minimization Java sources failed' }

& 'C:/msys64/mingw64/bin/cmake.exe' -S (Join-Path $root 'cpp') -B (Join-Path $root 'build/cpp') `
    -G Ninja -DCMAKE_CXX_COMPILER=C:/msys64/mingw64/bin/g++.exe
if ($LASTEXITCODE -ne 0) { throw 'CMake configuration failed' }
& 'C:/msys64/mingw64/bin/cmake.exe' --build (Join-Path $root 'build/cpp')
if ($LASTEXITCODE -ne 0) { throw 'C++ build failed' }

& $java -version 2>&1 | Out-File (Join-Path $resultRoot 'environment.log') -Encoding UTF8
& 'C:/msys64/mingw64/bin/g++.exe' --version 2>&1 | Out-File (Join-Path $resultRoot 'environment.log') -Append -Encoding UTF8
& 'C:/Program Files/PostgreSQL/18/bin/psql.exe' --version 2>&1 | Out-File (Join-Path $resultRoot 'environment.log') -Append -Encoding UTF8

$generators = @('avsDefaults', 'randomDefaults', 'dominoRandom', 'dominoAVS')
$reducers = @('none', 'simpleGreedy', 'additionalGreedy', 'HGS', 'random', 'sticcer')

foreach ($seed in $Seeds) {
    foreach ($generator in $generators) {
        $prefix = Join-Path $resultRoot "$generator-$seed"
        $snapshot = "$prefix.ser"
        $fullJson = "$prefix-full.json"

        & $java -cp $classpath org.schemaanalyst.minimization.GenerateBaselineSnapshot `
            $generator $seed $Budget $snapshot 2>&1 | Tee-Object "$prefix-generation.log"
        if ($LASTEXITCODE -ne 0) { continue }

        & $java -cp $classpath org.schemaanalyst.minimization.ExportBaselineJson `
            $snapshot $fullJson 2>&1 | Tee-Object "$prefix-export.log"
        if ($LASTEXITCODE -ne 0) { continue }

        & $cpp $fullJson "$prefix-boundary-report.json" 2>&1 | Tee-Object "$prefix-boundary.log"

        foreach ($reducer in $reducers) {
            & $java -cp $classpath org.schemaanalyst.minimization.RunSnapshotReducer `
                $snapshot $reducer "$prefix-$reducer.json" 2>&1 | Tee-Object "$prefix-$reducer.log"
        }
    }
}

Write-Output "Results: $resultRoot"
