# Daisy 免费编译、安装与续签

## 1. 免费方案的边界

Apple 免费开发者账号签出的 App 只有 7 天有效。Daisy 可以完全免费编译和侧载，但必须让 Windows 上的 AltServer/AltStore 定期刷新。AltStore 官方文档说明，免费账号同一时间最多注册 10 个 App ID、在一台设备上保持 3 个侧载 App 处于活跃状态。Daisy 将 App Intent 放在主 App 内，不额外占用扩展 App ID。

## 2. 从 GitHub 获取 IPA

1. 将仓库设为公开，确保标准 GitHub-hosted macOS Runner 免费。
2. 打开 GitHub 仓库的 **Actions**。
3. 运行 **iOS CI**，确认单元测试和 UI 测试全部通过。
4. 手动运行 **Build unsigned IPA**。
5. 下载保留期为 1 天的 `Daisy-unsigned-ipa` Artifact 并解压得到 `Daisy-unsigned.ipa`。

仓库和 Artifact 不得包含真实 API Key、付款截图或本地账本。

## 3. Windows 安装 AltServer

以 [AltStore 官方 Windows 安装页](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows) 为准：

1. 从 Apple 直接安装最新 iTunes 和 iCloud，不要使用 Microsoft Store 版本；官方页面提供当前下载入口。
2. 下载官方 [AltServer for Windows](https://cdn.altstore.io/file/altstore/altinstaller.zip)，解压后运行 `Setup.exe`。
3. 从 Windows 开始菜单以管理员身份运行 AltServer；防火墙询问时允许专用网络。
4. USB 连接 iPhone，保持解锁并在手机与电脑上确认“信任”。
5. 打开 iTunes，登录 Apple Account，并为这台 iPhone 开启“通过 Wi-Fi 与此 iPhone 同步”。
6. 点击系统托盘中的 AltServer → **Install AltStore** → 选择目标 iPhone，使用免费 Apple Account 完成签名。AltStore 官方说明凭据只发送给 Apple。
7. iPhone 打开“设置 → 通用 → VPN 与设备管理”（名称可能略有差异），信任对应开发者身份。
8. iPhone 打开“设置 → 隐私与安全性 → 开发者模式”，按系统提示重启并再次确认。

## 4. 安装 Daisy

推荐方法：保持 AltServer 在 Windows 运行，并让 iPhone 与电脑处于同一 Wi-Fi 或使用 USB 连接。把 `Daisy-unsigned.ipa` 存入 iPhone“文件”App，在 AltStore 的 **My Apps** 中点击 `+` 并选择它。AltStore 会使用免费账号重新签名并安装。

备用方法：在 Windows 按住 Shift 点击 AltServer 托盘图标，选择 **Sideload .ipa...** 并直接选择电脑上的 IPA。AltStore 官方说明，这种直接安装方式需要每 7 天手动重新安装。

## 5. 每 7 天续签

- Windows 与 iPhone 保持同一 Wi-Fi，AltServer 在后台运行；或在刷新时使用 USB 连接。
- 每周打开一次 AltStore，在 **My Apps** 检查 Daisy 剩余天数并点击 **Refresh All**。
- 自动发现失败时用 USB 连接后刷新。
- 刷新是重新签名，不应删除本地账本；仍建议定期在 Daisy 中导出 JSON 备份。

官方参考：[AltServer 工作方式](https://faq.altstore.io/altstore-classic/altserver)、[My Apps 与 7 天有效期](https://faq.altstore.io/altstore-classic/your-altstore)、[App ID 限制](https://faq.altstore.io/altstore-classic/app-ids)。

## 6. 配置 AI 识别服务

### 自选 OpenAI-compatible 服务

1. 打开 Daisy → 设置 → AI 识别服务。
2. 填写配置名称、服务商提供的 Base URL（通常以 `/v1` 结尾）和 API Key。
3. 点击“获取模型”，选择支持图片输入的视觉模型。
4. 点击“测试视觉识别”检查模型是否能读取图片，然后保存。测试状态仅用于能力诊断，不改变自动入账阈值。

Daisy 不使用产品自有中转站：截图从 iPhone 直接发送到你填写的 URL，API Key 只保存在 iPhone Keychain。公网服务必须使用 HTTPS。Daisy 本身不收费，但第三方服务是否提供免费额度由服务商决定。

### 完全免费的 Windows 本地方案

1. Windows 安装 Ollama 并拉取支持视觉的模型。
2. 只在专用网络中开放 Ollama 端口，不要直接暴露公网。
3. Daisy → 设置 → AI 识别服务，填写：

```text
Base URL: http://<Windows局域网IP>:11434/v1
API Key: ollama
```

4. 点击“获取模型”，选择视觉模型。
5. 点击“测试视觉识别”，通过后保存。

## 7. 配置背面轻点

1. 快捷指令中新建“付款后记账”。
2. 添加系统“截屏”动作。
3. 紧接着添加 Daisy 的“识别付款截图”动作。
4. 展开 Daisy 动作，确认“付款截图”参数显示为上一步的“截屏”；如果显示“每次询问”或为空，点该参数并选择“截屏”。
5. 只把完整的“付款后记账”快捷指令绑定到背面轻点，不要直接绑定单独的 Daisy 动作。App 无权自行截取其他 App 的屏幕，图片必须来自第一步系统截屏。
6. 如果升级 Daisy 后旧快捷指令仍不传图，删除旧的 Daisy 动作并重新添加一次，以刷新 App Intent 参数元数据。
7. 设置 → 辅助功能 → 触控 → 轻点背面 → 轻点两下 → 付款后记账。
