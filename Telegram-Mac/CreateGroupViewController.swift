//
//  CreateGroupViewController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 09/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac
import TGUIKit


fileprivate final class CreateGroupArguments {
    let context: AccountContext
    let choicePicture:(Bool)->Void
    let updatedText:(String)->Void
    init(context: AccountContext, choicePicture:@escaping(Bool)->Void, updatedText:@escaping(String)->Void) {
        self.context = context
        self.updatedText = updatedText
        self.choicePicture = choicePicture
    }
}

fileprivate enum CreateGroupEntry : Comparable, Identifiable {
    case info(Int32, String?, String, GeneralViewType)
    case peer(Int32, Peer, Int32, PeerPresence?, GeneralViewType)
    case section(Int32)
    fileprivate var stableId:AnyHashable {
        switch self {
        case .info:
            return -1
        case let .peer(_, peer, _, _, _):
            return peer.id
        case let .section(sectionId):
            return sectionId
        }
    }
    
    var index:Int32 {
        switch self {
        case let .info(sectionId, _, _, _):
            return (sectionId * 1000) + 0
        case let .peer(sectionId, _, index, _, _):
            return (sectionId * 1000) + index
        case let .section(sectionId):
             return (sectionId + 1) * 1000 - sectionId
        }
    }
}

fileprivate func ==(lhs:CreateGroupEntry, rhs:CreateGroupEntry) -> Bool {
    switch lhs {
    case let .info(section, photo, text, viewType):
        if case .info(section, photo, text, viewType) = rhs {
            return true
        } else {
            return false
        }
    case let .section(sectionId):
        if case .section(sectionId) = rhs {
            return true
        } else {
            return false
        }
    case let .peer(sectionId, lhsPeer, index, lhsPresence, viewType):
        if case .peer(sectionId, let rhsPeer, index, let rhsPresence, viewType) = rhs {
            if let lhsPresence = lhsPresence, let rhsPresence = rhsPresence {
                if !lhsPresence.isEqual(to: rhsPresence) {
                    return false
                }
            } else if (lhsPresence != nil) != (rhsPresence != nil) {
                return false
            }
            return lhsPeer.isEqual(rhsPeer)
        } else {
            return false
        }
    }
}

fileprivate func <(lhs:CreateGroupEntry, rhs:CreateGroupEntry) -> Bool {
    return lhs.index < rhs.index
}

struct CreateGroupResult {
    let title:String
    let picture: String?
    let peerIds:[PeerId]
}

fileprivate func prepareEntries(from:[AppearanceWrapperEntry<CreateGroupEntry>], to:[AppearanceWrapperEntry<CreateGroupEntry>], arguments: CreateGroupArguments, initialSize:NSSize, animated:Bool) -> Signal<TableUpdateTransition, NoError> {
    
    return Signal { subscriber in
        let (deleted,inserted,updated) = proccessEntriesWithoutReverse(from, right: to, { entry -> TableRowItem in
            
            switch entry.entry {
            case let .info(_, photo, currentText, viewType):
                return GroupNameRowItem(initialSize, stableId:entry.stableId, account: arguments.context.account, placeholder: L10n.createGroupNameHolder, photo: photo, viewType: viewType, text: currentText, limit:140, textChangeHandler: arguments.updatedText, pickPicture: arguments.choicePicture)
            case let .peer(_, peer, _, presence, viewType):
                
                var color:NSColor = theme.colors.grayText
                var string:String = L10n.peerStatusRecently
                if let presence = presence as? TelegramUserPresence {
                    let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                    (string, _, color) = stringAndActivityForUserPresence(presence, timeDifference: arguments.context.timeDifference, relativeTo: Int32(timestamp))
                }
                return  ShortPeerRowItem(initialSize, peer: peer, account: arguments.context.account, height:50, photoSize:NSMakeSize(36, 36), statusStyle: ControlStyle(foregroundColor: color), status: string, inset:NSEdgeInsets(left: 30, right:30), viewType: viewType)
            case .section:
                return GeneralRowItem(initialSize, height: 30, stableId: entry.stableId, viewType: .separator)
            }
        })
        
        let transition = TableUpdateTransition(deleted: deleted, inserted: inserted, updated:updated, animated:animated, state:.none(nil))
        
        subscriber.putNext(transition)
        subscriber.putCompletion()
        return EmptyDisposable
        
    }
    
}

private func createGroupEntries(_ view: MultiplePeersView, picture: String?, text: String, appearance: Appearance) -> [AppearanceWrapperEntry<CreateGroupEntry>] {
    
    
    
    var entries:[CreateGroupEntry] = []
    var sectionId:Int32 = 0
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    entries.append(.info(sectionId, picture, text, .singleItem))
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    var index:Int32 = 0
    let peers = view.peers.map({$1})
    for (i, peer) in peers.enumerated() {
        entries.append(.peer(sectionId, peer, index, view.presences[peer.id], bestGeneralViewType(peers, for: i)))
        index += 1
    }
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    return entries.map{AppearanceWrapperEntry(entry: $0, appearance: appearance)}
}


class CreateGroupViewController: ComposeViewController<CreateGroupResult, [PeerId], TableView> { // Title, photo path
    private let entries:Atomic<[AppearanceWrapperEntry<CreateGroupEntry>]> = Atomic(value:[])
    private let disposable:MetaDisposable = MetaDisposable()
    private let pictureValue = Promise<String?>(nil)
    private let textValue = ValuePromise<String>("", ignoreRepeated: true)

    private let defaultText: String
    
    init(titles: ComposeTitles, context: AccountContext, defaultText: String = "") {
        self.defaultText = defaultText
        super.init(titles: titles, context: context)
        self.textValue.set(self.defaultText)
    }
    
    override func restart(with result: ComposeState<[PeerId]>) {
        super.restart(with: result)
        assert(isLoaded())
        let initialSize = self.atomicSize
        let table = self.genericView
        let pictureValue = self.pictureValue
        let textValue = self.textValue
        

        let entries = self.entries
        let arguments = CreateGroupArguments(context: context, choicePicture: { select in
            if select {
                
                filePanel(with: photoExts, allowMultiple: false, canChooseDirectories: false, for: mainWindow, completion: { paths in
                    if let path = paths?.first, let image = NSImage(contentsOfFile: path) {
                        _ = (putToTemp(image: image, compress: true) |> deliverOnMainQueue).start(next: { path in
                            let controller = EditImageModalController(URL(fileURLWithPath: path), settings: .disableSizes(dimensions: .square))
                            showModal(with: controller, for: mainWindow)
                            pictureValue.set(controller.result |> map {Optional($0.0.path)})
                           
                            
                            controller.onClose = {
                                removeFile(at: path)
                            }
                        })
                    }
                })
                
            } else {
                pictureValue.set(.single(nil))
            }
            
        }, updatedText: { text in
            textValue.set(text)
        })
        
        let signal:Signal<TableUpdateTransition, NoError> = combineLatest(context.account.postbox.multiplePeersView(result.result) |> deliverOnPrepareQueue, appearanceSignal |> deliverOnPrepareQueue, pictureValue.get() |> deliverOnPrepareQueue, textValue.get() |> deliverOnPrepareQueue) |> mapToSignal { view, appearance, picture, text in
            let list = createGroupEntries(view, picture: picture, text: text, appearance: appearance)
           
            return prepareEntries(from: entries.swap(list), to: list, arguments: arguments, initialSize: initialSize.modify({$0}), animated: true)
            
        } |> deliverOnMainQueue
        
        
        disposable.set(signal.start(next: { (transition) in
            table.merge(with: transition)
            //table.reloadData()
        }))
    }
    
    override var canBecomeResponder: Bool {
        return true
    }
    
    override func becomeFirstResponder() -> Bool? {
        return true
    }
    
    override func firstResponder() -> NSResponder? {
        if let view = genericView.viewNecessary(at: 1) as? GroupNameRowView {
            return view.textView
        }
        return nil
    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        return .rejected
    }
    
    deinit {
        disposable.dispose()
        _ = entries.swap([])
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.getBackgroundColor = {
            theme.colors.listBackground
        }
        readyOnce()
    }
    
    override func executeNext() -> Void {
        if let previousResult = previousResult {
            let result = combineLatest(pictureValue.get() |> take(1), textValue.get() |> take(1)) |> map { value, text in
                return CreateGroupResult(title: text, picture: value, peerIds: previousResult.result)
            }
            onComplete.set(result |> filter {
                !$0.title.isEmpty
            })
        }
    }
    
    override func backKeyAction() -> KeyHandlerResult {
        return .invokeNext
    }
    
    
    
}
