//
//  WidgetStorage.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 08.07.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import TelegramCore

import Postbox


private extension CacheUsageStatsResult {
    var totalBytes: UInt64 {
        switch self {
        case .progress:
            return 0
        case let .result(stats):
            return UInt64(stats.otherSize + stats.cacheSize)
        }
    }
}

private final class WidgetStorageProgress: View {
    private var animators: [DisplayLinkAnimator] = []
    private var removeAnimators: [Int : DisplayLinkAnimator] = [:]
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    struct Value {
        var index: Int
        var value: CGFloat
    }
    
    private(set) var progressValue: [Int : CGFloat] = [:] {
        didSet {
            needsDisplay = true
        }
    }
    
    func setProgress(_ values: [Int : CGFloat], tooltips: [Int: String]) {
        
        self.animators = []
        var toRemove: [Int : CGFloat] = [:]
        if !values.isEmpty {
            for value in values {
                let fromValue = self.progressValue[value.key] ?? 0
                let toValue = max(min(1, value.value), 0)
                
                self.animators.append(DisplayLinkAnimator(duration: 0.4, from: fromValue, to: toValue, update: { [weak self] updated in
                    self?.progressValue[value.key] = updated
                    
                }, completion: {}))
                
                removeAnimators.removeValue(forKey: value.key)
            }
            toRemove = self.progressValue.filter { value in
                return !values.contains(where: { $0.key == value.key }) && removeAnimators[value.key] == nil
            }
        } else {
            let fromValue: CGFloat = self.progressValue[0] ?? 0
            let toValue: CGFloat = fromValue == 1 ? 0 : 1
            
            self.animators.append(DisplayLinkAnimator(duration: 3.0, from: fromValue, to: toValue, update: { [weak self] updated in
                self?.progressValue[0] = updated
            }, completion: { [weak self] in
                self?.setProgress([:], tooltips: tooltips)
            }))
            
            toRemove = self.progressValue.filter {
                $0.key != 0 && removeAnimators[$0.key] == nil
            }
            removeAnimators.removeValue(forKey: 0)
        }
        for value in toRemove {
            removeAnimators[value.key] = DisplayLinkAnimator(duration: 0.4, from: value.value, to: 0, update: { [weak self] updated in
                self?.progressValue[value.key] = updated
            }, completion: { [weak self] in
                self?.setProgress([:], tooltips: tooltips)
                self?.progressValue.removeValue(forKey: value.key)
            })
        }
        
        self.removeAllSubviews()
        
        var list:[CGFloat] = Array(repeating: 0, count: values.count)
        for value in values {
            list[value.key] = value.value
        }
        
        list = normalize(list)
        
        var width: CGFloat = 0
        for (i, value) in list.enumerated() {
            let key = values.first(where: { $0.key == i })?.key
            if let key = key {
                let control = Control()
                addSubview(control)
                control.frame = NSMakeRect(width, 0, (value * frame.width) - width, frame.height)
                control.appTooltip = tooltips[key]
                width = value * frame.width
            }
        }
    }
    
    private func normalize(_ values:[CGFloat]) -> [CGFloat] {
        var values = values
        values.sort(by: <)
        
        var prev: CGFloat?
        for i in 0 ..< values.count {
            if let prev = prev {
                let minStep = max(0.01, values[i] - prev)
                values[i] = min(values[i] + 0.01 * (minStep / 0.01), 1)
            }
            prev = values[i]
        }
        return values
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        ctx.round(frame.size, frame.height / 2)
        
        let path = CGMutablePath()
        
        path.addRoundedRect(in: bounds, cornerWidth: frame.height / 2, cornerHeight: frame.height / 2)
        
        ctx.setStrokeColor(theme.colors.border.cgColor)
        ctx.setLineWidth(1.0)
        
        ctx.addPath(path)
        ctx.strokePath()
        
        
        var colors = [theme.colors.accent, theme.colors.peerAvatarBlueTop]
        
        if self.progressValue.count == 1 {
            colors = colors.reversed()
        }
        
        var values:[CGFloat] = Array(repeating: 0, count: self.progressValue.count)
        for value in self.progressValue {
            values[value.key] = value.value
        }
        
        values = normalize(values)
        
        for (i, value) in values.reversed().enumerated() {
            ctx.setFillColor(colors[i].cgColor)
            ctx.fill(NSMakeRect(0, 0, value * frame.width, frame.height))
        }
    }
    
    override func layout() {
        super.layout()
    }
}

final class WidgetStorageContainer : View {
    private let clearButton = WidgetButton()
    private let storageTitle = TextView()
    private let progressIndicator: WidgetStorageProgress = WidgetStorageProgress(frame: .zero)
    private let storageDesc = TextView()
    
    var clearAll:(()->Void)? = nil

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(clearButton)
        addSubview(storageTitle)
        addSubview(progressIndicator)
        addSubview(storageDesc)
        storageTitle.userInteractionEnabled = false
        storageTitle.isSelectable = false
        
        storageDesc.userInteractionEnabled = false
        storageDesc.isSelectable = false
        
        clearButton.set(handler: { [weak self] _ in
            self?.clearAll?()
        }, for: .Click)
    }
    private var state: WidgetStorageController.State?
    
    private let progressDisposable = MetaDisposable()
    
    func update(_ state: WidgetStorageController.State, animated: Bool) {

        let progress = state.progressValues
        progressIndicator.setProgress(progress.values, tooltips: progress.tooltips)
        
        self.state = state
        updateLocalizationAndTheme(theme: theme)
        
        clearButton.userInteractionEnabled = state.diskSpace.app != nil
        clearButton.change(opacity: state.diskSpace.app == nil ? 0.5 : 1, animated: animated)
    }
    
    deinit {
        progressDisposable.dispose()
    }
    
    override func layout() {
        super.layout()
        progressIndicator.setFrameSize(NSMakeSize(frame.width, 32))
        clearButton.centerX(y: frame.height - clearButton.frame.height)
        progressIndicator.centerX(y: storageTitle.frame.maxY + 20)
        
        
        storageTitle.resize(frame.width - 20)
        storageTitle.centerX()

        
        storageDesc.resize(frame.width - 20)
        storageDesc.centerX(y: progressIndicator.frame.maxY + 16)


    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)

        let theme = theme as! TelegramPresentationTheme
        
        clearButton.update(false, icon: theme.icons.empty_chat_storage_clear, text: strings().emptyChatStorageUsageClear)
        clearButton.setFrameSize(clearButton.size())
        
        let titleLayout = TextViewLayout.init(.initialize(string: strings().emptyChatStorageUsage, color: theme.colors.text, font: .medium(.text)))
        titleLayout.measure(width: frame.width - 20)
        storageTitle.update(titleLayout)
        
        let descAttr = NSMutableAttributedString()
        if let _ = state?.ccTask {
            descAttr.append(.initialize(string: strings().emptyChatStorageUsageClearing, color: theme.colors.grayText, font: .normal(.text)))
        } else if let totalBytes = state?.diskSpace.app {
            let text = totalBytes == 0 ? strings().emptyChatStorageUsageCacheDescEmpty : strings().emptyChatStorageUsageCacheDesc(String.prettySized(with: Int(totalBytes)))
            descAttr.append(.initialize(string: text, color: theme.colors.grayText, font: .normal(.text)))
        } else {
            descAttr.append(.initialize(string: strings().emptyChatStorageUsageLoading, color: theme.colors.grayText, font: .normal(.text)))
        }
        descAttr.detectBoldColorInString(with: .medium(.text))
        let descLayout = TextViewLayout(descAttr)
        descLayout.measure(width: frame.width - 20)
        storageDesc.update(descLayout)

        
        needsLayout = true
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class WidgetStorageController : TelegramGenericViewController<WidgetView<WidgetStorageContainer>> {

    struct State : Equatable {
        
        struct DiskSpace : Equatable {
            var free: UInt64
            var total: UInt64
            var app: UInt64?
        }
        
        var ccTask: (CCTaskData, Float)?
        var settings: CacheStorageSettings
        var diskSpace: DiskSpace
        static func ==(lhs:State, rhs: State) -> Bool {
            return lhs.diskSpace == rhs.diskSpace && lhs.ccTask?.0 == rhs.ccTask?.0 && lhs.settings == rhs.settings
        }
        
        var progressValues:(values: [Int: CGFloat], tooltips: [Int: String]) {
            if let usageBytes = diskSpace.app, diskSpace.total > 0 {
                                
                let appUsageBytes = usageBytes // UInt64(10 * 1024 * 1024 * 1024)
                
                
                
                let systemTotalBytes = diskSpace.total * 1024 * 1024 * 1024
                let systemFreeBytes = diskSpace.free * 1024 * 1024 * 1024
                let systemUsedBytes = systemTotalBytes - systemFreeBytes
                
                
                let systemUsedValue = CGFloat(systemUsedBytes - appUsageBytes) / CGFloat(systemTotalBytes)
                let appUsedValue = CGFloat(systemUsedBytes) / CGFloat(systemTotalBytes)
                
                
                var values:[Int: CGFloat] = [0 : systemUsedValue, 1: appUsedValue]
                
                if let ccTask = ccTask {
                    values[1] = (CGFloat(systemUsedBytes) - CGFloat(appUsageBytes) * CGFloat(ccTask.1)) / CGFloat(systemTotalBytes)
                }
                
                let systemText = String.prettySized(with: Int(systemUsedBytes - appUsageBytes))
                let appText = String.prettySized(with: Int(appUsageBytes))

                let tooltips:[Int: String] = [0 : strings().emptyChatStorageUsageTooltipSystem(systemText), 1: strings().emptyChatStorageUsageTooltipApp(appText)]
                
                return (values: values, tooltips: tooltips)
            } else {
                return (values: [:], tooltips: [:])
            }
        }
        
        enum NetworkPreset : Int {
            case low
            case normal
        }

    }
    
    private let disposable = MetaDisposable()
    private let actionsDisposable = DisposableSet()
    override init(_ context: AccountContext) {
        super.init(context)
        self.bar = .init(height: 0)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let initialState = State(settings: .defaultSettings, diskSpace: .init(free: 0, total: 0, app: 0))
        
        let statePromise = ValuePromise(initialState, ignoreRepeated: true)
        let stateValue = Atomic(value: initialState)
        let updateState: ((State) -> State) -> Void = { f in
            statePromise.set(stateValue.modify (f))
        }
        
        let mediaPath = context.account.postbox.mediaBox.basePath
        
        var diskSpaceUpdater:Signal<State.DiskSpace, NoError> = Signal { subscriber in
            
            let systemFree = freeSystemGigabytes() ?? 0
            let systemSize = systemSizeGigabytes() ?? 0
            var totalSize: UInt64 = 0
            scanFiles(at: mediaPath, anyway: { file, fs in
                totalSize += UInt64(fs)
            })
            subscriber.putNext(.init(free: systemFree, total: systemSize, app: totalSize))
            subscriber.putCompletion()

            return EmptyDisposable
        } |> runOn(.concurrentDefaultQueue())
        
        
        diskSpaceUpdater = (diskSpaceUpdater |> then(.complete() |> suspendAwareDelay(60.0 * 30, queue: Queue.concurrentDefaultQueue()))) |> restart
        
        let diskUpdater:Promise<State.DiskSpace> = Promise()
        
        diskUpdater.set(.single(.init(free: 0, total: 0, app: nil)) |> then(diskSpaceUpdater))
        
        actionsDisposable.add(diskUpdater.get().start(next: { diskSpace in
            updateState { current in
                var current = current
                current.diskSpace = diskSpace
                return current
            }
        }))
                

        let cacheSettingsPromise = Promise<CacheStorageSettings>()
        cacheSettingsPromise.set(context.sharedContext.accountManager.sharedData(keys: [SharedDataKeys.cacheStorageSettings])
            |> map { view -> CacheStorageSettings in
                return view.entries[SharedDataKeys.cacheStorageSettings]?.get(CacheStorageSettings.self) ?? CacheStorageSettings.defaultSettings
            })
        
        
        
        let taskAndProgress:Signal<(CCTaskData, Float)?, NoError> = context.cacheCleaner.task |> mapToSignal { task in
            if let task = task {
                return task.progress |> map {
                    return (task, $0)
                }
            } else {
                return .single(nil)
            }
        }
        
        
        let signal = combineLatest(queue: .mainQueue(), cacheSettingsPromise.get(), taskAndProgress, appearanceSignal)

        actionsDisposable.add(signal.start(next: { settings, ccTask, appearance in
            if ccTask == nil && stateValue.with({ $0.ccTask != nil }) {
                DispatchQueue.main.async {
                    diskUpdater.set(diskSpaceUpdater)
                }
            }
            updateState { current in
                var current = current
                current.settings = settings
                current.ccTask = ccTask
                return current
            }
        }))
        
        let context = self.context
        
        genericView.dataView = WidgetStorageContainer(frame: .zero)
        
       
        
        
        genericView.dataView?.clearAll = {
            confirm(for: context.window, information: strings().storageClearAllConfirmDescription, okTitle: strings().storageClearAll, successHandler: { _ in
                context.cacheCleaner.run()
            })
        }
                
        var first = true
        
        disposable.set((statePromise.get() |> deliverOnMainQueue).start(next: { [weak self] state in
            
            var buttons: [WidgetData.Button] = []
            
            let lowIsSelected = state.settings.defaultCacheStorageLimitGigabytes == 5
            let normalIsSelected = state.settings.defaultCacheStorageLimitGigabytes == 32
            let highIsSelected = state.settings.defaultCacheStorageLimitGigabytes == .max

            buttons.append(.init(text: { strings().emptyChatStorageUsageLow }, selected: {
                return lowIsSelected
            }, image: {
                return lowIsSelected ? theme.icons.empty_chat_storage_low_active : theme.icons.empty_chat_storage_low
            }, click: {
                _ = updateCacheStorageSettingsInteractively(accountManager: context.sharedContext.accountManager, {
                    $0.withUpdatedDefaultCacheStorageLimitGigabytes(5)
                }).start()
            }))
            
            buttons.append(.init(text: { strings().emptyChatStorageUsageMedium }, selected: {
                return normalIsSelected
            }, image: {
                return normalIsSelected ?  theme.icons.empty_chat_storage_medium_active : theme.icons.empty_chat_storage_medium
            }, click: {
                _ = updateCacheStorageSettingsInteractively(accountManager: context.sharedContext.accountManager, {
                    $0.withUpdatedDefaultCacheStorageLimitGigabytes(32)
                }).start()
            }))
            
            buttons.append(.init(text: { strings().emptyChatStorageUsageNoLimit }, selected: {
                return highIsSelected
            }, image: {
                return highIsSelected ? theme.icons.empty_chat_storage_high_active : theme.icons.empty_chat_storage_high
            }, click: {
                _ = updateCacheStorageSettingsInteractively(accountManager: context.sharedContext.accountManager, {
                    $0.withUpdatedDefaultCacheStorageLimitGigabytes(.max)
                }).start()
            }))
            
            let data: WidgetData = .init(title: { strings().emptyChatStorageUsageData }, desc: { strings().emptyChatStorageUsageDesc }, descClick: {
                context.bindings.rootNavigation().push(DataAndStorageViewController(context))
            }, buttons: buttons)
            
            self?.genericView.update(data)
            self?.genericView.dataView?.update(state, animated: !first)
            first = false
        }))

    }
    
    deinit {
        actionsDisposable.dispose()
        disposable.dispose()
    }
}
