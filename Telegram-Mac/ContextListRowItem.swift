//
//  ContextListRowItem.swift
//  TelegramMac
//
//  Created by keepcoder on 23/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac
import PostboxMac



class ContextListRowItem: TableRowItem {

    let result:ChatContextResult
    let results:ChatContextResultCollection
    private let _index:Int64
    let account:Account
    let iconSignal:Signal<(TransformImageArguments)->DrawingContext?,Void>
    let arguments:TransformImageArguments?
    var textLayout:(TextNodeLayout, TextNode)?
    let capImage:CGImage?
    var fileResource:TelegramMediaResource?
    let chatInteraction:ChatInteraction
    var audioWrapper:APSingleWrapper?
    private var vClass:AnyClass = ContextListImageView.self
    private let text:NSAttributedString
    override var stableId: AnyHashable {
        return Int64(_index)
    }
    
    init(_ initialSize: NSSize, _ results:ChatContextResultCollection, _ result:ChatContextResult, _ index:Int64, _ account:Account, _ chatInteraction:ChatInteraction) {
        self.result = result
        self.results = results
        self.chatInteraction = chatInteraction
        self._index = index
        self.account = account
        var representation: TelegramMediaImageRepresentation?
        var iconText:NSAttributedString? = nil
        switch result {
            //    case externalReference(id: String, type: String, title: String?, description: String?, url: String?, content: TelegramMediaWebFile?, thumbnail: TelegramMediaWebFile?, message: ChatContextResultMessage)

        case let .externalReference(_, type, title, description, url, content, thumbnail, _):
            if let thumbnail = thumbnail {
                representation = TelegramMediaImageRepresentation(dimensions: NSMakeSize(50, 50), resource: thumbnail.resource)
            }
            if let content = content {
                if content.mimeType.hasPrefix("audio") {
                    vClass = ContextListAudioView.self
                    audioWrapper = APSingleWrapper(resource: content.resource, name: title, performer: description, id: result.maybeId)
                } else if content.mimeType == "video/mp4" {
                    vClass = ContextListGIFView.self
                }
            }
            var selectedUrl: String?
            if let url = url {
                selectedUrl = url
            }
            if let selectedUrl = selectedUrl, let parsedUrl = URL(string: selectedUrl) {
                if let host = parsedUrl.host, !host.isEmpty {
                    iconText = NSAttributedString.initialize(string: host.substring(to: host.index(after: host.startIndex)).uppercased(), color: .white, font: .medium(25.0))
                }
            }
        case let .internalReference(_, _, title, description, image, file, _):
            if let file = file {
                fileResource = file.resource
                if file.isMusic || file.isVoice {
                    vClass = ContextListAudioView.self
                    audioWrapper = APSingleWrapper(resource: fileResource!, name: title, performer: description, id:result.maybeId)
                } else if file.isVideo && file.isAnimated {
                    vClass = ContextListGIFView.self
                }
            }
            if let image = image {
                representation = smallestImageRepresentation(image.representations)
            } else if let file = file {
                representation = smallestImageRepresentation(file.previewRepresentations)
            }
        }
        
        
        
        if let representation = representation {
            let tmpImage = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [representation], reference: nil)
            iconSignal = chatWebpageSnippetPhoto(account: account, photo: tmpImage, scale: 2.0, small:true)
            
            let iconSize = representation.dimensions.aspectFilled(CGSize(width: 50, height: 50))
            
            let imageCorners = ImageCorners(topLeft: .Corner(2.0), topRight: .Corner(2.0), bottomLeft: .Corner(2.0), bottomRight: .Corner(2.0))
            arguments = TransformImageArguments(corners: imageCorners, imageSize: representation.dimensions, boundingSize: iconSize, intrinsicInsets: NSEdgeInsets())
            iconText = nil
        } else {
            arguments = nil
            iconSignal = .complete()
            
            if iconText == nil {
                if let title = result.title, !title.isEmpty {
                    let titleText = title.substring(to: title.index(after: title.startIndex)).uppercased()
                    iconText = .initialize(string: titleText, color: .white, font: .medium(25.0))
                }
            }
        }

        if let iconText = iconText {
            capImage = capIcon(for: iconText)
        } else {
            capImage = nil
        }
        
        

        let attr:NSMutableAttributedString = NSMutableAttributedString()
        var title:String = "Untitled"
        if let t = result.title {
            title = t
        }
        _ = attr.append(string: title , color: theme.colors.text, font: .medium(.text))
        if let description = result.description {
            _ = attr.append(string:"\n")
            _ = attr.append(string: description, color: theme.colors.grayText, font: NSFont.normal(FontSize.text))
        }
        attr.addAttribute(.selectedColor, value: NSColor.white, range: attr.range)

        self.text = attr.copy() as! NSAttributedString
        super.init(initialSize)
        prepare(isSelected)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        prepare(isSelected)
        return super.makeSize(width, oldWidth: oldWidth)
    }
    
    override func prepare(_ selected: Bool) {
        textLayout = TextNode.layoutText(maybeNode: nil,  text, nil, 3, .end, NSMakeSize(width - textInset.left - textInset.right, height), nil, selected, .left)
    }
    
    override var height: CGFloat {
        return 60
    }
    
    let textInset:NSEdgeInsets = NSEdgeInsets(left:70, right:10, top:10)
    
    override func viewClass() -> AnyClass {
        return vClass
    }
}

class ContextListRowView : TableRowView {

    override var backdorColor: NSColor {
        return item?.isSelected ?? false ? theme.colors.blueSelect : theme.colors.background
    }
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        if let item = item as? ContextListRowItem {
            
            if !item.isSelected && item.index != item.table!.count - 1 {
                ctx.setFillColor(theme.colors.border.cgColor)
                ctx.fill(NSMakeRect(item.textInset.left, frame.height - .borderSize, frame.width - item.textInset.left, .borderSize))
            }
            
            if let layout = item.textLayout {
                let f = focus(layout.0.size)
                layout.1.draw(NSMakeRect(item.textInset.left, f.minY, layout.0.size.width, layout.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
            }
            
        }
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        needsDisplay = true
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
}

class ContextListImageView : TableRowView {
    let image:TransformImageView = TransformImageView()
    required init(frame frameRect: NSRect) {
        super.init(frame:frameRect)
        image.setFrameSize(NSMakeSize(50, 50))
        addSubview(image)
    }
    
    override var backdorColor: NSColor {
        return item?.isSelected ?? false ? theme.colors.blueSelect : theme.colors.background
    }
    
    override func layout() {
        super.layout()
        if let item = item as? ContextListRowItem, let arguments = item.arguments {
            image.set(arguments: arguments)
        }
        image.centerY(x:10)
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        if let item = item as? ContextListRowItem {
            
            if !item.isSelected && item.index != item.table!.count - 1 {
                ctx.setFillColor(theme.colors.border.cgColor)
                ctx.fill(NSMakeRect(item.textInset.left, frame.height - .borderSize, frame.width - item.textInset.left, .borderSize))
            }
            
            if let layout = item.textLayout {
                let f = focus(layout.0.size)
                layout.1.draw(NSMakeRect(item.textInset.left, f.minY, layout.0.size.width, layout.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
            }
            needsLayout = true
        }
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        let updated = self.item != item
        super.set(item: item)
        
        if let item = item as? ContextListRowItem, updated {
            if let capImage = item.capImage {
                self.image.layer?.contents = capImage
            } else {
                image.setSignal( item.iconSignal)
            }
        }
        needsDisplay = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class ContextListGIFView : ContextListRowView {
    private let player:GIFContainerView = GIFContainerView()
 
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        player.setFrameSize(NSMakeSize(50, 50))
        addSubview(player)
    }
    
    override func layout() {
        super.layout()
        player.centerY(x:10)
    }
    

    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        let updated = self.item != item
        super.set(item: item, animated: animated)
        
        if let item = item as? ContextListRowItem, updated, let resource = item.fileResource {
            player.update(with: resource, size: NSMakeSize(50,50), viewSize: NSMakeSize(50,50), account: item.account, table: item.table, iconSignal: item.iconSignal)
            player.needsLayout = true
        }
    }
}



class ContextListAudioView : ContextListRowView, APDelegate {
    let progressView:RadialProgressView = RadialProgressView()
    private let statusDisposable = MetaDisposable()
    private let fetchDisposable = MetaDisposable()
    private var fetchStatus:MediaResourceStatus?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        progressView.state = .Play
        progressView.fetchControls = FetchControls(fetch: { [weak self] in
            self?.checkOperation()
        })
        addSubview(progressView)
    }
    
    func checkOperation() {
        
        if let item = item as? ContextListRowItem, let status = fetchStatus {
            switch status {
            case .Fetching(progress: _):
                break
            case .Local, .Remote:
                if let wrapper = item.audioWrapper {
                    if let controller = globalAudio, let song = controller.currentSong, song.entry.isEqual(to: wrapper) {
                        controller.playOrPause()
                    } else {
                        let controller = APSingleResourceController(account: item.account, wrapper: wrapper, streamable: false)
                        controller.add(listener: self)
                        item.chatInteraction.inlineAudioPlayer(controller)
                        controller.start()
                    }
                }
               
                break
                
            }
        }
    }
    
    func songDidChanged(song: APSongItem, for controller: APController) {
        checkState()
    }
    func songDidChangedState(song: APSongItem, for controller: APController) {
        checkState()
    }
    
    func songDidStartPlaying(song:APSongItem, for controller:APController) {
        
    }
    func songDidStopPlaying(song:APSongItem, for controller:APController) {
        
    }
    func playerDidChangedTimebase(song:APSongItem, for controller:APController) {
        
    }
    
    func audioDidCompleteQueue(for controller:APController) {
        
    }
    
    func checkState() {
        if let item = item as? ContextListRowItem, let wrapper = item.audioWrapper, let controller = globalAudio, let song = controller.currentSong {
            if song.entry.isEqual(to: wrapper), case .playing = song.state {
                progressView.theme = RadialProgressTheme(backgroundColor: theme.colors.blueFill, foregroundColor: .white, icon: theme.icons.chatMusicPause, iconInset:NSEdgeInsets(left:1))
            } else {
                progressView.theme = RadialProgressTheme(backgroundColor: theme.colors.blueFill, foregroundColor: .white, icon: theme.icons.chatMusicPlay, iconInset:NSEdgeInsets(left:1))
            }
        } else {
            progressView.theme = RadialProgressTheme(backgroundColor: theme.colors.blueFill, foregroundColor: .white, icon: theme.icons.chatMusicPlay, iconInset:NSEdgeInsets(left:1))
        }
    }
    
    override func layout() {
        super.layout()
        progressView.centerY(x:10)
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        let updated = self.item != item
        super.set(item: item, animated: animated)
        
        if let item = item as? ContextListRowItem, updated, let resource = item.fileResource {
            
            let updatedStatusSignal = item.account.postbox.mediaBox.resourceStatus(resource) |> deliverOnMainQueue

            statusDisposable.set(updatedStatusSignal.start(next: { [weak self] status in
                if let strongSelf = self {
                    strongSelf.fetchStatus = status
                    switch status {
                    case let .Fetching(_, progress):
                        strongSelf.progressView.state = .Fetching(progress: progress, force: false)
                    case .Local:
                        strongSelf.progressView.state = .Play
                    case .Remote:
                        strongSelf.progressView.state = .Play
                    }
                }
            }))
            checkState()

        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        globalAudio?.remove(listener: self)
        statusDisposable.dispose()
        fetchDisposable.dispose()
    }
}

