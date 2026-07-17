# Daisy 免费编译、安装与续签

## 1. 免费方案的边界

Apple 免费 Personal Team 的描述文件只有 7 天有效。Daisy 可以完全免费编译和侧载，但必须让 Windows 上的 AltServer/AltStore 定期刷新。免费账号没有 TestFlight，且 Apple 当前限制为最多 10 个 App ID、3 台设备、每台设备 3 个 App。

## 2. 从 GitHub 获取 IPA

1. 将仓库设为公开，确保标准 GitHub-hosted macOS Runner 免费。
2. 打开 GitHub 仓库的 **Actions**。
3. 运行 **iOS CI**，确认单元测试和 UI 测试全部通过。
4. 手动运行 **Build unsigned IPA**。
5. 下载保留期为 1 天的 `Daisy-unsigned-ipa` Artifact 并解压得到 `Daisy-unsigned.ipa`。

仓库和 Artifact 不得包含真实 API Key、付款截图或本地账本。

## 3. Windows 安装 AltServer

1. 从 AltStore 官方页面下载 Windows 版 AltServer。
2. 按 AltStore 当前说明安装其要求的 Apple iTunes 和 iCloud 组件；不要混用不兼容版本。
3. USB 连接 iPhone，解锁并选择“信任此电脑”。
4. 在 iPhone 开启开发者模式并按系统要求重启。
5. 通过 AltServer 安装 AltStore，使用免费 Apple Account 完成签名。
6. 在 iPhone 的 VPN 与设备管理/开发者设置中信任对应身份。

## 4. 安装 Daisy

推荐方法：在 iPhone AltStore 的 **My Apps** 中点击 `+`，选择 `Daisy-unsigned.ipa`。AltStore 会使用免费账号重新签名并安装。

备用方法：在 Windows 按住 Shift 点击 AltServer 托盘图标，选择 **Sideload .ipa...**。此方式通常需要每 7 天手动重新安装。

## 5. 每 7 天续签

- Windows 与 iPhone 保持同一 Wi-Fi，AltServer 在后台运行。
- 每周打开一次 AltStore，检查 Daisy 剩余天数并点击 **Refresh All**。
- 自动发现失败时用 USB 连接后刷新。
- 刷新是重新签名，不应删除本地账本；仍建议定期在 Daisy 中导出 JSON 备份。

## 6. 配置 Windows 本地 AI

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
3. 添加 Daisy 的“识别付款截图”动作并传入截屏结果。
4. 设置 → 辅助功能 → 触控 → 轻点背面 → 轻点两下 → 付款后记账。
