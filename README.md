# 希沃白板 5 随机启动图

![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)
![Platform: Windows](https://img.shields.io/badge/Platform-Windows%207%2B-0078D6.svg)

> 每次启动希沃白板 5（EasiNote 5）时，从本地图片库里随机挑一张图替换启动图，然后启动白板。
> 双击即用、全程无窗口、无弹窗、不常驻。

Seewo EasiNote 5 random splash launcher: on every launch it picks a random image from a
local library, overwrites the `SplashScreen.png` of the **newest installed** EasiNote
version, verifies the copy with SHA-256, and only then starts `swenlauncher.exe`.

## 功能特性

- **随机启动图** —— 每次运行先随机挑一个子文件夹，再随机挑其中一张图片覆盖启动图。
- **自动适配版本** —— 读取注册表定位希沃白板安装目录，在 `EasiNote5_*` 中按版本号取最高的那个，白板升级后无需改配置。
- **普通权限运行** —— 平时以普通用户权限运行，只有写入 `Program Files` 被拒绝时才自动提权复制；希沃白板本身仍是普通权限启动。
- **确认成功才启动** —— 覆盖后做 SHA-256 校验，一致才启动 `swenlauncher.exe`；失败则不启动，只写日志。
- **全程无窗口** —— 主程序与提权子进程都是 GUI 子系统，没有任何对话框或控制台闪窗。
- **一键打包** —— `scripts/package.ps1` 把图片库 + 程序打成一个开箱即用的 zip，附带回快捷方式。

## 运行原理

1. **定位图片库**：优先读程序目录下的 `library.txt`（一行绝对路径，可选），否则从程序目录逐级向上 4 层找名为 `SeewoStartup` 且含图片的目录。
2. **定位希沃白板**：读 `HKLM\SOFTWARE\WOW6432Node\Seewo\EasiNote5` 的 `path` / `ExePath` / `VersionPath`，读不到再找 `%ProgramFiles(x86)%\Seewo\EasiNote5` 与 `%ProgramFiles%\Seewo\EasiNote5`。
3. **挑最新版本**：枚举安装目录下的 `EasiNote5_*`，解析目录名里的版本号，取版本最高且包含 `Main\Resources\Startup` 的目录（版本号相同才比较修改时间）。
4. **随机换图**：随机挑一个子文件夹，再随机挑其中一张图片，同名覆盖 `SplashScreen.png`（先清掉只读属性）。
5. **提权兜底**：直接复制失败时，用 `runas` 把自己以管理员身份重新拉起，子进程只做一次复制然后退出。
6. **校验后启动**：主进程对源图与目标做 SHA-256 比对，一致才启动 `swenlauncher.exe`；不一致则记录日志并退出。

## 目录结构

```
.
├── .github/workflows/build.yml    GitHub Actions：编译并上传产物
├── docs/                          设计说明与常见问题
├── packaging/                     打包用的模板（cmd、包内说明）
├── resources/                     app.ico（构建时生成，不入库）
├── scripts/
│   ├── common.ps1                 公共路径工具
│   ├── seewo-locate.ps1           自动定位希沃白板安装目录 / 启动器 / 最新版 Startup
│   ├── build.ps1                  编译主程序到 dist\
│   ├── install-shortcut.ps1       安装 / 重建快捷方式
│   ├── restore-shortcut.ps1       还原原版快捷方式
│   └── package.ps1                打包成开箱即用的 zip
├── src/
│   ├── SeewoRandomStartup.cs      主程序源码
│   └── app.manifest               应用清单（asInvoker）
├── dist/                          构建产物（不入库）
└── README.md
```

图片库 `SeewoStartup` 因图片版权原因**不随仓库分发**，请自行准备：
放在仓库同级目录（推荐）或仓库内部均可，程序与打包脚本都会自动找到它。

## 快速开始

### 从源码构建

需要 Windows 7+ 与 .NET Framework 4.x（系统自带，无需安装 SDK）。

```powershell
# 编译到 dist\SeewoRandomStartup.exe
powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1

# 安装 / 重建桌面、开始菜单、任务栏快捷方式（会自己提权）
powershell -ExecutionPolicy Bypass -File .\scripts\install-shortcut.ps1
```

也可以直接双击 `dist\SeewoRandomStartup.exe`（等价于安装后的快捷方式）。

### 从 Release 压缩包

解压后双击 `安装快捷方式.cmd` 即可；详见包内 `使用说明.txt`。

## 配置

| 配置项 | 位置 | 说明 |
| --- | --- | --- |
| 图片库位置 | 程序目录下的 `library.txt` | 一行绝对路径；不写则自动向上搜索 `SeewoStartup` |
| 图片 | `SeewoStartup\<子文件夹>\<图片>` | 支持 png / jpg / jpeg / bmp / gif / webp / tif / tiff |
| 兜底路径 | `src/SeewoRandomStartup.cs` 顶部常量 | 注册表键名等；正常无需修改 |

## 命令行参数

| 参数 | 说明 |
| --- | --- |
| `--no-launch` | 只换启动图，不启动希沃白板（调试用） |
| `--copy "<源>" "<目标>"` | 内部使用：提权子进程的复制模式 |

## 打包

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\package.ps1
```

产物为 `dist\希沃白板5随机启动图.zip`，包内包含图片库、主程序、脚本、文档、
随包快捷方式、`安装快捷方式.cmd`、`还原快捷方式.cmd` 与 `使用说明.txt`。

## 日志

```
%LOCALAPPDATA%\SeewoRandomStartup\launcher.log
```

每次运行挑了哪张图、写到哪个版本目录、是否提权、是否确认成功、是否启动白板，都有记录。
单文件超过 1 MB 会自动清空重建。

## 已知限制

- **Windows 快捷方式记录的是绝对路径**。经实测（WScript 不写 `RELATIVE_PATH`；用 `IShellLink::SetRelativePath` 写入后，Windows 10 15063 同样不解析），
  一个 `.lnk` 连同目标一起被复制/解压到别处后，无法按相对路径自动找到目标。
  因此发布包只能附带 `.lnk`，由 `安装快捷方式.cmd` 按解压后的真实路径重建一次。
  移动文件夹后重新运行一次安装脚本即可。
- 启动图写入 `Program Files` 需要管理员权限。若系统 UAC 设置为"始终提示"，
  提权时会弹出一次系统 UAC 窗口（这是系统行为，无法绕过）；设置为"不提示直接提升"时全程无窗口。
- 只支持 Windows。

## 开发

- 源码为单文件 C#，兼容 C# 5（用 .NET Framework 4.x 的 `csc.exe` 编译）。
- 修改后运行 `scripts/build.ps1` 重新编译；提交前请确认 `dist/`、`*.log`、`*.lnk` 未被跟踪。
- 提交信息建议使用 Conventional Commits 风格（`feat:` / `fix:` / `docs:` / `chore:`）。

## 许可证

本项目以 [GNU Affero General Public License v3.0](LICENSE) 发布。

## 免责声明

- 本项目与希沃（Seewo）官方无关，仅为个人自动化工具。
- 程序会修改希沃白板安装目录下的启动图文件（`SplashScreen.png`），请自行评估风险；
  仓库不包含任何游戏 / 影视图片素材，图片库需自行准备。
- "希沃""EasiNote"等名称与图标归其权利人所有。
