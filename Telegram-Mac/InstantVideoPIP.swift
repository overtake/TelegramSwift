//
//  InstantVideoPIP.swift
//  Telegram
//
//  Created by keepcoder on 22/05/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

enum InstantVideoPIPCornerAlignment {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

class InstantVideoPIPView : GIFContainerView {
    let playingProgressView: RadialProgressView = RadialProgressView(theme:RadialProgressTheme(backgroundColor: .clear, foregroundColor: NSColor.white.withAlphaComponent(0.8), lineWidth: 3), twist: false)

    override init() {
        super.init()
    }
    
    required init(frame frameRect: NSRect) {
        super.init()
        playingProgressView.userInteractionEnabled = false
    }
    
    override func viewDidMoveToWindow() {
        if let _ = window {
            playingProgressView.frame = bounds
            addSubview(playingProgressView)
        } else {
            playingProgressView.removeFromSuperview()
        }
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

class InstantVideoPIP: GenericViewController<InstantVideoPIPView>, APDelegate {
    private let controller:APController
    private weak var tableView:TableView?
    private var listener:TableScrollListener!
    
    private var currentMessage:Message? = nil
    private var scrollTime: TimeInterval = CFAbsoluteTimeGetCurrent()
    private var alignment:InstantVideoPIPCornerAlignment = .topRight
    private var isShown:Bool = false
    init(_ controller:APController, window:Window) {
        self.controller = controller
        
        super.init()
        listener = TableScrollListener({ [weak self] _ in
            self?.updateScrolled()
        })
        controller.add(listener: self)
        (controller.account.context.mainNavigation as? MajorNavigationController)?.add(listener: WeakReference(value: self))
    }
    
    override var window:Window? {
        return mainWindow
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer?.borderColor = NSColor.clear.cgColor
        view.layer?.borderWidth = 0
        view.autoresizingMask = [.maxYMargin, .minXMargin]
    }
    
    override func navigationWillChangeController() {
        if let controller = controller.account.context.mainNavigation?.controller as? ChatController {
            updateTableView(controller.genericView.tableView)
        } else {
            updateTableView(nil)
        }
    }
    
    
    private func updateScrolled() {
        
        scrollTime = CFAbsoluteTimeGetCurrent()
        let isAnimateScrolling = tableView?.clipView.isAnimateScrolling ?? false
        if !isAnimateScrolling {
            if let currentMessage = currentMessage {
                var needShow:Bool = true
                tableView?.enumerateVisibleViews(with: { view in
                    if let view = view as? ChatRowView, let item = view.item as? ChatRowItem {
                        if let stableId = item.stableId.base as? ChatHistoryEntryId {
                            if case .message(let message) = stableId {
                                if message.id == currentMessage.id {
                                    needShow = false
                                }
                            }
                        }
                    }
                })
                if needShow {
                    showIfNeeded(animated: !isShown)
                } else {
                    if isShown {
                        hide()
                    }
                }
            } else {
                hide()
            }
        }
    }
    
    deinit {
        tableView?.removeScroll(listener: listener)
        controller.remove(listener: self)
        window?.removeAllHandlers(for: self)
        if isShown {
            hide()
        }
    }
    
    func showIfNeeded(animated: Bool = true) {
        loadViewIfNeeded()
        isShown = true
        if let media = currentMessage?.media.first as? TelegramMediaFile {
            let signal:Signal<(TransformImageArguments) -> DrawingContext?, NoError>
            signal = chatWebpageSnippetPhoto(account: controller.account, photo: TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: media.previewRepresentations, reference: nil), scale: view.backingScaleFactor, small:true)
            genericView.update(with: media.resource, size: NSMakeSize(150, 150), viewSize: NSMakeSize(150, 150), account: controller.account, table: nil, iconSignal: signal)
        }

        if let contentView = window?.contentView, genericView.superview == nil {
            contentView.addSubview(genericView)
            genericView.layer?.cornerRadius = view.frame.width/2
            
         
            if genericView.frame.minX == 0 {
                if let contentView = window?.contentView {
                    switch alignment {
                    case .topRight:
                        genericView.setFrameOrigin(NSMakePoint(contentView.frame.width, contentView.frame.height - view.frame.height - 130))
                    case .topLeft:
                        genericView.setFrameOrigin(NSMakePoint(-genericView.frame.width, contentView.frame.height - view.frame.height - 130))
                    case .bottomRight:
                        genericView.setFrameOrigin(NSMakePoint(contentView.frame.width, 100))
                    case .bottomLeft:
                        genericView.setFrameOrigin(NSMakePoint(-genericView.frame.width, 100))
                    }
                }
            }

            alignToCorner(alignment)
        }
        
        var startDragPosition:NSPoint? = nil
        var startViewPosition:NSPoint = view.frame.origin
        window?.set(mouseHandler: { [weak self] (_) -> KeyHandlerResult in
            if let strongSelf = self, let _ = startDragPosition {
                if startViewPosition.x == strongSelf.view.frame.origin.x && startViewPosition.y == strongSelf.view.frame.origin.y {
                    globalAudio?.playOrPause()
                }
                startDragPosition = nil
                if let opacity = strongSelf.view.layer?.opacity, opacity < 0.5 {
                    globalAudio?.notifyCompleteQueue()
                    globalAudio?.cleanup()
                } else {
                    strongSelf.findCorner()
                }
                strongSelf.view._change(opacity: 1.0)
                
                return .invoked
            }
            return .rejected
        }, with: self, for: .leftMouseUp, priority: .high)
        
        window?.set(mouseHandler: { [weak self] (_) -> KeyHandlerResult in
            if let strongSelf = self, strongSelf.view._mouseInside() {
                startDragPosition = strongSelf.window?.mouseLocationOutsideOfEventStream
                startViewPosition = strongSelf.view.frame.origin
                
                return .invoked
            }
            return .rejected
        }, with: self, for: .leftMouseDown, priority: .high)
        
        window?.set(mouseHandler: { [weak self] (_) -> KeyHandlerResult in
            if let strongSelf = self, let startDragPosition = startDragPosition, let current = strongSelf.window?.mouseLocationOutsideOfEventStream, let frame = strongSelf.window?.contentView?.frame {
                let difference = NSMakePoint(startDragPosition.x - current.x, startDragPosition.y - current.y)
                let point = NSMakePoint(startViewPosition.x - difference.x, startViewPosition.y - difference.y)
                strongSelf.view.setFrameOrigin(point)
                
                if strongSelf.view.frame.maxX > frame.width {
                    let difference = strongSelf.view.frame.maxX - frame.width
                    strongSelf.view.layer?.opacity = (1.0 - Float(difference / strongSelf.view.frame.width))
                } else if point.x < 0 {
                    let difference = abs(point.x)
                    strongSelf.view.layer?.opacity = (1.0 - Float(difference / strongSelf.view.frame.width))
                } else {
                    strongSelf.view.layer?.opacity = 1.0
                }
                
                return .invoked
            }
            return .rejected
        }, with: self, for: .leftMouseDragged, priority: .high)
    }
    
    func hide(_ animated:Bool = true) {
        isShown = false
        if let contentView = window?.contentView, genericView.superview != nil {
            let point:NSPoint
            switch alignment {
            case .topRight:
                point = NSMakePoint(contentView.frame.width, contentView.frame.height - view.frame.height - 130)
            case .topLeft:
                point = NSMakePoint(-view.frame.width, contentView.frame.height - view.frame.height - 130)
            case .bottomRight:
                point = NSMakePoint(contentView.frame.width, 100)
            case .bottomLeft:
                point = NSMakePoint(-view.frame.width, 100)
            }
            
            genericView.change(pos: point, animated: animated, completion: { [weak view] completed in
                view?.removeFromSuperview()
            })
        }
        
        window?.removeAllHandlers(for: self)
    }
    
    func alignToCorner(_ corner:InstantVideoPIPCornerAlignment, _ animated: Bool = true) {
        if let contentView = window?.contentView {
            switch corner {
            case .topRight:
                genericView.change(pos: NSMakePoint(contentView.frame.width - view.frame.width - 20, contentView.frame.height - view.frame.height - 130), animated: animated)
            case .topLeft:
                genericView.change(pos: NSMakePoint(20, contentView.frame.height - view.frame.height - 130), animated: animated)
            case .bottomRight:
                genericView.change(pos: NSMakePoint(contentView.frame.width - view.frame.width - 20, 100), animated: animated)
            case .bottomLeft:
                genericView.change(pos: NSMakePoint(20, 100), animated: animated)
            }
        }
        
    }
    
    func findCorner() {
        if let contentView = window?.contentView {
            let center = NSMakePoint(contentView.frame.width/2, contentView.frame.height/2)
            let viewCenterPoint = NSMakePoint(view.frame.origin.x + view.frame.width/2, view.frame.origin.y + view.frame.height/2)
            if viewCenterPoint.x > center.x {
                if viewCenterPoint.y > center.y {
                    alignment = .topRight
                } else {
                    alignment = .bottomRight
                }
            } else {
                if viewCenterPoint.y > center.y {
                    alignment = .topLeft
                } else {
                    alignment = .bottomLeft
                }
            }
            alignToCorner(alignment)
        }
    }
    
    func updateTableView(_ tableView:TableView?) {
        self.tableView?.removeScroll(listener: listener)
        self.tableView = tableView
        self.tableView?.addScroll(listener: listener)
        updateScrolled()
    }
    
    
    
    func songDidChanged(song:APSongItem, for controller:APController) {
        var msg:Message? = nil
        switch song.entry {
        case let .song(message):
            if let md = (message.media.first as? TelegramMediaFile), md.isInstantVideo {
                msg = message
            }
        default:
            break
        }
        
        if let msg = msg {
            if let currentMessage = currentMessage, !isShown && currentMessage.id != msg.id, CFAbsoluteTimeGetCurrent() - scrollTime > 1.0 {
                if let item = tableView?.item(stableId: msg.chatStableId) {
                    tableView?.scroll(to: .center(id: item.stableId, innerId: nil, animated: true, focus: false, inset: 0))
                }
            }
            
            currentMessage = msg
            genericView.timebase = controller.timebase
            
        } else {
            currentMessage = nil
            genericView.player.reset(with: nil)
        }
        updateScrolled()
    }
    func songDidChangedState(song: APSongItem, for controller: APController) {
        switch song.state {
        case let .playing(data):
            genericView.playingProgressView.state = .ImpossibleFetching(progress: Float(data.progress), force: false)
        case .stoped, .waiting, .fetching:
            genericView.playingProgressView.state = .None
        case let .paused(data):
            genericView.playingProgressView.state = .ImpossibleFetching(progress: Float(data.progress), force: true)
        }
    }
    func songDidStartPlaying(song:APSongItem, for controller:APController) {
        
    }
    func songDidStopPlaying(song:APSongItem, for controller:APController) {
        if song.stableId == currentMessage?.chatStableId {
            genericView.timebase = nil
        }
    }
    func playerDidChangedTimebase(song:APSongItem, for controller:APController) {
        if song.stableId == currentMessage?.chatStableId {
            genericView.timebase = controller.timebase
        }
    }

    func audioDidCompleteQueue(for controller:APController) {
        hide()
    }
    
}
