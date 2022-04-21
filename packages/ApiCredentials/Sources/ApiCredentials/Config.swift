import Cocoa

public final class ApiEnvironment {
    public static var apiId:Int32 {
        return 9
    }
    public static var apiHash:String {
        return "3975f648bb682ee889f35483bc618d1c"
    }
    
    public static var bundleId: String {
        return "ru.keepcoder.Telegram"
    }
    public static var teamId: String {
        return "6N38VWS5BX"
    }
    
    public static var containerURL: URL? {
        let appGroupName = ApiEnvironment.group
        let containerUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)?.appendingPathComponent(prefix)
        if let containerUrl = containerUrl {
            try? FileManager.default.createDirectory(at: containerUrl, withIntermediateDirectories: true, attributes: nil)
            return containerUrl
        }
        return nil
    }
    
    public static func migrate() {
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
    
    public static var legacyContainerURL: URL? {
        let appGroupName = ApiEnvironment.group
        let containerUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)
        return containerUrl
    }
    
    public static var group: String {
        return teamId + "." + bundleId
    }
    
    public static var appData: Data {
        let apiData = evaluateApiData() ?? ""
        let dict:[String: String] = ["bundleId": bundleId, "data": apiData]
        return try! JSONSerialization.data(withJSONObject: dict, options: [])
    }
    public static var language: String {
        return "macos"
    }
    
    public static var prefixList:[String] {
        return ["debug", "stable", "appstore", "beta"]
    }
    
    public static var resolvedDeviceName:[String : String]? {
        if let file = Bundle.main.path(forResource: "mac_devices", ofType: "txt") {
            if let string = try? String(contentsOf: .init(fileURLWithPath: file)) {
                let lines = string.components(separatedBy: "\n\n")
                
                var result:[String : String] = [:]
                for line in lines {
                    let resolved = line.components(separatedBy: "\n")
                    if resolved.count == 2 {
                        result[resolved[1]] = resolved[0]
                    }
                }
                
                return result
            }
        }
        return nil
    }
    
    public static var prefix: String {
        var prefix: String = ""
        switch Configuration.value(for: .source) {
        case "DEBUG":
            prefix = "debug"
        case "STABLE":
            prefix = "stable"
        case "APP_STORE":
            prefix = "appstore"
        default:
            prefix = "beta"
        }
        return prefix
    }
    
    public static var version: String {
        var suffix: String = ""
        
        suffix = Configuration.value(for: .source) ?? "DEBUG"
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? ""
        return "\(shortVersion) \(suffix)"
    }
}



