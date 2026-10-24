# 自动定位希沃白板 5（EasiNote5）的安装位置 / 启动器 / 最新版本 Startup 目录。
# 被 build.ps1、install-shortcut.ps1、package.ps1 共用（点源加载）。

function Get-SeewoInstallRoot {
    foreach ($key in @('HKLM:\SOFTWARE\WOW6432Node\Seewo\EasiNote5', 'HKLM:\SOFTWARE\Seewo\EasiNote5')) {
        $path = (Get-ItemProperty -Path $key -Name 'path' -ErrorAction SilentlyContinue).path
        if ($path -and (Test-Path -LiteralPath $path)) { return $path }
    }

    $bases = @()
    $programFilesX86 = [Environment]::GetFolderPath('ProgramFilesX86')
    $programFiles    = [Environment]::GetFolderPath('ProgramFiles')
    if ($programFilesX86) { $bases += $programFilesX86 }
    if ($programFiles)    { $bases += $programFiles }
    $bases += 'C:\Program Files (x86)', 'C:\Program Files'

    foreach ($base in $bases) {
        $candidate = Join-Path $base 'Seewo\EasiNote5'
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    return 'C:\Program Files (x86)\Seewo\EasiNote5'
}

function Get-SeewoLauncher {
    foreach ($key in @('HKLM:\SOFTWARE\WOW6432Node\Seewo\EasiNote5', 'HKLM:\SOFTWARE\Seewo\EasiNote5')) {
        $exe = (Get-ItemProperty -Path $key -Name 'ExePath' -ErrorAction SilentlyContinue).ExePath
        if ($exe -and (Test-Path -LiteralPath $exe)) { return $exe }
    }

    $candidate = Join-Path (Get-SeewoInstallRoot) 'swenlauncher\swenlauncher.exe'
    if (Test-Path -LiteralPath $candidate) { return $candidate }
    return $null
}

# 挑出本机"最新版本"（EasiNote5_x.y.z.w）的 Main\Resources\Startup 目录。
function Get-SeewoNewestStartup {
    $installRoot = Get-SeewoInstallRoot
    $best = $null
    $bestVersion = $null
    $bestTime = [datetime]::MinValue

    foreach ($directory in (Get-ChildItem -LiteralPath $installRoot -Directory -ErrorAction SilentlyContinue)) {
        $startup = Join-Path $directory.FullName 'Main\Resources\Startup'
        if (-not (Test-Path -LiteralPath $startup)) { continue }

        $text = $directory.Name -replace '^EasiNote5_', ''
        $match = [regex]::Match($text, '^\d+(\.\d+)*')
        $version = $null
        if ($match.Success) { try { $version = [version]$match.Value } catch { } }

        $better = $false
        if ($version -and (-not $bestVersion)) { $better = $true }
        elseif ($version -and $bestVersion -and $version -gt $bestVersion) { $better = $true }
        elseif ($version -and $bestVersion -and $version -eq $bestVersion -and $directory.LastWriteTimeUtc -gt $bestTime) { $better = $true }
        elseif ((-not $version) -and (-not $bestVersion) -and $directory.LastWriteTimeUtc -gt $bestTime) { $better = $true }

        if ($better) {
            $best = $startup
            $bestVersion = $version
            $bestTime = $directory.LastWriteTimeUtc
        }
    }
    return $best
}
