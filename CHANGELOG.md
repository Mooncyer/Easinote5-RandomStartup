# 更新日志

本项目遵循 [语义化版本](https://semver.org/lang/zh-CN/) 与 [Keep a Changelog](https://keepachangelog.com/zh-CN/)。

## [0.0.2] - 2026-10-24

### 新增

- 程序集版本信息（`src/Version.cs`）：exe 现在带有文件版本与产品版本，本版为 `0.0.2`。
- 首个 GitHub Release 压缩包 `希沃白板5随机启动图.zip`：内含程序、图片库与安装 / 还原脚本。

### 变更

- `scripts/build.ps1` 改为连同 `src/Version.cs` 一起编译。

## [1.0.0] - 2026-09-13

### 新增

- 启动希沃白板 5 前，从图片库随机挑一张图覆盖启动图 `SplashScreen.png`。
- 自动探测希沃白板安装目录与**最新版本** `EasiNote5_*`，无需手动指定版本号。
- 覆盖后用 SHA-256 校验，确认成功才启动 `swenlauncher.exe`。
- 普通权限运行，写入被拒绝时自动提权（GUI 子系统 + 隐藏窗口，全程无弹窗）。
- 安装 / 还原与希沃白板原版同名同图标的快捷方式，可固定到任务栏。
- `scripts/package.ps1` 一键打包成开箱即用的 zip。
