param(
    [string]$JavaHome = (Join-Path $PSScriptRoot '..\..\schemaanalyst_experiments\runtime\jdk8u512-b09'),
    [string]$DependencyBuild = (Join-Path $PSScriptRoot '..'),
    [int[]]$Seeds = @(0),
    [int]$Budget = 10000,
    [string[]]$Generators = @('avsDefaults', 'randomDefaults', 'dominoRandom', 'dominoAVS'),
    [string[]]$Reducers = @('none', 'simpleGreedy', 'additionalGreedy', 'HGS', 'random', 'sticcer'),
    [int]$PostgresPort = 55432,
    [string]$PostgresUser = 'baseline',
    [string]$PostgresDatabase = 'coursework_validation'
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location -LiteralPath $root
$javaHomePath = (Resolve-Path $JavaHome).Path
$dependencyPath = (Resolve-Path $DependencyBuild).Path
$java = Join-Path $javaHomePath 'bin\java.exe'
$javac = Join-Path $javaHomePath 'bin\javac.exe'
$classes = Join-Path $root 'build\classes\java\main'
$classpath = "$classes;$dependencyPath\build\classes\java\main;$dependencyPath\build\classes\main;$dependencyPath\build\lib\*;$dependencyPath\lib\*"
$runId = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
$resultRoot = Join-Path $PSScriptRoot "results\matrix-$runId"
$cppBuild = Join-Path $root 'build\cpp'
$cpp = Join-Path $cppBuild 'test_suite_minimization.exe'
$cmake = 'C:\msys64\mingw64\bin\cmake.exe'
$compiler = 'C:\msys64\mingw64\bin\g++.exe'
$ctest = 'C:\msys64\mingw64\bin\ctest.exe'
$psql = 'C:\Program Files\PostgreSQL\18\bin\psql.exe'
$createdb = 'C:\Program Files\PostgreSQL\18\bin\createdb.exe'
$validator = Join-Path $PSScriptRoot 'validate_postgres.ps1'

New-Item -ItemType Directory -Force -Path $classes, $resultRoot | Out-Null

function Invoke-Logged {
    param(
        [string]$Executable,
        [string[]]$Arguments,
        [string]$LogPath
    )

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $Executable @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }

    $lines = @($output | ForEach-Object { $_.ToString() })
    [System.IO.File]::WriteAllLines(
        $LogPath,
        $lines,
        (New-Object System.Text.UTF8Encoding($false)))
    [pscustomobject]@{
        ExitCode = $exitCode
        Output = $lines
    }
}

function Add-Failure {
    param(
        [string]$Generator,
        [int]$Seed,
        [string]$Phase,
        [string]$Command,
        [string]$Message,
        [string]$LogPath
    )

    [void]$failures.Add([pscustomobject]@{
        generator = $Generator
        seed = $Seed
        phase = $Phase
        command = $Command
        message = $Message
        log = $LogPath
    })
}

function New-ResultRow {
    param([string]$Generator, [int]$Seed, [string]$Reducer)
    [ordered]@{
        generator = $Generator
        seed = $Seed
        reducer = $Reducer
        status = 'NOT_RUN'
        snapshot_sha256 = 'NA'
        generation_ns = 'NA'
        original_tests = 'NA'
        final_tests = 'NA'
        original_state_inserts = 'NA'
        final_state_inserts = 'NA'
        original_data_inserts = 'NA'
        final_data_inserts = 'NA'
        reduction_ns = 'NA'
        requirements_before = 'NA'
        requirements_after = 'NA'
        lost_requirements = 'NA'
        boundaries_before = 'NA'
        boundaries_after = 'NA'
        lost_boundaries = 'NA'
        unverified_boundary_tests = 'NA'
        postgres_cases = 'NA'
        postgres_matches = 'NA'
        postgres_status = 'NOT_RUN'
        verification = 'NOT_RUN'
        result_json = 'NA'
        postgres_csv = 'NA'
    }
}

function Sum-JsonProperty {
    param([object[]]$Items, [string]$Property)
    $total = 0
    foreach ($item in $Items) {
        $total += [int]$item.$Property
    }
    $total
}

function Get-LostValues {
    param([object[]]$Original, [object[]]$Reduced)
    $reducedSet = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($value in $Reduced) {
        [void]$reducedSet.Add([string]$value)
    }
    $lost = New-Object 'System.Collections.Generic.List[string]'
    foreach ($value in $Original) {
        if (-not $reducedSet.Contains([string]$value)) {
            [void]$lost.Add([string]$value)
        }
    }
    $lost.ToArray()
}

function Invoke-PostgresValidation {
    param(
        [string]$InputJson,
        [string]$ResultCsv,
        [string]$LogPath
    )

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $exceptionMessage = ''
    try {
        $output = @(& $validator `
            -InputJson $InputJson `
            -HostName '127.0.0.1' `
            -Port $PostgresPort `
            -User $PostgresUser `
            -Database $PostgresDatabase `
            -Psql $psql `
            -Createdb $createdb `
            -ResultPath $ResultCsv 2>&1)
    } catch {
        $exceptionMessage = $_.Exception.ToString()
        $output = @()
    } finally {
        $ErrorActionPreference = $previousPreference
    }

    $lines = @($output | ForEach-Object { $_.ToString() })
    if ($exceptionMessage) {
        $lines += $exceptionMessage
    }
    [System.IO.File]::WriteAllLines(
        $LogPath,
        $lines,
        (New-Object System.Text.UTF8Encoding($false)))

    if (-not (Test-Path -LiteralPath $ResultCsv)) {
        return [pscustomobject]@{ Cases = 0; Matches = 0; Status = 'FAILED' }
    }
    $rows = @(Import-Csv -LiteralPath $ResultCsv)
    if ($rows.Count -eq 0) {
        return [pscustomobject]@{ Cases = 0; Matches = 0; Status = 'NO_ROWS' }
    }
    $matches = @($rows | Where-Object { $_.matches_expected -ieq 'True' }).Count
    $status = if ($matches -eq $rows.Count) { 'PASS' } else { 'MISMATCH' }
    [pscustomobject]@{ Cases = $rows.Count; Matches = $matches; Status = $status }
}

function Add-PostgresEvidence {
    param(
        [string]$InputJson,
        [string]$ValidationCsv,
        [string]$OutputJson
    )

    $document = Get-Content -LiteralPath $InputJson -Raw -Encoding UTF8 | ConvertFrom-Json
    $validationRows = @()
    if (Test-Path -LiteralPath $ValidationCsv) {
        $validationRows = @(Import-Csv -LiteralPath $ValidationCsv)
    }
    $validationById = @{}
    foreach ($row in $validationRows) {
        $validationById[[string]$row.test_id] = $row
    }

    foreach ($test in $document.tests) {
        $validation = $null
        $actualResult = $null
        if ($validationById.ContainsKey([string]$test.id)) {
            $validation = $validationById[[string]$test.id]
            if ($validation.phase -eq 'data' -and $validation.actual_result -match '^(True|False)$') {
                $actualResult = [bool]::Parse($validation.actual_result)
            }
        }
        $test | Add-Member -NotePropertyName postgresValidation -NotePropertyValue ([ordered]@{
            phase = if ($validation) { [string]$validation.phase } else { 'missing' }
            actualResult = $actualResult
            sqlstate = if ($validation) { [string]$validation.sqlstate } else { '' }
            constraintName = if ($validation) { [string]$validation.constraint_name } else { '' }
        }) -Force
    }

    $jsonText = ConvertTo-Json -InputObject $document -Depth 100
    [System.IO.File]::WriteAllText(
        $OutputJson,
        $jsonText + [Environment]::NewLine,
        (New-Object System.Text.UTF8Encoding($false)))
    $document
}

$failures = New-Object 'System.Collections.Generic.List[object]'
$results = New-Object 'System.Collections.Generic.List[object]'
$environment = New-Object 'System.Collections.Generic.List[string]'

foreach ($entry in @(
    @{ Name = 'java'; File = $java; Args = @('-version') },
    @{ Name = 'javac'; File = $javac; Args = @('-version') },
    @{ Name = 'g++'; File = $compiler; Args = @('--version') },
    @{ Name = 'psql'; File = $psql; Args = @('--version') },
    @{ Name = 'cmake'; File = $cmake; Args = @('--version') }
)) {
    $versionLog = Join-Path $resultRoot "$($entry.Name)-version.log"
    $version = Invoke-Logged -Executable $entry.File -Arguments $entry.Args -LogPath $versionLog
    $environment.Add("$($entry.Name): $($version.Output -join ' ')")
    if ($version.ExitCode -ne 0) {
        Add-Failure -Generator 'all' -Seed 0 -Phase 'environment' `
            -Command "$($entry.File) $($entry.Args -join ' ')" `
            -Message "exit_code=$($version.ExitCode)" -LogPath $versionLog
    }
}

$environment.Add("java_home=$javaHomePath")
$environment.Add("dependency_build=$dependencyPath")
$environment.Add("powershell=$($PSVersionTable.PSVersion)")
$environment.Add("postgres_host=127.0.0.1")
$environment.Add("postgres_port=$PostgresPort")
$environment.Add("postgres_database=$PostgresDatabase")
[System.IO.File]::WriteAllLines(
    (Join-Path $resultRoot 'environment.log'),
    $environment,
    (New-Object System.Text.UTF8Encoding($false)))

$configureLog = Join-Path $resultRoot 'cmake-configure.log'
$configure = Invoke-Logged -Executable $cmake -Arguments @(
    '-S', (Join-Path $root 'cpp'),
    '-B', $cppBuild,
    '-G', 'Ninja',
    "-DCMAKE_CXX_COMPILER=$compiler"
) -LogPath $configureLog
if ($configure.ExitCode -ne 0) {
    Add-Failure -Generator 'all' -Seed 0 -Phase 'cmake-configure' `
        -Command "$cmake -S $root\cpp -B $cppBuild -G Ninja" `
        -Message "exit_code=$($configure.ExitCode)" -LogPath $configureLog
    throw "CMake configure failed; inspect $configureLog"
}

$buildLog = Join-Path $resultRoot 'cmake-build.log'
$buildResult = Invoke-Logged -Executable $cmake -Arguments @('--build', $cppBuild) -LogPath $buildLog
if ($buildResult.ExitCode -ne 0) {
    Add-Failure -Generator 'all' -Seed 0 -Phase 'cpp-build' `
        -Command "$cmake --build $cppBuild" `
        -Message "exit_code=$($buildResult.ExitCode)" -LogPath $buildLog
    throw "C++ build failed; inspect $buildLog"
}

$ctestLog = Join-Path $resultRoot 'ctest.log'
$testResult = Invoke-Logged -Executable $ctest -Arguments @(
    '--test-dir', $cppBuild, '--output-on-failure'
) -LogPath $ctestLog
if ($testResult.ExitCode -ne 0) {
    Add-Failure -Generator 'all' -Seed 0 -Phase 'cpp-tests' `
        -Command "$ctest --test-dir $cppBuild --output-on-failure" `
        -Message "exit_code=$($testResult.ExitCode)" -LogPath $ctestLog
    throw "C++ tests failed; inspect $ctestLog"
}

$javaSources = @(Get-ChildItem (Join-Path $root 'src\main\java\org\schemaanalyst\minimization') -Filter '*.java' |
    Select-Object -ExpandProperty FullName)
$compileLog = Join-Path $resultRoot 'java-compile.log'
$compileArguments = @('-encoding', 'UTF-8', '-cp', $classpath, '-d', $classes) + $javaSources
$compileResult = Invoke-Logged -Executable $javac -Arguments $compileArguments -LogPath $compileLog
if ($compileResult.ExitCode -ne 0) {
    Add-Failure -Generator 'all' -Seed 0 -Phase 'java-compile' `
        -Command "$javac -encoding UTF-8 -cp <classpath> -d $classes <minimization sources>" `
        -Message "exit_code=$($compileResult.ExitCode)" -LogPath $compileLog
    throw "Java experiment compilation failed; inspect $compileLog"
}

foreach ($seed in $Seeds) {
    foreach ($generator in $Generators) {
        $prefix = Join-Path $resultRoot "$generator-$seed"
        $snapshot = "$prefix.ser"
        $fullJson = "$prefix-full.json"
        $generationLog = "$prefix-generation.log"
        $generation = Invoke-Logged -Executable $java -Arguments @(
            '-cp', $classpath,
            'org.schemaanalyst.minimization.GenerateBaselineSnapshot',
            $generator, [string]$seed, [string]$Budget, $snapshot
        ) -LogPath $generationLog

        if ($generation.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $snapshot)) {
            $message = "exit_code=$($generation.ExitCode); snapshot_exists=$(Test-Path -LiteralPath $snapshot)"
            Add-Failure -Generator $generator -Seed $seed -Phase 'generation' `
                -Command "$java -cp <classpath> org.schemaanalyst.minimization.GenerateBaselineSnapshot $generator $seed $Budget $snapshot" `
                -Message $message -LogPath $generationLog
            foreach ($reducer in @($Reducers) + @('boundaryAware')) {
                $row = New-ResultRow -Generator $generator -Seed $seed -Reducer $reducer
                $row.status = 'GENERATION_FAILED'
                [void]$results.Add([pscustomobject]$row)
            }
            continue
        }

        $snapshotHash = (Get-FileHash -LiteralPath $snapshot -Algorithm SHA256).Hash.ToLowerInvariant()
        $exportLog = "$prefix-export.log"
        $export = Invoke-Logged -Executable $java -Arguments @(
            '-cp', $classpath,
            'org.schemaanalyst.minimization.ExportBaselineJson',
            $snapshot, $fullJson
        ) -LogPath $exportLog
        if ($export.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $fullJson)) {
            Add-Failure -Generator $generator -Seed $seed -Phase 'export' `
                -Command "$java -cp <classpath> org.schemaanalyst.minimization.ExportBaselineJson $snapshot $fullJson" `
                -Message "exit_code=$($export.ExitCode); json_exists=$(Test-Path -LiteralPath $fullJson)" `
                -LogPath $exportLog
            foreach ($reducer in @($Reducers) + @('boundaryAware')) {
                $row = New-ResultRow -Generator $generator -Seed $seed -Reducer $reducer
                $row.snapshot_sha256 = $snapshotHash
                $row.status = 'EXPORT_FAILED'
                [void]$results.Add([pscustomobject]$row)
            }
            continue
        }

        $fullDocument = Get-Content -LiteralPath $fullJson -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($fullDocument.snapshotSha256 -ne $snapshotHash) {
            Add-Failure -Generator $generator -Seed $seed -Phase 'snapshot-hash' `
                -Command "SHA256($snapshot); compare full JSON snapshotSha256" `
                -Message "file=$snapshotHash; json=$($fullDocument.snapshotSha256)" -LogPath $exportLog
            continue
        }

        $fullPostgresCsv = "$prefix-full-postgres.csv"
        $fullPostgresLog = "$prefix-full-postgres.log"
        $fullPostgresResult = Invoke-PostgresValidation -InputJson $fullJson `
            -ResultCsv $fullPostgresCsv -LogPath $fullPostgresLog
        $fullValidatedJson = "$prefix-full-validated.json"
        $fullDocument = Add-PostgresEvidence -InputJson $fullJson `
            -ValidationCsv $fullPostgresCsv -OutputJson $fullValidatedJson
        if ($fullPostgresResult.Status -ne 'PASS') {
            Add-Failure -Generator $generator -Seed $seed -Phase 'postgres-full' `
                -Command "validate_postgres.ps1 -InputJson $fullJson -Port $PostgresPort -User $PostgresUser -Database $PostgresDatabase" `
                -Message "status=$($fullPostgresResult.Status); matches=$($fullPostgresResult.Matches)/$($fullPostgresResult.Cases)" `
                -LogPath $fullPostgresLog
        }

        $fullCoveragePath = "$prefix-full-boundary-report.json"
        $fullCoverageLog = "$prefix-full-boundary.log"
        $fullCoverageRun = Invoke-Logged -Executable $cpp -Arguments @(
            $fullValidatedJson, $fullCoveragePath
        ) -LogPath $fullCoverageLog
        if ($fullCoverageRun.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $fullCoveragePath)) {
            Add-Failure -Generator $generator -Seed $seed -Phase 'full-coverage' `
                -Command "$cpp $fullValidatedJson $fullCoveragePath" `
                -Message "exit_code=$($fullCoverageRun.ExitCode); report_exists=$(Test-Path -LiteralPath $fullCoveragePath)" `
                -LogPath $fullCoverageLog
            continue
        }
        $fullCoverage = Get-Content -LiteralPath $fullCoveragePath -Raw -Encoding UTF8 | ConvertFrom-Json
        $fullBoundaries = @($fullCoverage.boundariesBefore | ForEach-Object { [string]$_ })
        $fullRequirements = @($fullCoverage.requirementsBefore | ForEach-Object { [string]$_ })
        $fullTests = @($fullDocument.tests)
        $generationNs = $fullDocument.generation.generationNanoseconds
        $originalStateInserts = Sum-JsonProperty -Items $fullTests -Property 'stateInsertCount'
        $originalDataInserts = Sum-JsonProperty -Items $fullTests -Property 'dataInsertCount'

        foreach ($reducer in $Reducers) {
            $row = New-ResultRow -Generator $generator -Seed $seed -Reducer $reducer
            $row.snapshot_sha256 = $snapshotHash
            $row.generation_ns = $generationNs
            $row.original_tests = $fullTests.Count
            $row.original_state_inserts = $originalStateInserts
            $row.original_data_inserts = $originalDataInserts

            if ((Get-FileHash -LiteralPath $snapshot -Algorithm SHA256).Hash.ToLowerInvariant() -ne $snapshotHash) {
                $row.status = 'SNAPSHOT_CHANGED'
                [void]$results.Add([pscustomobject]$row)
                Add-Failure -Generator $generator -Seed $seed -Phase 'snapshot-invariant' `
                    -Command "SHA256($snapshot)" -Message 'Source snapshot changed during reducer loop.' `
                    -LogPath $generationLog
                break
            }

            $reducedJson = "$prefix-$reducer.json"
            $reducerLog = "$prefix-$reducer.log"
            $reduction = Invoke-Logged -Executable $java -Arguments @(
                '-cp', $classpath,
                'org.schemaanalyst.minimization.RunSnapshotReducer',
                $snapshot, $reducer, $reducedJson
            ) -LogPath $reducerLog
            if ($reduction.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $reducedJson)) {
                $row.status = 'REDUCER_FAILED'
                [void]$results.Add([pscustomobject]$row)
                Add-Failure -Generator $generator -Seed $seed -Phase "reducer-$reducer" `
                    -Command "$java -cp <classpath> org.schemaanalyst.minimization.RunSnapshotReducer $snapshot $reducer $reducedJson" `
                    -Message "exit_code=$($reduction.ExitCode); json_exists=$(Test-Path -LiteralPath $reducedJson)" `
                    -LogPath $reducerLog
                continue
            }

            $reducedDocument = Get-Content -LiteralPath $reducedJson -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($reducedDocument.snapshotSha256 -ne $snapshotHash) {
                $row.status = 'SNAPSHOT_HASH_MISMATCH'
                [void]$results.Add([pscustomobject]$row)
                Add-Failure -Generator $generator -Seed $seed -Phase "reducer-hash-$reducer" `
                    -Command "Read snapshotSha256 from $reducedJson" `
                    -Message "expected=$snapshotHash; actual=$($reducedDocument.snapshotSha256)" `
                    -LogPath $reducerLog
                continue
            }

            $postgresCsv = "$prefix-$reducer-postgres.csv"
            $postgresLog = "$prefix-$reducer-postgres.log"
            $postgresResult = Invoke-PostgresValidation -InputJson $reducedJson `
                -ResultCsv $postgresCsv -LogPath $postgresLog
            $validatedJson = "$prefix-$reducer-validated.json"
            $reducedDocument = Add-PostgresEvidence -InputJson $reducedJson `
                -ValidationCsv $postgresCsv -OutputJson $validatedJson

            $coveragePath = "$prefix-$reducer-coverage.json"
            $coverageLog = "$prefix-$reducer-coverage.log"
            $coverageRun = Invoke-Logged -Executable $cpp -Arguments @(
                $validatedJson, $coveragePath
            ) -LogPath $coverageLog
            $row.requirements_before = $fullRequirements.Count
            $row.boundaries_before = $fullBoundaries.Count
            if ($coverageRun.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $coveragePath)) {
                $row.verification = 'FAILED'
                Add-Failure -Generator $generator -Seed $seed -Phase "coverage-$reducer" `
                    -Command "$cpp $validatedJson $coveragePath" `
                    -Message "exit_code=$($coverageRun.ExitCode); report_exists=$(Test-Path -LiteralPath $coveragePath)" `
                    -LogPath $coverageLog
            } else {
                $coverage = Get-Content -LiteralPath $coveragePath -Raw -Encoding UTF8 | ConvertFrom-Json
                $lostRequirements = @(Get-LostValues -Original $fullRequirements -Reduced @($coverage.requirementsBefore))
                $lostBoundaries = @(Get-LostValues -Original $fullBoundaries -Reduced @($coverage.boundariesBefore))
                $row.requirements_after = @($coverage.requirementsBefore).Count
                $row.lost_requirements = $lostRequirements -join ';'
                $row.boundaries_after = @($coverage.boundariesBefore).Count
                $row.lost_boundaries = $lostBoundaries -join ';'
                $row.unverified_boundary_tests = @($coverage.unverifiedBoundaryTestIds).Count
                $fullUnverifiedCount = @($fullCoverage.unverifiedBoundaryTestIds).Count
                $row.verification = if ($coverage.verified -and $lostRequirements.Count -eq 0 -and $lostBoundaries.Count -eq 0 -and $row.unverified_boundary_tests -eq 0 -and $fullUnverifiedCount -eq 0) {
                    'PASS'
                } elseif ($coverage.verified -and $lostRequirements.Count -eq 0 -and $lostBoundaries.Count -eq 0) {
                    'PASS_WITH_UNVERIFIED_CANDIDATES'
                } else {
                    'COVERAGE_LOSS'
                }
            }

            $methodTests = @($reducedDocument.tests)
            $row.final_tests = $methodTests.Count
            $row.final_state_inserts = Sum-JsonProperty -Items $methodTests -Property 'stateInsertCount'
            $row.final_data_inserts = Sum-JsonProperty -Items $methodTests -Property 'dataInsertCount'
            $row.reduction_ns = $reducedDocument.reduction.nanoseconds
            $row.result_json = $validatedJson
            $row.postgres_cases = $postgresResult.Cases
            $row.postgres_matches = $postgresResult.Matches
            $row.postgres_status = $postgresResult.Status
            $row.postgres_csv = if (Test-Path -LiteralPath $postgresCsv) { $postgresCsv } else { 'NA' }
            $row.status = if ($row.postgres_status -eq 'FAILED' -or $row.postgres_status -eq 'NO_ROWS') {
                'POSTGRES_FAILED'
            } elseif ($row.postgres_status -ne 'PASS') {
                'POSTGRES_MISMATCH'
            } elseif ($row.verification -eq 'PASS') {
                'PASS'
            } elseif ($row.verification -eq 'PASS_WITH_UNVERIFIED_CANDIDATES') {
                'PASS_WITH_UNVERIFIED_CANDIDATES'
            } else {
                'REQUIREMENT_OR_BOUNDARY_LOSS'
            }
            if ($row.postgres_status -ne 'PASS') {
                Add-Failure -Generator $generator -Seed $seed -Phase "postgres-$reducer" `
                    -Command "validate_postgres.ps1 -InputJson $reducedJson -Port $PostgresPort -User $PostgresUser -Database $PostgresDatabase" `
                    -Message "status=$($row.postgres_status); matches=$($row.postgres_matches)/$($row.postgres_cases)" `
                    -LogPath $postgresLog
            }
            [void]$results.Add([pscustomobject]$row)
        }

        $boundaryRow = New-ResultRow -Generator $generator -Seed $seed -Reducer 'boundaryAware'
        $boundaryRow.snapshot_sha256 = $snapshotHash
        $boundaryRow.generation_ns = $generationNs
        $boundaryRow.original_tests = $fullTests.Count
        $boundaryRow.original_state_inserts = $originalStateInserts
        $boundaryRow.original_data_inserts = $originalDataInserts
        $boundaryRow.requirements_before = $fullRequirements.Count
        $boundaryRow.boundaries_before = $fullBoundaries.Count
        $boundaryRow.reduction_ns = $fullCoverage.selectionNanoseconds

        if ($fullCoverageRun.ExitCode -ne 0 -or -not $fullCoverage.verified) {
            $boundaryRow.status = 'BOUNDARY_REDUCER_FAILED'
            $boundaryRow.verification = 'FAILED'
            [void]$results.Add([pscustomobject]$boundaryRow)
            continue
        }

        $selectedIds = New-Object 'System.Collections.Generic.HashSet[string]'
        foreach ($id in $fullCoverage.selectedTestIds) {
            [void]$selectedIds.Add([string]$id)
        }
        $selectedTests = @($fullTests | Where-Object { $selectedIds.Contains([string]$_.id) })
        $selectedDocument = [ordered]@{
            formatVersion = $fullDocument.formatVersion
            snapshotSha256 = $fullDocument.snapshotSha256
            generation = $fullDocument.generation
            schema = $fullDocument.schema
            requirements = $fullDocument.requirements
            tests = $selectedTests
        }
        $selectedJson = "$prefix-boundaryAware.json"
        $selectedText = ConvertTo-Json -InputObject $selectedDocument -Depth 100
        [System.IO.File]::WriteAllText(
            $selectedJson,
            $selectedText + [Environment]::NewLine,
            (New-Object System.Text.UTF8Encoding($false)))

        $postgresCsv = "$prefix-boundaryAware-postgres.csv"
        $postgresLog = "$prefix-boundaryAware-postgres.log"
        $postgresResult = Invoke-PostgresValidation -InputJson $selectedJson `
            -ResultCsv $postgresCsv -LogPath $postgresLog
        $selectedValidatedJson = "$prefix-boundaryAware-validated.json"
        $selectedDocument = Add-PostgresEvidence -InputJson $selectedJson `
            -ValidationCsv $postgresCsv -OutputJson $selectedValidatedJson

        $verifyPath = "$prefix-boundaryAware-verify.json"
        $verifyLog = "$prefix-boundaryAware-verify.log"
        $verifyRun = Invoke-Logged -Executable $cpp -Arguments @(
            $selectedValidatedJson, $verifyPath
        ) -LogPath $verifyLog
        if ($verifyRun.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $verifyPath)) {
            $boundaryRow.status = 'BOUNDARY_VERIFY_FAILED'
            $boundaryRow.verification = 'FAILED'
            Add-Failure -Generator $generator -Seed $seed -Phase 'boundary-aware-verification' `
                -Command "$cpp $selectedValidatedJson $verifyPath" `
                -Message "exit_code=$($verifyRun.ExitCode); report_exists=$(Test-Path -LiteralPath $verifyPath)" `
                -LogPath $verifyLog
            [void]$results.Add([pscustomobject]$boundaryRow)
            continue
        }

        $verifiedBoundary = Get-Content -LiteralPath $verifyPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $lostRequirements = @(Get-LostValues -Original $fullRequirements -Reduced @($verifiedBoundary.requirementsBefore))
        $lostBoundaries = @(Get-LostValues -Original $fullBoundaries -Reduced @($verifiedBoundary.boundariesBefore))
        $boundaryRow.final_tests = $selectedTests.Count
        $boundaryRow.final_state_inserts = Sum-JsonProperty -Items $selectedTests -Property 'stateInsertCount'
        $boundaryRow.final_data_inserts = Sum-JsonProperty -Items $selectedTests -Property 'dataInsertCount'
        $boundaryRow.requirements_after = @($verifiedBoundary.requirementsBefore).Count
        $boundaryRow.lost_requirements = $lostRequirements -join ';'
        $boundaryRow.boundaries_after = @($verifiedBoundary.boundariesBefore).Count
        $boundaryRow.lost_boundaries = $lostBoundaries -join ';'
        $boundaryRow.unverified_boundary_tests = @($verifiedBoundary.unverifiedBoundaryTestIds).Count
        $fullUnverifiedCount = @($fullCoverage.unverifiedBoundaryTestIds).Count
        $boundaryRow.verification = if ($verifiedBoundary.verified -and $lostRequirements.Count -eq 0 -and $lostBoundaries.Count -eq 0 -and $boundaryRow.unverified_boundary_tests -eq 0 -and $fullUnverifiedCount -eq 0) {
            'PASS'
        } elseif ($verifiedBoundary.verified -and $lostRequirements.Count -eq 0 -and $lostBoundaries.Count -eq 0) {
            'PASS_WITH_UNVERIFIED_CANDIDATES'
        } else {
            'COVERAGE_LOSS'
        }
        $boundaryRow.result_json = $selectedValidatedJson
        $boundaryRow.postgres_cases = $postgresResult.Cases
        $boundaryRow.postgres_matches = $postgresResult.Matches
        $boundaryRow.postgres_status = $postgresResult.Status
        $boundaryRow.postgres_csv = if (Test-Path -LiteralPath $postgresCsv) { $postgresCsv } else { 'NA' }
        $boundaryRow.status = if ($boundaryRow.postgres_status -eq 'FAILED' -or $boundaryRow.postgres_status -eq 'NO_ROWS') {
            'POSTGRES_FAILED'
        } elseif ($boundaryRow.postgres_status -ne 'PASS') {
            'POSTGRES_MISMATCH'
        } elseif ($boundaryRow.verification -eq 'PASS') {
            'PASS'
        } elseif ($boundaryRow.verification -eq 'PASS_WITH_UNVERIFIED_CANDIDATES') {
            'PASS_WITH_UNVERIFIED_CANDIDATES'
        } else {
            'REQUIREMENT_OR_BOUNDARY_LOSS'
        }
        if ($boundaryRow.postgres_status -ne 'PASS') {
            Add-Failure -Generator $generator -Seed $seed -Phase 'postgres-boundaryAware' `
                -Command "validate_postgres.ps1 -InputJson $selectedJson -Port $PostgresPort -User $PostgresUser -Database $PostgresDatabase" `
                -Message "status=$($boundaryRow.postgres_status); matches=$($boundaryRow.postgres_matches)/$($boundaryRow.postgres_cases)" `
                -LogPath $postgresLog
        }
        [void]$results.Add([pscustomobject]$boundaryRow)
    }
}

$summaryPath = Join-Path $resultRoot 'summary.csv'
if ($results.Count -gt 0) {
    $results | Export-Csv -LiteralPath $summaryPath -NoTypeInformation -Encoding UTF8
}
if ($failures.Count -gt 0) {
    $failures | Export-Csv -LiteralPath (Join-Path $resultRoot 'failures.csv') -NoTypeInformation -Encoding UTF8
}

Write-Output "Results: $resultRoot"
if (Test-Path -LiteralPath $summaryPath) {
    Import-Csv -LiteralPath $summaryPath |
        Select-Object generator, seed, reducer, status, final_tests, lost_requirements, lost_boundaries, postgres_status |
        Format-Table -AutoSize
}
if ($failures.Count -gt 0) {
    Write-Output "Failures: $($failures.Count). See $(Join-Path $resultRoot 'failures.csv') and per-run logs."
}
