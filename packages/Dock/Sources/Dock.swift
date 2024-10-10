import AppKit
import TGUIKit
import CommonCrypto

let kFinderInfo = "com.apple.FinderInfo"
let kResourceFork = "com.apple.ResourceFork"
let kFinderInfoMinSize = 16
let kFinderInfoSize = 32
let kFinderInfoMaxSize = 256
let kResourceForkMaxSize = 10 * 1024 * 1024  // 10 MB


private extension Data {
    func sha256() -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        self.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(self.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}


func logError(_ message: String) {
    print("Error: \(message)")
}

func bundlePath() -> String {
    return Bundle.main.bundlePath
}

func launch(command: String, arguments: [String]) -> Int {
    let task = Process()
    task.launchPath = command
    task.arguments = arguments

    task.launch()
    task.waitUntilExit()

    return Int(task.terminationStatus)
}

public class Dock {
    
    static func readCustomIconAttribute(bundle: String) -> Data {
        do {
            let data = try XAttr.get(named: kFinderInfo, atPath: bundle)
            return data
        } catch {
            return Data()
        }
    }

    static func writeCustomIconAttribute(bundle: String, value: Data) -> Bool {
        do {
            try XAttr.set(named: kFinderInfo, data: value, atPath: bundle)
            return true
        } catch {
            logError("Failed to write custom icon attribute: \(error)")
            return false
        }
    }

    static func enableCustomIcon(bundle: String) -> Bool {
        var info = readCustomIconAttribute(bundle: bundle)
        
        if info.isEmpty {
            info = Data(repeating: 0, count: kFinderInfoSize)
        }
        info[8] |= 4
        return writeCustomIconAttribute(bundle: bundle, value: info)
    }

    static func disableCustomIcon(bundle: String) -> Bool {
        let info = readCustomIconAttribute(bundle: bundle)
        guard !info.isEmpty else {
            return true
        }
        return writeCustomIconAttribute(bundle: bundle, value: Data())
    }

    // Refresh Dock
    static func refreshDock(silence: Bool) -> Bool {
        let _ = launch(command: "/bin/bash", arguments: ["-c", "rm /var/folders/*/*/*/com.apple.dock.iconcache"])
        
        if !silence {
            let killallResult = launch(command: "/usr/bin/killall", arguments: ["Dock"])
            if killallResult != 0 {
                logError("Failed to run `killall Dock`, result: \(killallResult)")
                return false
            }
        }
        return true
    }

    static func tempPath(ext: String) -> String {
        let tempDir = NSTemporaryDirectory()
        let tempFileTemplate = tempDir.appending("custom_icon_XXXXXX.\(ext)")
        
        return tempFileTemplate
    }

    static func readResourceFork(path: String) -> Data? {
        let result = try? XAttr.get(named: kResourceFork, atPath: path)

        if let result = result {
            if result.count > kResourceForkMaxSize {
                print("Icon Error: Got too large \(kResourceFork) xattr, size: \(result)")
                return nil
            } else {
                return result
            }
        }
        return nil
    }

    static func writeResourceFork(path: String, data: Data) -> Bool {
        do {
            try XAttr.set(named: kResourceFork, data: data, atPath: path)
        } catch {
            return false
        }
        return true
    }

    public static func digest(_ data: Data) -> String {
        return data.sha256()
    }

    static func setPreparedIcon(path: String, silence: Bool) -> String? {
        let sipsResult = launch(command: "/usr/bin/sips", arguments: ["-i", path])
        if sipsResult != 0 {
            print("Icon Error: Failed to run `sips -i \"\(path)\"`, result: \(sipsResult)")
            return nil
        }

        let bundle = bundlePath()
        let icon = bundle + "/Icon\r"
        let touchResult = launch(command: "/usr/bin/touch", arguments: [icon])
        if touchResult != 0 {
            print("Icon Error: Failed to run `touch \"\(icon)\"`, result: \(touchResult)")
            return nil
        }

        guard let rsrc = readResourceFork(path: path) else {
            return nil
        }

        if rsrc.isEmpty {
            print("Icon Error: Empty resource fork after sips in \"\(path)\"")
            return nil
        }

        if !writeResourceFork(path: icon, data: rsrc) || !enableCustomIcon(bundle: bundle) {
            return nil
        }
        
        return refreshDock(silence: silence) ? digest(rsrc) : nil
    }

    
    @discardableResult static func clearCustomAppIcon(silence: Bool) -> Bool {
        let bundle = bundlePath();
        let icon = bundle + "/Icon\r";
        try? FileManager.default.removeItem(atPath: icon)
        try? XAttr.remove(named: kFinderInfo, atPath: bundle)
        return refreshDock(silence: silence);

    }


    @discardableResult public static func setCustomAppIcon(path: String?, silence: Bool = false) -> String? {
        let temp = tempPath(ext: "icns")
        guard !temp.isEmpty else {
            return nil
        }
        
        
        guard let path = path else {
            clearCustomAppIcon(silence: silence)
            NSApplication.shared.applicationIconImage = nil
            return nil
        }

        NSApplication.shared.applicationIconImage = NSImage(contentsOfFile: path)
        
        defer {
            try? FileManager.default.removeItem(atPath: temp)
        }

        do {
            try FileManager.default.copyItem(atPath: path, toPath: temp)
            return setPreparedIcon(path: temp, silence: silence)
        } catch {
            print("Icon Error: Failed to copy icon from \"\(path)\" to \"\(temp)\"")
            return nil
        }
    }
    
    public static func currentAppIconDigest() -> String? {
        let bundle = bundlePath()
        let icon = bundle + "/Icon\r";
        let attr = readCustomIconAttribute(bundle: bundle)
        if attr.isEmpty {
            return nil
        }
        let value = readResourceFork(path: icon)
        if let value = value {
            return digest(value)
        }
        return nil
    }

}
