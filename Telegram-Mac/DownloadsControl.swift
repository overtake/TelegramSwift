//
//  DownloadsControl.swift
//  Telegram
//
//  Created by Mike Renoir on 25.02.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import FetchManager


final class DownloadsControlArguments {
    let open:()->Void
    let navigate:(MessageId)->Void
    init(open: @escaping()->Void, navigate: @escaping(MessageId)->Void) {
        self.open = open
        self.navigate = navigate
    }
}

final class DownloadsControl : Control {
    
    private let progressView = LinearProgressControl(progressHeight: 2)
    
    private let titleView = TextView()
    private let textContainer = View()
    private let nextView = ImageView()
    
    private var state: DownloadsSummary.State = .empty
    private var arguments: DownloadsControlArguments? = nil
    private let unseenDisposable = MetaDisposable()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
                
        textContainer.addSubview(titleView)
        addSubview(textContainer)
        
        addSubview(nextView)
        
        addSubview(progressView)
        
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = theme as! TelegramPresentationTheme
        self.backgroundColor = theme.colors.background
        self.border = [.Top]
        
        progressView.style = ControlStyle(foregroundColor: theme.colors.accent, backgroundColor: .clear, highlightColor: .clear)

        let attr = NSMutableAttributedString()        
        attr.append(getTitle(self.state))
        attr.append(.initialize(string: "  "))
        attr.append(getStatus(self.state))

        
        let titleLayout = TextViewLayout(attr, maximumNumberOfLines: 1, truncationType: .middle)
        titleLayout.measure(width: textContainer.frame.width)
        titleLayout.interactions = globalLinkExecutor
        titleView.update(titleLayout)
        
        
        nextView.image = theme.icons.generalNext
        nextView.sizeToFit()
        needsLayout = true
    }
    
    
    
    override func layout() {
        super.layout()
        
        progressView.frame = NSMakeRect(0, frame.height - progressView.frame.height, frame.width - .borderSize, 2)
        
        titleView.resize(frame.width - 20)
        titleView.setFrameOrigin(.zero)
        textContainer.setFrameSize(NSMakeSize(frame.width - 10 - 10, titleView.frame.height))
        textContainer.centerY(x: 10)
        nextView.centerY(x: frame.width - 10 - nextView.frame.width)

    }
    
    deinit {
        unseenDisposable.dispose()
    }
    
    func update(_ state: DownloadsSummary.State, context: AccountContext, arguments: DownloadsControlArguments, animated: Bool) {
        self.state = state
        self.arguments = arguments
        progressView.set(progress: state.totalProgress, animated: animated)
        switch state {
        case .downloading:
            self.progressView.change(opacity: 1, animated: animated)
            self.unseenDisposable.set(nil)
        case .hasUnseen:
            self.progressView.change(opacity: 0, animated: animated)
            let signal = markAllRecentDownloadItemsAsSeen(postbox: context.account.postbox) |> delay(5.0, queue: .mainQueue())
            self.unseenDisposable.set(signal.start())
        case .empty:
            self.progressView.change(opacity: 0, animated: animated)
            self.unseenDisposable.set(nil)
        }
        updateLocalizationAndTheme(theme: theme)
    }
    private func getTitle(_ state: DownloadsSummary.State) -> NSAttributedString {
        switch state {
        case let .downloading(_, _, msgs), let .hasUnseen(msgs):
            let text: String
            text = strings().downloadsManagerControlTitleCountable(msgs.count)
            return .initialize(string: text, color: theme.colors.text, font: .medium(.text))
        case .empty:
            return self.titleView.textLayout?.attributedString ?? NSAttributedString()
        }
    }
    private func getStatus(_ state: DownloadsSummary.State) -> NSAttributedString {
        switch state {
        case let .downloading(bytesLoaded, totalBytes, _):
            let attr = NSMutableAttributedString()
            let status = String.prettySized(with: Int(bytesLoaded)) + " / " + String.prettySized(with: Int(totalBytes))
            _ = attr.append(string: status, color: theme.colors.grayText, font: .normal(.text))
            return attr
        case let .hasUnseen(msgs):
            let attr = NSMutableAttributedString()
            let size: Int = msgs.reduce(0, { current, value in
                if let file = value.media.first as? TelegramMediaFile {
                    return current + (file.size ?? 0)
                } else {
                    return current
                }
            })
            let sizeText = String.prettySized(with: size)
            _ = attr.append(string: sizeText, color: theme.colors.grayText, font: .normal(.text))
            return attr
        default:
            break
        }
        return NSAttributedString()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


final class DownloadsSummary {
    
    private let fetchManager: FetchManagerImpl
    private let context: AccountContext
    
    enum State: Equatable {
        case empty
        case downloading(bytesLoaded: Double, totalBytes: Double, messages: [Message])
        case hasUnseen([Message])
        
        var totalProgress: Double {
            switch self {
            case let .downloading(bytesLoaded, totalBytes, _):
                if totalBytes.isZero {
                    return 0.0
                } else {
                    return bytesLoaded / totalBytes
                }
            case .hasUnseen:
                return 0
            default:
                return 0
            }
        }
        
        
        var messages: [Message] {
            switch self {
            case .empty:
                return []
            case let .downloading(_, _, msgs):
                return msgs
            case let .hasUnseen(msgs):
                return msgs
            }
        }
        
        var isEmpty: Bool {
            switch self {
            case .empty:
                return true
            case let .downloading(bytesLoaded, totalBytes, msgs):
                return msgs.isEmpty || bytesLoaded == totalBytes
            case let .hasUnseen(msgs):
                return msgs.isEmpty
            }
        }
    }
    
    private let stateValue: Promise<State> = Promise()
    var state: Signal<State, NoError> {
        return stateValue.get() |> deliverOnMainQueue
    }
    
    init(_ fetchManager: FetchManagerImpl, context: AccountContext) {
        self.fetchManager = fetchManager
        self.context = context
        initialize()
    }
    
    func initialize() {
        
        let engine = self.context.engine
        
        let entriesWithFetchStatuses = Signal<[(entry: FetchManagerEntrySummary, progress: Double)], NoError> { subscriber in
            let queue = Queue()
            final class StateHolder {
                final class EntryContext {
                    var entry: FetchManagerEntrySummary
                    var isRemoved: Bool = false
                    var statusDisposable: Disposable?
                    var status: MediaResourceStatus?
                    
                    init(entry: FetchManagerEntrySummary) {
                        self.entry = entry
                    }
                    
                    deinit {
                        self.statusDisposable?.dispose()
                    }
                }
                
                let queue: Queue
                
                var entryContexts: [FetchManagerLocationEntryId: EntryContext] = [:]
                
                let state = Promise<[(entry: FetchManagerEntrySummary, progress: Double)]>()
                
                init(queue: Queue) {
                    self.queue = queue
                }
                
                func update(engine: TelegramEngine, entries: [FetchManagerEntrySummary]) {
                    if entries.isEmpty {
                        self.entryContexts.removeAll()
                    } else {
                        for entry in entries {
                            let context: EntryContext
                            if let current = self.entryContexts[entry.id] {
                                context = current
                            } else {
                                context = EntryContext(entry: entry)
                                self.entryContexts[entry.id] = context
                            }
                            
                            context.entry = entry
                            
                            if context.isRemoved {
                                context.isRemoved = false
                                context.status = nil
                                context.statusDisposable?.dispose()
                                context.statusDisposable = nil
                            }
                        }
                        
                        for (_, context) in self.entryContexts {
                            if !entries.contains(where: { $0.id == context.entry.id }) {
                                context.isRemoved = true
                            }
                            
                            if context.statusDisposable == nil {
                                context.statusDisposable = (engine.account.postbox.mediaBox.resourceStatus(context.entry.resourceReference.resource)
                                |> deliverOn(self.queue)).start(next: { [weak self, weak context] status in
                                    guard let strongSelf = self, let context = context else {
                                        return
                                    }
                                    if context.status != status {
                                        context.status = status
                                        strongSelf.notifyUpdatedIfReady()
                                    }
                                })
                            }
                        }
                    }
                    
                    self.notifyUpdatedIfReady()
                }
                
                func notifyUpdatedIfReady() {
                    var result: [(entry: FetchManagerEntrySummary, progress: Double)] = []
                    loop: for (_, context) in self.entryContexts {
                        guard let status = context.status else {
                            return
                        }
                        let progress: Double
                        switch status {
                        case .Local:
                            progress = 1.0
                        case .Remote:
                            if context.isRemoved {
                                continue loop
                            }
                            progress = 0.0
                        case let .Paused(value):
                            progress = Double(value)
                        case let .Fetching(_, value):
                            progress = Double(value)
                        }
                        result.append((context.entry, progress))
                    }
                    self.state.set(.single(result))
                }
            }
            let holder = QueueLocalObject<StateHolder>(queue: queue, generate: {
                return StateHolder(queue: queue)
            })
            let entriesDisposable = self.fetchManager.entriesSummary.start(next: { entries in
                holder.with { holder in
                    holder.update(engine: engine, entries: entries)
                }
            })
            let holderStateDisposable = MetaDisposable()
            holder.with { holder in
                holderStateDisposable.set(holder.state.get().start(next: { state in
                    subscriber.putNext(state)
                }))
            }
            
            return ActionDisposable {
                entriesDisposable.dispose()
                holderStateDisposable.dispose()
            }
        }
        
        let recentDownload = recentDownloadItems(postbox: context.account.postbox)
        let combined = combineLatest(queue: .mainQueue(), entriesWithFetchStatuses, recentDownload)
        let stateSignal: Signal<State, NoError> = (combined |> mapToSignal { entries, recentDownloadItems -> Signal<State, NoError> in
            if !entries.isEmpty {
                var totalBytes = 0.0
                var totalProgressInBytes = 0.0
                for (entry, progress) in entries {
                    var size = 1024 * 1024 * 1024
                    if let sizeValue = entry.resourceReference.resource.size {
                        size = sizeValue
                    }
                    totalBytes += Double(size)
                    totalProgressInBytes += Double(size) * progress
                }
                
                let ids:[MessageId] = entries.map { $0.entry }.compactMap { value in
                    switch value.id.locationKey {
                    case let .messageId(messageId):
                        return messageId
                    default:
                        return nil
                    }
                }
                let signals = ids.map { id in
                    engine.account.postbox.transaction { transaction in
                        transaction.getMessage(id)
                    }
                }
                return combineLatest(signals) |> map { msgs in
                    return .downloading(bytesLoaded: totalProgressInBytes, totalBytes: totalBytes, messages: msgs.compactMap { $0 })
                }
            } else {
                let unseen = recentDownloadItems.filter { !$0.isSeen }.map { $0.message }
                if !unseen.isEmpty {
                    return .single(.hasUnseen(unseen))
                }
                return .single(.empty)
            }
        }
        |> mapToSignal { value -> Signal<State, NoError> in
            return .single(value) |> delay(0.1, queue: .mainQueue())
        }
        |> distinctUntilChanged
        |> deliverOnMainQueue)

        
        self.stateValue.set(stateSignal)
        
    }
}
