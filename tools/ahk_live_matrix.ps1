param(
    [string]$Repo = "D:\Tech\Projects\Autohotkey\Lib\visual_studio\tasks\2026-08-11-ahkhack-foundation"
)

$ErrorActionPreference = "Stop"
Get-CimInstance Win32_Process -Filter "Name='AutoHotkey64.exe'" | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
$candidates = @()
$candidates += Get-ChildItem -Path "D:\Tech\Projects\Autohotkey" -Recurse -Filter "AutoHotkey64.exe" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match '\\v2\.|\\\.worktrees\\ahk-runtime|\\build\\ahk2exe-' }
$candidates += Get-ChildItem -Path "$Repo\build" -Recurse -Filter "AutoHotkey64.exe" -ErrorAction SilentlyContinue
$runtimes = $candidates | Select-Object -ExpandProperty FullName -Unique
$tests = @(
    "tests\ahk_live_test.ahk",
    "tests\ahk_live_cross_smoke.ahk",
    "tests\ahk_live_product_test.ahk",
    "tests\ahk_live_six_test.ahk",
    "tests\ahk_live_benchmark.ahk"
)
$outputs = @{
    "tests\ahk_live_test.ahk" = "ahk_live_test.out"
    "tests\ahk_live_cross_smoke.ahk" = "ahk_live_cross_smoke.out"
    "tests\ahk_live_product_test.ahk" = "ahk_live_product_test.out"
    "tests\ahk_live_six_test.ahk" = "ahk_live_six_test.out"
    "tests\ahk_live_benchmark.ahk" = "ahk_live_benchmark.out"
}

foreach ($runtime in $runtimes) {
    foreach ($test in $tests) {
        $pidFile = Join-Path $env:TEMP "ahk_live_probe_target.pid"
        Remove-Item -LiteralPath $pidFile -ErrorAction SilentlyContinue
        $target = Start-Process -FilePath $runtime -ArgumentList @("tests\ahk_live_probe_target.ahk") -WorkingDirectory $Repo -WindowStyle Hidden -PassThru
        $started = $false
        for ($i = 0; $i -lt 10; $i++) {
            Start-Sleep -Milliseconds 250
            if (Test-Path $pidFile) { $started = $true; break }
        }
        if (-not $started) {
            throw "target did not start for $runtime"
        }
        $targetPid = (Get-Content -LiteralPath $pidFile | Select-Object -First 1).Trim()
        $outName = $outputs[$test]
        $outPath = Join-Path $env:TEMP $outName
        Remove-Item -LiteralPath $outPath -ErrorAction SilentlyContinue
        $proc = Start-Process -FilePath $runtime -ArgumentList @($test, $targetPid) -WorkingDirectory $Repo -WindowStyle Hidden -Wait -PassThru
        $text = if (Test-Path $outPath) { Get-Content -LiteralPath $outPath -Raw -ErrorAction SilentlyContinue } else { "" }
        $name = Split-Path $test -Leaf
        $pass = $proc.ExitCode -eq 0 -and $text -match "PASS" -and $text -notmatch "FAIL"
        Write-Output ("[{0}] {1} exit={2} pass={3}" -f (Split-Path $runtime -Leaf), $name, $proc.ExitCode, $pass)
        if (-not $pass) {
            Write-Output $text
            Stop-Process -Id $targetPid -Force -ErrorAction SilentlyContinue
            throw "validation failed: $runtime $test"
        }
        Stop-Process -Id $targetPid -Force -ErrorAction SilentlyContinue
    }
}
