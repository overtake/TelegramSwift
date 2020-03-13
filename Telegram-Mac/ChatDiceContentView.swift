//
//  ChatDiceContentView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 27.02.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import Postbox
import TelegramCore
import SyncCore
import TGUIKit
import SwiftSignalKit
private let diceSide1: String = "1️⃣"
private let diceSide2: String = "2️⃣"
private let diceSide3: String = "3️⃣"
private let diceSide4: String = "4️⃣"
private let diceSide5: String = "5️⃣"
private let diceSide6: String = "6️⃣"

private extension Int32 {
    var diceSide: String {
        switch self {
        case 1:
            return diceSide1
        case 2:
            return diceSide2
        case 3:
            return diceSide3
        case 4:
            return diceSide4
        case 5:
            return diceSide5
        case 6:
            return diceSide6
        default:
            preconditionFailure()
        }
    }
}


private enum DicePlay : Equatable {
    case idle
    case failed
    case end(animated: Bool)
}

private struct DiceState : Equatable {
    let messageId: MessageId
    let play: DicePlay
    
    init(message: Message) {
        self.messageId = message.id
        if let dice = message.media.first as? TelegramMediaDice, dice.value == 0 {
            play = .idle
        } else if message.forwardInfo != nil {
            play = .end(animated: false)
        } else {
            if message.flags.contains(.Failed) {
                self.play = .failed
            } else if message.flags.isSending {
                play = .idle
            } else {
                if !FastSettings.diceHasAlreadyPlayed(message.id) {
                    play = .end(animated: true)
                } else {
                    play = .end(animated: false)
                }
            }
        }
        
    }
}

class ChatDiceContentView: ChatMediaContentView {
    private let playerView: LottiePlayerView = LottiePlayerView(frame: NSMakeRect(0, 0, 240, 240))
    private let thumbView = TransformImageView()
    private let loadResourceDisposable = MetaDisposable()
    private let stateDisposable = MetaDisposable()
    private var diceState: DiceState?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(self.playerView)
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
        guard let window = self.kitWindow else {
            return
        }
        alert(for: window, info: L10n.chatDiceResult)
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
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSView.boundsDidChangeNotification, object: self.enclosingScrollView?.contentView)
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
    
    override func update(with media: Media, size: NSSize, context: AccountContext, parent: Message?, table: TableView?, parameters: ChatMediaLayoutParameters?, animated: Bool, positionFlags: LayoutPositionFlags?, approximateSynchronousValue: Bool) {
        
        
        super.update(with: media, size: size, context: context, parent: parent, table: table, parameters: parameters, animated: animated, positionFlags: positionFlags, approximateSynchronousValue: approximateSynchronousValue)
        
        guard let media = media as? TelegramMediaDice, let parent = parent else {
            return
        }
        
        let currentValue = media.value
        let idleSticker: LocalAnimatedSticker = .dice_idle
       
        let diceState = DiceState(message: parent)
        
        if self.diceState != diceState {
            
            self.diceState = diceState
            
                
            let data: Signal<(Data, TelegramMediaFile), NoError>
            if let currentValue = currentValue, currentValue > 0 && currentValue <= 6 {
                data = context.diceCache.diceData(currentValue.diceSide, synchronous: approximateSynchronousValue)
            } else {
                data = Signal { subscriber in
                    let resource = idleSticker.file.resource as! LocalBundleResource
                    if let path = Bundle.main.path(forResource: resource.name, ofType: resource.ext), let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedRead]) {
                        subscriber.putNext((data, idleSticker.file))
                        subscriber.putCompletion()
                    }
                    return EmptyDisposable
                } |> runOn(resourcesQueue)
            }
            
            
            
            self.loadResourceDisposable.set((data |> deliverOnMainQueue).start(next: { [weak self] data in
                guard let `self` = self else {
                    return
                }
                let playPolicy: LottiePlayPolicy
                
                switch diceState.play {
                case .failed:
                    playPolicy = .framesCount(1)
                case .idle:
                    playPolicy = .loop
                case let .end(animated):
                    if !animated {
                        playPolicy = .toEnd(from: 179)
                    } else {
                        let currentFrame = self.playerView.currentFrame ?? 0
                        playPolicy = .toEnd(from: currentFrame)
                    }
                }
                let animation = LottieAnimation(compressed: data.0, key: LottieAnimationEntryKey(key: .media(data.1.id), size: size), cachePurpose: .none, playPolicy: playPolicy, maximumFps: 60)
                animation.onFinish = {
                    if case .end = diceState.play {
                        FastSettings.markDiceAsPlayed(parent.id)
                    }
                }
                self.playerView.set(animation)
                if let currentValue = currentValue, currentValue > 0 && currentValue <= 6 {
                    let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: size, boundingSize: size, intrinsicInsets: NSEdgeInsets())

                    self.thumbView.setSignal(signal: cachedMedia(media: data.1, arguments: arguments, scale: self.backingScaleFactor), clearInstantly: true)
                    if !self.thumbView.isFullyLoaded {
                        self.thumbView.setSignal(chatMessageDiceSticker(postbox: context.account.postbox, file: data.1, value: currentValue.diceSide, scale: self.backingScaleFactor, size: size), cacheImage: { result in
                            cacheMedia(result, media: data.1, arguments: arguments, scale: System.backingScale)
                        })
                        self.thumbView.set(arguments: arguments)
                    } else {
                        self.thumbView.dispose()
                    }
                    
                    self.stateDisposable.set((self.playerView.state |> deliverOnMainQueue).start(next: { [weak self] state in
                        guard let `self` = self else { return }
                        switch state {
                        case .playing:
                            self.playerView.isHidden = false
                            self.thumbView.isHidden = true
                        default:
                            self.playerView.isHidden = false
                            self.thumbView.isHidden = false
                        }
                    }))
                } else {
                    self.thumbView.image = nil
                    self.stateDisposable.set(nil)
                }
                
                
                
            }))
            
           
            
        }
        
       
        
    }
    
    override func layout() {
        super.layout()
        self.playerView.frame = bounds
        self.thumbView.frame = bounds
    }
    
}
