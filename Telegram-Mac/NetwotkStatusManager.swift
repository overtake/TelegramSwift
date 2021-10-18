//
//  ConnectingStatusController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 07.10.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox

private enum Status : Equatable {
    case core(ConnectionStatus)
    case updated
    case connected
    
    var text: String {
        switch self {
        case .connected:
            return L10n.connectionStatusConnected
        case .updated:
            return L10n.connectionStatusUpdated
        case let .core(status):
            switch status {
            case let .connecting(proxyAddress, _):
                return proxyAddress != nil ? L10n.connectionStatusConnectingToProxy : L10n.connectionStatusConnecting
            case .waitingForNetwork:
                return L10n.connectionStatusWaitingForNetwork
            case .updating:
                return L10n.connectionStatusUpdating
            case .online:
                return ""
            }
        }
    }
    
    var shouldAddProgress: Bool {
        switch self {
        case .connected:
            return false
        case .updated:
            return false
        case let .core(status):
            switch status {
            case .connecting:
                return true
            case .waitingForNetwork:
                return true
            case .updating:
                return true
            case .online:
                return false
            }
        }
    }
    
    func color(_ window: NSWindow) -> NSColor {
        switch self {
        case .connected:
            return theme.colors.accent
        case .updated:
            return theme.colors.accent
        case let .core(status):
            switch status {
            case .connecting:
                return window.backgroundColor
            case .waitingForNetwork:
                return window.backgroundColor
            case .updating:
                return window.backgroundColor
            case .online:
                return window.backgroundColor
            }
        }
    }
    func textColor(_ window: NSWindow) -> NSColor {
        switch self {
        case .connected, .updated:
            return theme.colors.underSelectedColor
        default:
            if let superview = window.standardWindowButton(.closeButton)?.superview, !theme.dark {
                let view = ObjcUtils.findElements(byClass: "NSTextField", in: superview).first as? NSTextField
                return view?.textColor ?? theme.colors.grayText
            }
            return theme.colors.grayText
        }
    }
}

private final class ConnectingStatusView: View {
    private let textView: TextView = TextView()
    private let visualEffect: VisualEffect
    private let container = View()
    private var progressView: InfiniteProgressView?
    private let imageView: ImageView
    private var backgroundView: ImageView?
    
    private var status: Status?
    
        
    required init(frame frameRect: NSRect) {
        self.visualEffect = VisualEffect(frame: frameRect.size.bounds)
        self.imageView = ImageView(frame: frameRect.size.bounds)
        super.init(frame: frameRect)
        autoresizingMask = [.width, .height]
        addSubview(imageView)
        addSubview(self.visualEffect)
        addSubview(container)
        container.addSubview(textView)
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        
    
    }
    
    
    override func layout() {
        super.layout()
    
        textView.resize(frame.width - 80)
        textView.center()
        if let progressView = self.progressView {
            progressView.centerY(x: 0)
            textView.centerY(x: progressView.frame.maxX + 5)
        } else {
            textView.center()
        }
        self.container.center()
        self.imageView.center()
        self.visualEffect.frame = bounds
        self.backgroundView?.frame = bounds
        updateAnimation()
    }
    
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateAnimation() {
        let animation = makeSpringAnimation("transform")
        
        let to: CGFloat = (frame.width - 40) / imageView.frame.width
        let from: CGFloat = 0.1

        var fr = CATransform3DIdentity
        fr = CATransform3DTranslate(fr, floorToScreenPixels(System.backingScale, imageView.frame.width / 2), floorToScreenPixels(System.backingScale, imageView.frame.height / 2), 0)
        fr = CATransform3DScale(fr, from, from, 1)
        fr = CATransform3DTranslate(fr, -floorToScreenPixels(System.backingScale, imageView.frame.width / 2), -floorToScreenPixels(System.backingScale, imageView.frame.height / 2), 0)
        
        animation.timingFunction = .init(name: .easeInEaseOut)
        animation.fromValue = NSValue(caTransform3D: fr)
        animation.toValue = to
        animation.fillMode = .forwards
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.beginTime = self.imageView.layer!.convertTime(CACurrentMediaTime(), from: nil)
        let speed: Float = 1.0
        animation.speed = speed * Float(animation.duration / 1.0)
        
        var tr = CATransform3DIdentity
        tr = CATransform3DTranslate(tr, floorToScreenPixels(System.backingScale, imageView.frame.width / 2), floorToScreenPixels(System.backingScale, imageView.frame.height / 2), 0)
        tr = CATransform3DScale(tr, to, to, 1)
        tr = CATransform3DTranslate(tr, -floorToScreenPixels(System.backingScale, imageView.frame.width / 2), -floorToScreenPixels(System.backingScale, imageView.frame.height / 2), 0)
        animation.toValue = NSValue(caTransform3D: tr)

        imageView.layer?.add(animation, forKey: "transform")
    }
    
    func set(_ status: Status, animated: Bool) {
        self.status = status
        let text: String = status.text
        
        guard let window = appDelegate?.window else {
            return
        }

        let layout = TextViewLayout(.initialize(string: text, color: status.textColor(window), font: .bold(.text)))
        layout.measure(width: frame.width - 80)
        textView.update(layout)
        
        let backgroundView = ImageView(frame: bounds)
        
        backgroundView.image = generateImage(frame.size, contextGenerator: { size, ctx in
            ctx.clear(size.bounds)
            ctx.setFillColor(status.color(window).cgColor)
            ctx.round(size, size.height / 2)
            ctx.fill(size.bounds)
        })
        if self.backgroundView != nil {
            self.addSubview(backgroundView, positioned: .above, relativeTo: self.backgroundView)
        } else {
            self.addSubview(backgroundView, positioned: .below, relativeTo: self.subviews.first)
        }
        if animated && self.backgroundView != nil {
            let current = self.backgroundView
            backgroundView.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 1.2, completion: { [weak current] _ in
                current?.removeFromSuperview()
            })
        } else {
            self.backgroundView?.removeFromSuperview()
        }
        self.backgroundView = backgroundView
        
        
        imageView.image = generateImage(frame.size, contextGenerator: { size, ctx in
            ctx.clear(size.bounds)
            ctx.setFillColor(NSColor.black.withAlphaComponent(0.08).cgColor)
            ctx.round(size, size.height / 2)
            ctx.fill(size.bounds)
        })
        imageView.sizeToFit()
        
        updateAnimation()
        
        self.visualEffect.bgColor = .clear
        
        if status.shouldAddProgress {
            if self.progressView == nil {
                let progressView: InfiniteProgressView = .init(color: status.textColor(window), lineWidth: 2.0)
                self.progressView = progressView
                progressView.progress = nil
                progressView.setFrameSize(NSMakeSize(layout.layoutSize.height - 3, layout.layoutSize.height - 3))
                self.container.addSubview(progressView)
            }
            self.progressView?.color = status.textColor(window)
            self.container.setFrameSize(NSMakeSize(layout.layoutSize.width + progressView!.frame.width + 5, max(progressView!.frame.height, layout.layoutSize.height)))
        } else {
            self.progressView?.removeFromSuperview()
            self.progressView = nil
            self.container.setFrameSize(NSMakeSize(layout.layoutSize.width, layout.layoutSize.height))
        }
        
        needsLayout = true
    }
}

final class NetworkStatusManager {
    private let account: Account
    private let sharedContext: SharedAccountContext
    private let window: Window
    private let disposable = MetaDisposable()
    
    private var currentView: ConnectingStatusView?
    private var backgroundView: View?
    init(account: Account, window: Window, sharedContext: SharedAccountContext) {
        self.account = account
        self.window = window
        self.sharedContext = sharedContext
        initialize()
    }
    
    func initialize() {
        
        let updating: Signal<Bool, NoError> = account.stateManager.isUpdating |> mapToSignal { isUpdating in
            return isUpdating ? .single(isUpdating) |> delay(1.0, queue: .mainQueue()) : .single(isUpdating)
        }
        
        let connecting: Signal<ConnectionStatus, NoError> = account.network.connectionStatus |> mapToSignal { status in
            switch status {
            case .online:
                return .single(status)
            default:
                return .single(status) |> delay(1.0, queue: .mainQueue())
            }
        }
        
        let fakeStatus: ValuePromise<ConnectionStatus?> = ValuePromise(nil)
        
        let previousStatus: Atomic<ConnectionStatus> = Atomic(value: .online(proxyAddress: nil))
        
        let connectionStatus: Signal<Status?, NoError> = combineLatest(queue: .mainQueue(), connecting, updating, fakeStatus.get()) |> deliverOnMainQueue |> map { status, isUpdating, fakeStatus -> ConnectionStatus in
            var status = fakeStatus ?? status
            switch status {
            case let .online(proxyAddress):
                if isUpdating {
                    status = .updating(proxyAddress: proxyAddress)
                }
            default:
                break
            }
            return status
        } |> mapToQueue { coreStatus in
            let previous = previousStatus.swap(coreStatus)
            
            if previous != coreStatus {
                switch coreStatus {
                case .online:
                    switch previous {
                    case .connecting, .waitingForNetwork:
                        return .single(.connected) |> then(.single(nil) |> delay(1.5, queue: .mainQueue()))
                    case .updating:
                        return .single(.updated) |> then(.single(nil) |> delay(1.5, queue: .mainQueue()))
                    default:
                        return .single(nil)
                    }
                default:
                    return .single(.core(coreStatus))
                }
            } else {
                return .complete()
            }
        }
        |> deliverOnMainQueue
        |> distinctUntilChanged
                
        disposable.set(combineLatest(connectionStatus, appearanceSignal, window.fullScreen).start(next: { [weak self] status, _, _ in
            self?.updateStatus(status, animated: true)
        }))
//        #if DEBUG
//        window.set(handler: { _ in
//            let statuses:[ConnectionStatus] = [.waitingForNetwork, .connecting(proxyAddress: nil, proxyHasConnectionIssues: false), .online(proxyAddress: nil), .updating(proxyAddress: nil)]
//            fakeStatus.set(statuses.randomElement()!)
//            return .rejected
//        }, with: window, for: .A)
//        #endif
    }
    
    private func updateStatus(_ status: Status?, animated: Bool) {
        guard let windowView = windowView else {
            return
        }

        if #available(macOS 10.14, *) {
            if let status = status {
                                
                let view: ConnectingStatusView = self.currentView ?? .init(frame: windowView.superview.bounds)
                view.set(status, animated: animated)
                
                if animated, self.currentView == nil {
                    view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }

                
                self.currentView = view
                windowView.superview.addSubview(view, positioned: .below, relativeTo: windowView.aboveView)
                
                window.title = ""
                
                if self.backgroundView == nil {
                    self.backgroundView = View(frame: view.bounds)
                    self.backgroundView?.autoresizingMask = [.width, .height]
                }
                windowView.superview.addSubview(self.backgroundView!, positioned: .below, relativeTo: view)
                self.backgroundView?.backgroundColor = status.color(window)
            } else {
                if let view = self.backgroundView {
                    performSubviewRemoval(view, animated: animated)
                    self.backgroundView = nil
                }
                if let view = currentView {
                    performSubviewRemoval(view, animated: animated)
                    self.currentView = nil
                }
                window.title = appName
            }
        }
    }
    
    
    struct WindowView {
        let superview: NSView
        let aboveView: NSView?
    }
    var windowView: WindowView? {
        guard let title = self.window.titleView ?? self.currentView?.superview else {
            return nil
        }
        
        let subviews = title.subviews
        for subview in subviews {
            if subview == window.standardWindowButton(.closeButton) {
                return .init(superview: title, aboveView: subview)
            }
        }
        return nil
    }
    
    deinit {
        cleanup()
    }
    
    func cleanup() {
        disposable.dispose()
        self.updateStatus(nil, animated: false)
    }
}
