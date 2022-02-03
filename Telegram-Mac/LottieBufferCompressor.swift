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

private enum WriteResult {
    case success
    case failed
}
private enum ReadResult {
    case success(Data)
    case cached(Data, ()->Void)
    case failed
}

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



final class TRLotData {
    
    
    fileprivate var map:[Int : FrameDst]
    fileprivate let bufferSize: Int
    
    private let mapPath: String
    private let dataPath: String
    var isFinished: Bool = false {
        didSet {
            let cpy = map
            for (key, value) in cpy {
                map[key] = .init(offset: value.offset, length: value.length, finished: isFinished)
            }
        }
    }
    
    private var readHandle: FileHandle?
    private var writeHandle: FileHandle?
    private let key: LottieAnimationEntryKey
    fileprivate let queue: Queue
    
    fileprivate func hasAlreadyFrame(_ frame: Int) -> Bool {
        assert(queue.isCurrent())
        return self.map[frame] != nil
    }
    fileprivate func readFrame(frame: Int) -> ReadResult {
        
        self.writeHandle?.closeFile()
        self.writeHandle = nil
        assert(queue.isCurrent())
        
        if !isFinished {
            return .failed
        }
        
        if let dest = map[frame] {
            let readHande: FileHandle?
            if let handle = self.readHandle {
                readHande = handle
            } else {
                readHande = FileHandle(forReadingAtPath: self.dataPath)
                self.readHandle = readHande
            }
            
            guard let dataHandle = readHande else {
                self.map.removeAll()
                return .failed
            }
            
            dataHandle.seek(toFileOffset: UInt64(dest.offset))
            let data = dataHandle.readData(ofLength: dest.length)
            if data.count == dest.length {
                return .success(data)
            } else {
                self.map.removeValue(forKey: frame)
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
    }
    
    fileprivate func writeFrame(frame: Int, data:Data) -> WriteResult {
        self.readHandle?.closeFile()
        self.readHandle = nil
        assert(queue.isCurrent())
        if map[frame] == nil {
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
            self.map[frame] = FrameDst(offset: Int(length), length: data.count, finished: isFinished)
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
        
        return path + "-v28-lzfse-bs\(bufferSize)-lt\(animation.liveTime)-map"
    }
    
    static func dataPath(_ animation: LottieAnimation, bufferSize: Int) -> String {
        let path = TRLotData.directory + animation.cacheKey
        
        return path + "-v28-lzfse-bs\(bufferSize)-lt\(animation.liveTime)-data"
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
            
            mapHandle?.closeFile()
        }
        
        guard let handle = FileHandle(forReadingAtPath: self.mapPath) else {
            self.map = [:]
            self.bufferSize = bufferSize
            deferr(self)
            return
        }
        mapHandle = handle
        
        guard let data = NSKeyedUnarchiver.unarchiveObject(withFile: self.mapPath) as? Data else {
            self.map = [:]
            self.bufferSize = bufferSize
            deferr(self)
            return
        }
        do {
            self.map = try PropertyListDecoder().decode([Int: FrameDst].self, from: data)
            self.bufferSize = bufferSize
            deferr(self)
        } catch {
            self.map = [:]
            self.bufferSize = bufferSize
            deferr(self)
        }
        self.isFinished = self.map.filter { $0.value.finished }.count == self.map.count

    }
    
}

private let lzfseQueue = Queue(name: "LZFSE BUFFER Queue", qos: DispatchQoS.default)


final class TRLotFileSupplyment {
    fileprivate let bufferSize: Int
    fileprivate let data:TRLotData
    fileprivate let queue: Queue
    fileprivate var shouldWaitToRead: [Int:Int] = [:]
    
    init(_ animation:LottieAnimation, bufferSize: Int, queue: Queue) {
        self.data = TRLotData(animation, bufferSize: bufferSize, queue: queue)
        self.queue = queue
        for value in self.data.map {
            shouldWaitToRead[value.key] = value.key
        }
        self.bufferSize = bufferSize
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
    
    func addFrame(_ previous: RenderedFrame?, _ current: RenderedFrame) {
        if shouldWaitToRead[Int(current.frame)] == nil {
            shouldWaitToRead[Int(current.frame)] = Int(current.frame)
            queue.async {
                if !self.data.hasAlreadyFrame(Int(current.frame)) {
                    let address = current.data!.assumingMemoryBound(to: UInt8.self)
                    
                    let dst: UnsafeMutablePointer<UInt8> = malloc(self.bufferSize)!.assumingMemoryBound(to: UInt8.self)
                    var length:Int = self.bufferSize
                    if let previous = previous {
                        let uint64Bs = self.bufferSize / 8
                        let dstDelta: UnsafeMutablePointer<UInt8> = malloc(self.bufferSize)!.assumingMemoryBound(to: UInt8.self)
                        memcpy(dstDelta, previous.data!.assumingMemoryBound(to: UInt8.self), self.bufferSize)
                        
                        
                        let ui64Dst = dstDelta.withMemoryRebound(to: UInt64.self, capacity: uint64Bs, { previousBytes in
                            return previousBytes
                        })
                        
                        let ui64Address = address.withMemoryRebound(to: UInt64.self, capacity: uint64Bs, { address in
                            return address
                        })
                        
                        
                        var i: Int = 0
                        while i < uint64Bs {
                            ui64Dst[i] = ui64Dst[i] ^ ui64Address[i]
                            i &+= 1
                        }
                        
                        let ui8 = ui64Dst.withMemoryRebound(to: UInt8.self, capacity: self.bufferSize, { body in
                            return body
                        })
                        
                        length = compression_encode_buffer(dst, self.bufferSize, ui8, self.bufferSize, nil, COMPRESSION_LZ4)
                        dstDelta.deallocate()
                    } else {
                        length = compression_encode_buffer(dst, self.bufferSize, address, self.bufferSize, nil, COMPRESSION_LZ4)
                    }
                    let _ = self.data.writeFrame(frame: Int(current.frame), data: Data(bytesNoCopy: dst, count: length, deallocator: .none))
                    dst.deallocate()
                }
            }
        }
    }

    func readFrame(previous: RenderedFrame?, frame: Int) -> UnsafeRawPointer? {
        var rendered: UnsafeRawPointer? = nil
        if shouldWaitToRead[frame] != nil {
            queue.sync {
                switch self.data.readFrame(frame: frame) {
                case let .success(data):
                    let address = malloc(bufferSize)!.assumingMemoryBound(to: UInt8.self)
                    
                    
                    rendered = data.withUnsafeBytes { dataBytes -> UnsafeRawPointer in

                        let unsafeBufferPointer = dataBytes.bindMemory(to: UInt8.self)
                        let unsafePointer = unsafeBufferPointer.baseAddress!

                        let _ = compression_decode_buffer(address, bufferSize, unsafePointer, data.count, nil, COMPRESSION_LZ4)

                        if let previous = previous {

                            let previousBytes = previous.data!.assumingMemoryBound(to: UInt64.self)

                            let uint64Bs = self.bufferSize / 8

                            address.withMemoryRebound(to: UInt64.self, capacity: uint64Bs, { address in
                                var i = 0
                                while i < uint64Bs {
                                    address[i] = previousBytes[i] ^ address[i]
                                    i &+= 1
                                }
                            })

                        }
                        return UnsafeRawPointer(address)
                    }
                    
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

func startLottieCacheCleaner() {
    cleaner.start()
}


