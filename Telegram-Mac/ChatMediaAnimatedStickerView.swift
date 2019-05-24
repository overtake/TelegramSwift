//
//  ChatMediaAnimatedSticker.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 13/05/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import PostboxMac
import TelegramCoreMac
import TGUIKit
import SwiftSignalKitMac
import Lottie

class ChatMediaAnimatedStickerView: ChatMediaContentView {

    private let loadResourceDisposable = MetaDisposable()
    
    private var animatedView: AnimationView = AnimationView()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(animatedView)
        
        
        animatedView.background = .random
        //animatedView.shouldRasterizeWhenIdle = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    deinit {
        loadResourceDisposable.dispose()
        animatedView.stop()
    }
    
    func removeNotificationListeners() {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidUpdatedDynamicContent() {
        super.viewDidUpdatedDynamicContent()
        updatePlayerIfNeeded()
    }
    
    @objc func updatePlayerIfNeeded() {
        
        let accept = parameters?.autoplay == true && window != nil && window!.isKeyWindow && !NSIsEmptyRect(visibleRect) && !self.isDynamicContentLocked

        if accept {
            animatedView.play(fromFrame: 0, toFrame: .greatestFiniteMagnitude, loopMode: LottieLoopMode.loop, completion: { _ in
                
            })
        } else {
            animatedView.stop()
            animatedView.currentTime = 0
        }
        
    }
    
    
    
    func updateListeners() {
        if let window = window {
            NotificationCenter.default.removeObserver(self)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSWindow.didBecomeKeyNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSWindow.didResignKeyNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSView.boundsDidChangeNotification, object: table?.clipView)
        } else {
            removeNotificationListeners()
        }
    }
    
    override func willRemove() {
        super.willRemove()
        updateListeners()
        updatePlayerIfNeeded()
    }
    
    override func viewDidMoveToWindow() {
        updateListeners()
        updatePlayerIfNeeded()
    }
    
    override func update(with media: Media, size: NSSize, context: AccountContext, parent: Message?, table: TableView?, parameters: ChatMediaLayoutParameters?, animated: Bool, positionFlags: LayoutPositionFlags?, approximateSynchronousValue: Bool) {
        
        super.update(with: media, size: size, context: context, parent: parent, table: table, parameters: parameters, animated: animated, positionFlags: positionFlags, approximateSynchronousValue: approximateSynchronousValue)
     
        
        guard let file = media as? TelegramMediaFile else { return }
        
        let loadingSignal:Signal<Animation?, NoError> = context.account.postbox.mediaBox.resourceData(file.resource) |> deliverOn(graphicsThreadPool) |> map { data in
            if data.complete {
                return Animation.filepath(data.path, animationCache: LRUAnimationCache.sharedCache)
            } else {
                return nil
            }
        } |> deliverOnMainQueue
        
        
        loadResourceDisposable.set(loadingSignal.start(next: { [weak self] animation in
            self?.animatedView.animation = animation
            self?.updatePlayerIfNeeded()
        }))
        _ = fileInteractiveFetched(account: context.account, fileReference: parent != nil ? FileMediaReference.message(message: MessageReference(parent!), media: file) : FileMediaReference.standalone(media: file)).start()
        
    }
    
    override func layout() {
        super.layout()
        self.animatedView.frame = bounds

    }
    
}
