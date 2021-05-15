//
//  GroupCallTileView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 10.05.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit

struct VoiceChatTile {
    let rect: NSRect
    let index: Int
    
    var bestQuality: PresentationGroupCallRequestedVideo.Quality {
        if rect.width > 480 || rect.height > 480 {
            return .full
        } else if rect.width > 160 || rect.height > 160 {
            return .medium
        } else {
            return .thumbnail
        }
    }
}


func tileViews(_ count: Int, windowSize: NSSize, frameSize: NSSize) -> [VoiceChatTile] {
    
    var tiles:[VoiceChatTile] = []
//    let minSize: NSSize = NSMakeSize(160, 100)
    
    func optimalCellSize(_ size: NSSize, count: Int) -> (size: NSSize, rows: Int, cols: Int) {
        var size: NSSize = frameSize
        var rows: Int = 2
        while true {
            if count == 0 {
                return (size: size, rows: 0, cols: 0)
            } else if count == 1 {
                return (size: size, rows: 1, cols: 1)
            } else if count == 2 {
                if windowSize.width < GroupCallTheme.fullScreenThreshold {
                    return (size: NSMakeSize(frameSize.width / 2, frameSize.height), rows: 2, cols: 1)
                } else {
                    return (size: NSMakeSize(frameSize.width, frameSize.height / 2), rows: 1, cols: 2)
                }
            } else {
                if size.width / size.height > 2 {
                    rows += 1
                }
                let cols: Int = Int(ceil(Float(count) / Float(rows)))
                if CGFloat(cols) * size.height > frameSize.height {
                    size = NSMakeSize(frameSize.width / CGFloat(rows), frameSize.height / CGFloat(cols))
                } else {
                    size = NSMakeSize(frameSize.width / CGFloat(rows), frameSize.height / CGFloat(cols))
                    return (size: size, rows: rows, cols: cols)
                }
            }
        }
    }
    
    let data = optimalCellSize(frameSize, count: count)
    
    
    var point: CGPoint = .zero
    var index: Int = 0
    
    let inset: CGFloat = 5
    
    let insetSize = NSMakeSize(CGFloat((data.rows - 1) * 5) / CGFloat(data.rows), CGFloat((data.cols - 1) * 5) / CGFloat(data.cols))

    
    if data.cols * data.rows > count && data.rows == 2 {
        tiles.append(.init(rect: CGRect(origin: point, size: CGSize(width: frameSize.width, height: data.size.height - insetSize.height)), index: index))
        point.y += (data.size.height - insetSize.height) + inset
        index += 1
    }
    

    for _ in 0 ..< data.cols {
        for _ in 0 ..< data.rows {
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

    return tiles
}



final class GroupCallTileView: View {
    
    private enum TileEntry : Comparable, Identifiable {
        static func < (lhs: TileEntry, rhs: TileEntry) -> Bool {
            return lhs.index < rhs.index
        }
        case video(DominantVideo, PeerGroupCallData, Bool, Bool, CALayerContentsGravity, Int)
        var index: Int {
            switch self {
            case let .video(_, _, _, _, _, index):
                return index
            }
        }
        
        var video: DominantVideo {
            switch self {
            case let .video(video, _, _ , _, _, _):
                return video
            }
        }
        var member: PeerGroupCallData {
            switch self {
            case let .video(_, member, _ , _, _, _):
                return member
            }
        }
        
        var stableId: Int {
            switch self {
            case let .video(video, _, _ , _, _, _):
                return video.endpointId.hash
            }
        }
        
        var isFullScreen: Bool {
            switch self {
            case let .video(_, _, isFullScreen, _, _, _):
                return isFullScreen
            }
        }
        var resizeMode: CALayerContentsGravity {
            switch self {
            case let .video(_, _, _, _, resizeMode, _):
                return resizeMode
            }
        }
        var isPinned: Bool {
            switch self {
            case let .video(_, _, _, isPinned, _, _):
                return isPinned
            }
        }
    }

    
    private var views: [GroupCallMainVideoContainerView] = []
    private var items:[TileEntry] = []
    private let call: PresentationGroupCall
    private var controlsMode: GroupCallView.ControlsMode = .normal
    private var arguments: GroupCallUIArguments? = nil
    init(call: PresentationGroupCall, arguments: GroupCallUIArguments?, frame: NSRect) {
        self.call = call
        self.arguments = arguments
        super.init(frame: frame)
    }
    
    func update(state: GroupCallUIState, transition: ContainedViewLayoutTransition, animated: Bool, controlsMode: GroupCallView.ControlsMode) {
        
        self.controlsMode = controlsMode
        
        var items:[TileEntry] = []
        var index: Int = 0
        
        
        guard let window = self.window as? Window else {
            return
        }
        
        let prevTiles = tileViews(self.items.count, windowSize: window.frame.size, frameSize: frame.size)

        for member in state.videoActive(.main) {
            let endpoints:[String] = [member.screencastEndpoint, member.videoEndpoint].compactMap { $0 }
            for endpointId in endpoints {
                if state.activeVideoViews.contains(where: { $0.mode == .main && $0.endpointId == endpointId }) {
                    let dominant = state.currentDominantSpeakerWithVideo
                    if dominant == nil || dominant?.endpointId == endpointId || dominant?.peerId == member.peer.id && !endpoints.contains(dominant!.endpointId) {
                        let source: VideoSourceMacMode?
                        if member.videoEndpoint == endpointId {
                            source = .video
                        } else if member.screencastEndpoint == endpointId {
                            source = .screencast
                        } else {
                            source = nil
                        }
                        if let source = source {
                            items.append(.video(DominantVideo(member.peer.id, endpointId, source, false), member, state.isFullScreen, state.currentDominantSpeakerWithVideo?.endpointId == endpointId, state.isFullScreen ? .resizeAspect : .resizeAspectFill, index))
                            index += 1
                        }
                    }
                }
            }
        }
        
        
        let tiles = tileViews(items.count, windowSize: window.frame.size, frameSize: frame.size)
        let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: self.items, rightList: items)
        for rdx in deleteIndices.reversed() {
            self.deleteItem(at: rdx, animated: animated)
            self.items.remove(at: rdx)
        }
        for (idx, item, pix) in indicesAndItems {
            var prevFrame: NSRect? = nil
            if let pix = pix {
                prevFrame = prevTiles[pix].rect
            }
            self.insertItem(item, at: idx, prevFrame: prevFrame, frame: tiles[idx].rect, animated: animated)
            self.items.insert(item, at: idx)
        }

        
        for (idx, item, _) in updateIndices {
            let item =  item
            updateItem(item, at: idx, animated: animated)
            self.items[idx] = item
        }
        
        updateLayout(size: frame.size, transition: transition)

    }
    
    private func deleteItem(at index: Int, animated: Bool) {
        let view = self.views.remove(at: index)
        
        if animated {
            view.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak view] _ in
                view?.removeFromSuperview()
            })
//            view.layer?.animateScaleSpring(from: 1, to: 0.1, duration: 0.4, removeOnCompletion: false, bounce: false)
        } else {
            view.removeFromSuperview()
        }
        
    }
    private func insertItem(_ item: TileEntry, at index: Int, prevFrame: NSRect?, frame: NSRect, animated: Bool) {
        
        let view = GroupCallMainVideoContainerView(call: self.call)
        view.frame = prevFrame ?? frame
        if index == 0 {
            addSubview(view, positioned: .below, relativeTo: self.subviews.first)
        } else {
            addSubview(view, positioned: .above, relativeTo: self.subviews[index - 1])
        }
        
        view.updatePeer(peer: item.video, participant: item.member, resizeMode: item.resizeMode, transition: .immediate, animated: animated, controlsMode: self.controlsMode, isFullScreen: item.isFullScreen, isPinned: item.isPinned, arguments: arguments)
        
        self.views.insert(view, at: index)
        
        if animated && prevFrame == nil {
            view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
         }
    }
    private func updateItem(_ item: TileEntry, at index: Int, animated: Bool) {
        self.views[index].updatePeer(peer: item.video, participant: item.member, resizeMode: item.resizeMode, transition: animated ? .animated(duration: 0.2, curve: .easeInOut) : .immediate, animated: animated, controlsMode: self.controlsMode, isFullScreen: item.isFullScreen, isPinned: item.isPinned, arguments: arguments)
    }
    
    
    override func layout() {
        super.layout()
        self.updateLayout(size: frame.size, transition: .immediate)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        
        guard let window = self.window as? Window else {
            return
        }
        
        let tiles = tileViews(items.count, windowSize: window.frame.size, frameSize: size)
        for tile in tiles {
            transition.updateFrame(view: views[tile.index], frame: tile.rect)
            views[tile.index].updateLayout(size: tile.rect.size, transition: transition)
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
}
