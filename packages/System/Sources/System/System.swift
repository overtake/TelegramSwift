import Foundation


func deviceFromSystemProfiler() -> String? {
    // Starting with MacBook M2 the hw.model returns simply Mac[digits],[digits].
    // So we try reading "system_profiler" output.
    let process = Process()
    if #available(macOS 10.13, *) {
        process.launchPath = "/usr/bin/log"
    } else {
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
    }
    process.arguments = ["-json", "SPHardwareDataType", "-detailLevel", "mini"]
    let pipe = Pipe()
    process.standardOutput = pipe
    do {
        try process.run()
    } catch {
        return nil
    }
    process.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let document = try? JSONSerialization.jsonObject(with: data, options: [])
    guard let fields = (document as? [String: Any])?["SPHardwareDataType"] as? [[String: Any]], !fields.isEmpty else {
        return nil
    }
    let result = fields[0]["machine_name"] as? String ?? ""
    guard !result.isEmpty else {
        return nil
    }
    let chip = fields[0]["chip_type"] as? String ?? ""
    return chip.hasPrefix("Apple ") ? (result + chip.dropFirst(5)) : result
}

public func deviceModelPretty() -> String {
    if let fromSystemProfiler = deviceFromSystemProfiler(), !fromSystemProfiler.isEmpty {
        return fromSystemProfiler
    }
    var length = 0
    sysctlbyname("hw.model", nil, &length, nil, 0)
    if length > 0 {
        var bytes = [CChar](repeating: 0, count: length)
        sysctlbyname("hw.model", &bytes, &length, nil, 0)
        if let parsed = fromIdentifier(model: String(cString: bytes)), !parsed.isEmpty {
            return parsed
        }
    }
    return ""
}


func fromIdentifier(model: String) -> String? {
    guard !model.isEmpty, model.lowercased().contains("mac") else {
        return nil
    }
    
    var words = [String]()
    var word = ""
    for ch in model {
        if !ch.isLetter {
            continue
        }
        if ch.isUppercase {
            if !word.isEmpty {
                words.append(word)
                word = ""
            }
        }
        word.append(ch)
    }
    if !word.isEmpty {
        words.append(word)
    }
    
    var result = ""
    for word in words {
        if !result.isEmpty && word != "Mac" && word != "Book" {
            result.append(" ")
        }
        result.append(word)
    }
    
    return result
}
