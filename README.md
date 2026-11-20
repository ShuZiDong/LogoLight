# 徽光 · LogoLight

徽光是一款中文 macOS 菜单栏工具，用来调节 MacBook Pro 机身背面的发光 Apple 标志。点击菜单栏的四角星，可以设置亮度，切换常亮、呼吸或关闭，也可以恢复系统自动调光。

## 兼容性

已在一台配备发光标志的 Apple M5 Pro MacBook Pro、macOS 27.2 上测试。应用通过 macOS 的私有 CoreBrightness 接口控制灯光，系统更新可能影响兼容性。若正在使用 Backglow，请先退出它，再用徽光接管灯光。

## 从源码构建

在 Apple Silicon Mac 上安装 Xcode Command Line Tools，然后在仓库目录运行：

```sh
./build.sh
open "../徽光.app"
```

构建脚本会在仓库的上一级目录生成「徽光.app」并进行本地签名。将它拖进「应用程序」即可安装。正常退出时，徽光会恢复接管前的灯光设置。
