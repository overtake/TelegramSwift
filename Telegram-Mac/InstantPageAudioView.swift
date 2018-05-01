//
//  InstantPageAudioItem.swift
//  Telegram
//
//  Created by keepcoder on 11/04/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac

final class InstantPageAudioView: View, InstantPageView, APDelegate {
    
    
    private let account: Account
    let media: InstantPageMedia
    private var nameView: TextView?
    private let statusView: RadialProgressView = RadialProgressView()
    private let linearProgress: LinearProgressControl = LinearProgressControl(progressHeight: 3)
    private var bufferingStatusDisposable: MetaDisposable = MetaDisposable()
    private var ranges: (IndexSet, Int)?

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
    
    private func updateStatus(_ ranges: IndexSet, _ size: Int) {
        self.ranges = (ranges, size)
        
        if let ranges = self.ranges, !ranges.0.isEmpty, ranges.1 != 0 {
            for range in ranges.0.rangeView {
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
    
    init(account: Account, media: InstantPageMedia) {
        self.account = account
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
        
        if let current = globalAudio?.currentSong {
            if current.entry.isEqual(to: self.wrapper) {
                globalAudio?.add(listener: self)
            }
        }
        statusView.state = .Icon(image: theme.icons.ivAudioPlay, mode: .copy)
        linearProgress.set(progress: 0, animated:true)

    }
    
    var wrapper: APSingleWrapper {
        let file = self.media.media as! TelegramMediaFile
        return APSingleWrapper(resource: file.resource, name: nil, performer: nil, id: file.id ?? MediaId(namespace: 0, id: 0))
    }
    
    override func layout() {
        super.layout()
        statusView.centerY()
        linearProgress.setFrameSize(frame.width - statusView.frame.maxX - 10 - frame.minX * 2, 3)
        if let nameView = nameView {
            nameView.layout?.measure(width: frame.width - statusView.frame.maxX - 10 - frame.minX * 2)
            nameView.update(nameView.layout, origin: NSMakePoint(statusView.frame.maxX + 10, 12))
            linearProgress.setFrameOrigin(statusView.frame.maxX + 10, nameView.frame.maxY + 5)
        } else {
            linearProgress.centerY(x: statusView.frame.maxX + 10)
        }
    }
    
    func updateIsVisible(_ isVisible: Bool) {
        
    }
    
    func songDidChanged(song: APSongItem, for controller: APController) {
        linearProgress.onUserChanged = { [weak controller, weak self] progress in
            controller?.set(trackProgress: progress)
            self?.linearProgress.set(progress: CGFloat(progress), animated: false)
        }
    }
    
    func songDidChangedState(song: APSongItem, for controller: APController) {
        switch song.state {
        case .waiting, .paused:
            statusView.state = .Icon(image: theme.icons.ivAudioPlay, mode: .copy)
        case .stoped:
            statusView.state = .Icon(image: theme.icons.ivAudioPlay, mode: .copy)
            linearProgress.set(progress: 0, animated:true)
        case let .playing(data):
            linearProgress.set(progress: CGFloat(data.progress), animated: data.animated)
            statusView.state = .Icon(image: theme.icons.ivAudioPause, mode: .copy)
            break
        case .fetching:
            break
        }
    }
    
    func songDidStartPlaying(song: APSongItem, for controller: APController) {
       
    }
    
    func songDidStopPlaying(song: APSongItem, for controller: APController) {
        self.bufferingStatusDisposable.set(nil)
        statusView.state = .Icon(image: theme.icons.ivAudioPlay, mode: .copy)
        linearProgress.set(progress: 0)
        linearProgress.set(fetchingProgress: 0)
        linearProgress.onUserChanged = nil
    }
    
    func playerDidChangedTimebase(song: APSongItem, for controller: APController) {
        
    }
    
    func audioDidCompleteQueue(for controller: APController) {
        
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
