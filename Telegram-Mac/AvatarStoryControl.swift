//
//  AvatarStoryControl.swift
//  Telegram
//
//  Created by Mike Renoir on 18.07.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import Postbox
import TGUIKit
import SwiftSignalKit

final class AvatarStoryControl : Control {
    
    private var loadingStatuses = Bag<Disposable>()


    
    let avatar: AvatarControl
    fileprivate var indicator: AvatarStoryIndicatorComponent.IndicatorView?

    var contentUpdated: ((Any?)->Void)? {
        didSet {
            self.avatar.contentUpdated = { [weak self] anyValue in
                self?.contentUpdated?(anyValue)
            }
        }
    }
    func callContentUpdater() {
        self.contentUpdated?(avatar.imageContents)
    }
    
    required init(font: NSFont, size: NSSize) {
        self.avatar = .init(font: font)
        super.init(frame: size.bounds)
        addSubview(self.avatar)
        self.avatar.userInteractionEnabled = false
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    required init(frame frameRect: NSRect) {
        self.avatar = .init(font: .avatar(frameRect.height / 2))
        super.init(frame: frameRect)
        addSubview(self.avatar)
        self.avatar.userInteractionEnabled = false
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    func setState(account: Account, state: AvatarNodeState) {
        self.avatar.setState(account: account, state: state)
    }
    func setSignal(_ signal: Signal<(CGImage?, Bool), NoError>, force: Bool = true) {
        self.avatar.setSignal(signal, force: force)
    }
    
    func setPeer(account: Account, peer: Peer?, message: Message? = nil, size: NSSize? = nil, disableForum: Bool = false, cornerRadius: CGFloat? = nil, forceMonoforum: Bool = false) {
        self.avatar.setPeer(account: account, peer: peer, message: message, size: size, disableForum: disableForum, cornerRadius: cornerRadius, forceMonoforum: forceMonoforum)
    }
    
    
    func update(component: AvatarStoryIndicatorComponent?, availableSize: CGSize, progress: CGFloat = 1.0, transition: ContainedViewLayoutTransition)  {
        
        if let component = component {
            let isNew: Bool
            let current: AvatarStoryIndicatorComponent.IndicatorView
            if let view = self.indicator {
                current = view
                isNew = false
            } else {
                current = AvatarStoryIndicatorComponent.IndicatorView(frame: NSMakeSize(availableSize.width + 6, availableSize.height + 6).bounds)
                self.indicator = current
                self.addSubview(current, positioned: .below, relativeTo: avatar)
                isNew = true
            }
            current.update(component: component, availableSize: availableSize, transition: .immediate, displayProgress: !self.loadingStatuses.isEmpty)
            
            if transition.isAnimated, isNew {
                current.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.2, bounce: false)
                current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            }
        } else if let indicator = self.indicator {
            performSubviewRemoval(indicator, animated: transition.isAnimated)
            self.indicator = nil
        }
        self.updateLayout(size: frame.size, transition: transition)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        if let indicator = self.indicator {
            transition.updateFrame(view: self.avatar, frame: size.bounds.insetBy(dx: 3, dy: 3))
            transition.updateFrame(view: indicator, frame: size.bounds)
        } else {
            transition.updateFrame(view: self.avatar, frame: size.bounds)
        }
    }
    
    
    var radius: CGFloat {
        if self.indicator != nil {
            return (frame.height - 6 ) / 2
        } else {
            return frame.height / 2
        }
    }
    
    var photoRect: NSRect {
        return self.avatar.frame
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: frame.size, transition: .immediate)
    }
    
    
    func cancelLoading() {
        for disposable in self.loadingStatuses.copyItems() {
            disposable.dispose()
        }
        self.loadingStatuses.removeAll()
        self.updateStoryIndicator(transition: .immediate)
    }
    
    deinit {
        cancelLoading()
    }
    
    func pushLoadingStatus(signal: Signal<Never, NoError>) -> Disposable {
        let disposable = MetaDisposable()
        
        let loadingStatuses = self.loadingStatuses
        
        for d in loadingStatuses.copyItems() {
            d.dispose()
        }
        loadingStatuses.removeAll()
        
        let index = loadingStatuses.add(disposable)
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2, execute: { [weak self] in
            self?.updateStoryIndicator(transition: .animated(duration: 0.2, curve: .easeOut))
        })
        
        disposable.set(signal.start(completed: { [weak self] in
            Queue.mainQueue().async {
                loadingStatuses.remove(index)
                if loadingStatuses.isEmpty {
                    self?.updateStoryIndicator(transition: .animated(duration: 0.2, curve: .easeOut))
                }
            }
        }))
        
        return ActionDisposable { [weak self] in
            loadingStatuses.get(index)?.dispose()
            loadingStatuses.remove(index)
            if loadingStatuses.isEmpty {
                self?.updateStoryIndicator(transition: .animated(duration: 0.2, curve: .easeOut))
            }
        }
    }

    private func updateStoryIndicator(transition: ContainedViewLayoutTransition) {
        if let indicator = self.indicator, let component = indicator.component, let availableSize = indicator.availableSize {
            indicator.update(component: component, availableSize: availableSize, progress: indicator.progress ?? 1.0, transition: transition, displayProgress: !self.loadingStatuses.isEmpty)
        }
    }
}
