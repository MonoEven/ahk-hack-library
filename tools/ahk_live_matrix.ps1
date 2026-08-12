param(
    [string]$Repo = "D:\Tech\Projects\Autohotkey\Lib\visual_studio\tasks\2026-08-11-ahkhack-foundation"
)

$ErrorActionPreference = "Stop"
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
        Start-Sleep -Milliseconds 1000
        if (-not (Test-Path $pidFile)) {
            throw "target did not start for $runtime"
        }
        $pid = (Get-Content -LiteralPath $pidFile | Select-Object -First 1).Trim()
        $proc = Start-Process -FilePath $runtime -ArgumentList @($test, $pid) -WorkingDirectory $Repo -WindowStyle Hidden -Wait -PassThru
        $name = Split-Path $test -Leaf
        Write-Output ("[{0}] {1} exit={2}" -f (Split-Path $runtime -Leaf), $name, $proc.ExitCode)
        Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
    }
}
