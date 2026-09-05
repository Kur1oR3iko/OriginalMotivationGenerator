# iOS 6–14 兼容版

已增加独立的 Objective-C / UIKit 工程，目标最低版本为 iOS 6.0，真机架构为 armv7 + arm64。原 SwiftUI 工程继续保留。**目前仅完成源码移植和静态检查，尚未使用 Apple SDK 编译，也未验证任一版本的实际运行。**

## 已实现

- 横屏、白底黑字、点击全屏生成下一条；iPhone / iPad 单行自动缩放。
- 原版的三组 225 个词条、11,390,625 个组合及相同的排列算法。
- 与原版相同的偏移量、游标和最后短语存储键。保持相同 Bundle ID 且以保留数据的方式升级时可复用进度；卸载或更换应用容器不能保证保留。
- 乘法使用 `int64_t`，避免 armv7 上的 32 位溢出。
- iOS 6/7 使用 PNG 启动图；iOS 8 及以上使用启动 storyboard。图标使用独立 PNG，不依赖现代 Asset Catalog。
- 使用旧版粗体系统字体；较新机型预留横屏两侧边距。外观不完全等同于 SwiftUI 的圆角黑体，全面屏的显示范围仍需真机检查。

## 构建

### GitHub Actions

仓库增加了 `Build iOS 6-14 Legacy` 工作流。推送到 `codex/ios6-14-legacy` 分支且修改相关源码时触发，也可手动触发。它在 Ubuntu 22.04 上下载固定版本的 Theos 生态交叉工具链和固定提交的 iOS 9.3 SDK，分别编译 armv7（最低 iOS 6.0）及 arm64（最低 iOS 7.0），再合并为通用二进制。

流程会解析 Mach-O，检查真实架构、最低系统版本和动态库路径，然后上传 **未签名 IPA** 与 `verification.json`。该 IPA 需要另行签名才能正常安装；工作流不读取签名证书。构建成功不等于真机验证通过。

Linux 构建不编译 storyboard，而使用 PNG 启动图。因此较新机型可能使用兼容显示尺寸。需要验证全面屏布局时，应同时比较下述 Xcode 构建产物。

### 本地 Xcode

优先尝试 **Xcode 7.3.1 + 自带 iOS 9.3 SDK**，并使用能够运行它的 macOS 环境。该工具链可面向 iOS 6 并生成 armv7 / arm64；本仓库尚未实测此构建组合。现代 Xcode 无法直接替代这套旧系统工具链。

```sh
open OriginalMotivationGeneratorLegacy.xcodeproj

# 无签名真机构建，只验证编译、链接与资源，不产生可直接安装的签名 IPA。
xcodebuild -project OriginalMotivationGeneratorLegacy.xcodeproj \
  -scheme OriginalMotivationGeneratorLegacy -configuration Release \
  -sdk iphoneos CODE_SIGNING_ALLOWED=NO \
  CONFIGURATION_BUILD_DIR="$PWD/build-legacy" build

lipo -info build-legacy/OriginalMotivationGeneratorLegacy.app/OriginalMotivationGeneratorLegacy
```

确认产物同时包含 armv7 和 arm64。安装需要适合目标设备的签名和描述文件；老 Xcode 的设备连接、账号登录和安装能力不能等同于应用二进制的运行兼容性。不要把旧工具链产物视为符合当前 App Store / TestFlight 上传要求的版本。

两个工程使用相同 Bundle ID，因此通常会相互覆盖。需要同时安装时，修改旧版工程的 Bundle ID，但进度也会分开。

本工程独立于原有 CMake、模拟器 GitHub Actions 和 Xcode Cloud 配置；原有 CI 成功不能证明旧版工程成功。

## 必须补做的运行验证

逐个覆盖 iOS 6、7、8、9、10、11、12、13、14，并记录设备型号和补丁版本。重点检查：

1. iOS 6 的 armv7 设备，以及 iOS 7–10 的 32 位和 64 位设备。
2. iOS 11–14 的 arm64 设备，包括全面屏 iPhone 和 iPad。
3. 冷启动、两个横屏方向、连续点击、退到后台、结束进程后恢复进度、VoiceOver 激活。
4. 长短语无截断、文字避开屏幕缺口、启动画面尺寸和状态栏。
5. 游标接近上限时生成最后组合，之后显示完成提示。

在完成这些验证前，应描述为“目标支持 iOS 6–14 的移植版”，不能宣称“所有系统已验证可用”。

## 维护词库和资源

修改原版词库或图标后，用 Python 3 和 Pillow 运行：

```sh
python tools/prepare_legacy.py
```

此脚本从 Swift 文件提取原始词条，并更新旧版 plist、图标和白色启动图片。旧版 Xcode 构建不需要 Python。
