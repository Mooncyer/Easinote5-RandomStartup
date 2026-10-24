param([string]$Sentinel)

# 安装 / 重建 "希沃白板 5" 快捷方式
#   目标：<项目根>\dist\SeewoRandomStartup.exe
#   名称、图标与希沃白板原版快捷方式一致（图标自动探测本机最新版 swenlauncher.exe,0），
#   因为指向真正的 exe，所以可以正常"固定到任务栏"。
#   写 C:\Users\Public\Desktop 需要管理员权限，脚本会自己提权。

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
. (Join-Path $PSScriptRoot 'seewo-locate.ps1')

$logFile = Join-Path (Get-ProjectRoot) 'install.log'

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
    # 自己提权。部分宿主（脚本宿主 / CI）对提权子进程的 -Wait 不可靠，
    # 所以让提权进程结束后写一个哨兵文件，父进程等它出现再退出。
    $sentinelPath = Join-Path $env:TEMP ('seewo-randomstartup-install-' + [Guid]::NewGuid().ToString('N') + '.done')
    Write-Host '正在请求管理员权限...'
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -Wait -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-Sentinel', $sentinelPath) | Out-Null
    for ($i = 0; $i -lt 240 -and -not (Test-Path -LiteralPath $sentinelPath); $i++) { Start-Sleep -Milliseconds 500 }
    Remove-Item -LiteralPath $sentinelPath -Force -ErrorAction SilentlyContinue
    exit
}

try {
    $exePath      = Get-BuiltExe
    $launcherExe  = Get-SeewoLauncher
    $shortcutName = '希沃白板 5'
    $nameWithExt  = $shortcutName + '.lnk'
    $desktopLnk   = Join-Path 'C:\Users\Public\Desktop' $nameWithExt
    $startMenuLnk = Join-Path (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs') $nameWithExt
    $pinnedLnk    = Join-Path (Join-Path $env:APPDATA 'Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar') $nameWithExt

    if (-not (Test-Path -LiteralPath $exePath)) { throw "找不到主程序，请先运行 scripts\build.ps1：$exePath" }

    Write-Log '==== 安装 / 重建快捷方式 ===='
    Write-Log ('主程序      : ' + $exePath)
    Write-Log ('希沃安装目录: ' + (Get-SeewoInstallRoot))
    Write-Log ('最新版启动图: ' + (Get-SeewoNewestStartup))
    Write-Log ('图标 / 启动器: ' + $launcherExe)

    $iconSource = $exePath
    if ($launcherExe) { $iconSource = $launcherExe }

    $shell = New-Object -ComObject WScript.Shell

    function Save-Shortcut {
        param([string]$Path)
        $directory = Split-Path -Parent $Path
        if (-not (Test-Path -LiteralPath $directory)) { New-Item -ItemType Directory -Force -Path $directory | Out-Null }

        $shortcut = $shell.CreateShortcut($Path)
        $shortcut.TargetPath       = $exePath
        $shortcut.Arguments        = ''
        $shortcut.WorkingDirectory = (Split-Path -Parent $exePath)
        $shortcut.Description      = $shortcutName
        $shortcut.WindowStyle      = 1
        $shortcut.IconLocation     = $iconSource + ',0'
        $shortcut.Save()
    }

    function Backup-Shortcut {
        param([string]$Path)
        if (Test-Path -LiteralPath $Path) {
            $backup = $Path + '.original'
            if (-not (Test-Path -LiteralPath $backup)) {
                Copy-Item -LiteralPath $Path -Destination $backup -Force
                Write-Log "已备份原快捷方式: $backup"
            }
        }
    }

    Backup-Shortcut $desktopLnk
    Backup-Shortcut $pinnedLnk

    $targets = @($desktopLnk, $startMenuLnk, $pinnedLnk, (Get-BundledShortcut))
    foreach ($target in $targets) {
        try {
            Save-Shortcut -Path $target
            Write-Log "已写入快捷方式: $target"
        }
        catch {
            Write-Log "写入失败 $target : $($_.Exception.Message)"
        }
    }

    Write-Log '完成：桌面 / 开始菜单 / 任务栏上的"希沃白板 5"现在都会先随机换一张启动图，再启动希沃白板。'
}
finally {
    Complete-Sentinel
}
