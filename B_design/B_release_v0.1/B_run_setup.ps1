param(
    [string]$ContainerName = 'student-postgres',
    [string]$DatabaseRole = 'student'
)
# Run from this release folder or pass the full path to this script.
# Uses the member's existing course container authentication, never a password file.
$ErrorActionPreference = 'Stop'
function Invoke-ReleaseSql([string]$DatabaseName, [string]$FileName) {
    $sqlText = Get-Content -LiteralPath (Join-Path $PSScriptRoot $FileName) -Raw
    $sqlText | & docker exec -i $ContainerName psql -X -U $DatabaseRole -d $DatabaseName -v ON_ERROR_STOP=1 -P pager=off
    if ($LASTEXITCODE -ne 0) { throw "Stopped: $FileName on $DatabaseName (see database error above)." }
}
Invoke-ReleaseSql 'postgres' 'B_create_database.psql'
Invoke-ReleaseSql 'glucolink_a2' 'B_setup.sql'
Invoke-ReleaseSql 'glucolink_a2' '00_environment_check.sql'
Invoke-ReleaseSql 'glucolink_a2' 'B_verify_setup.sql'
Write-Output 'B setup steps completed. Check every validation row, then record the result.'
