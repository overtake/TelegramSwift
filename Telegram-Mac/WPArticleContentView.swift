//
//  WPArticleContentView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 18/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac


class WPArticleContentView: WPContentView {
    private var durationView:VideoDurationView?
    private var progressIndicator:ProgressIndicator?
    private(set) var imageView:TransformImageView?
    private var playIcon:ImageView?
    private let openExternalDisposable:MetaDisposable = MetaDisposable()
    private let loadingStatusDisposable: MetaDisposable = MetaDisposable()
    private var countAccessoryView: ChatMessageAccessoryView?
    override var backgroundColor: NSColor {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
   
    
    required public init() {
        super.init()
    }
    
    deinit {
        openExternalDisposable.dispose()
        loadingStatusDisposable.dispose()
    }
    
    override func viewDidMoveToSuperview() {
        if superview == nil {
            openExternalDisposable.set(nil)
            progressIndicator?.removeFromSuperview()
            progressIndicator?.animates = false
        } else if let progressIndicator = progressIndicator {
            imageView?.addSubview(progressIndicator)
            progressIndicator.animates = true
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    func open() {
        if let content = content?.content, let layout = self.content, let window = kitWindow {
            if ExternalVideoLoader.isPlayable(content) {
                
                openExternalDisposable.set((sharedVideoLoader.status(for: content) |> deliverOnMainQueue).start(next: { (status) in
                    if let status = status {
                        switch status {
                        case .fail:
                            execute(inapp: .external(link: content.url, false))
                        case .loaded:
                            showChatGallery(account: layout.account, message: layout.parent, layout.table)
                        default:
                            break
                        }
                    }
                }))
                
                _ = sharedVideoLoader.fetch(for: content).start()
                return
            }
            if content.embedType == "iframe" {
                showModal(with: WebpageModalController(content:content,account:layout.account), for: window)
            } else if layout.isGalleryAssemble {
                showChatGallery(account: layout.account, message: layout.parent, layout.table, type: .alone)
            } else {
                execute(inapp: .external(link: content.url, false))
            }

        }
    }
    
    override func mouseUp(with event: NSEvent) {
        if let imageView = imageView, imageView._mouseInside(), event.clickCount == 1 {
            open()
        } else {
            super.mouseUp(with: event)
        }
    }

    
    
    override func update(with layout: WPLayout) {
        
        if let layout = layout as? WPArticleLayout {
            if ExternalVideoLoader.isPlayable(layout.content) {
                loadingStatusDisposable.set((sharedVideoLoader.status(for: layout.content) |> deliverOnMainQueue).start(next: { [weak self] status in
                    if let status = status , let strongSelf = self {
                        switch status {
                        case .fetching:
                            if strongSelf.progressIndicator == nil {
                                strongSelf.progressIndicator = ProgressIndicator(frame: NSMakeRect(0, 0, 25, 25))
                               // self?.progressIndicator?.set(color: .white)
                                strongSelf.imageView?.addSubview((strongSelf.progressIndicator)!)
                            }
                            strongSelf.progressIndicator?.animates = true
                        default:
                            strongSelf.progressIndicator?.animates = false
                            strongSelf.progressIndicator?.removeFromSuperview()
                            strongSelf.progressIndicator = nil
                        }
                        strongSelf.needsLayout = true
                    }
                }))
            } else {
                progressIndicator?.animates = false
                progressIndicator?.removeFromSuperview()
                progressIndicator = nil
            }
            
            
            var updateImageSignal:Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
            if self.content?.content.image != layout.content.image {
                if let image = layout.content.image {
                    updateImageSignal = chatWebpageSnippetPhoto(account: layout.account, photo: image, scale: backingScaleFactor, small:layout.smallThumb)
                    
                    if imageView == nil {
                        imageView = TransformImageView()
                        imageView?.alphaTransitionOnFirstUpdate = true
                        self.addSubview(imageView!)
                    }
                    
                    if ExternalVideoLoader.isPlayable(layout.content) {
                        if playIcon == nil {
                            playIcon = ImageView()
                            imageView?.addSubview(playIcon!)
                        }
                        playIcon?.image = ExternalVideoLoader.playIcon(layout.content)
                        playIcon?.sizeToFit()
                    } else {
                        playIcon?.removeFromSuperview()
                        playIcon = nil
                    }
                    
                    if let arguments = layout.imageArguments {
                        imageView?.set(arguments: arguments)
                        imageView?.setSignal(signal: cachedMedia(media: image, size: arguments.imageSize, scale: backingScaleFactor))
                        
                        if let updateImageSignal = updateImageSignal, imageView?.layer?.contents == nil  {
                                imageView?.setSignal(updateImageSignal, cacheImage: { [weak self] signal in
                                    if let strongSelf = self {
                                        return cacheMedia(signal: signal, media: image, size: arguments.imageSize, scale: strongSelf.backingScaleFactor)
                                    } else {
                                        return .complete()
                                    }
                                })
                            }
                        }
                    
                } else {
                    imageView?.removeFromSuperview()
                    imageView = nil
                }
            }
            

            if let durationNode = layout.duration {
                if durationView == nil {
                    durationView = VideoDurationView(durationNode)
                    imageView?.addSubview(durationView!)
                } else {
                    durationView?.updateNode(durationNode)
                }
                durationView?.sizeToFit()
            } else {
                durationView?.removeFromSuperview()
                durationView = nil
            }
            
            if let mediaCount = layout.mediaCount {
                if countAccessoryView == nil {
                    countAccessoryView = ChatMessageAccessoryView(frame: NSZeroRect)
                    imageView?.addSubview(countAccessoryView!)
                }
                countAccessoryView?.updateText(tr(.chatWebpageMediaCount(1, mediaCount)), maxWidth: 30)
            } else {
                countAccessoryView?.removeFromSuperview()
                countAccessoryView = nil
            }
           
        }
        
        super.update(with: layout)
        
    }
    
    override func layout() {
        super.layout()
        
        if let layout = self.content as? WPArticleLayout {
            
            if !textView.isEqual(to: layout.textLayout) {
                textView.update(layout.textLayout)
            }
            
            playIcon?.isHidden = progressIndicator != nil
            
            if let imageView = imageView {
                
                progressIndicator?.center()
                
                if let arguments = layout.imageArguments {
                    imageView.set(arguments: arguments)
                    imageView.setFrameSize(arguments.boundingSize)
                }
                
                var origin:NSPoint = NSMakePoint(layout.contentRect.width - imageView.frame.width - 10, 0)
                
                if layout.textLayout?.cutout == nil {
                    var y:CGFloat = 0
                    if let textLayout = layout.textLayout {
                        y += textLayout.layoutSize.height + 6.0
                    }
                    origin = NSMakePoint(0, y)
                }
                
                imageView.setFrameOrigin(origin.x, origin.y)
                playIcon?.center()
                
                if let durationView = durationView {
                    durationView.setFrameOrigin(imageView.frame.width - durationView.frame.width - 10, imageView.frame.height - durationView.frame.height - 10)
                }
                if let countAccessoryView = countAccessoryView {
                    countAccessoryView.setFrameOrigin(imageView.frame.width - countAccessoryView.frame.width - 10, 10)
                }
            }
        }
       
        
    }
    
    override func interactionContentView(for innerId: AnyHashable ) -> NSView {
        return self.imageView ?? self
    }
    
   
    
}
