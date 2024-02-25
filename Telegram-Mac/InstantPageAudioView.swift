//
//  InstantPageAudioItem.swift
//  Telegram
//
//  Created by keepcoder on 11/04/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import TelegramCore
import RangeSet
import SwiftSignalKit

final class InstantPageAudioView: View, InstantPageView, APDelegate {
    
    
    private let context: AccountContext
    let media: InstantPageMedia
    private var nameView: TextView?
    private let statusView: RadialProgressView = RadialProgressView()
    private let linearProgress: LinearProgressControl = LinearProgressControl(progressHeight: 3)
    private var bufferingStatusDisposable: MetaDisposable = MetaDisposable()
    private var ranges: (RangeSet<Int64>, Int64)?

    weak var controller:APController? {
        didSet {
            if let controller = controller {
                self.bufferingStatusDisposable.set((controller.bufferingStatus
                    |> deliverOnMainQueue).start(next: { [weak self] status in
                        if let status = status {
                            self?.updateStatus(status.0, status.1)
                        }
                    }))
                controller.add(listener: self)
            }
        }
    }
    
    private func updateStatus(_ ranges: RangeSet<Int64>, _ size: Int64) {
        self.ranges = (ranges, size)
        
        if let ranges = self.ranges, !ranges.0.isEmpty, ranges.1 != 0 {
            for range in ranges.0.ranges {
                var progress = (CGFloat(range.count) / CGFloat(ranges.1))
                progress = progress == 1.0 ? 0 : progress
                linearProgress.set(fetchingProgress: progress, animated: progress > 0)
                
                break
            }
        }
    }
    
    deinit {
        bufferingStatusDisposable.dispose()
    }
    
    init(context: AccountContext, media: InstantPageMedia) {
        self.context = context
        self.media = media
        super.init()
        addSubview(statusView)
        addSubview(linearProgress)
        linearProgress.style = ControlStyle(foregroundColor: theme.colors.text, backgroundColor: theme.colors.border, highlightColor: theme.colors.text)
        linearProgress.set(background: theme.colors.border, for: .Normal)
       
        let file = media.media as! TelegramMediaFile
        
        if file.isMusic {
            nameView = TextView()
            let attr = NSMutableAttributedString()
            _ = attr.append(string: file.musicText.1, color: theme.colors.text, font: .medium(.title))
            _ = attr.append(string: " - ", color: theme.colors.grayText, font: .normal(.title))
            _ = attr.append(string: file.musicText.0, color: theme.colors.grayText, font: .normal(.title))
            let nameLayout = TextViewLayout(attr, maximumNumberOfLines: 1)
            nameView?.update(nameLayout)
            addSubview(nameView!)
        }
        
        linearProgress.fetchingColor = theme.colors.grayText
        
        if let current = context.sharedContext.getAudioPlayer()?.currentSong {
            if current.entry.isEqual(to: self.wrapper) {
                context.sharedContext.getAudioPlayer()?.add(listener: self)
            }
        }
        statusView.state = .Icon(image: theme.icons.ivAudioPlay)
        linearProgress.set(progress: 0, animated:true)

    }
    
    var wrapper: APSingleWrapper {
        let file = self.media.media as! TelegramMediaFile
        return APSingleWrapper(resource: file.resource, name: nil, performer: nil, duration: file.duration, id: file.id ?? MediaId(namespace: 0, id: 0))
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        

        
        let insets = NSEdgeInsets(top: 18.0, left: 17.0, bottom: 18.0, right: 17.0)
        
        let leftInset: CGFloat = 46.0 + 10.0
        let rightInset: CGFloat = 0.0
        
        let maxTitleWidth = max(1.0, size.width - insets.left - leftInset - rightInset - insets.right)

        statusView.centerY(x: insets.left)
        
        let leftScrubberInset: CGFloat = insets.left + 46.0 + 10.0
        let rightScrubberInset: CGFloat = insets.right
        
        
        if let nameView = nameView {
            nameView.textLayout?.measure(width: maxTitleWidth)
            nameView.update(nameView.textLayout, origin: CGPoint(x: insets.left + leftInset, y: 5))
        }
        
        var topOffset: CGFloat = 0.0
        if nameView == nil {
            topOffset = -10.0
        }
        
        linearProgress.frame = CGRect(origin: CGPoint(x: leftScrubberInset, y: 26.0 + topOffset + 5), size: CGSize(width: size.width - leftScrubberInset - rightScrubberInset, height: 5))
        
    }
    
    func updateIsVisible(_ isVisible: Bool) {
        
    }
    
    func songDidChanged(song: APSongItem, for controller: APController, animated: Bool) {
        linearProgress.onUserChanged = { [weak controller, weak self] progress in
            controller?.set(trackProgress: progress)
            self?.linearProgress.set(progress: CGFloat(progress), animated: false)
        }
    }
    
    func songDidChangedState(song: APSongItem, for controller: APController, animated: Bool) {
        statusView.theme =  RadialProgressTheme(backgroundColor: .blackTransparent, foregroundColor: .white, icon: nil, blendMode: .copy)
        switch song.state {
        case .waiting, .paused:
            statusView.state = .Icon(image: theme.icons.ivAudioPlay)
        case .stoped:
            statusView.state = .Icon(image: theme.icons.ivAudioPlay)
            linearProgress.set(progress: 0, animated:true)
        case let .playing(_, _, progress):
            linearProgress.set(progress: CGFloat(progress), animated: animated)
            statusView.state = .Icon(image: theme.icons.ivAudioPause)
            break
        case .fetching:
            break
        }
    }
    
    func songDidStartPlaying(song: APSongItem, for controller: APController, animated: Bool) {
       
    }
    
    func songDidStopPlaying(song: APSongItem, for controller: APController, animated: Bool) {
        self.bufferingStatusDisposable.set(nil)
        statusView.state = .Icon(image: theme.icons.ivAudioPlay)
        linearProgress.set(progress: 0)
        linearProgress.set(fetchingProgress: 0)
        linearProgress.onUserChanged = nil
    }
    
    func playerDidChangedTimebase(song: APSongItem, for controller: APController, animated: Bool) {
        
    }
    
    func audioDidCompleteQueue(for controller: APController, animated: Bool) {
        
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
