//
//  BufferCompressor.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 19/06/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import Compression
import Accelerate
import Postbox
import SwiftSignalKit
import TGUIKit
import ApiCredentials

private let enableDifference = false

private let maxFrameBufferSizeCache = 7200

private enum WriteResult {
    case success
    case failed
}
private enum ReadResult {
    case success(Data)
    case cached(Data, ()->Void)
    case failed
}

private var sharedData:Atomic<[LottieAnimationEntryKey:WeakReference<TRLotData>]> = Atomic(value: [:])

private struct FrameDst : Codable {
    let offset: Int
    let length: Int
    let finished: Bool
    init(offset: Int, length: Int, finished: Bool) {
        self.offset = offset
        self.length = length
        self.finished = finished
    }
}
private struct DstData : Codable {
    var dest: [Int : FrameDst]
    var fps: Int32
    var startFrame: Int32
    var endFrame: Int32
}


private let version = 67

final class TRLotData {
    
    
    fileprivate var map:DstData
    fileprivate let bufferSize: Int
    
    private let mapPath: String
    private let dataPath: String
    var isFinished: Bool = false {
        didSet {
            assert(queue.isCurrent())
            let cpy = map
            for (key, value) in cpy.dest {
                map.dest[key] = .init(offset: value.offset, length: value.length, finished: isFinished)
            }
        }
    }
    
    private var readHandle: FileHandle?
    private var writeHandle: FileHandle?
    private let key: LottieAnimationEntryKey
    fileprivate let queue: Queue
    
    fileprivate func hasAlreadyFrame(_ frame: Int) -> Bool {
        assert(queue.isCurrent())
        return map.dest[frame] != nil
    }
    fileprivate func readFrame(frame: Int) -> ReadResult {
        
        self.writeHandle?.closeFile()
        self.writeHandle = nil
        assert(queue.isCurrent())
        
        if !isFinished {
            return .failed
        }
        
        if let dest = map.dest[frame] {
            let readHande: FileHandle?
            if let handle = self.readHandle {
                readHande = handle
            } else {
                readHande = FileHandle(forReadingAtPath: self.dataPath)
                self.readHandle = readHande
            }
            
            guard let dataHandle = readHande else {
                self.map.dest.removeAll()
                return .failed
            }
            
            dataHandle.seek(toFileOffset: UInt64(dest.offset))
            let data = dataHandle.readData(ofLength: dest.length)
            if data.count == dest.length {
                return .success(data)
            } else {
                self.map.dest.removeValue(forKey: frame)
                return .failed
            }
        }
        
        return .failed
    }
    
    deinit {
        queue.sync {
            self.readHandle?.closeFile()
            self.writeHandle?.closeFile()
            let data = try? PropertyListEncoder().encode(self.map)
            if let data = data {
                _ = NSKeyedArchiver.archiveRootObject(data, toFile: self.mapPath)
            }
        }
        _ = sharedData.modify { value in
            var value = value
            value.removeValue(forKey: self.key)
            return value
        }
    }
    
    fileprivate func writeFrame(frame: Int, data:Data) -> WriteResult {
        self.readHandle?.closeFile()
        self.readHandle = nil
        assert(queue.isCurrent())
        if map.dest[frame] == nil {
            let writeHandle: FileHandle?
            if let handle = self.writeHandle {
                writeHandle = handle
            } else {
                writeHandle = FileHandle(forWritingAtPath: self.dataPath)
                self.writeHandle = writeHandle
            }
            
            guard let dataHandle = writeHandle else {
                return .failed
            }
            let length = dataHandle.seekToEndOfFile()
            dataHandle.write(data)
            var frames = self.map.dest
            frames[frame] = FrameDst(offset: Int(length), length: data.count, finished: isFinished)
            self.map = DstData(dest: frames, fps: self.map.fps, startFrame: self.map.startFrame, endFrame: self.map.endFrame)
        }

        return .success
    }
    
    
    fileprivate static var directory: String {
        let groupPath = ApiEnvironment.containerURL!.path
        
        let path = groupPath + "/trlottie-animations/"
        try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        return path
    }
    
    
    static func mapPath(_ animation: LottieAnimation, bufferSize: Int) -> String {

        let path = TRLotData.directory + animation.cacheKey
        
        return path + "-v\(version)-lzfse-bs\(bufferSize)-lt\(animation.liveTime)-map"
    }
    
    static func dataPath(_ animation: LottieAnimation, bufferSize: Int) -> String {
        let path = TRLotData.directory + animation.cacheKey
        
        return path + "-v\(version)-lzfse-bs\(bufferSize)-lt\(animation.liveTime)-data"
    }
    
    init(_ animation: LottieAnimation, bufferSize: Int, queue: Queue) {
        self.queue = queue
        self.mapPath = TRLotData.mapPath(animation, bufferSize: bufferSize)
        self.dataPath = TRLotData.dataPath(animation, bufferSize: bufferSize)
        self.key = animation.key
        var mapHandle:FileHandle?
        
        
        let deferr:(TRLotData)->Void = { data in
            if !FileManager.default.fileExists(atPath: data.mapPath) {
                FileManager.default.createFile(atPath: data.mapPath, contents: nil, attributes: nil)
            }
            if !FileManager.default.fileExists(atPath: data.dataPath) {
                FileManager.default.createFile(atPath: data.dataPath, contents: nil, attributes: nil)
            }
            try? FileManager.default.setAttributes([.modificationDate : Date()], ofItemAtPath: data.mapPath)
            try? FileManager.default.setAttributes([.modificationDate : Date()], ofItemAtPath: data.dataPath)
            _ = sharedData.modify { value in
                var value = value
                value[data.key] = WeakReference(value: data)
                return value
            }

            mapHandle?.closeFile()
        }
        
        guard let handle = FileHandle(forReadingAtPath: self.mapPath) else {
            self.map = .init(dest: [:], fps: 0, startFrame: 0, endFrame: 0)
            self.bufferSize = bufferSize
            deferr(self)
            return
        }
        mapHandle = handle
        
        guard let data = NSKeyedUnarchiver.unarchiveObject(withFile: self.mapPath) as? Data else {
            self.map = .init(dest: [:], fps: 0, startFrame: 0, endFrame: 0)
            self.bufferSize = bufferSize
            deferr(self)
            return
        }
        do {
            self.map = try PropertyListDecoder().decode(DstData.self, from: data)
            self.bufferSize = bufferSize
            deferr(self)
        } catch {
            self.map = .init(dest: [:], fps: 0, startFrame: 0, endFrame: 0)
            self.bufferSize = bufferSize
            deferr(self)
        }
        if !self.map.dest.isEmpty {
            self.isFinished = self.map.dest.filter { $0.value.finished }.count == self.map.dest.count
        } else {
            self.isFinished = false
        }
    }
    
    func initialize(fps: Int32, startFrame: Int32, endFrame: Int32) {
        self.map.fps = fps
        self.map.startFrame = startFrame
        self.map.endFrame = endFrame
    }
    
}

private let lzfseQueue = Queue(name: "LZFSE BUFFER Queue", qos: DispatchQoS.default)


final class TRLotFileSupplyment {
    fileprivate let bufferSize: Int
    fileprivate let data:TRLotData
    fileprivate let queue: Queue
    
    init(_ animation:LottieAnimation, bufferSize: Int, queue: Queue) {
        let cached = sharedData.with { $0[animation.key]?.value }
        let queue = cached?.queue ?? queue
        self.data = cached ?? TRLotData(animation, bufferSize: bufferSize, queue: queue)
        self.queue = queue
        self.bufferSize = bufferSize
    }
    
    func initialize(fps: Int32, startFrame: Int32, endFrame: Int32) {
        queue.sync {
            self.data.initialize(fps: fps, startFrame: startFrame, endFrame: endFrame)
        }

    }
    
    var fps: Int32 {
        var fps: Int32 = 0
        queue.sync {
            fps = self.data.map.fps
        }
        return fps
    }
    var endFrame: Int32 {
        var endFrame: Int32 = 0
        queue.sync {
            endFrame = self.data.map.endFrame
        }
        return endFrame
    }
    var startFrame: Int32 {
        var startFrame: Int32 = 0
        queue.sync {
            startFrame = self.data.map.startFrame
        }
        return startFrame
    }

    func markFinished() {
        queue.async {
            self.data.isFinished = true
        }
    }
    var isFinished: Bool {
        var isFinished: Bool = false
        queue.sync {
            isFinished = self.data.isFinished
        }
        return isFinished
    }
    

    
    func addFrame(_ previous: Data?, _ current: (Data, Int32)) {
        queue.async {
            
            if !self.data.hasAlreadyFrame(Int(current.1)) {
                current.0.withUnsafeBytes { pointer in
                    let address = pointer.baseAddress!.assumingMemoryBound(to: UInt8.self)
                    let ui64Address = pointer.baseAddress!.assumingMemoryBound(to: UInt64.self)
                    let dst: UnsafeMutablePointer<UInt8> = malloc(self.bufferSize)!.assumingMemoryBound(to: UInt8.self)
                    var length:Int = self.bufferSize
                    if let previous = previous, enableDifference {
                        let uint64Bs = self.bufferSize / 8
                        let dstDelta: UnsafeMutablePointer<UInt8> = malloc(self.bufferSize)!.assumingMemoryBound(to: UInt8.self)
                        
                        previous.withUnsafeBytes { pointer in
                            memcpy(dstDelta, pointer.baseAddress!.assumingMemoryBound(to: UInt8.self), self.bufferSize)
                            
                            let ui64Dst = dstDelta.withMemoryRebound(to: UInt64.self, capacity: uint64Bs, { previousBytes in
                                return previousBytes
                            })
                            
                            var i: Int = 0
                            while i < uint64Bs {
                                ui64Dst[i] = ui64Dst[i] ^ ui64Address[i]
                                i &+= 1
                            }
                            
                            let ui8 = ui64Dst.withMemoryRebound(to: UInt8.self, capacity: self.bufferSize, { body in
                                return body
                            })
                            
                            length = compression_encode_buffer(dst, self.bufferSize, ui8, self.bufferSize, nil, COMPRESSION_LZFSE)
                            dstDelta.deallocate()
                        }
                        
                        
                    } else {
                        length = compression_encode_buffer(dst, self.bufferSize, address, self.bufferSize, nil, COMPRESSION_LZFSE)
                    }
                    let _ = self.data.writeFrame(frame: Int(current.1), data: Data(bytes: dst, count: length))
                    dst.deallocate()
                }
            }
        }
    }


    func readFrame(previous: Data?, frame: Int) -> Data? {
        var rendered: Data? = nil
        queue.sync {
            
            if self.data.isFinished {
                switch self.data.readFrame(frame: frame) {
                case let .success(data):
                    let address = malloc(bufferSize)!.assumingMemoryBound(to: UInt8.self)
                    data.withUnsafeBytes { dataBytes in
                        let unsafeBufferPointer = dataBytes.bindMemory(to: UInt8.self)
                        let unsafePointer = unsafeBufferPointer.baseAddress!

                        let _ = compression_decode_buffer(address, bufferSize, unsafePointer, data.count, nil, COMPRESSION_LZFSE)

                        if let previous = previous, enableDifference {
                            previous.withUnsafeBytes { pointer in
                                let previousBytes = pointer.baseAddress!.assumingMemoryBound(to: UInt64.self)
                                let uint64Bs = self.bufferSize / 8
                                address.withMemoryRebound(to: UInt64.self, capacity: uint64Bs, { address in
                                    var i = 0
                                    while i < uint64Bs {
                                        address[i] = previousBytes[i] ^ address[i]
                                        i &+= 1
                                    }
                                })
                            }
                        }
                    }
                    rendered = Data(bytes: address, count: bufferSize)
                    address.deallocate()
                default:
                    rendered = nil
                }
            }
        }
        return rendered
    }
    
    
}




private final class CacheRemovable {
    init() {
       
    }
    
    fileprivate func start() {
        let signal = Signal<Void, NoError>.single(Void()) |> deliverOn(lzfseQueue) |> then (Signal<Void, NoError>.single(Void()) |> delay(30 * 60, queue: lzfseQueue) |> restart)
        
        
        _ = signal.start(next: {
            self.clean()
        })
    }
    
    private func clean() {
        
        let fileURLs = try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: TRLotData.directory), includingPropertiesForKeys: nil, options: .skipsHiddenFiles )
        if let fileURLs = fileURLs {
            for url in fileURLs {
                let path = url.path
                let name = path.nsstring.lastPathComponent
                if let index = name.range(of: "lt") {
                    let tail = String(name[index.upperBound...])
                    if let until = tail.range(of: "-") {
                        if let liveTime = TimeInterval(tail[..<until.lowerBound]) {
                            if let createdAt = FileManager.default.modificationDateForFileAtPath(path: path), createdAt.timeIntervalSince1970 + liveTime < Date().timeIntervalSince1970 {
                                try? FileManager.default.removeItem(at: url)
                            }
                            continue
                        }
                    }
                }
                try? FileManager.default.removeItem(at: url)
            }
        }
        
        
    }
    
}
private let cleaner = CacheRemovable()

public func startLottieCacheCleaner() {
    cleaner.start()
}


