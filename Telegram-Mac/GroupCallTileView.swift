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
    fileprivate(set) var rect: NSRect
    fileprivate(set) var index: Int
    
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


func tileViews(_ count: Int, isFullscreen: Bool, frameSize: NSSize, pinnedIndex: Int? = nil) -> [VoiceChatTile] {
    
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
                if !isFullscreen {
                    return (size: NSMakeSize(frameSize.width / 2, frameSize.height), rows: 2, cols: 1)
                } else {
                    return (size: NSMakeSize(frameSize.width, frameSize.height / 2), rows: 1, cols: 2)
                }
            } else {
                if size.width / size.height > 2 {
                    rows += Int(floor(size.width / size.height / 3.0))
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

    
    let firstIsSuperior = data.cols * data.rows > count && data.rows == 2
    
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
    
    let getPos:(Int) -> (row: Int, col: Int) = { index in
        
        var index = index
        if data.cols * data.rows > count && data.rows == 2, index > 0 {
            index += 1
        }
        
        var col = Int(floor(Float(index) / Float(data.rows)))
        
        
        if col * data.rows - index > 0 {
            col += 1
        }
        
        
        return (row: data.rows - ((index + 1) % data.rows) - 1, col: col)
    }
    
    if let pinnedIndex = pinnedIndex {
        let pinnedPos = getPos(pinnedIndex)
        for i in 0 ..< tiles.count {
            let pos = getPos(i)
            var tile = tiles[i]
            
            let farAway = (row: CGFloat(pos.row - pinnedPos.row), col: CGFloat(pos.col - pinnedPos.col))
            
            if i == pinnedIndex {
                tile.rect = frameSize.bounds
            } else {
                var x: CGFloat = 0
                var y: CGFloat = 0
                
                if i == 0 && firstIsSuperior {
                    x = 0
                } else {
                    x += farAway.row * frameSize.width
                    x += max(0, farAway.row - 1) * inset
                }
                y += farAway.col * frameSize.height
                y += max(0, farAway.col - 1) * inset

                tile.rect = CGRect(origin: CGPoint(x: x, y: y), size: frameSize)
            }
            
            /*
             else if i < pinnedIndex {
                 if pos.col != pinnedPos.col {
                     tile.rect = tile.rect.offsetBy(dx: 0, dy: -tile.rect.maxY)
                 } else {
                     tile.rect = tile.rect.offsetBy(dx: -tile.rect.maxX, dy: 0)
                 }
             } else {
                 if pos.col != pinnedPos.col {
                     tile.rect = tile.rect.offsetBy(dx: 0, dy: frameSize.height - tile.rect.minY)
                 } else {
                     tile.rect = tile.rect.offsetBy(dx: frameSize.width - tile.rect.minX, dy: 0)
                 }
             }
             */
            
            tiles[i] = tile
        }
    }
    
    return tiles
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
    }

    
    private var views: [GroupCallMainVideoContainerView] = []
    private var items:[TileEntry] = []
    private let call: PresentationGroupCall
    private var controlsMode: GroupCallView.ControlsMode = .normal
    private var arguments: GroupCallUIArguments? = nil
    private var prevState: GroupCallUIState?
    private var pinnedIndex: Int? = nil
    init(call: PresentationGroupCall, arguments: GroupCallUIArguments?, frame: NSRect) {
        self.call = call
        self.arguments = arguments
        super.init(frame: frame)
        self.layer?.cornerRadius = 4
    }
    
    func update(state: GroupCallUIState, transition: ContainedViewLayoutTransition, animated: Bool, controlsMode: GroupCallView.ControlsMode) {
        
        self.controlsMode = controlsMode
        
        var items:[TileEntry] = []
        
//        let previousPinnedIndex = self.items.firstIndex(where: { $0.isPinned || $0.isFocused })

        
        let prevTiles = tileViews(self.items.count, isFullscreen: prevState?.isFullScreen ?? state.isFullScreen, frameSize: frame.size, pinnedIndex: self.items.firstIndex(where: { $0.isPinned }))
        
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
                        items.append(.init(video: video, member: member, isFullScreen: state.isFullScreen, isPinned: pinVideo?.pinMode == .permanent, isFocused: pinVideo?.pinMode == .focused || activeVideos.count == 1, resizeMode: resizeMode, index: activeVideo.index))
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
                
        
        updateLayout(size: frame.size, transition: transition)

        
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
        
        view.updatePeer(peer: item.video, participant: item.member, resizeMode: item.resizeMode, transition: animated && prevView != nil ? .animated(duration: 0.2, curve: .easeInOut) : .immediate, animated: animated, controlsMode: self.controlsMode, isPinned: item.isPinned, isFocused: item.isFocused, arguments: self.arguments)
        
        self.views.insert(view, at: index)
        
        if animated && prevFrame == nil {
            view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
         }
    }
    private func updateItem(_ item: TileEntry, at index: Int, prevFrame: NSRect?, animated: Bool) {
        if let prevFrame = prevFrame {
            self.views[index].frame = prevFrame
        }
        self.views[index].updatePeer(peer: item.video, participant: item.member, resizeMode: item.resizeMode, transition: animated ? .animated(duration: 0.2, curve: .easeInOut) : .immediate, animated: animated, controlsMode: self.controlsMode, isPinned: item.isPinned, isFocused: item.isFocused, arguments: self.arguments)
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
