$ErrorActionPreference = 'Stop'

$cmake = 'C:/msys64/mingw64/bin/cmake.exe'
$compiler = 'C:/msys64/mingw64/bin/g++.exe'
$ctest = 'C:/msys64/mingw64/bin/ctest.exe'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$build = Join-Path $root 'build/cpp'
$resultDirectory = Join-Path $PSScriptRoot 'results/cpp-checks'
$fixture = Join-Path $PSScriptRoot 'fixtures/basic.json'
$report = Join-Path $resultDirectory 'basic-report.json'

New-Item -ItemType Directory -Force -Path $resultDirectory | Out-Null

& $cmake -S (Join-Path $root 'cpp') -B $build -G Ninja "-DCMAKE_CXX_COMPILER=$compiler"
if ($LASTEXITCODE -ne 0) { throw 'CMake configuration failed' }

& $cmake --build $build
if ($LASTEXITCODE -ne 0) { throw 'C++ build failed' }

& $ctest --test-dir $build --output-on-failure
if ($LASTEXITCODE -ne 0) { throw 'C++ tests failed' }

& (Join-Path $build 'test_suite_minimization.exe') $fixture $report
if ($LASTEXITCODE -ne 0) { throw 'CLI fixture failed' }

Get-Content -LiteralPath $report -Encoding UTF8
