# 打包成开箱即用的 zip：<项目根>\dist\希沃白板5随机启动图.zip
# 包内结构：
#   希沃白板5随机启动图\
#       SeewoStartup\          图片库
#       dist\SeewoRandomStartup.exe
#       scripts\ src\ resources\ docs\ ...
#       希沃白板 5.lnk         随包附带的快捷方式
#       安装快捷方式.cmd       安装到桌面 / 开始菜单 / 任务栏
#       还原快捷方式.cmd
#       使用说明.txt
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
. (Join-Path $PSScriptRoot 'seewo-locate.ps1')

$root        = Get-ProjectRoot
$dist        = Join-Path $root 'dist'
$packageName = '希沃白板5随机启动图'
$stagingRoot = Join-Path $dist '_staging'
$stagingPkg  = Join-Path $stagingRoot $packageName
$zipPath     = Join-Path $dist ($packageName + '.zip')

Write-Host '1/5 编译主程序 ...'
& (Join-Path $PSScriptRoot 'build.ps1')

Write-Host '2/5 检查图片库 ...'
$library = Find-ImageLibrary -StartDirectory $root
if (-not $library) { throw '找不到图片库 SeewoStartup（放在仓库同级或仓库内均可）' }
Write-Host ('    图片库: ' + $library)

Write-Host '3/5 组织包内容 ...'
if (Test-Path -LiteralPath $stagingRoot) { Remove-Item -LiteralPath $stagingRoot -Recurse -Force }
New-Item -ItemType Directory -Force -Path (Join-Path $stagingPkg 'dist') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $stagingPkg 'SeewoStartup') | Out-Null

# 只复制图片库内容，跳过误放在里面的程序目录（旧版 _Launcher、含 exe 的目录）
$libraryItems = @(Get-ChildItem -LiteralPath $library -Force | Where-Object {
    $isProgram = $false
    if ($_.PSIsContainer) {
        if ($_.Name -eq '_Launcher') { $isProgram = $true }
        elseif (Test-Path -LiteralPath (Join-Path $_.FullName 'SeewoRandomStartup.exe')) { $isProgram = $true }
    }
    -not $isProgram
})
$libraryItems | Copy-Item -Destination (Join-Path $stagingPkg 'SeewoStartup') -Recurse -Force

$exclude = @('.git', '.github', '.gitignore', '.gitattributes', '.editorconfig', 'dist', 'packaging',
             'install.log', 'restore.log', '希沃白板 5.lnk', 'diag.ps1', 'diag.out.txt')
Get-ChildItem -LiteralPath $root -Force | Where-Object { $_.Name -notin $exclude } |
    Copy-Item -Destination $stagingPkg -Recurse -Force

Copy-Item -LiteralPath (Get-BuiltExe) -Destination (Join-Path $stagingPkg 'dist\SeewoRandomStartup.exe') -Force

Write-Host '4/5 生成快捷方式与说明 ...'
$launcher   = Get-SeewoLauncher
$stagingExe = Join-Path $stagingPkg 'dist\SeewoRandomStartup.exe'
$iconSource = $stagingExe
if ($launcher) { $iconSource = $launcher }

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut((Join-Path $stagingPkg '希沃白板 5.lnk'))
$shortcut.TargetPath       = $stagingExe
$shortcut.Arguments        = ''
$shortcut.WorkingDirectory = (Join-Path $stagingPkg 'dist')
$shortcut.Description      = '希沃白板 5'
$shortcut.WindowStyle      = 1
$shortcut.IconLocation     = $iconSource + ',0'
$shortcut.Save()

Copy-Item -LiteralPath (Join-Path $root 'packaging\install.cmd') -Destination (Join-Path $stagingPkg '安装快捷方式.cmd') -Force
Copy-Item -LiteralPath (Join-Path $root 'packaging\restore.cmd') -Destination (Join-Path $stagingPkg '还原快捷方式.cmd') -Force
Copy-Item -LiteralPath (Join-Path $root 'packaging\PACKAGE_README.txt') -Destination (Join-Path $stagingPkg '使用说明.txt') -Force

Write-Host '5/5 压缩 ...'
Add-Type -AssemblyName System.IO.Compression.FileSystem
if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
[System.IO.Compression.ZipFile]::CreateFromDirectory(
    $stagingPkg, $zipPath,
    [System.IO.Compression.CompressionLevel]::Optimal,
    $true)
if (Test-Path -LiteralPath $stagingRoot) { Remove-Item -LiteralPath $stagingRoot -Recurse -Force }

$info = Get-Item -LiteralPath $zipPath
Write-Host ''
Write-Host ('打包完成: ' + $info.FullName + '  (' + [math]::Round($info.Length / 1MB, 2) + ' MB)')
