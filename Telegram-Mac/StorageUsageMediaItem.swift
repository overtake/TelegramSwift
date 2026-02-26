//
//  StorageUsageMediaItem.swift
//  Telegram
//
//  Created by Mike Renoir on 26.12.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import TGUIKit
import SwiftSignalKit
import Postbox
import TelegramMedia

final class StorageUsageMediaItem : GeneralRowItem {
    let context: AccountContext
    let message: Message
    fileprivate let toggle:(MessageId, Bool?)->Void
    fileprivate let getSelected: (MessageId)->Bool?
    fileprivate let preview: (Message)->Void
    fileprivate let _menuItems:()->[ContextMenuItem]
    
    private(set) var iconArguments:TransformImageArguments?
    private(set) var icon:TelegramMediaImage?
    private(set) var docIcon:CGImage?

    
    fileprivate let sizeLayout: TextViewLayout
    fileprivate let titleLayout: TextViewLayout
    fileprivate let dateLayout: TextViewLayout
    
    enum Mode {
        case media
        case audio
    }
    
    let mode: Mode
    
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, getSelected: @escaping(MessageId)->Bool?, message: Message, size: Int64, viewType: GeneralViewType, toggle:@escaping(MessageId, Bool?)->Void, preview: @escaping(Message)->Void, menuItems:@escaping()->[ContextMenuItem]) {
        self.context = context
        self.getSelected = getSelected
        self.message = message
        self.toggle = toggle
        self.preview = preview
        self._menuItems = menuItems
        
        self.sizeLayout = .init(.initialize(string: String.prettySized(with: size, round: true), color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1)
        
        let name: String
        if let _ = message.anyMedia as? TelegramMediaImage {
            name = strings().storageUsageMediaPhoto
            self.mode = .media
        } else if let file = message.anyMedia as? TelegramMediaFile {
            if file.isMusic {
                name = file.musicText.0
            } else if file.isVoice {
                name = strings().storageUsageMediaVoice
            } else if file.isInstantVideo {
                name = strings().storageUsageMediaVideoMessage
            } else if file.isVideo {
                name = strings().storageUsageMediaVideo
            } else {
                name = file.fileName ?? strings().storageUsageMediaFile
            }
            if file.isVoice || file.isMusic || file.isInstantVideo {
                self.mode = .audio
            } else {
                self.mode = .media
            }
        } else {
            name = strings().storageUsageMediaFile
            self.mode = .media
        }
        
        self.titleLayout = .init(.initialize(string: name, color: theme.colors.text, font: .medium(.text)), maximumNumberOfLines: 1)

        let dateFormatter = makeNewDateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short

        
        self.dateLayout = .init(.initialize(string: dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(message.timestamp))), color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1)

        super.init(initialSize, height: 42, stableId: stableId, viewType: viewType, inset: NSEdgeInsets())
        
        
        
        let iconImageRepresentation:TelegramMediaImageRepresentation?
        if let image = message.anyMedia as? TelegramMediaImage {
            iconImageRepresentation = smallestImageRepresentation(image.representations)
        } else if let file = message.anyMedia as? TelegramMediaFile {
            iconImageRepresentation = smallestImageRepresentation(file.previewRepresentations)
        } else {
            iconImageRepresentation = nil
        }
        
        let fileName: String = name
        
        var fileExtension: String = "file"
        if let range = fileName.range(of: ".", options: [.backwards]) {
            fileExtension = fileName[range.upperBound...].lowercased()
        }
        if fileExtension.length > 5 {
            fileExtension = "file"
        }
        docIcon = extensionImage(fileExtension: fileExtension)
        
        if let iconImageRepresentation = iconImageRepresentation, let mediaId = message.anyMedia?.id {
            iconArguments = TransformImageArguments(corners: ImageCorners(radius: .cornerRadius), imageSize: iconImageRepresentation.dimensions.size.aspectFilled(PeerMediaIconSize), boundingSize: PeerMediaIconSize, intrinsicInsets: NSEdgeInsets())
            icon = TelegramMediaImage(imageId: mediaId, representations: [iconImageRepresentation], immediateThumbnailData: iconImageRepresentation.immediateThumbnailData, reference: nil, partialReference: nil, flags: [])
        }
        
        _ = makeSize(initialSize.width)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        sizeLayout.measure(width: .greatestFiniteMagnitude)
        dateLayout.measure(width: width - 130 - sizeLayout.layoutSize.width)
        titleLayout.measure(width: width - 130 - sizeLayout.layoutSize.width)
        
        return true
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        return .single(_menuItems())
    }
    
    override func viewClass() -> AnyClass {
        return StorageUsageMediaItemView.self
    }
}


final class StorageUsageMediaItemView : GeneralContainableRowView, APDelegate {
    private let nameView = TextView()
    private let dateView = TextView()
    private let sizeView = TextView()
    
    private let content = View()
    
    
    private var preview: TransformImageView?
    private var audio:RadialProgressView?
    
    private let resourceDataDisposable = MetaDisposable()
    private var videoPlayer:GIFPlayerView?
    private var videoData: AVGifData? {
        didSet {
            updateAnimatableContent()
        }
    }

    private let previewSize = NSMakeSize(30, 30)

    
    private var selection: SelectingControl?

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        nameView.userInteractionEnabled = false
        dateView.userInteractionEnabled = false
        sizeView.userInteractionEnabled = false
        
        nameView.isSelectable = false
        dateView.isSelectable = false
        sizeView.isSelectable = false
        
        content.addSubview(self.nameView)
        content.addSubview(self.dateView)
                
        self.addSubview(self.content)
        self.addSubview(self.sizeView)

        
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Highlight)
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Normal)
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Hover)
        
        containerView.set(handler: { [weak self] _ in
            self?.action()
        }, for: .Click)

    }
    
    override var additionBorderInset: CGFloat {
        guard let item = item as? StorageUsageMediaItem else {
            return 0
        }
        if item.getSelected(item.message.id) != nil {
            return 30 + item.viewType.innerInset.left + 20 + item.viewType.innerInset.left
        } else {
            return 30 + item.viewType.innerInset.left
        }
    }
    
    private func action() {
        guard let item = item as? StorageUsageMediaItem else {
            return
        }
        if item.getSelected(item.message.id) != nil {
            item.toggle(item.message.id, nil)
        } else if let event = NSApp.currentEvent {
            showContextMenu(event)
        }
    }
    
    override func updateColors() {
        super.updateColors()
        let highlighted = containerView.controlState != .Highlight ? self.backdorColor : theme.colors.grayHighlight
        containerView.set(background: self.backdorColor, for: .Normal)
        containerView.set(background: highlighted, for: .Highlight)

    }
    
    
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        
        
        guard let item = item as? StorageUsageMediaItem else {
            return
        }
        
        var contentFrame: NSRect = containerView.bounds
        
        if item.getSelected(item.message.id) != nil {
            contentFrame = contentFrame.offsetBy(dx: item.viewType.innerInset.left + 20, dy: 0)
        }
        
        transition.updateFrame(view: content, frame: contentFrame)

        if let preview = preview {
            transition.updateFrame(view: preview, frame: preview.centerFrameY(x: item.viewType.innerInset.left))
        }
        if let audio = audio {
            transition.updateFrame(view: audio, frame: audio.centerFrameY(x: item.viewType.innerInset.left))
        }
        
        if let video = videoPlayer {
            transition.updateFrame(view: video, frame: video.centerFrameY(x: item.viewType.innerInset.left))
        }
        
        transition.updateFrame(view: sizeView, frame: sizeView.centerFrameY(x: containerView.frame.width - sizeView.frame.width - item.viewType.innerInset.right))
        

        transition.updateFrame(view: nameView, frame: CGRect(origin: CGPoint(x: item.viewType.innerInset.left + previewSize.width + item.viewType.innerInset.left, y: 4), size: nameView.frame.size))

        transition.updateFrame(view: dateView, frame: CGRect(origin: CGPoint(x: item.viewType.innerInset.left + previewSize.width + item.viewType.innerInset.left, y: content.frame.height - dateView.frame.height - 4), size: dateView.frame.size))

        if let control = self.selection {
            transition.updateFrame(view: control, frame: control.centerFrameY(x: item.viewType.innerInset.left))
        }
    
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        let previous = self.item as? StorageUsageMediaItem
        super.set(item: item, animated: animated)
        
        guard let item = item as? StorageUsageMediaItem else {
            return
        }
        dateView.update(item.dateLayout)
        sizeView.update(item.sizeLayout)
        nameView.update(item.titleLayout)
        
        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration: 0.2, curve: .easeInOut)
        } else {
            transition = .immediate
        }
        
        if let selected = item.getSelected(item.message.id) {
            let current: SelectingControl
            if let view = self.selection {
                current = view
            } else {
                let unselected: CGImage = item.customTheme?.unselectedImage ?? theme.icons.chatToggleUnselected
                let selected: CGImage = item.customTheme?.selectedImage ?? theme.icons.chatToggleSelected
                current = SelectingControl(unselectedImage: unselected, selectedImage: selected)
                self.selection = current
                
                containerView.addSubview(current, positioned: .below, relativeTo: content)
                current.centerY(x: item.viewType.innerInset.left)
                
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    current.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.3)
                }
            }
            current.set(selected: selected, animated: animated)
        } else if let view = self.selection {
            performSubviewRemoval(view, animated: animated)
            self.selection = nil
        }
        
        switch item.mode {
        case .media:
            
            if let view = self.audio {
                performSubviewRemoval(view, animated: animated)
                self.audio = nil
            }
            
            let updateIconImageSignal:Signal<ImageDataTransformation,NoError>
            if let icon = item.icon {
                updateIconImageSignal = chatWebpageSnippetPhoto(account: item.context.account, imageReference: ImageMediaReference.message(message: MessageReference(item.message), media: icon), scale: backingScaleFactor, small: true, autoFetchFullSize: false)
            } else {
                updateIconImageSignal = .complete()
            }
            
            let preview: TransformImageView
            if let view = self.preview {
                preview = view
            } else {
                preview = TransformImageView(frame: previewSize.bounds)
                content.addSubview(preview)
                self.preview = preview
            }
            
            if let icon = item.icon, let arguments = item.iconArguments {
                preview.setSignal(signal: cachedMedia(media: icon, arguments: arguments, scale: System.backingScale), clearInstantly: previous?.message.id != item.message.id)
            } else {
                preview.clear()
            }
            
            if !preview.isFullyLoaded {
                if !preview.hasImage {
                    preview.layer?.contents = item.docIcon
                }
                preview.setSignal(updateIconImageSignal, clearInstantly: false, animate: true, cacheImage: { result in
                    if let icon = item.icon, let arguments = item.iconArguments {
                        cacheMedia(result, media: icon, arguments: arguments, scale: System.backingScale)
                    }
                })
            }
            
            if let arguments = item.iconArguments {
                preview.set(arguments: arguments)
            }
        case .audio:
            if let view = self.preview {
                performSubviewRemoval(view, animated: animated)
                self.preview = nil
            }
            let audio: RadialProgressView
            if let view = self.audio {
                audio = view
            } else {
                audio = RadialProgressView()
                content.addSubview(audio)
                var frame = content.focus(previewSize)
                frame.origin.x = item.viewType.innerInset.left
                audio.frame = frame
                self.audio = audio
                audio.scaleOnClick = true
                audio.set(handler: { [weak self] _ in
                    if let item = self?.item as? StorageUsageMediaItem {
                        item.preview(item.message)
                    }
                }, for: .Click)
            }
            audio.userInteractionEnabled = item.getSelected(item.message.id) == nil
            
            if let file = item.message.anyMedia as? TelegramMediaFile, file.isInstantVideo {
                let current: GIFPlayerView
                if let view = self.videoPlayer {
                    current = view
                } else {
                    current = GIFPlayerView()
                    var frame = content.focus(previewSize)
                    frame.origin.x = item.viewType.innerInset.left
                    current.frame = frame
                    content.addSubview(current, positioned: .below, relativeTo: audio)
                    self.videoPlayer = current
                    current.layer?.cornerRadius = previewSize.height / 2
                }
                let image = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: file.previewRepresentations, immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
                
                current.setSignal( chatMessagePhoto(account: item.context.account, imageReference: ImageMediaReference.message(message: MessageReference(item.message), media: image), scale: backingScaleFactor))
                let arguments = TransformImageArguments(corners: ImageCorners(radius: 20), imageSize: previewSize, boundingSize: previewSize, intrinsicInsets: NSEdgeInsets())
                current.set(arguments: arguments)
                
                resourceDataDisposable.set((item.context.account.postbox.mediaBox.resourceData(file.resource) |> deliverOnResourceQueue |> map { data in return data.complete ?  AVGifData.dataFrom(data.path) : nil} |> deliverOnMainQueue).start(next: { [weak self] data in
                    self?.videoData = data
                }))
            } else {
                if let view = self.videoPlayer {
                    performSubviewRemoval(view, animated: animated)
                    self.videoPlayer = nil
                }
                self.videoData = nil
                resourceDataDisposable.set(nil)
            }
            
            self.checkState(animated: animated)
        }
        
        updateLayout(size: frame.size, transition: transition)

    }
    
    override func updateAnimatableContent() {
        videoPlayer?.set(data: window != nil && visibleRect != .zero ? videoData : nil)
    }
    
    func checkState(animated: Bool) {
        
        guard let item = item as? StorageUsageMediaItem, let audio = self.audio else {
            return
        }
        
        var activityBackground = theme.colors.accent
        var activityForeground = theme.colors.underSelectedColor
        
        if let media = item.message.anyMedia as? TelegramMediaFile, media.isInstantVideo {
            activityBackground = .blackTransparent
            activityForeground = .white
        }
        
        let play = theme.icons.storage_music_play
        let pause = theme.icons.storage_music_pause
        let inset = NSEdgeInsets(left: 3, top: 3)

        if let controller = item.context.sharedContext.getAudioPlayer(), let song = controller.currentSong {
            if song.entry.isEqual(to: item.message), case .playing = song.state {
                audio.theme = RadialProgressTheme(backgroundColor: activityBackground, foregroundColor: activityForeground, icon: pause, iconInset: inset)
                audio.state = .Icon(image: pause)
            } else {
                audio.theme = RadialProgressTheme(backgroundColor: activityBackground, foregroundColor: activityForeground, icon: play, iconInset: inset)
                audio.state = .Icon(image: play)
            }
        } else {
            audio.theme = RadialProgressTheme(backgroundColor: activityBackground, foregroundColor: activityForeground, icon: play, iconInset: inset)
            audio.state = .Icon(image: play)
        }
    }
    
    override func interactionContentView(for innerId: AnyHashable, animateIn: Bool ) -> NSView {
        return preview ?? audio ?? self
    }
    
    func songDidChanged(song: APSongItem, for controller: APController, animated: Bool) {
        checkState(animated: animated)
    }
    func songDidChangedState(song: APSongItem, for controller: APController, animated: Bool) {
        checkState(animated: animated)
    }
    
    func songDidStartPlaying(song:APSongItem, for controller:APController, animated: Bool) {
        checkState(animated: animated)
    }
    func songDidStopPlaying(song:APSongItem, for controller:APController, animated: Bool) {
        checkState(animated: animated)
    }
    func playerDidChangedTimebase(song:APSongItem, for controller:APController, animated: Bool) {
        checkState(animated: animated)
    }
    
    func audioDidCompleteQueue(for controller:APController, animated: Bool) {
        checkState(animated: animated)
    }
    
    deinit {
        resourceDataDisposable.dispose()
    }

}
