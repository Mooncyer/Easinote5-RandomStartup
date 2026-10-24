# resources

`app.ico` 是 `scripts/build.ps1` 在构建时从本机
`...\Seewo\EasiNote5\swenlauncher\swenlauncher.exe` 提取出来的图标，
属于希沃白板的资源，因此**不随仓库分发**（已被 `.gitignore` 忽略）。

首次构建时会自动生成；如果没有安装希沃白板，则跳过图标直接编译，
快捷方式仍会引用本机的 `swenlauncher.exe` 作为图标来源。
