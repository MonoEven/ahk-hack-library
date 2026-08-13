param(
    [string]$Repo = "D:\Tech\Projects\Autohotkey\Lib\visual_studio\tasks\2026-08-11-ahkhack-foundation",
    [string]$OutFile = "$PSScriptRoot\..\reports\runtime_matrix_all.txt"
)

$ErrorActionPreference = "Continue"

function Wait-TestProcess {
    param($Process, [int]$TimeoutSeconds = 90)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while (-not $Process.HasExited -and (Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 250
    }
    if (-not $Process.HasExited) {
        Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
        return $false
    }
    return $true
}

function Read-Output {
    param([string]$Test, [string]$Version)
    $map = @{
        "tests\ahk_live_test.ahk"          = (Join-Path $env:TEMP "ahk_live_test.out")
        "tests\ahk_live_cross_smoke.ahk"   = (Join-Path $env:TEMP "ahk_live_cross_smoke.out")
        "tests\ahk_live_product_test.ahk"  = (Join-Path $env:TEMP "ahk_live_product_test.out")
        "tests\ahk_live_six_test.ahk"      = (Join-Path $env:TEMP "ahk_live_six_test.out")
        "tests\ahk_live_benchmark.ahk"     = (Join-Path $env:TEMP "ahk_live_benchmark.out")
        "tests\remote_hook_test.ahk"       = (Join-Path $Repo "tests\remote_hook_test.out")
    }
    $path = $map[$Test]
    if ($path) {
        if (Test-Path -LiteralPath $path) {
            return Get-Content -LiteralPath $path -Raw -ErrorAction SilentlyContinue
        }
        return ""
    }
    if ($Test -match "evalscript_inproc") {
        $file = Join-Path $Repo "tests\evalscript_inproc_$Version.out"
        if (Test-Path -LiteralPath $file) { return Get-Content -LiteralPath $file -Raw }
        return ""
    }
    if ($Test -match "evalscript_repeat") {
        $file = Join-Path $Repo "tests\evalscript_repeat_$Version.out"
        if (Test-Path -LiteralPath $file) { return Get-Content -LiteralPath $file -Raw }
        return ""
    }
    if ($Test -match "evalscript_class") {
        $file = Join-Path $Repo "tests\evalscript_class_$Version.out"
        if (Test-Path -LiteralPath $file) { return Get-Content -LiteralPath $file -Raw }
        return ""
    }
    return ""
}

function Test-Satisfies {
    param([string]$Test, [string]$Text)
    if ($Test -match "evalscript_inproc") { return $Text -match "r1=3" }
    if ($Test -match "evalscript_repeat") { return $Text -match "OK" }
    if ($Test -match "evalscript_class") { return $Text -match "r=3" }
    return $Text -match "PASS" -and $Text -notmatch "FAIL"
}

$candidates = Get-ChildItem -Path "D:\Tech\Projects\Autohotkey" -Recurse -Filter "AutoHotkey64.exe" -File -ErrorAction SilentlyContinue |
    Where-Object {
        $_.FullName -match '\\v2\.0-|\\v2\.0\.|\\v2\.1-|\\\.worktrees\\ahk-runtime\\|\\MyAutohotkey\\AutoHotkey64\.exe$|\\Projects\\MyAutoHotkey\\AutoHotkey-alpha\\bin\\|^D:\\Tech\\Projects\\Autohotkey\\AutoHotkey64\.exe$|\\build\\ahk2exe-|\\Lib\\.codex\\autohotkey-2\.0\.26\\runtime\\'
    } | Select-Object -ExpandProperty FullName -Unique

$runtimes = @()
$seen = @{}
foreach ($exe in $candidates) {
    $probeOut = Join-Path $env:TEMP "ahk_version_probe.out"
    Remove-Item -LiteralPath $probeOut -ErrorAction SilentlyContinue
    $p = Start-Process -FilePath $exe -ArgumentList @("tests\_version_probe.ahk") -WorkingDirectory $Repo -WindowStyle Hidden -Wait -PassThru
    $version = if (Test-Path -LiteralPath $probeOut) { (Get-Content -LiteralPath $probeOut -Raw).Trim() } else { "unknown" }
    $label = $version
    if ($version -eq "2.0-beta") {
        $label = "2.0-beta-" + ([IO.Path]::GetFileName([IO.Path]::GetDirectoryName($exe)))
    }
    if (-not $seen.ContainsKey($label)) {
        $seen[$label] = $true
        $runtimes += [pscustomobject]@{ Label = $label; Path = $exe; Version = $version }
    }
}

$tests = @(
    "tests\ahk_live_cross_smoke.ahk",
    "tests\ahk_live_test.ahk",
    "tests\ahk_live_product_test.ahk",
    "tests\ahk_live_six_test.ahk",
    "tests\ahk_live_benchmark.ahk",
    "tests\remote_hook_test.ahk",
    "tests\evalscript_inproc.ahk",
    "tests\evalscript_repeat.ahk",
    "tests\evalscript_class.ahk"
)

$reportDir = Split-Path -Parent $OutFile
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
$lines = @()
$lines += "AHK runtime verification matrix"
$lines += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$lines += "Runtimes: $($runtimes.Count)"
$lines += ""
$summary = @{}

foreach ($rt in $runtimes) {
    $lines += "===== $($rt.Label) ($($rt.Path)) ====="
    foreach ($test in $tests) {
        $pidFile = Join-Path $env:TEMP "ahk_live_probe_target.pid"
        Remove-Item -LiteralPath $pidFile -ErrorAction SilentlyContinue
        $target = $null
        $needsTarget = $test -notmatch "evalscript_"
        if ($needsTarget) {
            $target = Start-Process -FilePath $rt.Path -ArgumentList @("tests\ahk_live_probe_target.ahk") -WorkingDirectory $Repo -WindowStyle Hidden -PassThru
            $deadline = (Get-Date).AddSeconds(15)
            while (-not (Test-Path -LiteralPath $pidFile) -and (Get-Date) -lt $deadline) {
                Start-Sleep -Milliseconds 200
            }
            if (-not (Test-Path -LiteralPath $pidFile)) {
                Stop-Process -Id $target.Id -Force -ErrorAction SilentlyContinue
                $lines += "[$($rt.Label)] $test = TARGET_START_FAIL"
                continue
            }
        }
        $targetPid = if ($needsTarget) { [int]((Get-Content -LiteralPath $pidFile | Select-Object -First 1).Trim()) } else { 0 }
        $args = @($test)
        if ($needsTarget) { $args += $targetPid }
        $proc = Start-Process -FilePath $rt.Path -ArgumentList $args -WorkingDirectory $Repo -WindowStyle Hidden -PassThru
        $finished = Wait-TestProcess -Process $proc -TimeoutSeconds 90
        $text = Read-Output -Test $test -Version $rt.Version
        $pass = $finished -and $proc.ExitCode -eq 0 -and (Test-Satisfies -Test $test -Text $text)
        $state = if ($pass) { "PASS" } elseif (-not $finished) { "TIMEOUT" } else { "FAIL" }
        $key = $rt.Label
        if (-not $summary.ContainsKey($key)) { $summary[$key] = @{} }
        $summary[$key][$test] = $state
        $detail = if ($pass) { "" } else { " exit=$($proc.ExitCode)" }
        $lines += "[$($rt.Label)] $test = $state$detail"
        if (-not $pass -and $text) {
            $tail = ($text -split "`r?`n" | Where-Object { $_ -ne "" } | Select-Object -Last 3) -join " | "
            $lines += "    $tail"
        }
        if ($target) {
            Stop-Process -Id $targetPid -Force -ErrorAction SilentlyContinue
            Stop-Process -Id $target.Id -Force -ErrorAction SilentlyContinue
        }
    }
    $lines += ""
}

$lines += "===== Summary ====="
$lines += ("{0,-22} {1}" -f "Runtime", "Pass/Total")
foreach ($key in ($summary.Keys | Sort-Object)) {
    $passCount = ($summary[$key].Values | Where-Object { $_ -eq "PASS" }).Count
    $lines += ("{0,-22} {1}/{2}" -f $key, $passCount, $tests.Count)
}
$lines | Set-Content -LiteralPath $OutFile -Encoding UTF8
$lines | ForEach-Object { Write-Output $_ }
