param(
    [string]$Repo = "D:\Tech\Projects\Autohotkey\Lib\visual_studio\tasks\2026-08-11-ahkhack-foundation"
)

$ErrorActionPreference = "Stop"
Get-CimInstance Win32_Process -Filter "Name='AutoHotkey64.exe'" | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
$runtimes = @(
    "D:\Tech\Projects\Autohotkey\Lib\.worktrees\ahk-runtime\AutoHotkey64.exe",
    "$Repo\build\ahk2exe-2.0.26\AutoHotkey64.exe"
)
$tests = @("tests\ahk_live_test.ahk", "tests\ahk_live_cross_smoke.ahk", "tests\ahk_live_product_test.ahk")

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
        $proc = Start-Process -FilePath $runtime -ArgumentList @($test, $targetPid) -WorkingDirectory $Repo -WindowStyle Hidden -Wait -PassThru
        $name = Split-Path $test -Leaf
        Write-Output ("[{0}] {1} exit={2}" -f (Split-Path $runtime -Leaf), $name, $proc.ExitCode)
        Stop-Process -Id $targetPid -Force -ErrorAction SilentlyContinue
    }
}
