final class ApiEnvironment {
    static var apiId:Int32 {
        return 1041243
    }
    static var apiHash:String {
        return "a22e951ebb6655d6d80ff04ada0306de"
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



