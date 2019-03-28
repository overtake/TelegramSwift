//
//  GalleryTouchBar.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 19/09/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac
import TGUIKit


@available(OSX 10.12.2, *)
private extension NSTouchBarItem.Identifier {
    static let zoomControls = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.gallery.zoom")
    static let rotate = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.gallery.rotate")

    static let videoPlayControl = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.gallery.videoPlayControl")
    static let videoTimeControls = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.gallery.videoTimeControls")
    static let scrubber = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.gallery.scrubber")
}

@available(OSX 10.12.2, *)
private class GalleryThumbsTouchBarItem: NSCustomTouchBarItem, NSScrubberDelegate, NSScrubberDataSource, NSScrubberFlowLayoutDelegate {
    
    private static let itemViewIdentifier = "GalleryTouchBarThumbItemView"
    
    private var entries: [MGalleryItem] = []
    private var selected:(MGalleryItem)->Void
    init(identifier: NSTouchBarItem.Identifier, selected:@escaping(MGalleryItem)->Void) {
        self.selected = selected
        super.init(identifier: identifier)
        
        let scrubber = TGScrubber()
        scrubber.register(GalleryTouchBarThumbItemView.self, forItemIdentifier: NSUserInterfaceItemIdentifier(rawValue: GalleryThumbsTouchBarItem.itemViewIdentifier))
        
        scrubber.mode = .free
        scrubber.selectionBackgroundStyle = .outlineOverlay
        scrubber.selectionOverlayStyle = .outlineOverlay
        scrubber.delegate = self
        scrubber.dataSource = self
        scrubber.isContinuous = true
        scrubber.floatsSelectionViews = false
        scrubber.itemAlignment = .center
        self.view = scrubber
    }
    
    var scrubber: NSScrubber {
        return view as! NSScrubber
    }
    
    func insertItem(_ item: MGalleryItem, at: Int) {
        let index = min(at, entries.count)
        entries.insert(item, at: index)
        scrubber.insertItems(at: IndexSet(integer: index))
    }
    func removeItem(at: Int) {
        if at < entries.count {
            entries.remove(at: at)
            scrubber.removeItems(at: IndexSet(integer: at))
        }
    }
    func updateItem(_ item: MGalleryItem, at: Int) {
        if at < entries.count {
            entries[at] = item
            scrubber.reloadItems(at: IndexSet(integer: at))
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var lockNotify: Bool = false
    func selectAndScroll(to item: MGalleryItem?) {
        Queue.mainQueue().justDispatch {
            if let first = self.entries.firstIndex(where: {$0.entry.stableId == item?.stableId}) {
                self.lockNotify = true
                self.scrubber.selectedIndex = first
            } else {
                self.scrubber.selectedIndex = -1
            }
        }
    }
    
    func numberOfItems(for scrubber: NSScrubber) -> Int {
        return entries.count
    }
    
    
    func scrubber(_ scrubber: NSScrubber, viewForItemAt index: Int) -> NSScrubberItemView {
        let view = scrubber.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: GalleryThumbsTouchBarItem.itemViewIdentifier), owner: nil) as! GalleryTouchBarThumbItemView
        view.update(entries[index])
        return view
    }
    
    func scrubber(_ scrubber: NSScrubber, layout: NSScrubberFlowLayout, sizeForItemAt itemIndex: Int) -> NSSize {
        return NSMakeSize(40, 30)
    }
    func scrubber(_ scrubber: NSScrubber, didHighlightItemAt highlightedIndex: Int) {
        
    }
    
    
    func scrubber(_ scrubber: NSScrubber, didSelectItemAt index: Int) {
        if let current = NSApp.currentEvent, current.window == nil {
            selected(entries[index])
        }
    }
    
}

@available(OSX 10.12.2, *)
class GalleryTouchBar: NSTouchBar, NSTouchBarDelegate {
    private let interactions: GalleryInteractions

    private var selectedItem: MGalleryItem?
    private let videoStatusDisposable = MetaDisposable()
    init(interactions: GalleryInteractions, selectedItemChanged: @escaping(@escaping(MGalleryItem) -> Void) ->Void, transition:@escaping(@escaping(UpdateTransition<MGalleryItem>, MGalleryItem?) -> Void) ->Void) {
        self.interactions = interactions
        super.init()
        self.customizationIdentifier = .windowBar
        self.delegate = self
        
        self.defaultItemIdentifiers = [.scrubber]
        
        
        transition { [weak self] transition, selectedItem in
            self?.applyTransition(transition, selectedItem)
        }
        selectedItemChanged { [weak self] selectedItem in
            self?.updateSelectedItem(selectedItem)
        }
    
        
    }
    
    private func applyTransition(_ transition: UpdateTransition<MGalleryItem>, _ selectedItem: MGalleryItem?) {
        guard let item = self.item(forIdentifier: .scrubber) as? GalleryThumbsTouchBarItem else {return}
        item.lockNotify = true
        //item.scrubber.performSequentialBatchUpdates { [weak item] in
            for rdx in transition.deleted.reversed() {
                item.removeItem(at: rdx)
            }
            for (idx, insertItem) in transition.inserted {
                item.insertItem(insertItem, at: idx)
            }
            for (idx, updateItem) in transition.updated {
                item.updateItem(updateItem, at: idx)
            }
       // }
        if !transition.isEmpty {
            item.scrubber.reloadData()
        }
        updateSelectedItem(selectedItem)
    }
    
    private func updateSelectedItem(_ item: MGalleryItem?) {
        if self.selectedItem?.entry != item?.entry {
            self.selectedItem = item
            //
            var items: [NSTouchBarItem.Identifier] = []
            if !(item is MGalleryGIFItem) && !(item is MGalleryVideoItem) {
                items.append(.zoomControls)
                items.append(.rotate)
            }
            if let item = item as? MGalleryVideoItem {
                items.append(.videoPlayControl)
                items.append(.videoTimeControls)
                videoStatusDisposable.set((item.playerState |> deliverOnMainQueue).start(next: { [weak self] state in
                    self?.updateVideoControls(state)
                }))
            } else {
                videoStatusDisposable.set(nil)
            }
            items.append(.fixedSpaceLarge)
            items.append(.scrubber)
            items.append(.fixedSpaceLarge)
            
            self.defaultItemIdentifiers = items
            
            (self.item(forIdentifier: .scrubber) as? GalleryThumbsTouchBarItem)?.selectAndScroll(to: item)
        }
    }
    
    private func updateVideoControls(_ state: AVPlayerState) {
        guard let button = (self.item(forIdentifier: .videoPlayControl) as? NSCustomTouchBarItem)?.view as? NSButton else {return}
        guard let segment = (self.item(forIdentifier: .videoTimeControls) as? NSCustomTouchBarItem)?.view as? NSSegmentedControl else {return}

        if let item = selectedItem as? MGalleryExternalVideoItem {
            switch ExternalVideoLoader.serviceType(item.content) {
            case .youtube:
                button.bezelColor = .redUI
            case .vimeo:
                button.bezelColor = .blueUI
            case .none:
                button.bezelColor = nil
            }
        } else {
            button.bezelColor = nil
        }
        switch state {
        case let .playing(duration):
            button.isEnabled = true
            button.image = NSImage(named: NSImage.touchBarPauseTemplateName)!
            segment.setEnabled(duration >= 30, forSegment: 0)
            segment.setEnabled(duration >= 30, forSegment: 1)
        case let .paused(duration):
            button.isEnabled = true
            button.image = NSImage(named: NSImage.touchBarPlayTemplateName)!
            
            segment.setEnabled(duration >= 30, forSegment: 0)
            segment.setEnabled(duration >= 30, forSegment: 1)
        default:
            button.isEnabled = false
            button.image = NSImage(named: NSImage.touchBarPlayTemplateName)!
            segment.setEnabled(false, forSegment: 0)
            segment.setEnabled(false, forSegment: 1)
        }
    }
    
    deinit {
        videoStatusDisposable.dispose()
    }
    

    @objc private func zoom(_ sender: Any?) {
        guard let segment = sender as? NSSegmentedControl else {return}
        switch segment.selectedSegment {
        case 0:
            interactions.zoomOut()
        case 1:
            interactions.zoomIn()
        default:
            break
        }
    }
    
    @objc private func rotate() {
        interactions.rotateLeft()
    }
    @objc private func videoTimeControlsActions(_ sender: Any?) {
        guard let segment = sender as? NSSegmentedControl else {return}
        if let item = selectedItem {
            switch segment.selectedSegment {
            case 0:
                item.rewindBack()
            case 1:
                item.rewindForward()
            default:
                break
            }
        }
    }
    
    @objc private func playOrPauseAction() {
        if let item = selectedItem {
            item.togglePlayerOrPause()
        }
    }
    
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case .zoomControls:
            let item = NSCustomTouchBarItem(identifier: identifier)
            
            let segment = NSSegmentedControl()
            segment.segmentStyle = .separated
            segment.segmentCount = 2
            segment.setImage(NSImage(named: NSImage.Name("Icon_TouchBar_ZoomOut"))!, forSegment: 0)
            segment.setImage(NSImage(named: NSImage.Name("Icon_TouchBar_ZoomIn"))!, forSegment: 1)
            
            segment.setWidth(93, forSegment: 0)
            segment.setWidth(93, forSegment: 1)
            
            segment.trackingMode = .momentary
            segment.target = self
            segment.action = #selector(zoom(_:))
            item.view = segment
            return item
        case .rotate:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(image: NSImage(named: NSImage.touchBarRotateLeftTemplateName)!, target: self, action: #selector(rotate))
            button.addWidthConstraint(size: 93)
            item.view = button
            item.customizationLabel = button.title
            return item
            
        case .videoTimeControls:
            let item = NSCustomTouchBarItem(identifier: identifier)
            
            let segment = NSSegmentedControl()
            segment.segmentStyle = .separated
            segment.segmentCount = 2
            segment.setImage(NSImage(named: NSImage.touchBarSkipBack15SecondsTemplateName)!, forSegment: 0)
            segment.setImage(NSImage(named: NSImage.touchBarSkipAhead15SecondsTemplateName)!, forSegment: 1)
            
            segment.setWidth(93, forSegment: 0)
            segment.setWidth(93, forSegment: 1)
            
            segment.trackingMode = .momentary
            segment.target = self
            segment.action = #selector(videoTimeControlsActions(_:))
            item.view = segment
            return item
        case .videoPlayControl:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(image:NSImage(named: NSImage.touchBarPlayTemplateName)!, target: self, action: #selector(playOrPauseAction))
            button.addWidthConstraint(size: 93)
            item.view = button
            item.customizationLabel = button.title
            return item
        case .scrubber:
            return GalleryThumbsTouchBarItem(identifier: identifier, selected: { [weak self] item in
                self?.interactions.select(item)
            })

        default:
            return nil
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
