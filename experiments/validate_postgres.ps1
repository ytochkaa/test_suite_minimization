param(
    [Parameter(Mandatory = $true)]
    [string]$InputJson,
    [string]$HostName = '127.0.0.1',
    [int]$Port = 55432,
    [string]$User = 'baseline',
    [string]$Database = 'coursework_validation',
    [string]$Psql = 'C:/Program Files/PostgreSQL/18/bin/psql.exe',
    [string]$Createdb = 'C:/Program Files/PostgreSQL/18/bin/createdb.exe',
    [string]$ResultPath
)

$ErrorActionPreference = 'Stop'

function Get-ConstraintName {
    param([string]$Message)
    if ($Message -match 'violates check constraint "([^"]+)"') {
        return $matches[1]
    }
    if ($Message -match 'CONSTRAINT NAME:\s*"?([^"\s]+)"?') {
        return $matches[1]
    }
    ''
}

$inputPath = (Resolve-Path $InputJson).Path
$schemaPath = (Resolve-Path (Join-Path $PSScriptRoot 'schema.sql')).Path.Replace('\', '/')
if ([string]::IsNullOrWhiteSpace($ResultPath)) {
    $resultDirectory = Join-Path $PSScriptRoot 'results/postgres-validation'
    $resultPath = Join-Path $resultDirectory ([System.IO.Path]::GetFileNameWithoutExtension($inputPath) + '.csv')
} else {
    $resultPath = [System.IO.Path]::GetFullPath($ResultPath)
    $resultDirectory = Split-Path -Parent $resultPath
}
New-Item -ItemType Directory -Force -Path $resultDirectory | Out-Null

$databaseExists = & $Psql -X -w -h $HostName -p $Port -U $User -d postgres -tAc `
    "SELECT 1 FROM pg_database WHERE datname = '$Database'"
if ($LASTEXITCODE -ne 0) { throw 'Cannot query PostgreSQL databases' }
if (-not $databaseExists) {
    & $Createdb -w -h $HostName -p $Port -U $User $Database
    if ($LASTEXITCODE -ne 0) { throw "Cannot create isolated database $Database" }
}

$document = Get-Content -LiteralPath $inputPath -Raw -Encoding UTF8 | ConvertFrom-Json
$rows = New-Object System.Collections.Generic.List[object]

foreach ($test in $document.tests) {
    $reset = @"
\set ON_ERROR_STOP on
DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;
\i '$schemaPath'
"@
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $resetOutput = $reset | & $Psql -X -w -h $HostName -p $Port -U $User -d $Database 2>&1
        $resetExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($resetExitCode -ne 0) {
        $rows.Add([pscustomobject]@{
            test_id = $test.id
            expected_result = $test.expectedResult
            actual_result = $false
            matches_expected = $false
            phase = 'reset'
            sqlstate = ''
            constraint_name = ''
            message = ($resetOutput -join ' ')
        })
        continue
    }

    $stateFailed = $false
    $stateMessage = ''
    foreach ($statement in $test.stateSql) {
        $previousPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $stateOutput = "\set VERBOSITY verbose`n$statement" |
                & $Psql -X -w -h $HostName -p $Port -U $User -d $Database -v ON_ERROR_STOP=1 2>&1
            $stateExitCode = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $previousPreference
        }
        if ($stateExitCode -ne 0) {
            $stateFailed = $true
            $stateMessage = $stateOutput -join ' '
            break
        }
    }
    if ($stateFailed) {
        $rows.Add([pscustomobject]@{
            test_id = $test.id
            expected_result = $test.expectedResult
            actual_result = $false
            matches_expected = $false
            phase = 'state'
            sqlstate = if ($stateMessage -match 'ERROR:\s+([0-9A-Z]{5}):') { $matches[1] } else { '' }
            constraint_name = Get-ConstraintName $stateMessage
            message = $stateMessage
        })
        continue
    }

    $actual = $true
    $message = ''
    $sqlstate = ''
    foreach ($statement in $test.dataSql) {
        $previousPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $dataOutput = "\set VERBOSITY verbose`n$statement" |
                & $Psql -X -w -h $HostName -p $Port -U $User -d $Database -v ON_ERROR_STOP=1 2>&1
            $dataExitCode = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $previousPreference
        }
        if ($dataExitCode -ne 0) {
            $actual = $false
            $message = $dataOutput -join ' '
            if ($message -match 'ERROR:\s+([0-9A-Z]{5}):') { $sqlstate = $matches[1] }
            break
        }
    }

    $rows.Add([pscustomobject]@{
        test_id = $test.id
        expected_result = [bool]$test.expectedResult
        actual_result = $actual
        matches_expected = ($actual -eq [bool]$test.expectedResult)
        phase = 'data'
        sqlstate = $sqlstate
        constraint_name = Get-ConstraintName $message
        message = $message
    })
}

$rows | Export-Csv -LiteralPath $resultPath -NoTypeInformation -Encoding UTF8
$rows | Format-Table
Write-Output "Results: $resultPath"

if ($rows.Where({ -not $_.matches_expected }).Count -gt 0) {
    throw 'One or more PostgreSQL results differ from the expected results.'
}
