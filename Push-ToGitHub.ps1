param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryUrl
)

$ErrorActionPreference = "Stop"

Push-Location $PSScriptRoot
try {
    if (-not (Test-Path -LiteralPath ".git")) {
        throw "This folder is not a Git repository."
    }

    $existingRemote = git remote
    if ($existingRemote -contains "origin") {
        git remote set-url origin $RepositoryUrl
    }
    else {
        git remote add origin $RepositoryUrl
    }

    git push -u origin main
    git push origin v1.0

    Write-Host "Pushed main and v1.0 to:"
    Write-Host "  $RepositoryUrl"
}
finally {
    Pop-Location
}
