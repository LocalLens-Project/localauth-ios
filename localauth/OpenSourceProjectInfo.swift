import Foundation

enum OpenSourceProjectInfo {
    // Replace these placeholders before publishing your own public fork.
    static let publicAppIdentifier = "com.example.localauth"
    static let supportEmail = "opensource@example.com"
    static let contributorsLabel = "LocalAuth Contributors"

    static let repositoryURLString = "https://github.com/example/localauth-ios"
    static let documentationURLString = "https://github.com/example/localauth-ios#readme"
    static let hardwareKeyCompatibilityURLString = "https://github.com/example/localauth-ios#hardware-key-compatibility"
    static let issueTrackerURLString = "https://github.com/example/localauth-ios/issues"
    static let projectStoryURLString = "https://github.com/example/localauth-ios#project-story"

    static let travelVaultBaseURLString = ""
    static let travelVaultDeviceAttestBaseURLString = ""

    private static var currentLanguage: AppLanguage {
        AppLanguage.current
    }

    static var travelVaultDeploymentNotice: String {
        switch currentLanguage {
        case .en:
            return "This open-source snapshot does not ship with a hosted Travel Vault service. Deploy and configure your own endpoint before using it."
        case .es:
            return "Esta instantanea de codigo abierto no incluye un servicio Travel Vault alojado. Despliega y configura tu propio endpoint antes de usarlo."
        case .ja:
            return "このオープンソース版にはホスト済みの Travel Vault サービスは含まれていません。使用する前に、自分のエンドポイントをデプロイして設定してください。"
        case .zhTW:
            return "這份開源快照預設不附帶線上 Travel Vault 服務；如需使用，請先自行部署並完成設定。"
        case .zhCN:
            return "开源仓库默认不附带线上 Travel Vault 服务；如需使用，请先自行部署并完成配置。"
        }
    }

    static var travelVaultRemoteNotConfiguredMessage: String {
        switch currentLanguage {
        case .en:
            return "Travel Vault is not configured in this open-source snapshot. Fill in your own service URLs before using it."
        case .es:
            return "Travel Vault no esta configurado en esta instantanea de codigo abierto. Completa tus propias URL del servicio antes de usarlo."
        case .ja:
            return "このオープンソース版では Travel Vault がまだ設定されていません。使用する前に、自分のサービス URL を入力してください。"
        case .zhTW:
            return "這份開源快照尚未配置 Travel Vault；請先填入你自己的服務 URL。"
        case .zhCN:
            return "当前开源快照尚未配置 Travel Vault；请先填入你自己的服务 URL。"
        }
    }

    static var travelVaultDeviceAttestationMessage: String {
        switch currentLanguage {
        case .en:
            return "Travel Vault device attestation failed. Check your App Attest setup, bundle identifier, and remote verifier."
        case .es:
            return "La atestacion del dispositivo para Travel Vault fallo. Revisa la configuracion de App Attest, el identificador del paquete y el verificador remoto."
        case .ja:
            return "Travel Vault のデバイス証明に失敗しました。App Attest の設定、Bundle Identifier、リモート検証サービスを確認してください。"
        case .zhTW:
            return "Travel Vault 的裝置證明失敗。請檢查 App Attest 設定、Bundle Identifier 與遠端驗證服務。"
        case .zhCN:
            return "Travel Vault 的设备证明失败。请检查 App Attest 配置、Bundle Identifier 与远端验证服务。"
        }
    }

    static var travelVaultAccessBlockedMessage: String {
        switch currentLanguage {
        case .en:
            return "The current network is blocking requests to your Travel Vault endpoint. Try another network or your own deployment domain."
        case .es:
            return "La red actual esta bloqueando las solicitudes a tu endpoint de Travel Vault. Prueba otra red o tu propio dominio desplegado."
        case .ja:
            return "現在のネットワークが Travel Vault エンドポイントへのリクエストをブロックしています。別のネットワークか、自分でデプロイしたドメインを試してください。"
        case .zhTW:
            return "目前網路正在攔截你配置的 Travel Vault 端點。請改用其他網路，或檢查自建部署網域。"
        case .zhCN:
            return "当前网络正在拦截你配置的 Travel Vault 端点。请改用其他网络，或检查自建部署域名。"
        }
    }
}
