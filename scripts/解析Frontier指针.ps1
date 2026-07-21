param(
    [Parameter(Mandatory)]
    [string]$MapPath
)

$Selector = Join-Path $PSScriptRoot '..\skills\wayfinder-workflow\scripts\解析Frontier指针.ps1'
& $Selector -MapPath $MapPath
exit $LASTEXITCODE
