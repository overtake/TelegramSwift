//
//  GIFContainerView.swift
//  TelegramMac
//
//  Created by keepcoder on 24/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import TGUIKit
import PostboxMac
import SwiftSignalKitMac
class GIFContainerView: Control {

    let player:GIFPlayerView = GIFPlayerView()
    private var progressView:RadialProgressView?
    var playerInset:NSEdgeInsets = NSEdgeInsets() {
        didSet {
            self.needsLayout = true
        }
    }
    private let statusDisposable = MetaDisposable()
    private let fetchDisposable = MetaDisposable()
    private let playerDisposable = MetaDisposable()
    
    private var reference:MediaResourceReference?
    private var context: AccountContext?
    private var size:NSSize = NSZeroSize
    private var ignoreWindowKey: Bool = false
    private weak var tableView:TableView?
    var timebase:CMTimebase? {
        didSet {
            player.reset(with: timebase, false)
        }
    }
    private var data:AVGifData? {
        didSet {
            updatePlayerIfNeeded()
        }
    }
    
    override init() {
        super.init()
        addSubview(player)
        self.backgroundColor = .clear
        self.layer?.borderWidth = 1.5
        //self.layer?.cornerRadius = 4.0
        player.background = .clear
        player.setVideoLayerGravity(.resizeAspectFill)
        set(handler: { [weak self] control in
            if let `self` = self, let window = self.window as? Window, let table = self.tableView, let context = self.context {
                _ = startModalPreviewHandle(table, window: window, context: context)
            }
        }, for: .LongMouseDown)
        
    }
    
    
    required convenience init(frame frameRect: NSRect) {
        self.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func clean() {
        fetchDisposable.dispose()
        statusDisposable.dispose()
        playerDisposable.dispose()
        removeNotificationListeners()
    }
    
    func cancel() {
        fetchDisposable.set(nil)
        statusDisposable.set(nil)
    }
    
    func cancelFetching() {
        if let reference = reference {
            context?.account.postbox.mediaBox.cancelInteractiveResourceFetch(reference.resource)
        }
    }
    
    
    func fetch() {
        if let context = context, let reference = reference {
            fetchDisposable.set(fetchedMediaResource(postbox: context.account.postbox, reference: reference, statsCategory: .file).start())
        }
    }
    
 
    
    func removeNotificationListeners() {
        NotificationCenter.default.removeObserver(self)
    }
    
    
    @objc func updatePlayerIfNeeded() {
        
        
        
        let wAccept = window != nil && (window!.isKeyWindow || self.ignoreWindowKey)  && !NSIsEmptyRect(visibleRect)
        var accept:Bool = false

        if let window = window {
            var points:[NSPoint] = []
            
            points.append(convert(focus(NSMakeSize(1, 1)).origin, to: window.contentView))
            points.append(convert(NSMakePoint(1, 1), to: window.contentView))
            points.append(convert(NSMakePoint(frame.width - 1, frame.height - 1), to: window.contentView))
            
            
            for point in points {
                if let hit = window.contentView?.hitTest(point) {
                    accept = wAccept && (hit == self.player || hit == self)
                    if !accept && wAccept, let hit = hit as? Control {
                        accept = !hit.userInteractionEnabled
                    }
                }
                if accept {
                    break
                }
            }
            
            
            
        }
        
        if !ignoreWindowKey {
            var s:Signal<Void, Void> = .single(Void())
            if accept {
                s = s |> delay(0.1, queue: Queue.mainQueue())
            }
            playerDisposable.set(s.start(next: {[weak self] (next) in
                if let strongSelf = self {
                    strongSelf.player.set(data: accept ? strongSelf.data : nil, timebase: strongSelf.timebase)
                }
            }))
        } else {
             player.set(data: accept ? data : nil, timebase: timebase)
        }
        
    }
    
    
    func updateListeners() {
        removeNotificationListeners()
        if let window = window {
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSWindow.didBecomeKeyNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSWindow.didResignKeyNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSView.boundsDidChangeNotification, object: tableView?.clipView)
        }
    }
    deinit {
        playerDisposable.dispose()
    }
    
    override func viewDidMoveToWindow() {
        updateListeners()
        updatePlayerIfNeeded()
    }
    
    func update(with reference: MediaResourceReference, size: NSSize, viewSize:NSSize, file: TelegramMediaFile?, context: AccountContext, table: TableView?, ignoreWindowKey: Bool = false, iconSignal:Signal<(TransformImageArguments)->DrawingContext?, NoError>) {
        let updated = self.reference == nil || !self.reference!.resource.id.isEqual(to: reference.resource.id)
        self.tableView = table
        self.context = context
        self.reference = reference
        self.size = size
        self.setFrameSize(size)
        self.ignoreWindowKey = ignoreWindowKey
        self.layer?.borderColor = theme.colors.background.cgColor
        
        updateListeners()
        player.setFrameSize(viewSize)
        
        player.center()
        progressView?.center()
        let imageSize = viewSize.aspectFitted(NSMakeSize(size.width, size.height))
        let arguments = TransformImageArguments(corners: ImageCorners(radius:2.0), imageSize: (file?.dimensions ?? imageSize).aspectFilled(viewSize), boundingSize: imageSize, intrinsicInsets: NSEdgeInsets())

        if let file = file {
            player.setSignal(signal: cachedMedia(media: file, arguments: arguments, scale: backingScaleFactor), clearInstantly: updated)
            if updated {
                player.set(data: nil, timebase: nil)
                player.reset()
            }
        }
        player.animatesAlphaOnFirstTransition = !player.hasImage

        
        player.setSignal(iconSignal, cacheImage: { [weak file] image in
            if let file = file {
                return cacheMedia(signal: image, media: file, arguments: arguments, scale: System.backingScale)
            } else {
                return .complete()
            }
        })


        player.set(arguments: arguments)
        
        let updatedStatusSignal = context.account.postbox.mediaBox.resourceStatus(reference.resource)
        
        self.statusDisposable.set((combineLatest(updatedStatusSignal, context.account.postbox.mediaBox.resourceData(reference.resource) |> deliverOnResourceQueue |> map { data in return data.complete ?  AVGifData.dataFrom(data.path) : nil}) |> deliverOnMainQueue).start(next: { [weak self] status, data in
            if let strongSelf = self {
                if case .Local = status {
                    
                    if let progressView = strongSelf.progressView {
                        progressView.state = .Fetching(progress: 1.0, force: false)

                        strongSelf.progressView = nil
                        progressView.layer?.animateAlpha(from: 1, to: 0, duration: 0.25, timingFunction: .linear, removeOnCompletion: false, completion: { [weak progressView] completed in
                            if completed {
                                progressView?.removeFromSuperview()
                            }
                        })
                    }
                    
                    strongSelf.data = data
                    
                } else {
                    if strongSelf.progressView == nil {
                        let progressView = RadialProgressView()
                        progressView.frame = CGRect(origin: CGPoint(), size: CGSize(width: 40.0, height: 40.0))
                        strongSelf.progressView = progressView
                        strongSelf.addSubview(progressView)
                        strongSelf.progressView?.center()
                    }
                }
                
                strongSelf.progressView?.fetchControls = FetchControls(fetch: { [weak strongSelf] in
                    switch status {
                    case .Fetching:
                        strongSelf?.cancelFetching()
                    case .Remote:
                        strongSelf?.fetch()
                    default:
                        break
                    }
                })
                
                switch status {
                case let .Fetching(_, progress):
                    strongSelf.progressView?.state = .Fetching(progress: progress, force: false)
                case .Local:
                    strongSelf.progressView?.state = .Play
                case .Remote:
                    strongSelf.progressView?.state = .Remote
                }
            }
        }))

        
        fetch()
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        progressView?.center()
    }
    
    override func copy() -> Any {
        let view = View()
        view.backgroundColor = .clear
        let layer:CALayer = CALayer()
        layer.frame = NSMakeRect(0, visibleRect.minY == 0 ? 0 :  player.visibleRect.height - player.frame.height, player.frame.width,  player.frame.height)
        layer.contents = player.layer?.contents
        layer.masksToBounds = true
        view.frame = player.visibleRect
        layer.shouldRasterize = true
        layer.rasterizationScale = backingScaleFactor
        view.layer?.addSublayer(layer)
        return view
    }

    
}
