# 公共路径工具：被 build.ps1 / install-shortcut.ps1 / package.ps1 点源加载。
# 约定：项目根 = 本文件所在目录（scripts）的上一级；项目根下有 src\、resources\、scripts\、dist\。

function Get-ProjectRoot {
    return (Split-Path -Parent $PSScriptRoot)
}

function Get-BuiltExe {
    return (Join-Path (Get-ProjectRoot) 'dist\SeewoRandomStartup.exe')
}

function Get-BundledShortcut {
    return (Join-Path (Get-ProjectRoot) '希沃白板 5.lnk')
}

function Test-ImageLibrary {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    foreach ($sub in (Get-ChildItem -LiteralPath $Path -Directory -ErrorAction SilentlyContinue)) {
        $hit = Get-ChildItem -LiteralPath $sub.FullName -File -Recurse -ErrorAction SilentlyContinue |
               Where-Object { $_.Extension -match '^\.(png|jpg|jpeg|bmp|gif|webp)$' } |
               Select-Object -First 1
        if ($hit) { return $true }
    }
    return $false
}

# 找图片库 SeewoStartup：从起点目录逐级向上最多 4 层
function Find-ImageLibrary {
    param([string]$StartDirectory)
    if (-not $StartDirectory) { $StartDirectory = (Get-ProjectRoot) }

    $directory = (Resolve-Path -LiteralPath $StartDirectory -ErrorAction Stop).Path
    $fallback = $null
    for ($level = 0; $level -lt 4 -and $directory; $level++) {
        $candidate = Join-Path $directory 'SeewoStartup'
        if (Test-Path -LiteralPath $candidate) {
            if (Test-ImageLibrary -Path $candidate) { return $candidate }
            if (-not $fallback) { $fallback = $candidate }
        }
        $parent = Split-Path -Parent $directory
        if (-not $parent -or $parent -eq $directory) { break }
        $directory = $parent
    }
    return $fallback
}
