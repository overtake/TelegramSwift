//
//  GroupCallTileView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 10.05.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit


struct VoiceChatTile {
    fileprivate(set) var rect: NSRect
    fileprivate(set) var index: Int
    
    var bestQuality: PresentationGroupCallRequestedVideo.Quality {
        let option = min(rect.width, rect.height)
        if option > 500 {
            return .full
        } else if option > 160 {
            return .medium
        } else {
            return .thumbnail
        }
    }
}


func tileViews(_ count: Int, isFullscreen: Bool, frameSize: NSSize, pinnedIndex: Int? = nil) -> [VoiceChatTile] {
    
    var tiles:[VoiceChatTile] = []
    let minSize: NSSize = NSMakeSize(240, 135)
    
    func optimalCellSize(_ size: NSSize, count: Int) -> (size: NSSize, cols: Int, rows: Int) {
        var size: NSSize = frameSize
        var cols: Int = 2
        while true {
            if count == 0 {
                return (size: size, cols: 0, rows: 0)
            } else if count == 1 {
                return (size: size, cols: 1, rows: 1)
            } else if count == 2 {
                if !isFullscreen {
                    return (size: NSMakeSize(frameSize.width / 2, frameSize.height), cols: 2, rows: 1)
                } else {
                    return (size: NSMakeSize(frameSize.width, frameSize.height / 2), cols: 1, rows: 2)
                }
            } else {
                if size.width / size.height > 2 {
                    cols += Int(floor(size.width / size.height / 3.0))
                }
                
                var rows: Int = Int(ceil(Float(count) / Float(cols)))
                if floor(frameSize.height / CGFloat(rows)) <= minSize.height {
                    cols = Int(max(floor(frameSize.width / minSize.width), 2))
                    rows = Int(ceil(Float(count) / Float(cols)))
                    var height = minSize.height
                    if CGFloat(rows) * minSize.height < frameSize.height {
                        height = frameSize.height / CGFloat(rows)
                    }
                    return (size: NSMakeSize(frameSize.width / CGFloat(cols), height), cols: cols, rows: rows)
                }
                if floor(CGFloat(rows) * size.height) > floor(frameSize.height) {
                    size = NSMakeSize(frameSize.width / CGFloat(cols), frameSize.height / CGFloat(rows))
                } else {
                    size = NSMakeSize(frameSize.width / CGFloat(cols), frameSize.height / CGFloat(rows))
                    return (size: size, cols: cols, rows: rows)
                }
            }
        }
    }
    
    var data = optimalCellSize(frameSize, count: count)
    data.size = NSMakeSize(floor(data.size.width), floor(data.size.height))
    
    var point: CGPoint = .zero
    var index: Int = 0
    let inset: CGFloat = 5
    let insetSize = NSMakeSize(floor(CGFloat((data.cols - 1) * 5) / CGFloat(data.cols)), floor(CGFloat((data.rows - 1) * 5) / CGFloat(data.rows)))

    
    let firstIsSuperior = data.rows * data.cols > count && data.cols == 2
    
    if data.rows * data.cols > count && data.cols == 2 {
        tiles.append(.init(rect: CGRect(origin: point, size: CGSize(width: frameSize.width, height: data.size.height - insetSize.height)), index: index))
        point.y += (data.size.height - insetSize.height) + inset
        index += 1
    }
    
    for _ in 0 ..< data.rows {
        for _ in 0 ..< data.cols {
            if index < count {
                let size = (data.size - insetSize)
                tiles.append(.init(rect: CGRect(origin: point, size: size), index: index))
                point.x += size.width + inset
                index += 1
            }
        }
        point.x = 0
        point.y += data.size.height - insetSize.height + inset
    }
    
    let getPos:(Int) -> (col: Int, row: Int) = { index in
        
        if index == 0 {
            return (col: 0, row: 0)
        }
        
        let index = index
        
        let row = Int(floor(Float(index) / Float(data.cols)))
        
        
        if data.rows * data.cols > count && data.cols <= 2 {
            let col = (index - 1) % data.cols
            return (col: col, row: col == 0 ? row + 1 : row)
        } else {
            return (col: index % data.cols, row: row)
        }
    }
    
    if let pinnedIndex = pinnedIndex {
        let pinnedPos = getPos(pinnedIndex)
        for i in 0 ..< tiles.count {
            let pos = getPos(i)
            var tile = tiles[i]
            
            let farAway = (col: CGFloat(pos.col - pinnedPos.col), row: CGFloat(pos.row - pinnedPos.row))
            
            if i == pinnedIndex {
                tile.rect = frameSize.bounds
            } else {
                var x: CGFloat = 0
                var y: CGFloat = 0
                
                if i == 0 && firstIsSuperior {
                    x = 0
                } else {
                    x += farAway.col * frameSize.width
                    x += max(0, farAway.col - 1) * inset
                }
                y += farAway.row * frameSize.height
                y += max(0, farAway.row - 1) * inset

                tile.rect = CGRect(origin: CGPoint(x: x, y: y), size: frameSize)
            }
            tiles[i] = tile
        }
    }
    
    return tiles
}



private final class LimitView : View {
    
    private class V : NSVisualEffectView {
        override var mouseDownCanMoveWindow: Bool {
            return true
        }
    }
    
    private let effectView: NSVisualEffectView = V()
    private let textView = TextView()
    private let imageView = TransformImageView()
    private let thumbView = ImageView()

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
        addSubview(effectView)
        addSubview(textView)
        addSubview(thumbView)
        effectView.wantsLayer = true
        effectView.material = .dark
        effectView.blendingMode = .withinWindow
        if #available(OSX 10.12, *) {
            effectView.isEmphasized = true
        }
        effectView.state = .active
        
        textView.userInteractionEnabled = false
        textView.isSelectable = false
    }
    private var dimension: CGSize?
    func update(_ peer: Peer, size: NSSize, context: AccountContext) {
        let profileImageRepresentations:[TelegramMediaImageRepresentation]
        if let peer = peer as? TelegramChannel {
            profileImageRepresentations = peer.profileImageRepresentations
        } else if let peer = peer as? TelegramUser {
            profileImageRepresentations = peer.profileImageRepresentations
        } else if let peer = peer as? TelegramGroup {
            profileImageRepresentations = peer.profileImageRepresentations
        } else {
            profileImageRepresentations = []
        }
        
        let id = profileImageRepresentations.first?.resource.id.hashValue ?? Int(peer.id.toInt64())
        let media = TelegramMediaImage(imageId: MediaId(namespace: 0, id: MediaId.Id(id)), representations: profileImageRepresentations, immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
            
        
        if let dimension = profileImageRepresentations.last?.dimensions.size {
            self.dimension = dimension
            let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: dimension, boundingSize: size, intrinsicInsets: NSEdgeInsets())
            self.imageView.set(arguments: arguments)
            self.imageView.setSignal(signal: cachedMedia(media: media, arguments: arguments, scale: self.backingScaleFactor), clearInstantly: false)
            self.imageView.setSignal(chatMessagePhoto(account: context.account, imageReference: ImageMediaReference.standalone(media: media), peer: peer, scale: self.backingScaleFactor), clearInstantly: false, animate: false, cacheImage: { result in
                cacheMedia(result, media: media, arguments: arguments, scale: System.backingScale)
            })
            
            if let reference = PeerReference(peer) {
                _ = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: .avatar(peer: reference, resource: media.representations.last!.resource)).start()
            }
        } else {
            self.imageView.setSignal(signal: generateEmptyRoundAvatar(self.imageView.frame.size, font: .avatar(90.0), account: context.account, peer: peer) |> map { TransformImageResult($0, true) })
        }
        
        let config = GroupCallsConfig(context.appConfiguration)
        
        let layout = TextViewLayout(.initialize(string: L10n.voiceChatTooltipErrorVideoUnavailable(config.videoLimit), color: GroupCallTheme.customTheme.textColor, font: .medium(.text)))
        layout.measure(width: size.width - 40)
        textView.update(layout)
        
        thumbView.image = GroupCallTheme.video_limit
        thumbView.sizeToFit()
        needsLayout = true
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        
        if let dimension = self.dimension {
            let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: dimension, boundingSize: frame.size, intrinsicInsets: NSEdgeInsets())
            self.imageView.set(arguments: arguments)
        }
                
        effectView.frame = bounds
        imageView.frame = bounds
        thumbView.center()
        thumbView.setFrameOrigin(NSMakePoint(thumbView.frame.minX, thumbView.frame.minY - 20))
        
        textView.resize(frame.width - 40)
        textView.center()
        textView.setFrameOrigin(NSMakePoint(textView.frame.minX, textView.frame.minY + 20))

    }
}


final class GroupCallTileView: View {
    
    private struct TileEntry : Comparable, Identifiable {
        static func < (lhs: TileEntry, rhs: TileEntry) -> Bool {
            return lhs.index < rhs.index
        }
        var stableId: Int {
            return video.endpointId.hash
        }
        let video: DominantVideo
        let member: PeerGroupCallData
        let isFullScreen: Bool
        let isPinned: Bool
        let isFocused: Bool
        let resizeMode: CALayerContentsGravity
        let index: Int
        let alone: Bool
    }
    
    struct Transition {
        let size: NSSize
        let prevPinnedIndex: Int?
        let pinnedIndex: Int?
        let prevTiles:[VoiceChatTile]
        let tiles:[VoiceChatTile]
    }

    
    private var views: [GroupCallMainVideoContainerView] = []
    private var items:[TileEntry] = []
    private let call: PresentationGroupCall
    private var controlsMode: GroupCallView.ControlsMode = .normal
    private var arguments: GroupCallUIArguments? = nil
    private var prevState: GroupCallUIState?
    private var pinnedIndex: Int? = nil
    
    private var limitView: LimitView? = nil
    
    init(call: PresentationGroupCall, arguments: GroupCallUIArguments?, frame: NSRect) {
        self.call = call
        self.arguments = arguments
        super.init(frame: frame)
        self.layer?.cornerRadius = 10
    }
    
    func update(state: GroupCallUIState, context: AccountContext, transition: ContainedViewLayoutTransition, size: NSSize, animated: Bool, controlsMode: GroupCallView.ControlsMode) -> Transition {
        
                
        self.controlsMode = controlsMode
        
        var items:[TileEntry] = []
        
        let prevItems = self.items
        
        
        let prevTiles = tileViews(self.items.count, isFullscreen: prevState?.isFullScreen ?? state.isFullScreen, frameSize: frame.size, pinnedIndex: self.items.firstIndex(where: { $0.isPinned || $0.isFocused }))
        
        let prevTilesOpaque = tileViews(self.items.count, isFullscreen: prevState?.isFullScreen ?? state.isFullScreen, frameSize: frame.size, pinnedIndex: nil)

        
        let prevPinnedIndex = self.items.firstIndex(where: { $0.isPinned || $0.isFocused })

        
        let activeMembers = state.videoActive(.main)
        
        let activeVideos = state.activeVideoViews.filter { $0.mode == .main }
        
        for member in activeMembers {
            let endpoints:[String] = [member.presentationEndpoint, member.videoEndpoint].compactMap { $0 }
            for endpointId in endpoints {
                if let activeVideo = state.activeVideoViews.first(where: { $0.mode == .main && $0.endpointId == endpointId }) {
                    
                    let source: VideoSourceMacMode?
                    if member.videoEndpoint == endpointId {
                        source = .video
                    } else if member.presentationEndpoint == endpointId {
                        source = .screencast
                    } else {
                        source = nil
                    }
                    if let source = source {
                        
                        let pinVideo = state.dominantSpeaker?.endpointId == endpointId ? state.dominantSpeaker : nil
                        
                        let resizeMode: CALayerContentsGravity = state.isFullScreen ? .resizeAspect : .resizeAspectFill
                        
                        let video = DominantVideo(member.peer.id, endpointId, source, pinVideo?.pinMode)
                        items.append(.init(video: video, member: member, isFullScreen: state.isFullScreen, isPinned: pinVideo?.pinMode == .permanent, isFocused: pinVideo?.pinMode == .focused || activeVideos.count == 1, resizeMode: resizeMode, index: activeVideo.index, alone: activeVideos.count == 1))
                    }
                }
            }
        }
        
        
        
        let tiles = tileViews(items.count, isFullscreen: state.isFullScreen, frameSize: frame.size, pinnedIndex: self.pinnedIndex)
        
        
        let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: self.items, rightList: items)
        
        var deletedViews:[Int: GroupCallMainVideoContainerView] = [:]
        
        for rdx in deleteIndices.reversed() {
            deletedViews[rdx] = self.deleteItem(at: rdx, animated: animated)
            self.items.remove(at: rdx)
        }
        for (idx, item, pix) in indicesAndItems {
            var prevFrame: NSRect? = nil
            var prevView: GroupCallMainVideoContainerView? = nil
            if let pix = pix {
                prevFrame = prevTiles[pix].rect
                prevView = deletedViews[pix]
            }
            self.insertItem(item, at: idx, prevFrame: prevFrame, prevView: prevView, frame: tiles[idx].rect, animated: animated)
            self.items.insert(item, at: idx)
        }

        
        for (idx, item, prev) in updateIndices {
            let item =  item
            updateItem(item, at: idx, prevFrame: prev != idx ? prevTiles[prev].rect : nil, animated: animated)
            self.items[idx] = item
        }
        self.prevState = state
        self.pinnedIndex = self.items.firstIndex(where: { $0.isPinned || $0.isFocused })
        
        for (i, view) in views.enumerated() {
            if let pinnedIndex = pinnedIndex, i == pinnedIndex {
                view.layer?.zPosition = 1000
            } else {
                view.layer?.zPosition = CGFloat(i)
            }
        }
        
        let size = getSize(size)
        
        var update: Bool = false
        
        
        
        var prevPinnedId: String?
        if let prevPinnedIndex = prevPinnedIndex {
            prevPinnedId = prevItems[prevPinnedIndex].video.endpointId
        }
        
        var pinnedId: String?
        if let pinnedIndex = pinnedIndex {
            pinnedId = items[pinnedIndex].video.endpointId
        }
        
         if prevPinnedId != nil, pinnedId != nil, prevPinnedId != pinnedId {
            update = true
         } else if let pinnedId = pinnedId {
            let contains = prevItems.contains(where: { tile in
                tile.video.endpointId == pinnedId
            })
            if !contains {
                update = true
            }
         } else if pinnedId == nil, let prevPinnedId = prevPinnedId {
            let contains = items.contains(where: { tile in
                tile.video.endpointId == prevPinnedId
            })
            if !contains {
                update = true
            }
         }
        
        if update {
            updateLayout(size: size, transition: .immediate)
        }
        
        if tiles.isEmpty {
            let current: LimitView
            if let v = self.limitView {
                current = v
            } else {
                current = LimitView(frame: size.bounds)
                self.limitView = current
                addSubview(current)
                
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 2, duration: 0.2)
                }
            }
            current.update(state.peer, size: size, context: context)
        } else {
            if let view = self.limitView {
                self.limitView = nil
                if animated {
                    view.layer?.animateAlpha(from: 2, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak view] _ in
                        view?.removeFromSuperview()
                    })
                } else {
                    view.removeFromSuperview()
                }
            }
        }
        
        return Transition(size: size, prevPinnedIndex: prevPinnedIndex, pinnedIndex: pinnedIndex, prevTiles: prevTilesOpaque, tiles: tiles)
    }
    
    func getSize(_ size: NSSize) -> NSSize {
        
        let tiles = tileViews(items.count, isFullscreen: prevState?.isFullScreen ?? false, frameSize: size, pinnedIndex: pinnedIndex)
        
        if let tile = tiles.last, pinnedIndex == nil {
            if tile.rect.maxY - size.height < 4 {
                return NSMakeSize(size.width, size.height)
            } else {
                return NSMakeSize(size.width, tile.rect.maxY)
            }
        } else {
            if tiles.isEmpty {
                return NSMakeSize(size.width, 200)
            }
            return size
        }
    }
    
    private func deleteItem(at index: Int, animated: Bool) -> GroupCallMainVideoContainerView {
        let view = self.views.remove(at: index)
        
        if animated {
            view.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak view] completion in
                if completion {
                    view?.removeFromSuperview()
                }
            })
        } else {
            view.removeFromSuperview()
        }
        return view
    }
    private func insertItem(_ item: TileEntry, at index: Int, prevFrame: NSRect?, prevView: GroupCallMainVideoContainerView?, frame: NSRect, animated: Bool) {
        
        let view = prevView ?? GroupCallMainVideoContainerView(call: self.call)
        view.frame = prevFrame ?? frame
        prevView?.layer?.removeAllAnimations()
        if index == 0 {
            addSubview(view, positioned: .below, relativeTo: self.subviews.first)
        } else {
            addSubview(view, positioned: .above, relativeTo: self.subviews[index - 1])
        }
        
        view.updatePeer(peer: item.video, participant: item.member, resizeMode: item.resizeMode, transition: animated && prevView != nil ? .animated(duration: 0.2, curve: .easeInOut) : .immediate, animated: animated, controlsMode: self.controlsMode, isPinned: item.isPinned, isFocused: item.isFocused, isAlone: item.alone, arguments: self.arguments)
        view.updateLayout(size: view.frame.size, transition: .immediate)

        self.views.insert(view, at: index)
        
        if animated && prevFrame == nil {
            view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
         }
    }
    private func updateItem(_ item: TileEntry, at index: Int, prevFrame: NSRect?, animated: Bool) {
        if let prevFrame = prevFrame {
            self.views[index].frame = prevFrame
        }
        self.views[index].updatePeer(peer: item.video, participant: item.member, resizeMode: item.resizeMode, transition: animated ? .animated(duration: 0.2, curve: .easeInOut) : .immediate, animated: animated, controlsMode: self.controlsMode, isPinned: item.isPinned, isFocused: item.isFocused, isAlone: item.alone, arguments: self.arguments)
    }
    
    
    override func layout() {
        super.layout()
        self.updateLayout(size: frame.size, transition: .immediate)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {

        
        let tiles:[VoiceChatTile] = tileViews(items.count, isFullscreen: prevState?.isFullScreen ?? false, frameSize: size, pinnedIndex: pinnedIndex)
        
        
        for tile in tiles {
            transition.updateFrame(view: views[tile.index], frame: tile.rect)
            views[tile.index].updateLayout(size: tile.rect.size, transition: transition)
        }
        
        limitView?.frame = bounds
    }
    
    func makeTemporaryOffset(_ makeRect: (NSRect)->NSRect, pinnedIndex: Int?, size: NSSize) {
        let tiles:[VoiceChatTile] = tileViews(items.count, isFullscreen: prevState?.isFullScreen ?? false, frameSize: size, pinnedIndex: pinnedIndex)
        
        for tile in tiles {
            let rect = makeRect(tile.rect)
            views[tile.index].frame = rect
            views[tile.index].updateLayout(size: rect.size, transition: .immediate)
        }

    }
    
    func updateMode(controlsMode: GroupCallView.ControlsMode, controlsState: GroupCallControlsView.Mode, animated: Bool) {

        for view in views {
            view.updateMode(controlsMode: controlsMode, controlsState: controlsState, animated: animated)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    public override var mouseDownCanMoveWindow: Bool {
        return true
    }
}
