# 编译 src\SeewoRandomStartup.cs -> dist\SeewoRandomStartup.exe
# 使用系统自带的 .NET Framework 编译器（csc.exe），无需安装任何 SDK。
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
. (Join-Path $PSScriptRoot 'seewo-locate.ps1')

$root = Get-ProjectRoot
$dist = Join-Path $root 'dist'
if (-not (Test-Path -LiteralPath $dist)) { New-Item -ItemType Directory -Force -Path $dist | Out-Null }

$csc = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $csc)) { $csc = 'C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe' }
if (-not (Test-Path -LiteralPath $csc)) { throw '找不到 csc.exe，需要 .NET Framework 4.x' }

# exe 自身的图标：优先用仓库里的 resources\app.ico；没有就从本机 swenlauncher.exe 提取。
# （Seewo 图标不随仓库分发，首次构建时自动生成为未跟踪文件）
$ico = Join-Path $root 'resources\app.ico'
if (-not (Test-Path -LiteralPath $ico)) {
    $launcher = Get-SeewoLauncher
    if ($launcher) {
        Add-Type -AssemblyName System.Drawing
        $icon = [System.Drawing.Icon]::ExtractAssociatedIcon($launcher)
        $stream = [System.IO.File]::Create($ico)
        $icon.Save($stream)
        $stream.Close()
        $icon.Dispose()
        Write-Host ('已从 swenlauncher.exe 提取图标: ' + $ico)
    }
}

# 注意：必须用变量展开（/out:$out），不要在数组里写 '/out:' + (...)，否则参数会被 PowerShell 拆开。
$src      = Join-Path $root 'src\SeewoRandomStartup.cs'
$manifest = Join-Path $root 'src\app.manifest'
$out      = Get-BuiltExe

if (Test-Path -LiteralPath $ico) {
    & $csc /nologo /target:winexe /platform:anycpu /optimize+ /codepage:65001 /out:$out /win32manifest:$manifest /win32icon:$ico $src
}
else {
    & $csc /nologo /target:winexe /platform:anycpu /optimize+ /codepage:65001 /out:$out /win32manifest:$manifest $src
}
if ($LASTEXITCODE -ne 0) { throw "编译失败，退出码 $LASTEXITCODE" }
Write-Host ('已生成: ' + $out)
