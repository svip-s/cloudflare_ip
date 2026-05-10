param(
    [string]$Repo = $env:GITHUB_REPO,
    [string]$Branch = $(if ($env:GITHUB_BRANCH) { $env:GITHUB_BRANCH } else { "main" }),
    [string]$Token = $env:GITHUB_TOKEN,
    [string]$WorkDir = $(if ($env:GITHUB_WORKDIR) { $env:GITHUB_WORKDIR } else { ".github-sync" }),
    [string]$Message = $(if ($env:GITHUB_MESSAGE) { $env:GITHUB_MESSAGE } else { "Update IP results and README" }),
    [string[]]$Files = @("best_ips.txt", "full_ips.txt", "README.MD"),
    [int]$PushRetries = $(if ($env:GITHUB_PUSH_RETRIES) { [int]$env:GITHUB_PUSH_RETRIES } else { 3 }),
    [int]$PushRetryDelay = $(if ($env:GITHUB_PUSH_RETRY_DELAY) { [int]$env:GITHUB_PUSH_RETRY_DELAY } else { 10 })
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

function Assert-CommandExists {
    param([Parameter(Mandatory = $true)][string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "$Name command not found."
    }
}

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
        [int[]]$AllowedExitCodes = @(0)
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & $FilePath @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($output) {
        $output | ForEach-Object { Write-Host $_ }
    }
    if ($AllowedExitCodes -notcontains $exitCode) {
        throw "$FilePath command failed with exit code ${exitCode}: $($Arguments -join ' ')"
    }
    return $exitCode
}

function Get-GitBaseArgs {
    param([string]$WorkingDirectory)

    $args = @("-c", "http.sslBackend=openssl")
    if ($WorkingDirectory) {
        $safeDirectory = [System.IO.Path]::GetFullPath($WorkingDirectory)
        $args += @("-c", "safe.directory=$safeDirectory")
    }
    if ($Token) {
        $basic = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("x-access-token:$Token"))
        $args += @("-c", "http.https://github.com/.extraheader=AUTHORIZATION: basic $basic")
    }
    return $args
}

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
        [string]$WorkingDirectory,
        [int[]]$AllowedExitCodes = @(0)
    )

    $gitArgs = Get-GitBaseArgs -WorkingDirectory $WorkingDirectory
    if ($WorkingDirectory) {
        $gitArgs += @("-C", $WorkingDirectory)
    }
    $gitArgs += $Arguments
    return Invoke-NativeCommand -FilePath "git" -Arguments $gitArgs -AllowedExitCodes $AllowedExitCodes
}

function Get-AheadCount {
    $gitArgs = @("rev-list", "--count", "origin/$Branch..HEAD")
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & git @(Get-GitBaseArgs -WorkingDirectory $WorkDir) -C $WorkDir @gitArgs 2>&1
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($exitCode -ne 0) {
        return 0
    }

    $count = 0
    if ([int]::TryParse(($output | Select-Object -First 1), [ref]$count)) {
        return $count
    }
    return 0
}

function Initialize-WorkTree {
    if (Test-Path -LiteralPath (Join-Path $WorkDir ".git")) {
        Invoke-Git -WorkingDirectory $WorkDir -Arguments @("fetch", "origin", $Branch)
        Write-Host "Resetting local sync branch to origin/$Branch..."
        Invoke-Git -WorkingDirectory $WorkDir -Arguments @("reset", "--hard")
        Invoke-Git -WorkingDirectory $WorkDir -Arguments @("checkout", "-B", $Branch, "origin/$Branch")
        return
    }

    if ((Test-Path -LiteralPath $WorkDir) -and (Get-ChildItem -LiteralPath $WorkDir -Force | Select-Object -First 1)) {
        throw "sync directory is not an empty git repository: $WorkDir"
    }
    Invoke-Git -Arguments @("clone", "--branch", $Branch, "--single-branch", $Repo, $WorkDir)
}

function Copy-ResultsToWorkTree {
    foreach ($file in $Files) {
        if (-not (Test-Path -LiteralPath $file)) {
            throw "result file not found: $file"
        }
        Copy-Item -LiteralPath $file -Destination (Join-Path $WorkDir $file) -Force
        Invoke-Git -WorkingDirectory $WorkDir -Arguments @("add", $file)
    }
}

function Test-HasStagedChanges {
    $exitCode = Invoke-Git `
        -WorkingDirectory $WorkDir `
        -Arguments @("diff", "--cached", "--quiet") `
        -AllowedExitCodes @(0, 1)
    return $exitCode -eq 1
}

function Save-Changes {
    if (-not (Test-HasStagedChanges)) {
        return
    }

    Invoke-Git -WorkingDirectory $WorkDir -Arguments @(
        "-c", "user.name=IP Update Bot",
        "-c", "user.email=ip-update-bot@users.noreply.github.com",
        "commit", "-m", $Message
    )
}

function Push-Changes {
    $ahead = Get-AheadCount
    if ($ahead -le 0) {
        Write-Host "Nothing to push: $($Files -join ', ') are already up to date."
        return
    }

    Write-Host "Pushing $ahead commit(s) to $Repo ($Branch)..."
    $attempt = 1
    while ($true) {
        try {
            Invoke-Git -WorkingDirectory $WorkDir -Arguments @("push", "origin", $Branch)
            break
        } catch {
            if ($attempt -ge $PushRetries) {
                Write-Error "Push failed after $attempt attempt(s)."
                throw
            }

            Write-Warning "Push failed; retrying push only in ${PushRetryDelay}s ($($attempt + 1)/$PushRetries)..."
            Start-Sleep -Seconds $PushRetryDelay
            $attempt++
        }
    }
    Write-Host "Push done: $($Files -join ', ')"
}

if (-not $Repo) {
    throw "GITHUB_REPO is not set. Set `$env:GITHUB_REPO or pass -Repo."
}
if (-not $Token) {
    Write-Warning "GITHUB_TOKEN is not set. Push may fail if git has no saved credentials."
} else {
    Write-Host "GitHub token loaded from environment."
}

Assert-CommandExists -Name "git"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root
$WorkDir = [System.IO.Path]::GetFullPath((Join-Path $root $WorkDir))

Initialize-WorkTree
Copy-ResultsToWorkTree
Save-Changes
Push-Changes
