[English](./README.md) | [简体中文](./README_zh_CN.md)

# LocalAuth

LocalAuth 是一个本地优先的 iOS 验证器应用，围绕一次性验证码提供分级保护能力。它把本机令牌存储、硬件密钥辅助解锁、局域网近距加密迁移，以及可选的自建 Travel Vault 临时备份与恢复流程组合在一起。

## 亮点

- 基于 Keychain、Secure Enclave 包装与生物识别解锁的本地令牌存储。
- 多种导入方式：二维码扫描、截图 OCR、手动 Base32 输入、局域网加密迁移。
- 支持 YubiKey challenge-response 与通用 CTAP2 `hmac-secret` 硬件密钥解锁流程。
- 可选的 Travel Vault 旅行备份与恢复能力，备份载荷端到端加密。
- SwiftUI 界面、SwiftData 持久化、多语言字符串，以及可切换 App 图标。

## 这份开源快照做了什么处理

为了公开发布，这个仓库已经做过一轮去敏感化整理：

- 私有 bundle identifier、开发团队标识、联系邮箱、线上服务地址，以及其他产品导流入口，已经替换成适合公开仓库的示例值。
- 这份快照默认没有连接任何正式 Travel Vault 后端；如需使用，你需要先自行部署并完成配置。
- 项目链接、公开联系方式和可选的 Travel Vault 地址集中放在 [`localauth/OpenSourceProjectInfo.swift`](./localauth/OpenSourceProjectInfo.swift) 中，方便你在发布自己的 fork 前统一替换。

## 环境要求

- Xcode 16 或更新版本
- iOS 18.0+
- NFC、生物识别、App Attest 与硬件密钥测试需要真机

## 本地运行

1. 用 Xcode 打开 [`localauth.xcodeproj`](./localauth.xcodeproj)。
2. 把占位 bundle identifier `com.example.localauth` 改成你自己的 App ID。
3. 设置你的 Apple 开发团队与签名配置。
4. 检查并更新 [`localauth/OpenSourceProjectInfo.swift`](./localauth/OpenSourceProjectInfo.swift) 中的仓库链接、公开联系信息，以及可选的 Travel Vault 地址。
5. 如果你打算启用 Travel Vault，还需要同步确认 App Attest、远端验证服务，以及 [`localauth/Services/TravelVaultRemoteConfig.swift`](./localauth/Services/TravelVaultRemoteConfig.swift) 里的接口路径与部署配置。

## 主要技术

- SwiftUI
- SwiftData
- LocalAuthentication / Secure Enclave / Keychain
- Vision OCR
- AVFoundation 二维码扫描
- MultipeerConnectivity
- 通过 Swift Package Manager 引入的 YubiKit

## 目录结构

- [`localauth/Views`](./localauth/Views)：SwiftUI 界面与引导流程
- [`localauth/Services`](./localauth/Services)：加密、OCR、同步、Travel Vault、CTAP2 与硬件密钥集成
- [`localauth/Models`](./localauth/Models)：持久化令牌模型与示例数据
- [`localauth/ViewModels`](./localauth/ViewModels)：令牌存储与导入导出编排

## Travel Vault 说明

这份公开仓库里的 Travel Vault 是一个可选的自建能力：

- 仓库内不附带正式线上端点。
- 应用侧配置默认是空 URL。
- App Attest、备份保留策略、接口鉴权与滥用防护，都需要你在自己的部署中负责。

## 许可证

本仓库中的源代码按 Apache-2.0 提供，详见 [`LICENSE`](./LICENSE)。

品牌标识、应用名称、图标与商店素材不在该授权范围内，详见 [`BRANDING.md`](./BRANDING.md)。

## 为什么源码里还有很多简体中文字符串

这个项目一开始并不是一个为公开发布而精心打磨的开源工程。最早，它只是团队内部一个很小的实验，后来却比预想中更快地成长为一款真正的产品。

也正是在那段内部探索与快速迭代的过程中，LocalAuth 最核心的理念逐渐成形：让不同价值的账户进入不同强度的信任边界，同时坚持本地优先与可验证的透明性。今天代码里仍然保留的一些简体中文字符串，正是项目早期演进阶段留下的真实痕迹；我们选择把这些痕迹保留下来，作为这款软件真实发展过程的一部分。
