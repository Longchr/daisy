# Daisy

Daisy 是一款原生 iPhone 私人记账 App。账本保存在本机，付款截图通过 iOS 快捷指令交给 App Intent，再直接调用用户配置的 OpenAI-compatible 视觉模型完成提取与分类。

## 已实现范围

- 原生 SwiftUI 总览、账单、分析、设置四个 Tab
- SwiftData 本地账本、默认账户与分类
- 原生首次引导、账户实时余额、双账户转账和归档恢复
- 月度/分类预算、周期账单提醒与本地通知确认
- 手动记账、搜索、筛选、详情、删除
- Swift Charts 月度趋势与分类占比
- Base URL / API Key / `/models` 获取 / 视觉模型测试
- Vision 本地 OCR、图片压缩、JSON 白名单校验、置信度策略、重复检测
- 自定义分类进入 AI 白名单、支付渠道到账户映射、可调自动入账阈值
- App Intent“识别付款截图”，限定图片输入并自动连接上一步截屏结果
- 相册截图识别与低置信结果确认
- 总览/分析下钻保持在来源 Tab 内，返回不会跳到其他主模块
- Face ID 锁、金额隐私、深色模式、动态字体与 VoiceOver 基础支持
- CSV/JSON 导出、JSON 恢复和本地数据清理
- 单元测试、UI 测试、公开仓库免费 macOS CI、无签名 IPA 工作流

## 工程生成

项目使用 [XcodeGen](https://github.com/yonaskolb/XcodeGen)，不提交易冲突的 `.xcodeproj`：

```bash
xcodegen generate
open Daisy.xcodeproj
```

当前 Windows 环境执行：

```powershell
./scripts/validate_project.ps1
```

完整安装步骤见 [免费安装与续签](docs/FREE_INSTALL.md)，测试范围见 [测试计划](docs/TEST_PLAN.md)，产品定义见 [PRD](docs/PRD.md)。

## 安全边界

- API Key 只保存在 iPhone Keychain。
- CI、公开仓库和 IPA 中不包含运行时 Key、截图或账本。
- 普通互联网 API 强制 HTTPS；HTTP 只允许用户明确开启的私有网络地址。
- 模型输出按不可信输入处理，不符合本地 schema 的结果不会自动入账。
