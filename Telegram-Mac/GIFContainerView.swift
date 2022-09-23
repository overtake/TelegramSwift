//
//  GIFContainerView.swift
//  TelegramMac
//
//  Created by keepcoder on 24/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore

import TGUIKit
import Postbox
import SwiftSignalKit



class GIFContainerView: Control {

    let player:GifPlayerBufferView = GifPlayerBufferView()

    
    private var progressView:RadialProgressView?
    var playerInset:NSEdgeInsets = NSEdgeInsets() {
        didSet {
            self.needsLayout = true
        }
    }
    private let statusDisposable = MetaDisposable()
    private let fetchDisposable = MetaDisposable()
    private let playerDisposable = MetaDisposable()
    
    private var context: AccountContext?
    private var size:NSSize = NSZeroSize
    private var ignoreWindowKey: Bool = false
    private weak var tableView:TableView?
    
    var associatedMessageId: MessageId? = nil
    private var fileReference: FileMediaReference?

    private var shimmer: ShimmerLayer?

    override init() {
        
        
        super.init()
      //  addSubview(player)
        self.backgroundColor = .clear
        
        

        player.background = .clear
        player.setVideoLayerGravity(.resizeAspectFill)
        set(handler: { [weak self] control in
            if let `self` = self, let window = self.window as? Window, let table = self.tableView, let context = self.context {
                startModalPreviewHandle(table, window: window, context: context)
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
        if let reference = fileReference {
            context?.account.postbox.mediaBox.cancelInteractiveResourceFetch(reference.media.resource)
        }
    }
    
    
    func fetch() {
        if let context = context, let reference = fileReference {
            fetchDisposable.set(fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: reference.resourceReference(reference.media.resource), statsCategory: .file).start())
        }
    }
    
    func removeNotificationListeners() {
        NotificationCenter.default.removeObserver(self)
    }
    
    
    var accept: Bool {
        let wAccept = window != nil && (window!.isKeyWindow || self.ignoreWindowKey)  && !NSIsEmptyRect(visibleRect)
        let accept:Bool = wAccept
        return accept
    }
    
    
    @objc func updatePlayerIfNeeded() {
        
        let accept = self.accept
        
        if !ignoreWindowKey {
            var s:Signal<Void, Void> = .single(Void())
            if accept {
                s = s |> delay(0.05, queue: Queue.mainQueue())
            }
            playerDisposable.set(s.start(next: {[weak self] (next) in
                if let strongSelf = self {
                    strongSelf.player.ticking = accept
                }
            }))
        } else {
            playerDisposable.set(nil)
            self.player.ticking = accept
        }
        
    }
    
    
    func updateListeners() {
        if let window = window {
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSWindow.didBecomeKeyNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSWindow.didResignKeyNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSView.boundsDidChangeNotification, object: tableView?.clipView)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSView.frameDidChangeNotification, object: tableView?.view)
        } else {
            removeNotificationListeners()
        }
    }
    deinit {
        playerDisposable.dispose()
        removeNotificationListeners()
    }
    
    override func viewDidMoveToWindow() {
        updateListeners()
        updatePlayerIfNeeded()
    }
    
    
    func update(with fileReference: FileMediaReference, size: NSSize, viewSize:NSSize, context: AccountContext, table: TableView?, ignoreWindowKey: Bool = false, isPreview: Bool = false, iconSignal:Signal<ImageDataTransformation, NoError>) {
        
        
        let updated = self.fileReference == nil || !fileReference.media.isEqual(to: self.fileReference!.media)
        
        self.tableView = table
        self.fileReference = fileReference
        self.context = context
        self.size = size
        self.setFrameSize(size)
        self.ignoreWindowKey = ignoreWindowKey
        self.layer?.borderColor = theme.colors.background.cgColor
        
        player.setFrameSize(viewSize)
        player.center()
        progressView?.center()
        
        player.update(fileReference, context: context)
        
        
        let imageSize = viewSize.aspectFitted(NSMakeSize(size.width, size.height))
        let size = (fileReference.media.dimensions?.size ?? imageSize).aspectFilled(viewSize)
        let arguments = TransformImageArguments(corners: ImageCorners(radius:2.0), imageSize: size, boundingSize: imageSize, intrinsicInsets: NSEdgeInsets())
        
        player.setSignal(signal: cachedMedia(media: fileReference.media, arguments: arguments, scale: backingScaleFactor), clearInstantly: updated)
        
        if true {
            let current: ShimmerLayer
            if let layer = self.shimmer {
                current = layer
            } else {
                current = ShimmerLayer()
                self.layer?.addSublayer(current)
                self.shimmer = current
            }
            current.update(backgroundColor: nil, data: nil, size: size, imageSize: size, cornerRadius: 0)
            current.updateAbsoluteRect(size.bounds, within: size)
            current.frame = size.bounds
        } else {
            self.removePlaceholder(animated: true)

        }
        
        if !player.isFullyLoaded {
            player.setSignal(iconSignal, cacheImage: { [weak self] result in
                cacheMedia(result, media: fileReference.media, arguments: arguments, scale: System.backingScale)
                //self?.removePlaceholder(animated: false)
            })
        }
        
        player.set(arguments: arguments)
        
        updatePlayerIfNeeded()
        
        fetch()
        
        needsLayout = true
    }
    
    private func removePlaceholder(animated: Bool) {
        if let shimmer = self.shimmer {
            if animated {
                shimmer.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak shimmer] _ in
                    shimmer?.removeFromSuperlayer()
                })
            } else {
                shimmer.removeFromSuperlayer()
            }
            self.shimmer = nil
        }
    }
    
    override func layout() {
        super.layout()
        progressView?.center()
        updatePlayerIfNeeded()
        let size = frame.size
        shimmer?.frame = size.bounds
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
