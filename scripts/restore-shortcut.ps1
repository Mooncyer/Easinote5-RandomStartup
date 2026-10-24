param([string]$Sentinel)

# 还原被替换的 "希沃白板 5" 快捷方式（使用 .original 备份）
$ErrorActionPreference = 'Stop'
$logFile = Join-Path (Split-Path -Parent $PSScriptRoot) 'restore.log'

function Write-Log {
    param([string]$Message)
    $line = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') + '  ' + $Message
    Write-Host $line
    try { Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8 } catch { }
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    return (New-Object Security.Principal.WindowsPrincipal($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Complete-Sentinel {
    if ($Sentinel) {
        try { Set-Content -LiteralPath $Sentinel -Value 'done' -Encoding ASCII } catch { }
    }
}

if (-not (Test-IsAdmin)) {
    $sentinelPath = Join-Path $env:TEMP ('seewo-randomstartup-restore-' + [Guid]::NewGuid().ToString('N') + '.done')
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -Wait -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-Sentinel', $sentinelPath) | Out-Null
    for ($i = 0; $i -lt 240 -and -not (Test-Path -LiteralPath $sentinelPath); $i++) { Start-Sleep -Milliseconds 500 }
    Remove-Item -LiteralPath $sentinelPath -Force -ErrorAction SilentlyContinue
    exit
}

try {
    $nameWithExt  = '希沃白板 5.lnk'
    $desktopLnk   = Join-Path 'C:\Users\Public\Desktop' $nameWithExt
    $startMenuLnk = Join-Path (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs') $nameWithExt
    $pinnedLnk    = Join-Path (Join-Path $env:APPDATA 'Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar') $nameWithExt
    $bundledLnk   = Join-Path (Split-Path -Parent $PSScriptRoot) $nameWithExt

    foreach ($path in @($desktopLnk, $pinnedLnk)) {
        $backup = $path + '.original'
        if (Test-Path -LiteralPath $backup) {
            Copy-Item -LiteralPath $backup -Destination $path -Force
            Write-Log "已还原: $path"
        }
    }

    if (Test-Path -LiteralPath $startMenuLnk) {
        Remove-Item -LiteralPath $startMenuLnk -Force
        Write-Log "已删除开始菜单快捷方式: $startMenuLnk"
    }

    if (Test-Path -LiteralPath $bundledLnk) {
        Remove-Item -LiteralPath $bundledLnk -Force
        Write-Log "已删除随包快捷方式: $bundledLnk"
    }
}
finally {
    Complete-Sentinel
}
