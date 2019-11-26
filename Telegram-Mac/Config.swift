private let api_id:Int32=9
private let api_hash:String="3975f648bb682ee889f35483bc618d1c"

final class ApiEnvironment {
    static var apiId:Int32 {
        return api_id
    }
    static var apiHash:String {
        return api_hash
    }
    static var appData: Data {
        let apiData = evaluateApiHash() ?? ""
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        let dict:[String: String] = ["bundleId":bundleId, "data":apiData]
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



