//
//  SlotsMediaContentView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 15/10/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import Postbox
import TelegramCore
import SyncCore
import TGUIKit
import SwiftSignalKit



class SlotsMediaContentView: ChatMediaContentView {
    private let idlePlayer: LottiePlayerView = LottiePlayerView(frame: NSMakeRect(0, 0, 240, 240))
    private let pullPlayer: LottiePlayerView = LottiePlayerView(frame: NSMakeRect(0, 0, 240, 240))

    private let spin1Player: LottiePlayerView = LottiePlayerView(frame: NSMakeRect(0, 0, 240, 240))
    private let spin2Player: LottiePlayerView = LottiePlayerView(frame: NSMakeRect(0, 0, 240, 240))
    private let spin3Player: LottiePlayerView = LottiePlayerView(frame: NSMakeRect(0, 0, 240, 240))

    
    private var value: SlotMachineValue = SlotMachineValue(rawValue: nil)
    
    private let thumbView = TransformImageView()
    private let loadResourceDisposable = MetaDisposable()
    private let stateDisposable = MetaDisposable()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(self.idlePlayer)
        addSubview(self.spin1Player)
        addSubview(self.spin2Player)
        addSubview(self.spin3Player)
        addSubview(self.pullPlayer)
        addSubview(self.thumbView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func clean() {
        loadResourceDisposable.dispose()
    }
    
    deinit {
        clean()
    }
    
    func removeNotificationListeners() {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidUpdatedDynamicContent() {
        super.viewDidUpdatedDynamicContent()
        updatePlayerIfNeeded()
    }
    
    
    
    
    @objc func updatePlayerIfNeeded() {
        
    }
    
    private var nextForceAccept: Bool = false
    
    
    override func executeInteraction(_ isControl: Bool) {
        
        let media = self.media as? TelegramMediaDice
        
        if let media = media, let message = self.parent {
            let item = self.table?.item(stableId: ChatHistoryEntryId.message(message))
            
            if let item = item as? ChatRowItem, let peer = item.peer, peer.canSendMessage(item.chatInteraction.mode.isThreadMode) {
                let text: String
                
                switch media.emoji {
                case diceSymbol:
                    text = L10n.chatEmojiDiceResultNew
                case dartSymbol:
                    text = L10n.chatEmojiDartResultNew
                default:
                    text = L10n.chatEmojiDefResultNew(media.emoji)
                }
                let view: NSView
                if !thumbView.isHidden {
                    view = thumbView
                } else {
                    view = idlePlayer
                }
                tooltip(for: view, text: text, interactions: globalLinkExecutor, button: (L10n.chatEmojiSend, { [weak item] in
                    item?.chatInteraction.sendPlainText(media.emoji)
                }), offset: NSMakePoint(0, -30))
            }
        }
    }
    
    var chatLoopAnimated: Bool {
        if let context = self.context {
            return context.autoplayMedia.loopAnimatedStickers
        }
        return true
    }
    
    func updateListeners() {
        if let window = window {
            NotificationCenter.default.removeObserver(self)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSWindow.didBecomeKeyNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSWindow.didResignKeyNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSView.boundsDidChangeNotification, object: table?.contentView)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSView.frameDidChangeNotification, object: self.enclosingScrollView?.documentView)
        } else {
            removeNotificationListeners()
        }
    }
    
    override func viewWillDraw() {
        super.viewWillDraw()
        updatePlayerIfNeeded()
    }
    
    override func willRemove() {
        super.willRemove()
        updateListeners()
        updatePlayerIfNeeded()
    }
    
    override func viewDidMoveToSuperview() {
        updateListeners()
        updatePlayerIfNeeded()
    }
    
    override func viewDidMoveToWindow() {
        updateListeners()
        updatePlayerIfNeeded()
    }
    
    var players:[LottiePlayerView] {
        return [idlePlayer, pullPlayer, spin1Player, spin2Player, spin3Player]
    }
    
    override func update(with media: Media, size: NSSize, context: AccountContext, parent: Message?, table: TableView?, parameters: ChatMediaLayoutParameters?, animated: Bool, positionFlags: LayoutPositionFlags?, approximateSynchronousValue: Bool) {
        
        
        if parent?.stableId != self.parent?.stableId {
            _ = players.map {
                $0.set(nil)
            }
        }
        
        super.update(with: media, size: size, context: context, parent: parent, table: table, parameters: parameters, animated: animated, positionFlags: positionFlags, approximateSynchronousValue: approximateSynchronousValue)
        
        guard let media = media as? TelegramMediaDice, let parent = parent else {
            return
        }
        
        let value = SlotMachineValue(rawValue: media.value)
        let previousValue = self.value
        self.value = value
        
        let sent: Bool = media.value != nil
        
        let played: Bool = FastSettings.diceHasAlreadyPlayed(parent)
        
        
        
        let data: Signal<[(String, Data?, TelegramMediaFile)], NoError> = context.diceCache.interactiveSymbolData(baseSymbol: media.emoji, synchronous: approximateSynchronousValue)
        
       
        if previousValue != value {
            _ = players.map {
                $0.animation?.triggerOn = nil
                $0.animation?.onFinish = nil
            }
        }
        
        let spinPolicy: LottiePlayPolicy
        if sent {
            if played {
                spinPolicy = .toEnd(from: .max)
            } else {
                spinPolicy = .onceEnd
            }
        } else {
            spinPolicy = .loop
        }
        
        self.loadResourceDisposable.set((data |> deliverOnMainQueue).start(next: { [weak self] data in
            guard let `self` = self else {
                return
            }
            if data.count < 21 {
                return
            }
            
            let idleData = data[1]
            if let data = idleData.1 {
                let policy: LottiePlayPolicy
                if value.jackpot && !played {
                    policy = .onceEnd
                } else {
                    policy = .onceToFrame(1)
                }
                let animation = LottieAnimation(compressed: data, key: LottieAnimationEntryKey(key: .media(idleData.2.id), size: size), cachePurpose: .none, playPolicy: policy, maximumFps: 60)
                self.idlePlayer.set(animation)
            }
            let pullData = data[2]
            if let data = pullData.1 {
                let animation = LottieAnimation(compressed: data, key: LottieAnimationEntryKey(key: .media(pullData.2.id), size: size), cachePurpose: .none, playPolicy: played ? .toEnd(from: .max) : .onceEnd, maximumFps: 60)
                self.pullPlayer.set(animation)
            }
            
            let indexes = value.packIndex
            
            
            
            var spinViews:[LottiePlayerView] = [self.spin1Player, self.spin2Player, self.spin3Player]
            
            for (i, index) in indexes.enumerated() {
                let view = spinViews[i]
                let spinData = data[index]
                if let data = spinData.1 {
                    let animation = LottieAnimation(compressed: data, key: LottieAnimationEntryKey(key: .media(spinData.2.id), size: size), cachePurpose: .none, playPolicy: spinPolicy, maximumFps: 60)
                    if sent && view.animation != nil {
                        view.animation?.triggerOn = (.first, { [weak view] in
                            view?.set(animation)
                        }, {})
                    } else {
                        view.set(animation)
                    }
                    if sent {
                        animation.onFinish = {
                            FastSettings.markDiceAsPlayed(parent)
                            if !played, value.is777, !parent.isIncoming(context.account, theme.bubbled) {
                                PlayConfetti(for: context.window)
                            }
                        }
                    }
                }
            }
            
        }))
        
        let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: size, boundingSize: size, intrinsicInsets: NSEdgeInsets())
        
        self.thumbView.setSignal(signal: cachedSlot(value: value, arguments: arguments, scale: self.backingScaleFactor), clearInstantly: true)
        //if !self.thumbView.isFullyLoaded {
        self.thumbView.setSignal(chatMessageSlotSticker(postbox: context.account.postbox, value: value, scale: self.backingScaleFactor, size: size), cacheImage: { result in
            cacheSlot(result, value: value, arguments: arguments, scale: System.backingScale)
        })
        self.thumbView.set(arguments: arguments)
        
        
        self.stateDisposable.set((self.spin1Player.state |> deliverOnMainQueue).start(next: { [weak self] state in
            guard let `self` = self else { return }
            switch state {
            case .playing:
                self.thumbView.isHidden = true
            case .stoped:
                switch spinPolicy {
                case .onceEnd:
                    self.thumbView.isHidden = true
                default:
                    self.thumbView.isHidden = false
                }
            default:
                break
            }
        }))

    }
    
    override func layout() {
        super.layout()
        _ = players.map {
            $0.frame = bounds
        }
        self.thumbView.frame = bounds
    }
    
}

