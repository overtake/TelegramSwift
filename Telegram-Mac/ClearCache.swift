//
//  ClearCache.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 03/08/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
import Postbox
import TelegramCore

private let cacheQueue = Queue(name: "org.telegram.clearCacheQueue")
private let cleanQueue = Queue(name: "org.telegram.cleanupQueue")


private func scanFiles(at path: String, anyway: ((String, Int)) -> Void) {
    guard let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: path), includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], options: [.skipsSubdirectoryDescendants], errorHandler: nil) else {
        return
    }
    while let item = enumerator.nextObject() {
        guard let url = item as? NSURL else {
            continue
        }
        guard let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey]) else {
            continue
        }
        if let value = resourceValues[.isDirectoryKey] as? Bool, value {
            continue
        }
        if let file = url.path {
            anyway((file, (resourceValues[.fileSizeKey] as? NSNumber)?.intValue ?? 0))
        }
    }
}

private func clearCache(_ files: [(String, Int)], excludes: [(partial: String, complete: String)], start: TimeInterval) -> Signal<Float, NoError> {
    return Signal { subscriber in
        
        var cancelled = false
        
        let files = files.filter { file in
            return !excludes.contains(where: {
                $0.partial == file.0 || $0.complete == file.0
            })
        }
        
        let total: Int = files.reduce(0, {
            $0 + $1.1
        })
        
        var cleaned: Int = 0
        
        for file in files {
            if !cancelled {
                let url = URL(fileURLWithPath: file.0)
                guard let resourceValues = try? url.resourceValues(forKeys: [.contentModificationDateKey]) else {
                    continue
                }
                let date = resourceValues.contentModificationDate?.timeIntervalSince1970 ?? start
                if date <= start {
                    unlink(file.0)
                }
                cleaned += file.1
                subscriber.putNext(Float(cleaned) / Float(total))
            } else {
                break
            }
        }
        
        subscriber.putNext(1.0)
        subscriber.putCompletion()
        
        return ActionDisposable {
            cancelled = true
        }
    } |> runOn(cleanQueue)
}


private final class CCTask : Equatable {
    static func == (lhs: CCTask, rhs: CCTask) -> Bool {
        return lhs === rhs
    }
    private let disposable = MetaDisposable()
    private var progressValue: ValuePromise<Float> = ValuePromise(0)
    private var progress: Atomic<Float> = Atomic(value: 0)

    init(_ account: Account, completion: @escaping()->Void) {
        let signal: Signal<Float, NoError> = account.postbox.mediaBox.allFileContexts()
            |> deliverOn(cacheQueue)
            |> mapToSignal { excludes in
                var files:[(String, Int)] = []
                scanFiles(at: account.postbox.mediaBox.basePath, anyway: { value in
                    files.append(value)
                })
                return clearCache(files, excludes: excludes, start: Date().timeIntervalSince1970)
            } |> deliverOn(cacheQueue)
        
        self.disposable.set(signal.start(next: { [weak self] value in
            guard let `self` = self else {
                return
            }
            self.progressValue.set(self.progress.with { _ in return value })
            if value == 1.0 {
                cacheQueue.after(0.2, completion)
            }
        }))
    }
    
    func getCurrentProgress() -> Float {
        return progress.with { $0 }
    }
    
    
    func updatedProgress() -> Signal<Float, NoError> {
        return progressValue.get()
    }
}

final class CCTaskData : Equatable {
    static func == (lhs: CCTaskData, rhs: CCTaskData) -> Bool {
        return lhs === rhs
    }
    
    private let task: CCTask
    fileprivate init?(_ task: CCTask?) {
        guard let task = task else {
            return nil
        }
        self.task = task
    }
    
    var currentProgress: Float {
        return self.task.getCurrentProgress()
    }
    
    var progress: Signal<Float, NoError> {
        return self.task.updatedProgress()
    }
}

private class CCContext {
    private let account: Account
    
    private let currentTaskValue: Atomic<CCTask?> = Atomic(value: nil)
    private let currentTask: ValuePromise<CCTask?> = ValuePromise(nil)

    init(account: Account) {
        self.account = account
    }
    
    func makeAndRunTask() {
        let account = self.account
        currentTask.set(currentTaskValue.modify { task in
            if let task = task {
                return task
            }
            return CCTask(account, completion: { [weak self] in
                if let `self` = self {
                    cacheQueue.justDispatch {
                        self.currentTask.set(self.currentTaskValue.modify { _ in return nil } )
                    }
                }
            })
        })
    }
    func cancel() {
        self.currentTask.set(self.currentTaskValue.modify { _ in return nil } )
    }
    
    func getTask() -> Signal<CCTaskData? ,NoError> {
        return currentTask.get() |> map { CCTaskData($0) }
    }
}



final class AccountClearCache {
    private let context: QueueLocalObject<CCContext>
    init(account: Account) {
        context = QueueLocalObject(queue:  cacheQueue, generate: {
            return CCContext(account: account)
        })
    }
    
    var task: Signal<CCTaskData?, NoError> {
        let signal: Signal<Signal<CCTaskData?, NoError>, NoError> =  context.signalWith({ ctx, subscriber in
            subscriber.putNext(ctx.getTask())
            subscriber.putCompletion()
            
            return EmptyDisposable
        })
        return signal |> switchToLatest
    }
    
    func run() {
        context.with { ctx in
            ctx.makeAndRunTask()
        }
    }
    
    func cancel() {
        context.with { ctx in
            ctx.cancel()
        }
    }
}
