param(
    [switch]$SkipCompiled
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$versions = @('v2.1-alpha.30', 'v2.0.26', 'v2.0.0', 'v2.0-beta.10')
$compiler = 'D:\Tech\Projects\Autohotkey\Compiler2\Ahk2Exe.exe'
$pass = 0
$fail = 0

function Invoke-RemoteCase {
    param($TargetExe, $AttacherExe, $Label)

    $pidFile = Join-Path $env:TEMP 'ahk_remote_attach_target.pid'
    $outFile = Join-Path $root 'tests\remote_hook_test.out'
    Remove-Item -LiteralPath $pidFile, $outFile -ErrorAction SilentlyContinue

    $target = Start-Process -FilePath $TargetExe -ArgumentList 'tests\remote_attach_target.ahk' -PassThru -WindowStyle Hidden
    try {
        $targetPid = ''
        for ($i = 0; $i -lt 60; $i++) {
            Start-Sleep -Milliseconds 250
            if (Test-Path $pidFile) {
                $targetPid = ((Get-Content $pidFile | Select-Object -First 1).Trim())
                break
            }
        }
        if (-not $targetPid) {
            Write-Output "$Label : no target pid"
            $script:fail++
            return
        }
        $caller = Start-Process -FilePath $AttacherExe -ArgumentList @('tests\remote_hook_test.ahk', $targetPid) -PassThru -Wait -WindowStyle Hidden
        $last = Get-Content $outFile -ErrorAction SilentlyContinue | Select-Object -Last 1
        if ($caller.ExitCode -eq 0 -and $last -eq 'PASS') {
            Write-Output "$Label : PASS"
            $script:pass++
        } else {
            Write-Output "$Label : FAIL ($last)"
            $script:fail++
        }
    } finally {
        Stop-Process -Id $target.Id -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $pidFile, $outFile -ErrorAction SilentlyContinue
    }
}

Write-Output '== interpreter x interpreter =='
foreach ($vt in $versions) {
    foreach ($va in $versions) {
        Invoke-RemoteCase `
            -TargetExe "D:\Tech\Projects\Autohotkey\$vt\AutoHotkey64.exe" `
            -AttacherExe "D:\Tech\Projects\Autohotkey\$va\AutoHotkey64.exe" `
            -Label "target=$vt attacher=$va"
    }
}

if (-not $SkipCompiled) {
    Write-Output '== compiled UPX target x interpreter =='
    $in = Join-Path $root 'tests\remote_attach_target.ahk'
    foreach ($v in $versions) {
        $out = Join-Path $root "build\remote_attach_target_${v}_upx.exe"
        & $compiler /in $in /out $out /base "D:\Tech\Projects\Autohotkey\$v\AutoHotkey64.exe" /compress 2 /silent verbose 2>&1 | Out-Null
        if (-not (Test-Path $out)) {
            Write-Output "compile $v : FAIL"
            $script:fail++
            continue
        }
        foreach ($va in $versions) {
            Invoke-RemoteCase `
                -TargetExe $out `
                -AttacherExe "D:\Tech\Projects\Autohotkey\$va\AutoHotkey64.exe" `
                -Label "compiled-base=$v attacher=$va"
        }
    }
}

Write-Output "PASS=$pass FAIL=$fail"
if ($fail -gt 0) {
    exit 1
}
