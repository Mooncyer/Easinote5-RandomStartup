# 设计说明

## 目标

在不打扰用户的前提下，让每次启动希沃白板 5 都换一张启动图：

- 双击快捷方式即可，不需要常驻进程；
- 不能出现任何窗口、控制台黑框或提示框；
- 写 `Program Files` 需要管理员权限，但希沃白板本身应以普通权限启动；
- 升级希沃白板、换机器后不需要改配置。

## 关键设计

### 1. 图片库定位

按顺序：

1. 程序目录下的 `library.txt`（一行绝对路径，可选）；
2. 从程序目录逐级向上最多 4 层，找名为 `SeewoStartup` 且包含图片的目录。

这样同一份程序既能用于"图片库在包根"的开箱即用包，也能用于"仓库与图片库同级"的开发目录，
还允许用户用 `library.txt` 指向任意位置。

### 2. 希沃白板版本定位

注册表 `HKLM\SOFTWARE\WOW6432Node\Seewo\EasiNote5`（32 位系统为 `HKLM\SOFTWARE\Seewo\EasiNote5`）里有：

| 值 | 含义 |
| --- | --- |
| `path` | 安装根目录，如 `C:\Program Files (x86)\Seewo\EasiNote5` |
| `ExePath` | 启动器，如 `...\swenlauncher\swenlauncher.exe` |
| `VersionPath` | 当前版本目录，如 `...\EasiNote5_5.2.4.8772` |

程序不直接用 `VersionPath`，而是枚举安装根目录下的 `EasiNote5_*`，解析目录名里的
版本号取最高者（版本号相同才比较修改时间），因为 `VersionPath` 可能滞后于实际安装的版本。
找不到版本目录时才回退到注册表 `VersionPath` 或安装根目录本身。

### 3. 权限模型

- 主进程清单为 `asInvoker`，正常双击是普通权限。
- 先尝试直接 `File.Copy`；失败（通常是拒绝访问）后，用 `ProcessStartInfo.Verb = "runas"`
  把自己重新拉起，参数 `--copy "<源>" "<目标>"`。
- 提权子进程仍是 GUI 子系统（`/target:winexe`），并设置 `WindowStyle = Hidden`，不会产生任何窗口。
- 子进程只负责复制就退出；是否成功由主进程重新计算 SHA-256 判断，不依赖子进程返回值。
- 启动白板时用的是主进程（普通权限），所以白板不会继承管理员令牌。

### 4. 确认后才启动

`FilesAreEqual` 会比较文件长度与 SHA-256：

- 一致 → 启动 `swenlauncher.exe`；
- 不一致 / 被占用 / 提权失败 → 不启动，写日志后退出。

### 5. 为什么发布包里的 .lnk 需要安装脚本修正

Windows 快捷方式内部保存的是目标的绝对路径。实测结论：

- `WScript.Shell` 的 `Shortcut` 对象不会写入 `RELATIVE_PATH`；
- 用 `IShellLink::SetRelativePath` 显式写入后，在 Windows 10 15063 上把 `.lnk` 与目标
  一起复制到别处、原路径删除后，`ShellExecute` 仍返回 `ERROR_CANCELLED`，不会按相对路径解析。

因此"解压后不运行任何东西、双击包内 `.lnk` 就能用"无法实现。
解决办法是包内附带 `.lnk`，由 `scripts/install-shortcut.ps1` 在安装时按真实路径重建。

### 6. 无弹窗

源码中没有任何 `MessageBox`；所有异常都写日志。
唯一可能出现的窗口是系统 UAC 确认框（当系统设置为"始终提示"时），这属于系统行为。
