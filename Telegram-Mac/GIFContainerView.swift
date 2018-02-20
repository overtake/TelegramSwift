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
class GIFContainerView: View {

    private(set) var player:GIFPlayerView = GIFPlayerView()
    private var progressView:RadialProgressView?
    var playerInset:NSEdgeInsets = NSEdgeInsets() {
        didSet {
            self.needsLayout = true
        }
    }
    private let statusDisposable = MetaDisposable()
    private let fetchDisposable = MetaDisposable()
    private let playerDisposable = MetaDisposable()
    
    private var resource:TelegramMediaResource?
    private var account:Account?
    private var size:NSSize = NSZeroSize
    private weak var tableView:TableView?
    var timebase:CMTimebase? {
        didSet {
            player.reset(with: timebase, false)
        }
    }
    private var path:String? {
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
        if let resource = resource {
            account?.postbox.mediaBox.cancelInteractiveResourceFetch(resource)
        }
    }
    
    
    func fetch() {
        if let account = account, let resource = resource {
            fetchDisposable.set(account.postbox.mediaBox.fetchedResource(resource, tag: TelegramMediaResourceFetchTag(statsCategory: .file)).start())
        }
    }
    
 
    
    func removeNotificationListeners() {
        NotificationCenter.default.removeObserver(self)
    }
    
    
    @objc func updatePlayerIfNeeded() {
        
        
        
        let wAccept = window != nil && window!.isKeyWindow && !NSIsEmptyRect(visibleRect)
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
        player.set(path: accept ? path : nil, timebase: timebase)
        
        
        /*var s:Signal<Void, Void> = .single()
        s = s |> delay(0.01, queue: Queue.mainQueue())
        playerDisposable.set(s.start(next: {[weak self] (next) in
            if let strongSelf = self {
                let accept = strongSelf.window != nil && strongSelf.window!.isKeyWindow && !NSIsEmptyRect(strongSelf.visibleRect)
                strongSelf.player.set(path: accept ? strongSelf.path : nil)
            }
        })) */
        
    }
    
    
    func updateListeners() {
        if let window = window {
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSWindow.didBecomeKeyNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSWindow.didResignKeyNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSView.boundsDidChangeNotification, object: tableView?.clipView)
        } else {
            removeNotificationListeners()
        }
    }
    deinit {
        playerDisposable.dispose()
    }
    
    override func viewDidMoveToWindow() {
        updateListeners()
        updatePlayerIfNeeded()
    }
    
    func update(with resource: TelegramMediaResource, size: NSSize, viewSize:NSSize, account: Account, table: TableView?, iconSignal:Signal<(TransformImageArguments)->DrawingContext?,Void>) {
        
        self.tableView = table
        self.account = account
        self.resource = resource
        self.size = size
        self.setFrameSize(size)
        
        self.layer?.borderColor = theme.colors.background.cgColor
        
        updateListeners()
        player.setFrameSize(viewSize)
        
        player.center()
        progressView?.center()
        
        player.setSignal( iconSignal)
        let imageSize = viewSize.aspectFitted(NSMakeSize(size.width, size.height - 8))

        let arguments = TransformImageArguments(corners: ImageCorners(radius:2.0), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: NSEdgeInsets())
        player.set(arguments: arguments)
        
        let updatedStatusSignal = account.postbox.mediaBox.resourceStatus(resource)
        
        self.statusDisposable.set((combineLatest(updatedStatusSignal, account.postbox.mediaBox.resourceData(resource)) |> deliverOnMainQueue).start(next: { [weak self] (status,resource) in
            if let strongSelf = self {
                if case .Local = status {
                    strongSelf.progressView?.removeFromSuperview()
                    strongSelf.progressView = nil
                    strongSelf.path = resource.path
                    
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
