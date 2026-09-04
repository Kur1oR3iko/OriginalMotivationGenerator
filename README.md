# 原始动机生成器

从 `emu98` 关于页彩蛋中独立出来的 iOS / iPadOS SwiftUI App。它保留原始的 225 个动词、225 个形容词和 225 个名词，以及遍历全部 11,390,625 种组合且不重复的生成算法。

应用启动后以横屏显示白底黑字短语，点击屏幕任意位置生成下一条。界面会根据 iPhone 或 iPad 的安全区和可用宽度自动调整字号，并始终保持单行。

## 构建

需要 macOS、Xcode、CMake 3.20 或更高版本。App 的最低系统版本为 iOS / iPadOS 15.0；提交 App Store Connect 时需使用 Xcode 26 或更高版本和 iOS 26 SDK 或更高版本构建。

```sh
open OriginalMotivationGenerator.xcodeproj
```

仓库同时保留了 CMake 构建文件。GitHub Actions 会在 `main` 和 `release/testflight` 分支上执行无签名模拟器构建；Xcode Cloud 负责归档并发布到 TestFlight。

在 Xcode 中选择模拟器即可运行。若要安装到真机，请在项目签名设置中选择自己的开发团队，或生成项目时传入：

```sh
cmake -S . -B build -G Xcode -DOMG_DEVELOPMENT_TEAM=你的团队ID
```

生成进度和随机起点只保存在本机；横屏点击任意位置即可生成下一条短语。
