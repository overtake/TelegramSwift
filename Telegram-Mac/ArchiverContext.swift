//
//  ArchiverContext.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 23/10/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//
import Zip
import SwiftSignalKitMac

enum ArchiveStatus : Equatable {
    case none
    case waiting
    case done(URL)
    case fail(ZipError)
    case progress(Double)
}
enum ArchiveSource : Hashable {
    static func == (lhs: ArchiveSource, rhs: ArchiveSource) -> Bool {
        switch lhs {
        case let .resource(lhsResource):
            if case let .resource(rhsResource) = rhs {
                return lhsResource.isEqual(to: rhsResource)
            } else {
                return false
            }
        }
    }
    
    var contents:[URL] {
        switch self {
        case let .resource(resource):
            if resource.path.contains("tg_temp_archive_") {
                let files = try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: resource.path), includingPropertiesForKeys: nil, options: FileManager.DirectoryEnumerationOptions.skipsHiddenFiles)
                return files ?? [URL(fileURLWithPath: resource.path)]
            }
            return [URL(fileURLWithPath: resource.path)]
        }
    }
    
    
    var hashValue: Int {
        switch self {
        case let .resource(resource):
            return resource.id.hashValue
        }
    }
    
    var destinationURL: URL {
        return URL(fileURLWithPath: NSTemporaryDirectory() + "tarchive-\(self.uniqueId).zip")
    }
    
    
    var uniqueId: Int64 {
        switch self {
        case .resource(let resource):
            return resource.randomId
        }
    }
    
    case resource(LocalFileArchiveMediaResource)
}

private final class Archiver {
    private let status: ValuePromise<ArchiveStatus> = ValuePromise(.waiting, ignoreRepeated: true)
    var statusSignal:Signal<ArchiveStatus, NoError> {
        return status.get()
    }
    let destination: URL
    private let source: ArchiveSource
    private let queue: Queue
    init(source : ArchiveSource, queue: Queue) {
        self.queue = queue
        self.source = source
        self.destination = source.destinationURL
    }
    
    func start(cancelToken:@escaping()->Bool) {
        let destination = self.destination
        let source = self.source
        queue.async { [weak status] in
            guard let status = status else {return}
            let contents = source.contents
            if !contents.isEmpty {
                do {
                    try Zip.zipFiles(paths: contents, zipFilePath: destination, password: nil, compression: ZipCompression.DefaultCompression, progress: { progress in
                        status.set(.progress(progress))
                    }, cancel: cancelToken)
                   status.set(.done(destination))
                } catch {
                    if let error = error as? ZipError {
                        status.set(.fail(error))
                    }
                }
            }
        }
        
    }
    
}
// добавить отмену архивирования если разлонигиваемся
private final class ArchiveStatusContext {
    var status: ArchiveStatus = .none
    let subscribers = Bag<(ArchiveStatus) -> Void>()
}
class ArchiverContext {
    var statuses:[ArchiveSource : ArchiveStatus] = [:]
    
    private let queue = Queue(name: "ArchiverContext")
    private var contexts: [ArchiveSource: Archiver] = [:]
    private let archiveQueue: Queue = Queue.concurrentDefaultQueue()
    private var statusContexts: [ArchiveSource: ArchiveStatusContext] = [:]
    private var statusesDisposable:[ArchiveSource : Disposable] = [:]
    private var cancelledTokens:[ArchiveSource : Any] = [:]
    init() {
    }
    
    deinit {
        self.queue.sync {
            self.contexts.removeAll()
            for status in statusesDisposable {
                status.value.dispose()
            }
        }
    }
    
    func remove(_ source: ArchiveSource) {
        queue.async {
            self.contexts.removeValue(forKey: source)
            self.statusesDisposable[source]?.dispose()
            self.statuses.removeValue(forKey: source)
            self.cancelledTokens[source] = true
        }
    }
    
    func archive(_ source: ArchiveSource, startIfNeeded: Bool = false) -> Signal<ArchiveStatus, NoError> {
        let queue = self.queue
        return Signal { [weak self] subscriber in
            guard let `self` = self else { return EmptyDisposable }
            if self.statusContexts[source] == nil {
                self.statusContexts[source] = ArchiveStatusContext()
            }
            
            let statusContext = self.statusContexts[source]!
            
            let index = statusContext.subscribers.add({ status in
                subscriber.putNext(status)
            })
            
            if let _ = self.contexts[source] {
                if let statusContext = self.statusContexts[source] {
                    for subscriber in statusContext.subscribers.copyItems() {
                        subscriber(statusContext.status)
                    }
                }
            } else {
                if startIfNeeded {
                    let archiver = Archiver(source: source, queue: self.archiveQueue)
                    self.contexts[source] = archiver
                    self.statusesDisposable[source] = (archiver.statusSignal |> deliverOn(queue)).start(next: { status in
                        statusContext.status = status
                        for subscriber in statusContext.subscribers.copyItems() {
                            subscriber(statusContext.status)
                        }
                    }, completed: {
                        subscriber.putCompletion()
                    })
                    
                    archiver.start(cancelToken: {
                        var cancelled: Bool = false
                        queue.sync {
                            cancelled = self.cancelledTokens[source] != nil
                            self.cancelledTokens.removeValue(forKey: source)
                        }
                        return cancelled
                    })
                } else {
                    for subscriber in statusContext.subscribers.copyItems() {
                        subscriber(statusContext.status)
                    }
                }
                
            }
            
            
            return ActionDisposable {
                self.queue.async {
                    if let current = self.statusContexts[source] {
                        current.subscribers.remove(index)
                    }
                }
            }
        } |> runOn(queue)
    }

}



