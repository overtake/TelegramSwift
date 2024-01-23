import AppKit
import TGUIKit


final class Dock {
    
}
let kFinderInfo = "com.apple.FinderInfo"
let kResourceFork = "com.apple.ResourceFork"
let kFinderInfoMinSize = 16
let kFinderInfoSize = 32
let kFinderInfoMaxSize = 256
let kResourceForkMaxSize = 10 * 1024 * 1024  // 10 MB

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

func readCustomIconAttribute(bundle: String) -> Data {
    do {
        let data = try XAttr.get(named: kFinderInfo, atPath: bundle)
        return data
    } catch {
        return Data()
    }
}

func writeCustomIconAttribute(bundle: String, value: Data) -> Bool {
    do {
        try XAttr.set(named: kFinderInfo, data: value, atPath: bundle)
        return true
    } catch {
        logError("Failed to write custom icon attribute: \(error)")
        return false
    }
}

func enableCustomIcon(bundle: String) -> Bool {
    var info = readCustomIconAttribute(bundle: bundle)
    
    if info.isEmpty {
        info = Data(repeating: 0, count: kFinderInfoSize)
    }
    info[8] |= 4
    return writeCustomIconAttribute(bundle: bundle, value: info)
}

func disableCustomIcon(bundle: String) -> Bool {
    let info = readCustomIconAttribute(bundle: bundle)
    guard !info.isEmpty else {
        return true
    }
    return writeCustomIconAttribute(bundle: bundle, value: Data())
}

// Refresh Dock
func refreshDock() -> Bool {
    let _ = launch(command: "/bin/bash", arguments: ["-c", "rm /var/folders/*/*/*/com.apple.dock.iconcache"])
    let killallResult = launch(command: "/usr/bin/killall", arguments: ["Dock"])
    
    if killallResult != 0 {
        logError("Failed to run `killall Dock`, result: \(killallResult)")
        return false
    }
    return true
}

// Temp path for icons
func tempPath(ext: String) -> String {
    let tempDir = NSTemporaryDirectory()
    let tempFileTemplate = tempDir.appending("custom_icon_XXXXXX.\(ext)")
    
    return tempFileTemplate
}



func readResourceFork(path: String) -> Data? {
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

func writeResourceFork(path: String, data: Data) -> Bool {
    do {
        try XAttr.set(named: kResourceFork, data: data, atPath: path)
    } catch {
        return false
    }
    return true
}

func digest(_ str: Data) -> UInt64 {
    return UInt64(bitPattern: Int64(str.hashValue))
}

func setPreparedIcon(path: String) -> UInt64? {
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

    return refreshDock() ? digest(rsrc) : nil
}

func setCustomAppIcon(image: NSImage) -> UInt64? {
   
    let tempPath = tempPath(ext: "tiff")
   
    defer { try? FileManager.default.removeItem(atPath: tempPath) }

    guard let pngData = image.tiffRepresentation else {
        print("Icon Error: Failed to convert image to PNG.")
        return nil
    }

    do {
        try pngData.write(to: URL(fileURLWithPath: tempPath))
        return setPreparedIcon(path: tempPath)
    } catch {
        print("Icon Error: Failed to save image to \"\(tempPath)\": \(error)")
        return nil
    }
}

public func setCustomAppIcon(fromPath path: String) -> UInt64? {
    let icns = path.lowercased().hasSuffix(".icns")
    if !icns {
        // Handle loading and processing the image
        // ...
        if let image = NSImage(contentsOfFile: path) {
            return setCustomAppIcon(image: image)
        } else {
            return nil
        }
    }

    let temp = tempPath(ext: "icns")
    guard !temp.isEmpty else {
        return nil
    }

    defer {
        try? FileManager.default.removeItem(atPath: temp)
    }

    do {
        try FileManager.default.copyItem(atPath: path, toPath: temp)
        return setPreparedIcon(path: temp)
    } catch {
        print("Icon Error: Failed to copy icon from \"\(path)\" to \"\(temp)\"")
        return nil
    }
}
