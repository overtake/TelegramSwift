final class ApiEnvironment {
    static var apiId:Int32 {
        return 9
    }
    static var apiHash:String {
        return "3975f648bb682ee889f35483bc618d1c"
    }
    
    static var bundleId: String {
        return "ru.keepcoder.Telegram"
    }
    static var teamId: String {
        return "6N38VWS5BX"
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



