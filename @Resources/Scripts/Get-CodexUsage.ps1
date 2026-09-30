param(
    [string]$OutputPath = (Join-Path $PSScriptRoot "..\codex-usage.json"),
    [int]$TimeoutSeconds = 20
)

$ErrorActionPreference = "Stop"

function Convert-UnixTimeToLocalLabel {
    param(
        [long]$UnixTime,
        [switch]$PreferToday
    )

    $localTime = [DateTimeOffset]::FromUnixTimeSeconds($UnixTime).ToLocalTime().DateTime
    $today = (Get-Date).Date

    if ($PreferToday -and $localTime.Date -eq $today) {
        return $localTime.ToString("HH:mm")
    }

    return $localTime.ToString("MM/dd HH:mm")
}

function New-UsagePayloadFromResult {
    param([object]$Result)

    $limit = $Result.rateLimitsByLimitId.codex
    if ($null -eq $limit) {
        $limit = $Result.rateLimits
    }

    if ($null -eq $limit) {
        throw "Codex usage data was not found."
    }

    $primaryUsed = [int]$limit.primary.usedPercent
    $secondaryUsed = [int]$limit.secondary.usedPercent
    $resetCredits = 0

    if ($Result.rateLimitResetCredits -and $null -ne $Result.rateLimitResetCredits.availableCount) {
        $resetCredits = [int]$Result.rateLimitResetCredits.availableCount
    }

    [ordered]@{
        ok = $true
        plan = ([string]$limit.planType).ToUpperInvariant()
        fiveHour = [ordered]@{
            label = "5 hr"
            used = $primaryUsed
            remaining = [Math]::Max(0, 100 - $primaryUsed)
            resetUnix = [long]$limit.primary.resetsAt
            resetLabel = Convert-UnixTimeToLocalLabel -UnixTime ([long]$limit.primary.resetsAt) -PreferToday
        }
        weekly = [ordered]@{
            label = "Weekly"
            used = $secondaryUsed
            remaining = [Math]::Max(0, 100 - $secondaryUsed)
            resetUnix = [long]$limit.secondary.resetsAt
            resetLabel = Convert-UnixTimeToLocalLabel -UnixTime ([long]$limit.secondary.resetsAt)
        }
        resetCredits = $resetCredits
        updated = (Get-Date).ToString("HH:mm")
        updatedFull = (Get-Date).ToString("yyyy/MM/dd HH:mm:ss")
        source = "codex app-server"
    }
}

function Read-JsonRpcResponse {
    param(
        [System.Diagnostics.Process]$Process,
        [int]$ExpectedId,
        [datetime]$Deadline
    )

    while ((Get-Date) -lt $Deadline) {
        if ($Process.HasExited) {
            throw "codex app-server exited before usage data was returned."
        }

        $line = $Process.StandardOutput.ReadLine()
        if ([string]::IsNullOrWhiteSpace($line)) {
            Start-Sleep -Milliseconds 100
            continue
        }

        try {
            $message = $line | ConvertFrom-Json
        }
        catch {
            continue
        }

        if ($message.id -eq $ExpectedId) {
            if ($message.error) {
                throw ($message.error | ConvertTo-Json -Depth 8)
            }

            return $message
        }
    }

    throw "Timed out while waiting for Codex response."
}

function Resolve-CodexExecutable {
    try {
        $command = Get-Command codex -ErrorAction Stop
        if ($command.Source -and (Test-Path -LiteralPath $command.Source)) {
            return $command.Source
        }
    }
    catch {
    }

    $candidateRoots = @()

    if ($env:LOCALAPPDATA) {
        $candidateRoots += (Join-Path $env:LOCALAPPDATA "OpenAI\Codex\bin")
    }

    if ($env:USERPROFILE) {
        $candidateRoots += (Join-Path $env:USERPROFILE "AppData\Local\OpenAI\Codex\bin")
    }

    $candidates = foreach ($root in ($candidateRoots | Select-Object -Unique)) {
        if (Test-Path -LiteralPath $root) {
            Get-ChildItem -LiteralPath $root -Recurse -Filter "codex.exe" -ErrorAction SilentlyContinue
        }
    }

    $best = $candidates |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($best -and (Test-Path -LiteralPath $best.FullName)) {
        return $best.FullName
    }

    throw "codex.exe was not found. Open Codex once, then run this script again."
}

$outputFullPath = [System.IO.Path]::GetFullPath($OutputPath)
$outputDirectory = Split-Path -Parent $outputFullPath
if (-not (Test-Path $outputDirectory)) {
    New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
}

$process = $null

try {
    $codexExe = Resolve-CodexExecutable

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $codexExe
    $startInfo.Arguments = "app-server"
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo

    if (-not $process.Start()) {
        throw "Unable to start codex app-server."
    }

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    $initialize = @{
        id = 1
        method = "initialize"
        params = @{
            clientInfo = @{
                name = "rainmeter-codex-widget"
                version = "1.0"
            }
            capabilities = @{}
        }
    } | ConvertTo-Json -Compress -Depth 8

    $initialized = @{
        method = "initialized"
    } | ConvertTo-Json -Compress -Depth 4

    $readUsage = @{
        id = 2
        method = "account/rateLimits/read"
    } | ConvertTo-Json -Compress -Depth 4

    $process.StandardInput.WriteLine($initialize)
    $process.StandardInput.Flush()
    Read-JsonRpcResponse -Process $process -ExpectedId 1 -Deadline $deadline | Out-Null

    $process.StandardInput.WriteLine($initialized)
    $process.StandardInput.Flush()

    $process.StandardInput.WriteLine($readUsage)
    $process.StandardInput.Flush()

    $usageMessage = Read-JsonRpcResponse -Process $process -ExpectedId 2 -Deadline $deadline
    $payload = New-UsagePayloadFromResult -Result $usageMessage.result
    $payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $outputFullPath -Encoding UTF8

    $payload | ConvertTo-Json -Compress -Depth 8
}
catch {
    $fallback = [ordered]@{
        ok = $false
        plan = "CODEX"
        fiveHour = [ordered]@{
            label = "5 hr"
            used = 0
            remaining = 0
            resetUnix = 0
            resetLabel = "--:--"
        }
        weekly = [ordered]@{
            label = "Weekly"
            used = 0
            remaining = 0
            resetUnix = 0
            resetLabel = "--/-- --:--"
        }
        resetCredits = 0
        updated = (Get-Date).ToString("HH:mm")
        updatedFull = (Get-Date).ToString("yyyy/MM/dd HH:mm:ss")
        source = "error"
        error = $_.Exception.Message
    }

    $fallback | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $outputFullPath -Encoding UTF8
    $fallback | ConvertTo-Json -Compress -Depth 8
    exit 1
}
finally {
    if ($null -ne $process -and -not $process.HasExited) {
        $process.Kill()
        $process.Dispose()
    }
}
