final class ApiEnvironment {
    static var apiId:Int32 {
        return 904055
    }
    static var apiHash:String {
        return "870b467d56944d5347e0f8d4efa93028"
    }
    
    static var bundleId: String {
        return "com.circlescollective.circlesfortelegram"
    }
    static var teamId: String {
        return "WDEGJM2L33"
    }
    
    static var group: String {
        return teamId + "." + bundleId
    }
    
    static var appData: Data {
        let apiData = evaluateApiData() ?? ""
        let dict:[String: String] = ["bundleId": bundleId, "data": apiData]
        return try! JSONSerialization.data(withJSONObject: dict, options: [])
    }
    static var language: String {
        return "macos"
    }
    static var version: String {
        var suffix: String = ""
        #if STABLE
            suffix = "STABLE"
        #elseif APP_STORE
            suffix = "APPSTORE"
        #elseif ALPHA
            suffix = "ALPHA"
        #elseif GITHUB
            suffix = "GITHUB"
        #else
            suffix = "BETA"
        #endif
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? ""
        return "\(shortVersion) \(suffix)"
    }
}



