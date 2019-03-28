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
    case info(String?, String)
    case peer(Peer, Int, PeerPresence?)
    
    fileprivate var stableId:AnyHashable {
        switch self {
        case .info:
            return Int32(0)
        case let .peer(peer, _, _):
            return peer.id
        }
    }
    
    var index:Int {
        switch self {
        case .info:
            return 0
        case let .peer(_, index, _):
            return index + 1
        }
    }
}

fileprivate func ==(lhs:CreateGroupEntry, rhs:CreateGroupEntry) -> Bool {
    switch lhs {
    case let .info(lhsPhoto, lhsText):
        if case let .info(rhsPhoto, rhsText) = rhs {
            return lhsPhoto == rhsPhoto && lhsText == rhsText
        } else {
            return false
        }
    case let .peer(lhsPeer,lhsIndex, lhsPresence):
        if case let .peer(rhsPeer,rhsIndex, rhsPresence) = rhs {
            if let lhsPresence = lhsPresence, let rhsPresence = rhsPresence {
                if !lhsPresence.isEqual(to: rhsPresence) {
                    return false
                }
         } else if (lhsPresence != nil) != (rhsPresence != nil) {
                return false
            }
            return lhsPeer.isEqual(rhsPeer) && lhsIndex == rhsIndex
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
            case let .info(photo, currentText):
                return GroupNameRowItem(initialSize, stableId:entry.stableId, account: arguments.context.account, placeholder: L10n.createGroupNameHolder, photo: photo, text: currentText, limit:140, textChangeHandler: arguments.updatedText, pickPicture: arguments.choicePicture)
            case let .peer(peer, _, presence):
                
                var color:NSColor = theme.colors.grayText
                var string:String = tr(L10n.peerStatusRecently)
                if let presence = presence as? TelegramUserPresence {
                    let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                    (string, _, color) = stringAndActivityForUserPresence(presence, timeDifference: arguments.context.timeDifference, relativeTo: Int32(timestamp))
                }
                return  ShortPeerRowItem(initialSize, peer: peer, account: arguments.context.account, height:50, photoSize:NSMakeSize(36, 36), statusStyle: ControlStyle(foregroundColor: color), status: string, inset:NSEdgeInsets(left: 30, right:30))
            }
        })
        
        let transition = TableUpdateTransition(deleted: deleted, inserted: inserted, updated:updated, animated:animated, state:.none(nil))
        
        subscriber.putNext(transition)
        subscriber.putCompletion()
        return EmptyDisposable
        
    }
    
}

private func createGroupEntries(_ view: MultiplePeersView, picture: String?, text: String, appearance: Appearance) -> [AppearanceWrapperEntry<CreateGroupEntry>] {
    
    var entries:[CreateGroupEntry] = [.info(picture, text)]
    var index:Int = 0
    for peer in view.peers.map({$1}) {
        entries.append(.peer(peer, index, view.presences[peer.id]))
        index += 1
    }
    return entries.map{AppearanceWrapperEntry(entry: $0, appearance: appearance)}
}


class CreateGroupViewController: ComposeViewController<CreateGroupResult, [PeerId], TableView> { // Title, photo path
    private let entries:Atomic<[AppearanceWrapperEntry<CreateGroupEntry>]> = Atomic(value:[])
    private let disposable:MetaDisposable = MetaDisposable()
    private let pictureValue = Promise<String?>(nil)
    private let textValue = ValuePromise<String>("", ignoreRepeated: true)

    
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
        if let view = genericView.viewNecessary(at: 0) as? GroupNameRowView {
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
        readyOnce()
    }
    
    override func executeNext() -> Void {
        if let previousResult = previousResult {
            let result = combineLatest(pictureValue.get() |> take(1), textValue.get() |> take(1)) |> map { value, text in
                return CreateGroupResult(title: text, picture: value, peerIds: previousResult.result)
            }
            onComplete.set(result)
        }
    }
    
    
    
}
