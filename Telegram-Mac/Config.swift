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
    
    static var containerURL: URL? {
        let appGroupName = ApiEnvironment.group
        let containerUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)?.appendingPathComponent(prefix)
        if let containerUrl = containerUrl {
            try? FileManager.default.createDirectory(at: containerUrl, withIntermediateDirectories: true, attributes: nil)
            return containerUrl
        }
        return nil
    }
    
    static func migrate() {
        if let containerURL = containerURL, let legacy = legacyContainerURL, let sequence = FileManager.default.enumerator(atPath: legacy.path) {
            let contents = try? FileManager.default.contentsOfDirectory(at: containerURL, includingPropertiesForKeys: nil, options: [])
            if let contents = contents, !contents.isEmpty {
                return
            }
            for value in sequence {
                if let value = value as? String {
                    if !prefixList.contains(value) {
                        try? FileManager.default.moveItem(at: legacy.appendingPathComponent(value), to: containerURL.appendingPathComponent(value))
                    }
                }
            }
        }
    }
    
    static var legacyContainerURL: URL? {
        let appGroupName = ApiEnvironment.group
        let containerUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)
        return containerUrl
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
    
    static var prefixList:[String] {
        return ["debug", "stable", "appstore", "beta"]
    }
    
    static var prefix: String {
        var prefix: String = ""
        #if DEBUG
        prefix = "debug"
        #elseif STABLE
        prefix = "stable"
        #elseif APP_STORE
        prefix = "appstore"
        #else
        prefix = "beta"
        #endif
        return prefix
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



