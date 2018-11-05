//
//  PeerMediaTouchBar.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 04/10/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac

@available(OSX 10.12.2, *)
private func peerMediaTouchBarItems(presentation: ChatPresentationInterfaceState) -> [NSTouchBarItem.Identifier] {
    var items: [NSTouchBarItem.Identifier] = []
    items.append(.flexibleSpace)
    if presentation.selectionState != nil {
        items.append(.forward)
        items.append(.delete)
    } else {
        items.append(.segmentMedias)
    }
    items.append(.flexibleSpace)
    return items
}

@available(OSX 10.12.2, *)
private extension NSTouchBarItem.Identifier {
    static let segmentMedias = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.sharedMedia.segment")
    static let forward = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.sharedMedia.forward")
    static let delete = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.sharedMedia.delete")

}

@available(OSX 10.12.2, *)
class PeerMediaTouchBar: NSTouchBar, NSTouchBarDelegate, Notifable {
    
    private let modeDisposable = MetaDisposable()
    private let chatInteraction: ChatInteraction
    private let toggleMode: (PeerMediaCollectionMode) -> Void
    private var currentMode: PeerMediaCollectionMode = .photoOrVideo
    init(chatInteraction: ChatInteraction, currentMode: Signal<PeerMediaCollectionMode, NoError>, toggleMode: @escaping(PeerMediaCollectionMode) -> Void) {
        self.chatInteraction = chatInteraction
        self.toggleMode = toggleMode
        super.init()
        self.delegate = self
        chatInteraction.add(observer: self)
        self.defaultItemIdentifiers = peerMediaTouchBarItems(presentation: chatInteraction.presentation)
        modeDisposable.set(currentMode.start(next: { [weak self] mode in
            let view = ((self?.item(forIdentifier: .segmentMedias) as? NSCustomTouchBarItem)?.view as? NSSegmentedControl)
            view?.setSelected(true, forSegment: mode.rawValue)
            self?.currentMode = mode
        }))
    }
    
    private func updateUserInterface() {
        for identifier in itemIdentifiers {
            switch identifier {
            case .forward:
                let button = (item(forIdentifier: identifier) as? NSCustomTouchBarItem)?.view as? NSButton
                button?.bezelColor = chatInteraction.presentation.canInvokeBasicActions.forward ? theme.colors.blueUI : nil
                button?.isEnabled = chatInteraction.presentation.canInvokeBasicActions.forward
                
            case .delete:
                let button = (item(forIdentifier: identifier) as? NSCustomTouchBarItem)?.view as? NSButton
                button?.bezelColor = chatInteraction.presentation.canInvokeBasicActions.delete ? theme.colors.redUI : nil
                button?.isEnabled = chatInteraction.presentation.canInvokeBasicActions.delete
            case .segmentMedias:
                let view = ((item(forIdentifier: identifier) as? NSCustomTouchBarItem)?.view as? NSSegmentedControl)
                view?.setSelected(true, forSegment: self.currentMode.rawValue)
            default:
                break
            }
        }
    }
    
    deinit {
        chatInteraction.remove(observer: self)
        modeDisposable.dispose()
    }
    
    func isEqual(to other: Notifable) -> Bool {
        return false
    }
    
    func notify(with value: Any, oldValue: Any, animated: Bool) {
        if let value = value as? ChatPresentationInterfaceState {
            self.defaultItemIdentifiers = peerMediaTouchBarItems(presentation: value)
            updateUserInterface()
        }
    }
    
    @objc private func segmentMediasAction(_ sender: Any?) {
        if let sender = sender as? NSSegmentedControl {
            switch sender.selectedSegment {
            case 0:
                toggleMode(.photoOrVideo)
            case 1:
                toggleMode(.file)
            case 2:
                toggleMode(.webpage)
            case 3:
                toggleMode(.music)
            case 4:
                toggleMode(.voice)
            default:
                break
            }
        }
    }
    
    @objc private func forwardMessages() {
        chatInteraction.forwardSelectedMessages()
    }
    @objc private func deleteMessages() {
        chatInteraction.deleteSelectedMessages()
    }
    
    
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case .segmentMedias:
            let item = NSCustomTouchBarItem(identifier: identifier)
            
            let segment = NSSegmentedControl()
            segment.segmentStyle = .automatic
            segment.segmentCount = 5
            segment.setLabel(L10n.peerMediaMedia, forSegment: 0)
            segment.setLabel(L10n.peerMediaFiles, forSegment: 1)
            segment.setLabel(L10n.peerMediaLinks, forSegment: 2)
            segment.setLabel(L10n.peerMediaAudio, forSegment: 3)
            segment.setLabel(L10n.peerMediaVoice, forSegment: 4)

            segment.setWidth(93, forSegment: 0)
            segment.setWidth(93, forSegment: 1)
            segment.setWidth(93, forSegment: 2)
            segment.setWidth(93, forSegment: 3)
            segment.setWidth(93, forSegment: 4)

            segment.trackingMode = .selectOne
            segment.target = self
            segment.action = #selector(segmentMediasAction(_:))
            item.view = segment
            return item
        case .forward:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let icon = NSImage(named: NSImage.Name("Icon_TouchBar_MessagesForward"))!
            let button = NSButton(title: L10n.messageActionsPanelForward, image: icon, target: self, action: #selector(forwardMessages))
            button.addWidthConstraint(size: 160)
            button.bezelColor = theme.colors.blueUI
            button.imageHugsTitle = true
            button.isEnabled = chatInteraction.presentation.canInvokeBasicActions.forward
            item.view = button
            item.customizationLabel = button.title
            return item
        case .delete:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let icon = NSImage(named: NSImage.Name("Icon_TouchBar_MessagesDelete"))!
            let button = NSButton(title: L10n.messageActionsPanelDelete, image: icon, target: self, action: #selector(deleteMessages))
            button.addWidthConstraint(size: 160)
            button.bezelColor = theme.colors.redUI
            button.imageHugsTitle = true
            button.isEnabled = chatInteraction.presentation.canInvokeBasicActions.delete
            item.view = button
            item.customizationLabel = button.title
            return item
        default:
            return nil
        }
    }
    
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
