import SwiftUI

// MARK: - Models and Enums / 模型与枚举
enum AppLanguage: String, CaseIterable {
    case en = "English"
    case es = "Español"
    case ja = "日本語"
    case zhTW = "繁體中文"
    case zhCN = "简体中文"
    
    var isMainland: Bool {
        self == .zhCN
    }
    
    // Detect the system language automatically / 自动检测系统语言
    static var current: AppLanguage {
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? Locale.current.identifier.lowercased()
        
        if preferred.hasPrefix("es") { return .es }
        if preferred.hasPrefix("ja") { return .ja }
        if preferred.hasPrefix("zh-hant") || preferred.contains("-tw") || preferred.contains("-hk") || preferred.contains("-mo") {
            return .zhTW
        }
        if preferred.hasPrefix("zh") { return .zhCN }
        
        return .en
    }
}

// Localized strings for the settings page / 设置页面本地化文本
struct SettingsStrings {
    let title: String
    let done: String
    let supportUs: String
    let changeIcon: String
    let repositoryLinkTitle: String
    let hardwareCompatibilityTitle: String
    let documentationTitle: String
    let issueTrackerTitle: String
    let contactEmail: String
    let contactEmailTapHint: String
    let contactEmailCopied: String
    let contactEmailTip: String
    let footerPrivacy: String
    let translationNotice: String?
    
    static func get(for lang: AppLanguage) -> SettingsStrings {
        switch lang {
        case .en:
            return SettingsStrings(
                title: "Settings",
                done: "Done",
                supportUs: "Project Resources",
                changeIcon: "Free App Icons",
                repositoryLinkTitle: "Repository",
                hardwareCompatibilityTitle: "Hardware Compatibility",
                documentationTitle: "Documentation",
                issueTrackerTitle: "Issue Tracker",
                contactEmail: "Contact Email",
                contactEmailTapHint: "Tap email to copy",
                contactEmailCopied: "Copied",
                contactEmailTip: "This open-source snapshot keeps an example mailbox here. Replace it with your public maintainer address before release.",
                footerPrivacy: "Core token features stay local by default. Internet access is only used when you intentionally use Travel Vault, while Nearby Sync transfers encrypted token data directly between nearby devices on the local network.",
                translationNotice: "Translations are community-maintained in the public repository. If you spot an issue, please open an issue or pull request."
            )
        case .es:
            return SettingsStrings(
                title: "Ajustes",
                done: "Hecho",
                supportUs: "Recursos del proyecto",
                changeIcon: "Iconos gratis",
                repositoryLinkTitle: "Repositorio",
                hardwareCompatibilityTitle: "Compatibilidad de hardware",
                documentationTitle: "Documentacion",
                issueTrackerTitle: "Seguimiento de incidencias",
                contactEmail: "Correo de contacto",
                contactEmailTapHint: "Toca el correo para copiar",
                contactEmailCopied: "Copiado",
                contactEmailTip: "Esta instantanea de codigo abierto conserva un correo de ejemplo. Sustituyelo por la direccion publica del proyecto antes del lanzamiento.",
                footerPrivacy: "Las funciones principales de tokens permanecen en local por defecto. El acceso a Internet solo se usa cuando utilizas intencionalmente el resguardo de viaje, mientras que la sincronizacion cercana transfiere datos cifrados directamente entre dispositivos cercanos en la red local.",
                translationNotice: "Las traducciones se mantienen en comunidad dentro del repositorio publico. Si detectas un problema, abre una incidencia o un pull request."
            )
        case .ja:
            return SettingsStrings(
                title: "設定",
                done: "完了",
                supportUs: "プロジェクト情報",
                changeIcon: "無料アイコン",
                repositoryLinkTitle: "リポジトリ",
                hardwareCompatibilityTitle: "ハードウェア互換情報",
                documentationTitle: "ドキュメント",
                issueTrackerTitle: "Issue Tracker",
                contactEmail: "お問い合わせ",
                contactEmailTapHint: "メールアドレスをタップしてコピー",
                contactEmailCopied: "コピー済み",
                contactEmailTip: "このオープンソース版では例示用のメールアドレスを表示しています。公開前に自分のメンテナ用窓口へ置き換えてください。",
                footerPrivacy: "通常のトークン機能はローカルで動作します。インターネット通信は旅行寄存を自分で使うときだけ発生し、Nearby Sync はローカルネットワーク上の近くの端末間で暗号化データを直接転送します。",
                translationNotice: "翻訳は公開リポジトリでコミュニティ管理されています。問題を見つけたら issue または pull request を送ってください。"
            )
        case .zhTW:
            return SettingsStrings(
                title: "設定",
                done: "完成",
                supportUs: "專案資源",
                changeIcon: "免費圖示",
                repositoryLinkTitle: "專案倉庫",
                hardwareCompatibilityTitle: "硬體相容說明",
                documentationTitle: "專案文件",
                issueTrackerTitle: "問題回報",
                contactEmail: "聯絡信箱",
                contactEmailTapHint: "可點擊信箱地址複製",
                contactEmailCopied: "已複製",
                contactEmailTip: "這份開源快照保留的是示例信箱；在正式發布前，請改成你的公開維護聯絡方式。",
                footerPrivacy: "核心令牌功能預設在本地運行；只有你主動使用旅行寄存時才會使用網際網路，而附近同步只會在區域網路內於鄰近裝置間直接傳輸加密資料。",
                translationNotice: "翻譯由公開倉庫中的社群共同維護；若你發現問題，歡迎提交 issue 或 pull request。"
            )
        case .zhCN:
            return SettingsStrings(
                title: "设置",
                done: "完成",
                supportUs: "项目资源",
                changeIcon: "免费图标",
                repositoryLinkTitle: "项目仓库",
                hardwareCompatibilityTitle: "硬件兼容说明",
                documentationTitle: "项目文档",
                issueTrackerTitle: "问题反馈",
                contactEmail: "联系邮箱",
                contactEmailTapHint: "可点击邮箱地址复制",
                contactEmailCopied: "已复制",
                contactEmailTip: "这份开源快照保留的是示例邮箱；在正式发布前，请替换成你自己的公开维护地址。",
                footerPrivacy: "核心令牌功能默认在本地运行；只有您主动使用旅行寄存时才会使用互联网，而附近同步只会在局域网内于邻近设备间直接传输加密数据。",
                translationNotice: "翻译由公开仓库中的社区共同维护；如果你发现问题，欢迎提交 issue 或 pull request。"
            )
        }
    }
}

// Additional copy used inside support pages / 页面内其他文案
struct SupportPageStrings {
    let title: String
    let subtitle: String
    let freeTitle: String
    let freeDescription: String
    let localTitle: String
    let localDescription: String
    let projectsTitle: String
    let projectsDescription: String
    let footer: String
    
    static func get(for lang: AppLanguage) -> SupportPageStrings {
        switch lang {
        case .en:
            return SupportPageStrings(
                title: "Open Source Notes",
                subtitle: "This public snapshot removes private storefronts, hosted endpoints, and maintainer contact details in favor of safe placeholders.",
                freeTitle: "PUBLIC SNAPSHOT",
                freeDescription: "Core token flows, hardware-key paths, and app icons are included in the repository. Nothing depends on a private unlock path.",
                localTitle: "LOCAL FIRST",
                localDescription: "Tokens, PIN data, and key material stay on device during normal use. Travel Vault only reaches the network when you intentionally use a configured endpoint.",
                projectsTitle: "PLACEHOLDERS",
                projectsDescription: "Repository links, hardware compatibility docs, contact email, and Travel Vault URLs are intentionally examples in this snapshot.",
                footer: "Replace the placeholders in OpenSourceProjectInfo.swift before publishing your own fork."
            )
        case .es:
            return SupportPageStrings(
                title: "Notas de codigo abierto",
                subtitle: "Esta instantanea publica elimina escaparates privados, endpoints alojados y datos de contacto del mantenedor a favor de placeholders seguros.",
                freeTitle: "INSTANTANEA PUBLICA",
                freeDescription: "Los flujos principales de tokens, las rutas de llaves fisicas y los iconos de la app estan incluidos en el repositorio.",
                localTitle: "PRIMERO LOCAL",
                localDescription: "Los tokens, los PIN y el material criptografico permanecen en el dispositivo durante el uso normal. Travel Vault solo usa la red cuando configuras y utilizas tu propio endpoint.",
                projectsTitle: "PLACEHOLDERS",
                projectsDescription: "Los enlaces del repositorio, la documentacion de compatibilidad, el correo de contacto y las URL de Travel Vault son ejemplos intencionales en esta instantanea.",
                footer: "Sustituye los placeholders de OpenSourceProjectInfo.swift antes de publicar tu propio fork."
            )
        case .ja:
            return SupportPageStrings(
                title: "オープンソース補足",
                subtitle: "この公開版では、私有の販売導線、ホスト済みエンドポイント、運用連絡先を安全なプレースホルダーへ置き換えています。",
                freeTitle: "公開スナップショット",
                freeDescription: "主要なトークン機能、ハードウェアキー経路、アプリアイコンはリポジトリに含まれています。",
                localTitle: "ローカル優先",
                localDescription: "通常利用ではトークン、PIN、鍵素材は端末内に保持されます。Travel Vault は、自分で設定したエンドポイントを使うときだけ通信します。",
                projectsTitle: "プレースホルダー",
                projectsDescription: "リポジトリ URL、互換情報、連絡先メール、Travel Vault の URL は、この公開版では意図的に例示値になっています。",
                footer: "自分の fork を公開する前に OpenSourceProjectInfo.swift のプレースホルダーを置き換えてください。"
            )
        case .zhTW:
            return SupportPageStrings(
                title: "開源補充",
                subtitle: "這份公開快照已把私有商店入口、線上端點與維護聯絡方式替換成安全的示例值。",
                freeTitle: "公開快照",
                freeDescription: "核心令牌流程、硬體金鑰路徑與 App 圖示都已包含在倉庫中，不依賴私有解鎖。",
                localTitle: "本地優先",
                localDescription: "日常使用時，令牌、PIN 與密鑰資料皆保留在裝置內；只有你主動使用已配置的 Travel Vault 端點時才會連網。",
                projectsTitle: "示例值",
                projectsDescription: "倉庫連結、硬體相容文件、聯絡信箱與 Travel Vault URL 在這份快照中都刻意保留為示例。",
                footer: "公開你自己的 fork 前，請先替換 OpenSourceProjectInfo.swift 中的示例值。"
            )
        case .zhCN:
            return SupportPageStrings(
                title: "开源补充",
                subtitle: "这份公开快照已经把私有商店入口、线上端点与维护联系方式替换成安全的示例值。",
                freeTitle: "公开快照",
                freeDescription: "核心令牌流程、硬件密钥路径与 App 图标都已经包含在仓库中，不依赖私有解锁。",
                localTitle: "本地优先",
                localDescription: "日常令牌、PIN 与密钥材料默认保留在本机；只有您主动使用已配置的 Travel Vault 端点时才会联网。",
                projectsTitle: "示例值",
                projectsDescription: "仓库链接、硬件兼容文档、联系邮箱与 Travel Vault URL 在这份快照里都刻意保留为示例。",
                footer: "在发布你自己的 fork 之前，请先替换 OpenSourceProjectInfo.swift 里的示例值。"
            )
        }
    }
}

struct SupportResourceItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let buttonTitle: String
    let systemImage: String
    let accent: Color
    let urlString: String

    static func resources(for lang: AppLanguage) -> [SupportResourceItem] {
        switch lang {
        case .en:
            return [
                SupportResourceItem(title: "Repository", subtitle: "Public source, README, and release notes.", buttonTitle: "Open", systemImage: "chevron.left.forwardslash.chevron.right", accent: .cyan, urlString: OpenSourceProjectInfo.repositoryURLString),
                SupportResourceItem(title: "Documentation", subtitle: "Setup notes, architecture overview, and export details.", buttonTitle: "Read", systemImage: "book.pages.fill", accent: .green, urlString: OpenSourceProjectInfo.documentationURLString),
                SupportResourceItem(title: "Issue Tracker", subtitle: "Report bugs, translation fixes, and hardware compatibility findings.", buttonTitle: "View", systemImage: "bubble.left.and.exclamationmark.bubble.right.fill", accent: .orange, urlString: OpenSourceProjectInfo.issueTrackerURLString)
            ]
        case .es:
            return [
                SupportResourceItem(title: "Repositorio", subtitle: "Codigo publico, README y notas de lanzamiento.", buttonTitle: "Abrir", systemImage: "chevron.left.forwardslash.chevron.right", accent: .cyan, urlString: OpenSourceProjectInfo.repositoryURLString),
                SupportResourceItem(title: "Documentacion", subtitle: "Notas de configuracion, arquitectura y exportacion.", buttonTitle: "Leer", systemImage: "book.pages.fill", accent: .green, urlString: OpenSourceProjectInfo.documentationURLString),
                SupportResourceItem(title: "Issue Tracker", subtitle: "Reporta errores, correcciones de traduccion y compatibilidad de hardware.", buttonTitle: "Ver", systemImage: "bubble.left.and.exclamationmark.bubble.right.fill", accent: .orange, urlString: OpenSourceProjectInfo.issueTrackerURLString)
            ]
        case .ja:
            return [
                SupportResourceItem(title: "リポジトリ", subtitle: "公開ソース、README、リリースノート。", buttonTitle: "開く", systemImage: "chevron.left.forwardslash.chevron.right", accent: .cyan, urlString: OpenSourceProjectInfo.repositoryURLString),
                SupportResourceItem(title: "ドキュメント", subtitle: "セットアップ手順、構成概要、エクスポート説明。", buttonTitle: "読む", systemImage: "book.pages.fill", accent: .green, urlString: OpenSourceProjectInfo.documentationURLString),
                SupportResourceItem(title: "Issue Tracker", subtitle: "バグ、翻訳修正、ハードウェア互換情報を報告。", buttonTitle: "表示", systemImage: "bubble.left.and.exclamationmark.bubble.right.fill", accent: .orange, urlString: OpenSourceProjectInfo.issueTrackerURLString)
            ]
        case .zhTW:
            return [
                SupportResourceItem(title: "專案倉庫", subtitle: "公開原始碼、README 與發佈說明。", buttonTitle: "開啟", systemImage: "chevron.left.forwardslash.chevron.right", accent: .cyan, urlString: OpenSourceProjectInfo.repositoryURLString),
                SupportResourceItem(title: "專案文件", subtitle: "設定步驟、架構概覽與匯出說明。", buttonTitle: "閱讀", systemImage: "book.pages.fill", accent: .green, urlString: OpenSourceProjectInfo.documentationURLString),
                SupportResourceItem(title: "問題回報", subtitle: "提交 bug、翻譯修正與硬體相容回饋。", buttonTitle: "查看", systemImage: "bubble.left.and.exclamationmark.bubble.right.fill", accent: .orange, urlString: OpenSourceProjectInfo.issueTrackerURLString)
            ]
        case .zhCN:
            return [
                SupportResourceItem(title: "项目仓库", subtitle: "公开源码、README 与发布说明。", buttonTitle: "打开", systemImage: "chevron.left.forwardslash.chevron.right", accent: .cyan, urlString: OpenSourceProjectInfo.repositoryURLString),
                SupportResourceItem(title: "项目文档", subtitle: "配置步骤、架构概览与导出说明。", buttonTitle: "阅读", systemImage: "book.pages.fill", accent: .green, urlString: OpenSourceProjectInfo.documentationURLString),
                SupportResourceItem(title: "问题反馈", subtitle: "提交 bug、翻译修正与硬件兼容反馈。", buttonTitle: "查看", systemImage: "bubble.left.and.exclamationmark.bubble.right.fill", accent: .orange, urlString: OpenSourceProjectInfo.issueTrackerURLString)
            ]
        }
    }
}

// Copy for the app-icon selection page / 图标选择页文案
struct IconPageStrings {
    let title: String
    let defaultSection: String
    let premiumSection: String
    let notSupported: String
    let failed: String
    
    static func get(for lang: AppLanguage) -> IconPageStrings {
        switch lang {
        case .en:
            return IconPageStrings(
                title: "App Icon",
                defaultSection: "Default",
                premiumSection: "More Styles",
                notSupported: "This device does not support icon switching",
                failed: "Failed to change icon. Please wait and try again."
            )
        case .es:
            return IconPageStrings(
                title: "Icono de la app",
                defaultSection: "Predeterminado",
                premiumSection: "Más estilos",
                notSupported: "Este dispositivo no admite el cambio de icono",
                failed: "No se pudo cambiar el icono. Espera un momento e inténtalo de nuevo."
            )
        case .ja:
            return IconPageStrings(
                title: "アプリアイコン",
                defaultSection: "デフォルト",
                premiumSection: "追加スタイル",
                notSupported: "このデバイスはアイコン変更に対応していません",
                failed: "アイコン変更に失敗しました。少し待って再試行してください。"
            )
        case .zhTW:
            return IconPageStrings(
                title: "App 圖示",
                defaultSection: "預設",
                premiumSection: "更多樣式",
                notSupported: "此裝置不支援更換圖示",
                failed: "更換圖示失敗，請稍候再試。"
            )
        case .zhCN:
            return IconPageStrings(
                title: "App 图标",
                defaultSection: "默认",
                premiumSection: "更多样式",
                notSupported: "此设备不支持更换图标",
                failed: "更换图标失败，请稍后重试。"
            )
        }
    }
}
