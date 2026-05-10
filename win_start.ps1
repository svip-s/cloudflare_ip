$env:GITHUB_TOKEN = "ghp_这里填写你的TOKEN"
$ErrorActionPreference = "Stop"

trap {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ScriptStackTrace) {
        Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    }
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$env:GITHUB_REPO = if ($env:GITHUB_REPO) { $env:GITHUB_REPO } else { "这里改成https://github.com/你的仓库/cfip.git链接" }

Set-Location $Root

function Assert-ResultFiles {
    $requiredFiles = @("best_ips.txt", "full_ips.txt", "README.MD")
    foreach ($file in $requiredFiles) {
        $path = Join-Path $Root $file
        if (-not (Test-Path -LiteralPath $path)) {
            throw "Missing result file: $file. Choose 2 to regenerate results first."
        }
    }
}

function Invoke-CheckedCommand {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Command,
        [Parameter(Mandatory = $true)]
        [string]$FailureMessage
    )

    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw $FailureMessage
    }
}

function Invoke-PushResults {
    Assert-ResultFiles
    Invoke-CheckedCommand `
        -Command { & (Join-Path $Root "push_results.ps1") } `
        -FailureMessage "Push failed. Check the error above."
}

function Invoke-UpdateResults {
    Invoke-CheckedCommand `
        -Command { python (Join-Path $Root "update.py") --no-github-sync } `
        -FailureMessage "Update failed. Push stopped."
    Invoke-CheckedCommand `
        -Command { python (Join-Path $Root "update_md.py") } `
        -FailureMessage "README update failed. Push stopped."
}

Write-Host ""
Write-Host "Choose an action:"
Write-Host "1. Push existing result files"
Write-Host "2. Regenerate results, then push (Default in 5s)"
Write-Host ""

Write-Host -NoNewline "Enter 1 or 2 [Default: 2]: "
$choice = $null
$deadline = (Get-Date).AddSeconds(5)
$canReadKey = $true

try {
    $null = [Console]::KeyAvailable
} catch {
    $canReadKey = $false
}

while ($canReadKey -and (Get-Date) -lt $deadline) {
    if ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
        $choice = $key.KeyChar.ToString()
        Write-Host $choice
        break
    }
    Start-Sleep -Milliseconds 100
}

if ($null -eq $choice) {
    Write-Host ""
    Write-Host ""
    Write-Host "Time out! Automatically selecting choice 2..."
    $choice = "2"
}

if (-not $choice -or -not $choice.Trim()) {
    $choice = "2"
}

switch ($choice.Trim()) {
    "1" {
        Invoke-PushResults
    }
    "2" {
        Invoke-UpdateResults
        Invoke-PushResults
    }
    default {
        throw "Invalid choice: $choice"
    }
}
