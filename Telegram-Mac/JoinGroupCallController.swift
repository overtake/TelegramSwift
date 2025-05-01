
import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox

private func formattedJoinedMessage(from names: [String]) -> String {
    switch names.count {
    case 0:
        return strings().groupCallJoinNone
    case 1:
        return strings().groupCallJoinSingle(names[0])
    case 2:
        return strings().groupCallJoinDouble(names[0], names[0])
    default:
        let nameList = names.prefix(2)
        let othersCount = names.count - 2
        let othersWord = strings().groupCallJoinMultipleOthersCountable(othersCount)
        return strings().groupCallJoinMultiple(nameList[0], nameList[1], othersWord)
    }
}

private final class HeaderItem : GeneralRowItem {
    fileprivate let context: AccountContext
    fileprivate let headerLayout: TextViewLayout
    fileprivate let infoLayout: TextViewLayout
    fileprivate let usersInfoLayout: TextViewLayout
    fileprivate let participants: [EnginePeer]
    fileprivate let dismiss: ()->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, inviter: EnginePeer, participants: [EnginePeer], context: AccountContext, dismiss: @escaping()->Void) {
        self.context = context
        self.dismiss = dismiss
        self.participants = participants
        self.headerLayout = .init(.initialize(string: strings().callGroupCall, color: theme.colors.text, font: .medium(.header)), alignment: .center)
        self.infoLayout = .init(.initialize(string: strings().groupCallInviteLinksInvited, color: theme.colors.text, font: .normal(.text)).detectBold(with: .medium(.text)), alignment: .center)
        

        self.usersInfoLayout = .init(.initialize(string: formattedJoinedMessage(from: participants.map { $0._asPeer().compactDisplayTitle }), color: theme.colors.text, font: .normal(.text)).detectBold(with: .medium(.text)))
        
        super.init(initialSize, stableId: stableId)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.headerLayout.measure(width: width - 40)
        self.infoLayout.measure(width: width - 40)
        
        self.usersInfoLayout.measure(width: width - 40)

        return true
    }
    
    override var height: CGFloat {
        return 80 + 20 + headerLayout.layoutSize.height + 10 + infoLayout.layoutSize.height + 20 + 20 + 20 + usersInfoLayout.layoutSize.height + (participants.count > 0 ? 55 : 0) + 10
    }
    
    override func viewClass() -> AnyClass {
        return HeaderItemView.self
    }
}

private final class HeaderItemView: GeneralRowView {
    
    private let dismiss = ImageButton()
    private let headerView = TextView()
    private let infoView = TextView()
    private let separator = View()
    
    private let iconView = View(frame: NSMakeRect(0, 0, 80, 80))
    private let gradient = SimpleGradientLayer()
    private let stickerView = ImageView()

    private var avatars:[AvatarContentView] = []
    private let avatarsContainer = View(frame: NSMakeRect(0, 0, 30 * 3, 30))

    private struct Avatar : Comparable, Identifiable {
        static func < (lhs: Avatar, rhs: Avatar) -> Bool {
            return lhs.index < rhs.index
        }
        
        var stableId: PeerId {
            return peer.id
        }
        
        static func == (lhs: Avatar, rhs: Avatar) -> Bool {
            if lhs.index != rhs.index {
                return false
            }
            if !lhs.peer.isEqual(rhs.peer) {
                return false
            }
            return true
        }
        
        let peer: Peer
        let index: Int
    }
    
    private var peers:[Avatar] = []

    
    private let usersInfoView = TextView()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(dismiss)
        addSubview(headerView)
        addSubview(infoView)
        addSubview(separator)
        addSubview(usersInfoView)
        
        addSubview(avatarsContainer)
        avatarsContainer.isEventLess = true
        
        
        headerView.userInteractionEnabled = false
        infoView.userInteractionEnabled = false
        headerView.isSelectable = false
        infoView.isSelectable = false
        
        usersInfoView.userInteractionEnabled = false
        usersInfoView.isSelectable = false
        
        dismiss.set(image: theme.icons.modalClose, for: .Normal)
        dismiss.sizeToFit()
        
        dismiss.autohighlight = false
        dismiss.scaleOnClick = true
        
        addSubview(iconView)
        gradient.frame = iconView.bounds
        iconView.layer?.addSublayer(gradient)
        iconView.addSubview(stickerView)
        
        stickerView.image = NSImage(resource: .iconJoinGroupCall).precomposed(theme.colors.underSelectedColor)
        stickerView.sizeToFit()
        stickerView.center()


        iconView.layer?.cornerRadius = iconView.frame.height / 2
        

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? HeaderItem else {
            return
        }
        self.iconView.backgroundColor = theme.colors.accent
        self.headerView.update(item.headerLayout)
        self.infoView.update(item.infoLayout)
        
        self.usersInfoView.update(item.usersInfoLayout)
        
        self.separator.backgroundColor = theme.colors.border
        
        dismiss.setSingle(handler: { [weak item] _ in
            item?.dismiss()
        }, for: .SingleClick)
        
        
        let duration = Double(0.2)
        let timingFunction = CAMediaTimingFunctionName.easeOut
        
        
        let peers:[Avatar] = item.participants.prefix(3).reduce([], { current, value in
            var current = current
            current.append(.init(peer: value._asPeer(), index: current.count))
            return current
        })
                
        let (removed, inserted, updated) = mergeListsStableWithUpdates(leftList: self.peers, rightList: peers)
        
        let photoSize = NSMakeSize(35, 35)
        
        for removed in removed.reversed() {
            let control = avatars.remove(at: removed)
            let peer = self.peers[removed]
            let haveNext = peers.contains(where: { $0.stableId == peer.stableId })
            control.updateLayout(size: photoSize, isClipped: false, animated: animated)
            if animated && !haveNext {
                control.layer?.animateAlpha(from: 1, to: 0, duration: duration, timingFunction: timingFunction, removeOnCompletion: false, completion: { [weak control] _ in
                    control?.removeFromSuperview()
                })
                control.layer?.animateScaleSpring(from: 1.0, to: 0.2, duration: duration)
            } else {
                control.removeFromSuperview()
            }
        }
        for inserted in inserted {
            let control = AvatarContentView(context: item.context, peer: inserted.1.peer, message: nil, synchronousLoad: false, size: photoSize, inset: 15)
            control.updateLayout(size: photoSize, isClipped: inserted.0 != 0, animated: animated)
            control.userInteractionEnabled = false
            control.setFrameSize(photoSize)
            control.setFrameOrigin(NSMakePoint(CGFloat(inserted.0) * (photoSize.width - 20), 0))
            avatars.insert(control, at: inserted.0)
            avatarsContainer.subviews.insert(control, at: inserted.0)
            if animated {
                if let index = inserted.2 {
                    control.layer?.animatePosition(from: NSMakePoint(CGFloat(index) * (photoSize.width - 18), 0), to: control.frame.origin, timingFunction: timingFunction)
                } else {
                    control.layer?.animateAlpha(from: 0, to: 1, duration: duration, timingFunction: timingFunction)
                    control.layer?.animateScaleSpring(from: 0.2, to: 1.0, duration: duration)
                }
            }
        }
        for updated in updated {
            let control = avatars[updated.0]
            control.updateLayout(size: photoSize, isClipped: updated.0 != 0, animated: animated)
            let updatedPoint = NSMakePoint(CGFloat(updated.0) * (photoSize.width - 20), 0)
            if animated {
                control.layer?.animatePosition(from: control.frame.origin - updatedPoint, to: .zero, duration: duration, timingFunction: timingFunction, additive: true)
            }
            control.setFrameOrigin(updatedPoint)
        }
        var index: CGFloat = 10
        for control in avatarsContainer.subviews.compactMap({ $0 as? AvatarContentView }) {
            control.layer?.zPosition = index
            index -= 1
        }
        
        self.peers = peers
        
    }
    
    override func layout() {
        super.layout()
        iconView.centerX(y: 20)
        dismiss.setFrameOrigin(NSMakePoint(10, 10))
        
        self.headerView.centerX(y: iconView.frame.maxY + 20)
        self.infoView.centerX(y: self.headerView.frame.maxY + 10)
        
        separator.frame = NSMakeRect(20, self.infoView.frame.maxY + 10, frame.width - 40, .borderSize)
        
        usersInfoView.centerX(y: frame.height - 20 - usersInfoView.frame.height)
        
        
        var avatarRect = self.focus(NSMakeSize(avatarsContainer.subviews.max(by: { $0.frame.maxX < $1.frame.maxX })?.frame.maxX ?? 0, avatarsContainer.subviewsWidthSize.height))
        avatarRect.origin.y = usersInfoView.frame.minY - avatarRect.height - 20
        self.avatarsContainer.frame = avatarRect
        
    }
}

private final class Arguments {
    let context: AccountContext
    let dismiss:()->Void
    init(context: AccountContext, dismiss:@escaping()->Void) {
        self.context = context
        self.dismiss = dismiss
    }
}

private struct State : Equatable {
    var inviter: EnginePeer?
    var participants: [EnginePeer]
    var summary: GroupCallSummary
}


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    if let inviter = state.inviter {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("header"), equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return HeaderItem(initialSize, stableId: stableId, inviter: inviter, participants: state.participants, context: arguments.context, dismiss: arguments.dismiss)
        }))
    }
   
  
    // entries
//    
//    entries.append(.sectionId(sectionId, type: .normal))
//    sectionId += 1
    
    return entries
}

func JoinGroupCallController(context: AccountContext, summary: GroupCallSummary, reference: InternalGroupCallReference) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State(inviter: context.myPeer.flatMap(EnginePeer.init), participants: summary.topParticipants.compactMap { $0.peer }, summary: summary)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    var close:(()->Void)? = nil
    var getController:(()->ViewController?)? = nil
    
    var window:Window {
        get {
            return bestWindow(context, getController?())
        }
    }

    let arguments = Arguments(context: context, dismiss: {
        close?()
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "")
    
    getController = { [weak controller] in
        return controller
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    
    controller.validateData = { _ in
        
        _ = requestOrJoinConferenceCall(context: context, initialInfo: summary.info, reference: reference).startStandalone(next: { result in
            switch result {
            case let .samePeer(callContext), let .success(callContext):
                applyGroupCallResult(context.sharedContext, callContext)
            default:
                alert(for: context.window, info: strings().errorAnError)
            }
        })
        
        close?()
        
        return .none
    }

    let modalInteractions = ModalInteractions(acceptTitle: strings().groupCallJoinTitle, accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, singleButton: true, customTheme: {
        .init(background: theme.colors.background, listBackground: theme.colors.background)
    })
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
    
}


/*

 */



