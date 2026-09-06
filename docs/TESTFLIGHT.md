# GitHub → TestFlight

推送到 `main` 或 `release/testflight` 会触发 GitHub Actions：跑回归测试、用发布证书归档，再上传 App Store Connect / TestFlight。也可在 Actions 里手动运行 **TestFlight**。

Build 号使用 `github.run_number`，避免和已有 TestFlight 构建冲突。

## 仓库 Secrets

在 GitHub 仓库 **Settings → Secrets and variables → Actions** 添加：

| Secret | 内容 |
| --- | --- |
| `APPLE_TEAM_ID` | Apple Developer Team ID，当前项目为 `89M33WN9W7` |
| `APP_STORE_CONNECT_KEY_ID` | App Store Connect API Key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect Issuer ID |
| `APP_STORE_CONNECT_KEY` | `.p8` 私钥全文，或它的 base64 |
| `APP_STORE_CONNECT_KEY_IS_BASE64` | 若 `APP_STORE_CONNECT_KEY` 是 base64，设为 `true` |
| `BUILD_CERTIFICATE_BASE64` | Apple Distribution `.p12` 的 base64 |
| `P12_PASSWORD` | `.p12` 密码 |
| `BUILD_PROVISION_PROFILE_BASE64` | App Store 描述文件 `.mobileprovision` 的 base64 |
| `KEYCHAIN_PASSWORD` | 可选，CI 临时钥匙串密码 |

生成证书和描述文件的 base64：

```sh
base64 -i distribution.p12 | pbcopy
base64 -i AppStore.mobileprovision | pbcopy
```

App Store Connect API Key 需要 **App Manager** 或更高权限，并允许上传构建。

首次上传前，在 App Store Connect 创建同名 App，Bundle ID 为 `com.kurio.original-motivation-generator`。
